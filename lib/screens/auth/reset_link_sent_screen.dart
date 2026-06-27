import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class ResetLinkSentScreen extends StatelessWidget {
  final String email;

  const ResetLinkSentScreen({
    super.key,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 18, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Check Your Email',
                      style: TextStyle(
                        color: Color(0xFF222222),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    color: Color(0xFF777777),
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                  children: [
                    const TextSpan(
                      text: "We've sent a password reset link to ",
                    ),
                    TextSpan(
                      text: email,
                      style: const TextStyle(
                        color: Color(0xFF444444),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const TextSpan(
                      text:
                          '. Open the link from your email to create a new password.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 34),
              Center(
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFFE1E8),
                  ),
                  child: const Icon(
                    Icons.mark_email_read_outlined,
                    color: AppColors.primary,
                    size: 62,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Center(
                child: Text(
                  'Waiting for reset link...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF222222),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'If the link does not open Breedr automatically, return here after resetting your password from the email.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF777777),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Use Another Email',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
