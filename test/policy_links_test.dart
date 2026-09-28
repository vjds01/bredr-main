import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('policy links use one screen with a privacy-section anchor', () {
    final policyWidget = File(
      'lib/widgets/policy_agreement_text.dart',
    ).readAsStringSync();
    final termsScreen = File(
      'lib/screens/auth/terms_screen.dart',
    ).readAsStringSync();

    expect(policyWidget, contains("text: 'Terms of Service'"));
    expect(policyWidget, contains("text: 'Privacy Policy'"));
    expect(policyWidget, contains('color: AppColors.primary'));
    expect(policyWidget, contains('decoration: TextDecoration.underline'));
    expect(policyWidget, contains('openAtPrivacyPolicy: true'));
    expect(termsScreen, contains("'Terms of Service'"));
    expect(termsScreen, contains('Scrollable.ensureVisible'));
    expect(termsScreen, contains("_section('Privacy Policy'"));
    expect(termsScreen, contains("'I Agree'"));
    expect(termsScreen, contains('onPressed: () => Navigator.pop(context)'));
  });
}
