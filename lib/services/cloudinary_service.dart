import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CloudinaryUploadException implements Exception {
  final String message;
  final int? statusCode;

  const CloudinaryUploadException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class CloudinaryService {
  static const String cloudName = 'dfzwbn5tk';
  static const String uploadPreset = 'breedr_upload';

  Future<String?> uploadImage(File file) async {
    try {
      return await uploadImageOrThrow(file);
    } catch (e) {
      debugPrint('Cloudinary error: $e');
      return null;
    }
  }

  Future<String> uploadImageOrThrow(File file) async {
    return _uploadOrThrow(file, resourceType: 'image', noun: 'photo');
  }

  Future<String> uploadEvidenceOrThrow(File file) async {
    if (_isPdf(file)) {
      return _uploadPdfEvidenceToStorage(file);
    }
    return _uploadOrThrow(file, resourceType: 'auto', noun: 'evidence file');
  }

  bool _isPdf(File file) {
    final path = file.path.toLowerCase();
    return path.endsWith('.pdf');
  }

  Future<String> _uploadPdfEvidenceToStorage(File file) async {
    try {
      final originalName = file.uri.pathSegments.isNotEmpty
          ? file.uri.pathSegments.last
          : 'evidence.pdf';
      final safeName = originalName.replaceAll(
        RegExp(r'[^A-Za-z0-9._-]'),
        '_',
      );
      final timestamp = DateTime.now().microsecondsSinceEpoch;
      final ref = FirebaseStorage.instance
          .ref()
          .child('evidence/pdfs/${timestamp}_$safeName');

      final task = await ref.putFile(
        file,
        SettableMetadata(
          contentType: 'application/pdf',
          customMetadata: {'originalName': originalName},
        ),
      );

      return await task.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      debugPrint('PDF evidence Firebase Storage upload error: $e');
      final message = switch (e.code) {
        'unauthorized' || 'permission-denied' =>
          'PDF evidence upload is blocked by Firebase Storage rules. Please deploy the latest storage rules and try again.',
        'bucket-not-found' =>
          'Firebase Storage is not ready for PDF evidence uploads.',
        _ => 'The PDF evidence could not be uploaded right now. ${e.message ?? 'Please try again.'}',
      };
      throw CloudinaryUploadException(message);
    } catch (e) {
      debugPrint('Unexpected PDF evidence upload error: $e');
      throw const CloudinaryUploadException(
        'The PDF evidence could not be uploaded right now. Please try again.',
      );
    }
  }

  Future<String> _uploadOrThrow(
    File file, {
    required String resourceType,
    required String noun,
  }) async {
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload',
      );

      final request = http.MultipartRequest('POST', uri);

      request.fields['upload_preset'] = uploadPreset;

      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        final secureUrl = data['secure_url'] as String?;
        if (secureUrl == null || secureUrl.isEmpty) {
          throw CloudinaryUploadException(
            'The upload service did not return a $noun URL.',
          );
        }
        return secureUrl;
      }

      String message = 'The upload service rejected the $noun.';
      try {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        final cloudinaryMessage =
            (data['error'] as Map<String, dynamic>?)?['message'] as String?;
        if (cloudinaryMessage != null && cloudinaryMessage.isNotEmpty) {
          message = cloudinaryMessage;
        }
      } catch (_) {
        // Keep the user-friendly fallback when the response is not JSON.
      }
      throw CloudinaryUploadException(message, statusCode: response.statusCode);
    } on CloudinaryUploadException {
      rethrow;
    } on SocketException {
      throw CloudinaryUploadException(
        'No internet connection was available while uploading the $noun.',
      );
    } on http.ClientException {
      throw CloudinaryUploadException(
        'The $noun upload could not connect to the server.',
      );
    } catch (e) {
      debugPrint('Unexpected Cloudinary upload error: $e');
      throw CloudinaryUploadException(
        'The $noun could not be uploaded right now. Please try again.',
      );
    }
  }
}
