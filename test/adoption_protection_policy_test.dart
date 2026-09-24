import 'dart:io';

import 'package:breedr/services/adoption_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adoption protection policy is exactly one minute', () {
    expect(
      AdoptionService.protectionWindowDuration,
      const Duration(minutes: 1),
    );
    expect(AdoptionService.protectionPolicyMinutes, 1);
  });

  test('legacy deadline is replaced by one minute from its original start', () {
    final started = DateTime.utc(2026, 9, 1, 10);
    final legacyEnd = started.add(const Duration(days: 7));

    expect(
      AdoptionService.effectiveProtectionEnd(
        startedAt: started,
        storedEndsAt: legacyEnd,
      ),
      started.add(const Duration(minutes: 1)),
    );
  });

  test('a longer stored deadline is migrated to the current policy', () {
    final started = DateTime.utc(2026, 9, 1);
    final longerEnd = started.add(const Duration(days: 45));

    expect(
      AdoptionService.effectiveProtectionEnd(
        startedAt: started,
        storedEndsAt: longerEnd,
      ),
      started.add(const Duration(minutes: 1)),
    );
  });

  test('one-minute defense window is clearly labeled as testing mode', () {
    final source = File(
      'lib/screens/chat/chats_screen.dart',
    ).readAsStringSync();
    expect(source, contains('1-Minute Window (Testing Mode)'));
  });
}
