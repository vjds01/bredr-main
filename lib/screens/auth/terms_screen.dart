import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 8),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        'Terms and Services',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'By creating an account and using Breedr and using Breedr, you agree to the following rules and guidelines of the platform.',
                      textAlign: TextAlign.justify,
                      style: TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.6),
                    ),
                    const SizedBox(height: 16),
                    _term('1. User Responsibility.', 'User must provide accurate information when creating profiles, listing pets or interacting with other members.'),
                    _term('2. Responsible Breeding and Adoption.', 'Breedr promotes ethical and responsible breeding. Users must not post illegal activities, animal abuse or misleading pet listing .'),
                    _term('3. Proper use of Platform.', 'Users must communicate respectfully and must not use the platform for fraud, scams or harmful behavior.'),
                    _term('4. Account Security.', 'Users are responsible for maintaining the security of their accounts and login credentials.'),
                    _term('5. Third Party Services.', 'Breedr may use trusted services such as Google for authentication maps, or location-based features.'),
                    _term('6. Policy Updates.', 'Breedr may update these terms when necessary to improve platform and user experience.'),
                    const SizedBox(height: 20),
                    _section('Privacy Policy'),
                    const SizedBox(height: 6),
                    const Text(
                      'Breedr respects your privacy and protects your personal information.',
                      textAlign: TextAlign.justify,
                      style: TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.6),
                    ),
                    const SizedBox(height: 16),
                    _section('Information Collected'),
                    const SizedBox(height: 6),
                    const Text(
                      'The app may collect basic information such as name, email, and location to provide services',
                      textAlign: TextAlign.justify,
                      style: TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.6),
                    ),
                    const SizedBox(height: 16),
                    _section('How Information is Used'),
                    const SizedBox(height: 6),
                    const Text(
                      'Collected data is used to improve matchmaking, show nearby Breeders or pets, and enhances platform features.',
                      textAlign: TextAlign.justify,
                      style: TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.6),
                    ),
                    const SizedBox(height: 16),
                    _section('Data Protection'),
                    const SizedBox(height: 6),
                    const Text(
                      'Some feature may rely on trusted providers such as Google for location and authentication services.',
                      textAlign: TextAlign.justify,
                      style: TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _term(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: RichText(
        textAlign: TextAlign.justify,
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.6),
          children: [
            TextSpan(text: '$title ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: body),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark));
  }
}
