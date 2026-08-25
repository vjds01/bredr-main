import 'dart:convert';

import 'package:http/http.dart' as http;

class PasswordResetOtpResult {
  final String resetId;
  final int expiresInSeconds;
  final String message;

  const PasswordResetOtpResult({
    required this.resetId,
    required this.expiresInSeconds,
    required this.message,
  });
}

class PasswordResetVerificationResult {
  final String email;
  final String verificationToken;

  const PasswordResetVerificationResult({
    required this.email,
    required this.verificationToken,
  });
}

class PasswordResetOtpException implements Exception {
  final String message;

  const PasswordResetOtpException(this.message);

  @override
  String toString() => message;
}

class PasswordResetOtpService {
  PasswordResetOtpService._();

  static final PasswordResetOtpService instance = PasswordResetOtpService._();

  static const String _baseUrl = 'https://bredr-main-six.vercel.app';

  Future<PasswordResetOtpResult> requestCode(String email) async {
    final data = await _post('/api/password-reset/request', {
      'email': email.trim(),
    });

    return PasswordResetOtpResult(
      resetId: (data['resetId'] ?? '').toString(),
      expiresInSeconds: (data['expiresInSeconds'] as num?)?.toInt() ?? 600,
      message: _messageFrom(
        data,
        'A Breedr password reset code has been sent.',
      ),
    );
  }

  Future<PasswordResetVerificationResult> verifyCode({
    required String resetId,
    required String code,
  }) async {
    final data = await _post('/api/password-reset/verify', {
      'resetId': resetId,
      'code': code.trim(),
    });

    return PasswordResetVerificationResult(
      email: (data['email'] ?? '').toString(),
      verificationToken: (data['verificationToken'] ?? '').toString(),
    );
  }

  Future<void> confirmPassword({
    required String verificationToken,
    required String newPassword,
  }) async {
    await _post('/api/password-reset/confirm', {
      'verificationToken': verificationToken,
      'newPassword': newPassword,
    });
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const PasswordResetOtpException(
        'Please check your internet connection and try again.',
      );
    }

    Map<String, dynamic> data = {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {
      // Keep a friendly fallback below when the server returns non-JSON.
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PasswordResetOtpException(
        _messageFrom(
          data,
          'The reset service is unavailable right now. Please try again later.',
        ),
      );
    }

    if (data['ok'] == false) {
      throw PasswordResetOtpException(_messageFrom(data, 'Please try again.'));
    }

    return data;
  }

  static String _messageFrom(Map<String, dynamic> data, String fallback) {
    final message = data['message']?.toString().trim();
    return message == null || message.isEmpty ? fallback : message;
  }
}
