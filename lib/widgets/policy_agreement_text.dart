import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../screens/auth/terms_screen.dart';
import '../theme/app_colors.dart';

class PolicyAgreementText extends StatefulWidget {
  const PolicyAgreementText({super.key});

  @override
  State<PolicyAgreementText> createState() => _PolicyAgreementTextState();
}

class _PolicyAgreementTextState extends State<PolicyAgreementText> {
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => _openPolicy(openAtPrivacyPolicy: false);
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => _openPolicy(openAtPrivacyPolicy: true);
  }

  void _openPolicy({required bool openAtPrivacyPolicy}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TermsScreen(openAtPrivacyPolicy: openAtPrivacyPolicy),
      ),
    );
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const linkStyle = TextStyle(
      color: AppColors.primary,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.primary,
      decorationThickness: 1,
    );

    return Center(
      child: Text.rich(
        TextSpan(
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF999999),
            height: 1.35,
          ),
          children: [
            const TextSpan(text: "By signing up, you agree to Breedr's "),
            TextSpan(
              text: 'Terms of Service',
              style: linkStyle,
              recognizer: _termsRecognizer,
            ),
            const TextSpan(text: ' and '),
            TextSpan(
              text: 'Privacy Policy',
              style: linkStyle,
              recognizer: _privacyRecognizer,
            ),
            const TextSpan(
              text:
                  '. Your Google account will only be used for authentication.',
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
