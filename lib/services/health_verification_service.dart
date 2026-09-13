import 'dart:convert';

import 'package:http/http.dart' as http;

import 'user_session_service.dart';

class HealthVerificationService {
  HealthVerificationService._();

  static final instance = HealthVerificationService._();

  static const endpoint = String.fromEnvironment(
    'HEALTH_VERIFICATION_ENDPOINT',
  );
  static const testingRecipient = 'breedr0123@gmail.com';

  Future<String> requestClinicConfirmation({
    required String petId,
    required String petName,
    required Map<String, dynamic> record,
  }) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) throw StateError('You must be logged in first.');
    if (record['clinicConsentGranted'] != true) {
      throw StateError('Clinic verification consent is required.');
    }

    final recordId = record['recordId']?.toString().trim() ?? '';
    if (recordId.isEmpty) throw StateError('The health record has no ID.');

    if (endpoint.isEmpty) {
      throw StateError('Clinic verification email service is not configured.');
    }

    try {
      final idToken = await user.getIdToken();
      final response = await _postFollowingAppsScriptRedirect(
        Uri.parse(endpoint),
        jsonEncode({
          'action': 'createAndDispatch',
          'petId': petId,
          'recordId': recordId,
          'idToken': idToken,
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Email service returned ${response.statusCode}.');
      }
      final responseBody = response.body.trim();
      if (responseBody.startsWith('<!doctype html') ||
          responseBody.startsWith('<html')) {
        throw StateError(
          'The clinic email service returned a web page instead of an API '
          'response. Deploy the latest Apps Script version and verify its '
          'web-app access settings.',
        );
      }
      final result = jsonDecode(responseBody) as Map<String, dynamic>;
      if (result['ok'] != true) {
        throw StateError(
          result['error']?.toString() ?? 'Email dispatch failed.',
        );
      }
      return result['requestId']?.toString() ?? '';
    } catch (error) {
      rethrow;
    }
  }

  Future<http.Response> _postFollowingAppsScriptRedirect(
    Uri endpointUri,
    String body,
  ) async {
    final client = http.Client();
    try {
      final request = http.Request('POST', endpointUri)
        ..followRedirects = false
        ..headers['Content-Type'] = 'application/json'
        ..body = body;
      final streamed = await client
          .send(request)
          .timeout(const Duration(seconds: 20));
      var response = await http.Response.fromStream(streamed);

      if (response.statusCode == 301 ||
          response.statusCode == 302 ||
          response.statusCode == 303 ||
          response.statusCode == 307 ||
          response.statusCode == 308) {
        final location = response.headers['location'];
        if (location == null || location.trim().isEmpty) {
          throw StateError('Email service redirect had no destination.');
        }
        final redirectUri = endpointUri.resolve(location);
        response = await http
            .get(redirectUri)
            .timeout(const Duration(seconds: 20));
      }

      return response;
    } finally {
      client.close();
    }
  }

  Future<void> requestForPublishedPet({
    required String petId,
    required String petName,
    required List<Map<String, dynamic>> records,
  }) async {
    for (final record in records) {
      if (record['clinicConsentGranted'] == true &&
          record['verificationStatus'] != 'verified') {
        try {
          await requestClinicConfirmation(
            petId: petId,
            petName: petName,
            record: record,
          );
        } catch (_) {
          // Publishing already succeeded. The failed dispatch remains visible
          // to veterinary admins for retry and must not trigger a duplicate
          // listing when the owner retries publication.
        }
      }
    }
  }
}
