import 'dart:convert';

import 'package:http/http.dart' as http;

import 'user_session_service.dart';

class HealthVerificationService {
  HealthVerificationService._();

  static final instance = HealthVerificationService._();

  static const endpoint = String.fromEnvironment(
    'HEALTH_VERIFICATION_ENDPOINT',
  );
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
    if (record['clinicEmailVerificationAvailable'] != true) {
      throw StateError(
        'The selected clinic currently uses Veterinary Admin review.',
      );
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
          .timeout(const Duration(seconds: 60));
      var response = await http.Response.fromStream(streamed);

      var redirectCount = 0;
      while (_isRedirect(response.statusCode) && redirectCount < 5) {
        final location = response.headers['location'];
        if (location == null || location.trim().isEmpty) {
          throw StateError('Email service redirect had no destination.');
        }
        final redirectUri = endpointUri.resolve(location);
        // Keep the same client for Google's script.google.com ->
        // googleusercontent.com handoff. A separate client can lose response
        // context and turn an otherwise successful Apps Script result into a
        // misleading 404.
        response = await client
            .get(redirectUri)
            .timeout(const Duration(seconds: 60));
        redirectCount++;
      }

      return response;
    } finally {
      client.close();
    }
  }

  bool _isRedirect(int statusCode) =>
      statusCode == 301 ||
      statusCode == 302 ||
      statusCode == 303 ||
      statusCode == 307 ||
      statusCode == 308;

  Future<void> requestForPublishedPet({
    required String petId,
    required String petName,
    required List<Map<String, dynamic>> records,
  }) async {
    for (final record in records) {
      if (record['clinicConsentGranted'] == true &&
          record['clinicEmailVerificationAvailable'] == true &&
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
