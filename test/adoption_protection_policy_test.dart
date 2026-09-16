import 'dart:io';

import 'package:breedr/services/adoption_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adoption protection policy is exactly 30 days', () {
    expect(AdoptionService.protectionWindowDuration, const Duration(days: 30));
    expect(AdoptionService.protectionPolicyDays, 30);
  });

  test('legacy seven-day deadline is extended from its original start', () {
    final started = DateTime.utc(2026, 9, 1, 10);
    final legacyEnd = started.add(const Duration(days: 7));

    expect(
      AdoptionService.effectiveProtectionEnd(
        startedAt: started,
        storedEndsAt: legacyEnd,
      ),
      started.add(const Duration(days: 30)),
    );
  });

  test('a longer stored deadline is never shortened', () {
    final started = DateTime.utc(2026, 9, 1);
    final longerEnd = started.add(const Duration(days: 45));

    expect(
      AdoptionService.effectiveProtectionEnd(
        startedAt: started,
        storedEndsAt: longerEnd,
      ),
      longerEnd,
    );
  });

  test('production adoption UI contains no testing terminology', () {
    final source = File(
      'lib/screens/chat/chats_screen.dart',
    ).readAsStringSync();
    expect(source.toLowerCase(), isNot(contains('test mode')));
    expect(source.toLowerCase(), isNot(contains('for testing')));
  });
}
