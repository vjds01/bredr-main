import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pet_listing_data.dart';
import 'cloudinary_service.dart';
import 'pet_media_validation_service.dart';
import 'pet_eligibility_policy.dart';
import 'user_session_service.dart';
import 'health_verification_service.dart';

class PetService {
  PetService._();

  static final PetService instance = PetService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudinaryService _cloudinary = CloudinaryService();

  Future<void> setBreedingAvailability({
    required String petId,
    required bool available,
  }) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) throw StateError('You must be logged in first.');

    final petReference = _firestore.collection('pets').doc(petId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(petReference);
      final data = snapshot.data();
      if (data == null) {
        throw StateError('This pet profile could not be found.');
      }
      if (data['ownerId'] != user.uid) {
        throw StateError('Only the pet owner can change this listing.');
      }
      final purpose = _normalizeText(
        (data['normalizedPurpose'] ?? data['purpose'] ?? '').toString(),
      );
      if (purpose != 'breeding') {
        throw StateError('Only breeding listings can be changed here.');
      }

      transaction.update(petReference, {
        'status': available ? 'published' : 'paused',
        'isActive': available,
        'breedingAvailability': available ? 'available' : 'offline',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> relistReturnedPetForAdoption(String petId) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to publish a pet');
    }
    final petRef = _firestore.collection('pets').doc(petId);
    final listingCycleId = DateTime.now().microsecondsSinceEpoch.toString();
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(petRef);
      final data = snapshot.data();
      if (data == null) {
        throw Exception('This pet profile could not be found.');
      }
      if (data['ownerId'] != user.uid) {
        throw Exception('Only the pet owner can publish this profile.');
      }
      if (data['status'] != 'unpublished' ||
          data['adoptionStatus'] != 'returned') {
        throw Exception('This returned pet is not ready to be relisted.');
      }
      transaction.update(petRef, {
        'purpose': 'adoption',
        'normalizedPurpose': 'adoption',
        'status': 'published',
        'adoptionStatus': 'active',
        'listingCycleId': listingCycleId,
        'isActive': true,
        'reservedFor': FieldValue.delete(),
        'approvedRequestId': FieldValue.delete(),
        'adoptionRequestId': FieldValue.delete(),
        'adoptionConversationId': FieldValue.delete(),
        'adoptedBy': FieldValue.delete(),
        'adoptedAt': FieldValue.delete(),
        'relistedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<PetPublishResult> publishPet(PetListingData pet) async {
    final user = UserSessionService.instance.currentUser;

    if (user == null) {
      throw Exception('You must be logged in to publish a pet');
    }

    final purpose = _normalizeText(pet.purpose ?? '');
    final age = PetAgeValue.tryParse(pet.age);
    if (age == null) {
      throw const PetListingUpdateException('Please select a valid pet age.');
    }
    final eligibility = PetEligibilityPolicy.validate(
      purpose: purpose,
      age: age,
      gender: pet.gender,
      breedSize: pet.breedSize,
      petName: pet.name,
    );
    if (eligibility != null) {
      throw PetListingUpdateException(eligibility.message);
    }
    final questionError = PetEligibilityPolicy.validateInterviewQuestions(
      pet.interviewQuestions.map((question) => question.toMap()).toList(),
    );
    if (questionError != null) throw PetListingUpdateException(questionError);
    final duplicateKey = _duplicateKey(
      ownerId: user.uid,
      purpose: purpose,
      species: pet.species,
      name: pet.name,
    );

    await _ensureNoDuplicateActiveListing(
      ownerId: user.uid,
      purpose: purpose,
      species: pet.species,
      name: pet.name,
    );

    final profile = await UserSessionService.instance.getCurrentUserProfile();
    final userData = profile?.data();

    String profilePhotoUrl = '';

    if (pet.profilePhotoFile != null) {
      final photo = pet.profilePhotoFile!;
      if (!PetMediaValidation.isImagePath(photo.path) ||
          !PetMediaValidation.isImageSizeAllowed(await photo.length())) {
        throw const CloudinaryUploadException(
          'The profile photo must be a JPG or PNG image no larger than 5 MB.',
        );
      }
      profilePhotoUrl = await _cloudinary.uploadImageOrThrow(photo);
    }

    final additionalImageUrls = <String>[];

    for (final photo in pet.additionalPhotoFiles) {
      if (!PetMediaValidation.isImagePath(photo.path) ||
          !PetMediaValidation.isImageSizeAllowed(await photo.length())) {
        throw const CloudinaryUploadException(
          'Each additional photo must be a JPG or PNG image no larger than 5 MB.',
        );
      }
      additionalImageUrls.add(await _cloudinary.uploadImageOrThrow(photo));
    }

    final additionalVideoUrls = <String>[];
    for (final video in pet.additionalVideoFiles) {
      if (!PetMediaValidation.isMp4Path(video.path)) {
        throw const CloudinaryUploadException(
          'Only MP4 videos can be uploaded.',
        );
      }
      if (!PetMediaValidation.isVideoSizeAllowed(await video.length())) {
        throw const CloudinaryUploadException(
          'Videos must be 50 MB or smaller.',
        );
      }
      additionalVideoUrls.add(await _cloudinary.uploadVideoOrThrow(video));
    }

    final petWithOwner = pet.copyWith(
      ownerId: user.uid,
      ownerName: userData?['fullName'] as String? ?? user.displayName ?? '',
      ownerPhoto: userData?['profilePhoto'] as String? ?? user.photoURL ?? '',
      healthRecords: await _uploadHealthRecords(pet.healthRecords),
      breedingPreferredGender: PetEligibilityPolicy.oppositeGender(pet.gender),
    );

    final petData = petWithOwner.toFirestore(
      profilePhotoUrl: profilePhotoUrl,
      additionalImageUrls: additionalImageUrls,
      additionalVideoUrls: additionalVideoUrls,
    );

    final document = _firestore.collection('pets').doc();
    final publicationKey = _firestore
        .collection('petPublicationKeys')
        .doc(_publicationKeyId(duplicateKey));
    await _firestore.runTransaction((transaction) async {
      final keySnapshot = await transaction.get(publicationKey);
      final existingPetId = keySnapshot.data()?['petId'] as String?;

      if (existingPetId != null && existingPetId.isNotEmpty) {
        final existingPet = await transaction.get(
          _firestore.collection('pets').doc(existingPetId),
        );
        final status = _normalizeText(
          (existingPet.data()?['status'] ?? '').toString(),
        );
        if (existingPet.exists && !_isTerminalPetStatus(status)) {
          throw DuplicatePetListingException(pet.name);
        }
      }

      transaction.set(document, {
        ...petData,
        'duplicateKey': duplicateKey,
        'normalizedName': _normalizeText(pet.name),
        'normalizedSpecies': _normalizeText(pet.species),
        'normalizedPurpose': purpose,
      });
      transaction.set(publicationKey, {
        'ownerId': user.uid,
        'petId': document.id,
        'duplicateKey': duplicateKey,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    await HealthVerificationService.instance.requestForPublishedPet(
      petId: document.id,
      petName: pet.name,
      records: (petData['healthRecords'] as List? ?? const [])
          .map((value) => Map<String, dynamic>.from(value as Map))
          .toList(),
    );

    return PetPublishResult(
      document: document,
      profilePhotoUrl: profilePhotoUrl,
      additionalImageUrls: additionalImageUrls,
      additionalVideoUrls: additionalVideoUrls,
    );
  }

  Future<void> updatePetListing({
    required String petId,
    required Map<String, dynamic> editableFields,
    required String originalPurpose,
    File? newProfilePhoto,
    required String existingProfilePhotoUrl,
    required List<String> existingImageUrls,
    required List<String> existingVideoUrls,
    List<File> newImageFiles = const [],
    List<File> newVideoFiles = const [],
  }) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) throw StateError('You must be logged in first.');

    final purpose = _normalizeText(originalPurpose);
    final gender = (editableFields['gender'] ?? '').toString();
    final age = PetAgeValue.tryParse((editableFields['age'] ?? '').toString());
    if (age == null) {
      throw const PetListingUpdateException('Please select a valid pet age.');
    }
    final eligibility = PetEligibilityPolicy.validate(
      purpose: purpose,
      age: age,
      gender: gender,
      breedSize: (editableFields['breedSize'] ?? '').toString(),
      petName: (editableFields['name'] ?? 'This pet').toString(),
    );
    if (eligibility != null) {
      throw PetListingUpdateException(eligibility.message);
    }
    if (purpose == 'breeding') {
      final preferences = Map<String, dynamic>.from(
        editableFields['breedingPreferences'] as Map? ?? const {},
      );
      preferences['preferredGender'] = PetEligibilityPolicy.oppositeGender(
        gender,
      );
      editableFields['breedingPreferences'] = preferences;
    }
    final questions =
        (editableFields['interviewQuestions'] as List? ?? const [])
            .whereType<Map>()
            .map((question) => Map<String, dynamic>.from(question))
            .toList();
    final questionError = PetEligibilityPolicy.validateInterviewQuestions(
      questions,
    );
    if (questionError != null) throw PetListingUpdateException(questionError);
    final name = (editableFields['name'] ?? '').toString().trim();
    final species = (editableFields['species'] ?? '').toString().trim();
    if (name.isEmpty || species.isEmpty || purpose.isEmpty) {
      throw const PetListingUpdateException(
        'The pet name, species, and listing purpose are required.',
      );
    }

    final allImages = <File>[?newProfilePhoto, ...newImageFiles];
    for (final image in allImages) {
      if (!PetMediaValidation.isImagePath(image.path)) {
        throw const PetListingUpdateException(
          'Only JPG, JPEG, and PNG images can be uploaded.',
        );
      }
      if (!PetMediaValidation.isImageSizeAllowed(await image.length())) {
        throw const PetListingUpdateException(
          'Each image must be 5 MB or smaller.',
        );
      }
    }
    for (final video in newVideoFiles) {
      if (!PetMediaValidation.isMp4Path(video.path)) {
        throw const PetListingUpdateException(
          'Only MP4 videos can be uploaded.',
        );
      }
      if (!PetMediaValidation.isVideoSizeAllowed(await video.length())) {
        throw const PetListingUpdateException(
          'Videos must be 50 MB or smaller.',
        );
      }
    }

    final imageCount = existingImageUrls.length + newImageFiles.length;
    final videoCount = existingVideoUrls.length + newVideoFiles.length;
    if (imageCount + videoCount > 10) {
      throw const PetListingUpdateException(
        'You can upload up to 10 additional photos or videos.',
      );
    }
    if (videoCount > 0 && imageCount == 0) {
      throw const PetListingUpdateException(
        'Add a cover photo before adding pet videos.',
      );
    }

    final petReference = _firestore.collection('pets').doc(petId);
    final initialSnapshot = await petReference.get();
    final initialData = initialSnapshot.data();
    if (initialData == null) {
      throw const PetListingUpdateException(
        'This pet profile could not be found.',
      );
    }
    _validateEditableListing(initialData, user.uid, purpose);

    await _ensureNoDuplicateActiveListing(
      ownerId: user.uid,
      purpose: purpose,
      species: species,
      name: name,
      excludePetId: petId,
    );

    var profilePhotoUrl = existingProfilePhotoUrl.trim();
    if (newProfilePhoto != null) {
      profilePhotoUrl = await _cloudinary.uploadImageOrThrow(newProfilePhoto);
    }
    final imageUrls = <String>[...existingImageUrls];
    for (final image in newImageFiles) {
      imageUrls.add(await _cloudinary.uploadImageOrThrow(image));
    }
    final videoUrls = <String>[...existingVideoUrls];
    for (final video in newVideoFiles) {
      videoUrls.add(await _cloudinary.uploadVideoOrThrow(video));
    }

    final cleanImages = PetMediaValidation.uniqueAdditionalUrls(
      imageUrls,
      exclude: profilePhotoUrl,
    );
    final cleanVideos = PetMediaValidation.uniqueAdditionalUrls(videoUrls);
    final duplicateKey = _duplicateKey(
      ownerId: user.uid,
      purpose: purpose,
      species: species,
      name: name,
    );
    final newPublicationKey = _firestore
        .collection('petPublicationKeys')
        .doc(_publicationKeyId(duplicateKey));

    await _firestore.runTransaction((transaction) async {
      final currentSnapshot = await transaction.get(petReference);
      final currentData = currentSnapshot.data();
      if (currentData == null) {
        throw const PetListingUpdateException(
          'This pet profile could not be found.',
        );
      }
      _validateEditableListing(currentData, user.uid, purpose);

      final keySnapshot = await transaction.get(newPublicationKey);
      final claimedPetId = keySnapshot.data()?['petId'] as String?;
      if (claimedPetId != null && claimedPetId != petId) {
        final claimedPet = await transaction.get(
          _firestore.collection('pets').doc(claimedPetId),
        );
        final claimedStatus = _normalizeText(
          (claimedPet.data()?['status'] ?? '').toString(),
        );
        if (claimedPet.exists && !_isTerminalPetStatus(claimedStatus)) {
          throw DuplicatePetListingException(name);
        }
      }

      final oldDuplicateKey = _textValue(currentData['duplicateKey']);
      DocumentReference<Map<String, dynamic>>? oldPublicationKey;
      DocumentSnapshot<Map<String, dynamic>>? oldKeySnapshot;
      if (oldDuplicateKey.isNotEmpty && oldDuplicateKey != duplicateKey) {
        oldPublicationKey = _firestore
            .collection('petPublicationKeys')
            .doc(_publicationKeyId(oldDuplicateKey));
        oldKeySnapshot = await transaction.get(oldPublicationKey);
      }

      transaction.update(petReference, {
        ...editableFields,
        'normalizedName': _normalizeText(name),
        'normalizedSpecies': _normalizeText(species),
        'duplicateKey': duplicateKey,
        'petProfilePhoto': profilePhotoUrl,
        'additionalImages': cleanImages,
        'additionalVideos': cleanVideos,
        'hasProfilePhoto': profilePhotoUrl.isNotEmpty,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (oldPublicationKey != null &&
          oldKeySnapshot?.data()?['petId'] == petId) {
        transaction.delete(oldPublicationKey);
      }
      transaction.set(newPublicationKey, {
        'ownerId': user.uid,
        'petId': petId,
        'duplicateKey': duplicateKey,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  void _validateEditableListing(
    Map<String, dynamic> data,
    String userId,
    String originalPurpose,
  ) {
    if (data['ownerId'] != userId) {
      throw const PetListingUpdateException(
        'Only the pet owner can edit this listing.',
      );
    }
    if (data['adminRemoved'] == true ||
        _normalizeText((data['adminListingStatus'] ?? '').toString()) ==
            'removed') {
      throw const PetListingUpdateException(
        'A listing removed by an administrator cannot be edited.',
      );
    }
    final status = _normalizeText((data['status'] ?? '').toString());
    if (status == 'adopted' || status == 'removed' || status == 'deleted') {
      throw const PetListingUpdateException(
        'This pet listing can no longer be edited.',
      );
    }
    final currentPurpose = _normalizeText(
      (data['normalizedPurpose'] ?? data['purpose'] ?? '').toString(),
    );
    if (currentPurpose != originalPurpose) {
      throw const PetListingUpdateException(
        'The listing purpose changed while you were editing. Please reopen it.',
      );
    }
  }

  Future<void> _ensureNoDuplicateActiveListing({
    required String ownerId,
    required String purpose,
    required String species,
    required String name,
    String? excludePetId,
  }) async {
    final normalizedName = _normalizeText(name);
    final normalizedSpecies = _normalizeText(species);

    if (normalizedName.isEmpty || purpose.isEmpty) return;

    final existingPets = await _firestore
        .collection('pets')
        .where('ownerId', isEqualTo: ownerId)
        .get();

    for (final document in existingPets.docs) {
      if (document.id == excludePetId) continue;
      final data = document.data();
      final existingName = _normalizeText(
        (data['normalizedName'] ?? data['name'] ?? '').toString(),
      );
      final existingSpecies = _normalizeText(
        (data['normalizedSpecies'] ?? data['species'] ?? '').toString(),
      );
      final existingPurpose = _normalizeText(
        (data['normalizedPurpose'] ?? data['purpose'] ?? '').toString(),
      );
      final status = _normalizeText((data['status'] ?? '').toString());

      if (_isTerminalPetStatus(status)) continue;

      final isDuplicate =
          existingName == normalizedName &&
          existingSpecies == normalizedSpecies &&
          existingPurpose == purpose;

      if (isDuplicate) {
        throw DuplicatePetListingException(name);
      }
    }
  }

  bool _isTerminalPetStatus(String status) {
    return {
      'adopted',
      'matched',
      'removed',
      'inactive',
      'archived',
      'deleted',
    }.contains(status);
  }

  String _duplicateKey({
    required String ownerId,
    required String purpose,
    required String species,
    required String name,
  }) {
    return [
      ownerId,
      _normalizeText(purpose),
      _normalizeText(species),
      _normalizeText(name),
    ].join('|');
  }

  String _normalizeText(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _textValue(dynamic value) => value?.toString().trim() ?? '';

  String _publicationKeyId(String duplicateKey) {
    return base64Url.encode(utf8.encode(duplicateKey)).replaceAll('=', '');
  }

  Future<List<PetHealthRecordData>> _uploadHealthRecords(
    List<PetHealthRecordData> records,
  ) async {
    final uploaded = <PetHealthRecordData>[];

    for (final record in records) {
      if (record.file == null) {
        uploaded.add(record);
        continue;
      }

      final url = await _cloudinary.uploadImage(record.file!);

      uploaded.add(record.copyWith(fileUrl: url ?? ''));
    }

    return uploaded;
  }
}

class DuplicatePetListingException implements Exception {
  final String petName;

  const DuplicatePetListingException(this.petName);

  @override
  String toString() => 'Duplicate active pet listing: $petName';
}

class PetListingUpdateException implements Exception {
  final String message;

  const PetListingUpdateException(this.message);

  @override
  String toString() => message;
}

class PetPublishResult {
  final DocumentReference<Map<String, dynamic>> document;
  final String profilePhotoUrl;
  final List<String> additionalImageUrls;
  final List<String> additionalVideoUrls;

  const PetPublishResult({
    required this.document,
    required this.profilePhotoUrl,
    required this.additionalImageUrls,
    this.additionalVideoUrls = const [],
  });
}
