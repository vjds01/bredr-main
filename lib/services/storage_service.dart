import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadProfilePhoto({
    required String uid,
    required File? file,
  }) async {
    if (file == null) return null;

    debugPrint('Uploading profile photo: ${file.path}');
    
    final ref = _storage.ref().child(
      'users/$uid/profile_photo.jpg',
    );

    await ref.putFile(file);

    debugPrint('Profile photo uploaded');

    return await ref.getDownloadURL();
  }

  Future<List<String>> uploadAdditionalPhotos({
    required String uid,
    required List<File> files,
  }) async {
    List<String> urls = [];

    for (int i = 0; i < files.length; i++) {
      debugPrint('Uploading additional photo $i');

      final ref = _storage.ref().child(
        'users/$uid/additional/$i.jpg',
      );

      await ref.putFile(files[i]);

      debugPrint('Additional photo $i uploaded');

      urls.add(await ref.getDownloadURL());
    }

    return urls;
  }
}