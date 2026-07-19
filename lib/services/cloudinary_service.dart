import 'dart:convert';
import 'dart:io';

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
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );

      final request = http.MultipartRequest(
        'POST',
        uri,
      );

      request.fields['upload_preset'] = uploadPreset;

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
        ),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        final secureUrl = data['secure_url'] as String?;
        if (secureUrl == null || secureUrl.isEmpty) {
          throw const CloudinaryUploadException(
            'The image service did not return a photo URL.',
          );
        }
        return secureUrl;
      }

      String message = 'The photo upload service rejected the image.';
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
      throw CloudinaryUploadException(
        message,
        statusCode: response.statusCode,
      );
    } on CloudinaryUploadException {
      rethrow;
    } on SocketException {
      throw const CloudinaryUploadException(
        'No internet connection was available while uploading the photo.',
      );
    } on http.ClientException {
      throw const CloudinaryUploadException(
        'The photo upload could not connect to the server.',
      );
    } catch (e) {
      debugPrint('Unexpected Cloudinary upload error: $e');
      throw const CloudinaryUploadException(
        'The photo could not be uploaded right now. Please try again.',
      );
    }
  }
}
