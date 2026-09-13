import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startup restoration never invokes an interactive Google flow', () {
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
    expect(restoreBody, isNot(contains('_googleSignIn')));
    expect(restoreBody, isNot(contains('_ensureGoogleInitialized')));
    expect(restoreBody, isNot(contains('authenticate(')));
    expect(restoreBody, isNot(contains('attemptLightweightAuthentication')));
  });
}
