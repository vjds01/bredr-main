import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startup restoration uses lightweight, not interactive Google auth', () {
    final source = File(
      'lib/services/user_session_service.dart',
    ).readAsStringSync();
    final restoreStart = source.indexOf(
      'Future<SessionRestoreResult> restoreSession()',
    );
    final restoreEnd = source.indexOf(
      'Future<User?> _restoredUser()',
      restoreStart,
    );

    expect(restoreStart, greaterThanOrEqualTo(0));
    expect(restoreEnd, greaterThan(restoreStart));

    final restoreBody = source.substring(restoreStart, restoreEnd);
    expect(restoreBody, isNot(contains('authenticate(')));
    expect(restoreBody, contains('_restoreGoogleUser()'));

    expect(source, contains('attemptLightweightAuthentication()'));
    expect(source, contains('reauthenticationRequired'));
  });

  test('known sessions receive a cold-start restoration grace period', () {
    final source = File(
      'lib/services/user_session_service.dart',
    ).readAsStringSync();

    expect(
      source,
      contains(
        'static const _knownSessionRestoreTimeout = Duration(seconds: 15)',
      ),
    );
    expect(source, contains('.idTokenChanges()'));
    expect(source, contains('restoredUser ?? currentUser'));
    expect(source, contains("providerHint != 'password'"));
  });
}
