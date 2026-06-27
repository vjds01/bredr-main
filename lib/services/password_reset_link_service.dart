import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

class PasswordResetLinkService {
  PasswordResetLinkService._();

  static final PasswordResetLinkService instance = PasswordResetLinkService._();

  final AppLinks _appLinks = AppLinks();
  final StreamController<String> _resetCodeController =
      StreamController<String>.broadcast();

  StreamSubscription<Uri>? _subscription;
  bool _initialized = false;
  String? _pendingResetCode;

  Stream<String> get resetCodes => _resetCodeController.stream;

  String? consumePendingResetCode() {
    final code = _pendingResetCode;
    _pendingResetCode = null;
    return code;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final initialUri = await _appLinks.getInitialLink();
      _handleUri(initialUri);
    } catch (error) {
      debugPrint('Unable to read initial reset link: $error');
    }

    _subscription = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (error) {
        debugPrint('Unable to read incoming reset link: $error');
      },
    );
  }

  void _handleUri(Uri? uri) {
    if (uri == null) return;
    final isBreedrResetLink =
        uri.scheme == 'breedr' && uri.host == 'reset-password';
    final isFirebaseResetLink = uri.scheme == 'https' &&
        (uri.host == 'breedr-3c5dc.firebaseapp.com' ||
            uri.host == 'breedr-3c5dc.web.app') &&
        (uri.path.startsWith('/reset-password') ||
            uri.path.startsWith('/usermgmt'));
    if (!isBreedrResetLink && !isFirebaseResetLink) return;

    final code = _resetCodeFromUri(uri);
    if (code == null || code.trim().isEmpty) return;

    final trimmedCode = code.trim();
    if (!_resetCodeController.hasListener) {
      _pendingResetCode = trimmedCode;
      return;
    }
    _resetCodeController.add(trimmedCode);
  }

  String? _resetCodeFromUri(Uri uri) {
    final directCode = uri.queryParameters['oobCode'] ??
        uri.queryParameters['code'] ??
        uri.queryParameters['resetCode'];
    if (directCode != null && directCode.trim().isNotEmpty) {
      return directCode;
    }

    final nestedLink = uri.queryParameters['link'];
    if (nestedLink == null || nestedLink.trim().isEmpty) return null;

    final nestedUri = Uri.tryParse(nestedLink);
    if (nestedUri == null) return null;
    return nestedUri.queryParameters['oobCode'] ??
        nestedUri.queryParameters['code'] ??
        nestedUri.queryParameters['resetCode'];
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _resetCodeController.close();
  }
}
