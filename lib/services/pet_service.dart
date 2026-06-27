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

    final document = await _firestore.collection('pets').add(
          petWithOwner.toFirestore(
            profilePhotoUrl: profilePhotoUrl,
            additionalImageUrls: additionalImageUrls,
          ),
        );

    return PetPublishResult(
      document: document,
      profilePhotoUrl: profilePhotoUrl,
      additionalImageUrls: additionalImageUrls,
    );
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
