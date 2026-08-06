import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pet_listing_data.dart';
import 'cloudinary_service.dart';
import 'user_session_service.dart';

class PetService {
  PetService._();

  static final PetService instance = PetService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudinaryService _cloudinary = CloudinaryService();

  Future<PetPublishResult> publishPet(
    PetListingData pet,
  ) async {
    final user = UserSessionService.instance.currentUser;

    if (user == null) {
      throw Exception('You must be logged in to publish a pet');
    }

    final purpose = _normalizeText(pet.purpose ?? '');
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
      profilePhotoUrl =
          await _cloudinary.uploadImage(pet.profilePhotoFile!) ?? '';
    }

    final additionalImageUrls = <String>[];

    for (final photo in pet.additionalPhotoFiles) {
      final url = await _cloudinary.uploadImage(photo);

      if (url != null) {
        additionalImageUrls.add(url);
      }
    }

    final petWithOwner = pet.copyWith(
      ownerId: user.uid,
      ownerName: userData?['fullName'] as String? ?? user.displayName ?? '',
      ownerPhoto: userData?['profilePhoto'] as String? ?? user.photoURL ?? '',
      healthRecords: await _uploadHealthRecords(pet.healthRecords),
    );

    final petData = petWithOwner.toFirestore(
      profilePhotoUrl: profilePhotoUrl,
      additionalImageUrls: additionalImageUrls,
    );

    final document = await _firestore.collection('pets').add({
      ...petData,
      'duplicateKey': duplicateKey,
      'normalizedName': _normalizeText(pet.name),
      'normalizedSpecies': _normalizeText(pet.species),
      'normalizedPurpose': purpose,
    });

    return PetPublishResult(
      document: document,
      profilePhotoUrl: profilePhotoUrl,
      additionalImageUrls: additionalImageUrls,
    );
  }

  Future<void> _ensureNoDuplicateActiveListing({
    required String ownerId,
    required String purpose,
    required String species,
    required String name,
  }) async {
    final normalizedName = _normalizeText(name);
    final normalizedSpecies = _normalizeText(species);

    if (normalizedName.isEmpty || purpose.isEmpty) return;

    final existingPets = await _firestore
        .collection('pets')
        .where('ownerId', isEqualTo: ownerId)
        .get();

    for (final document in existingPets.docs) {
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

      final isDuplicate = existingName == normalizedName &&
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

class PetPublishResult {
  final DocumentReference<Map<String, dynamic>> document;
  final String profilePhotoUrl;
  final List<String> additionalImageUrls;

  const PetPublishResult({
    required this.document,
    required this.profilePhotoUrl,
    required this.additionalImageUrls,
  });
}
