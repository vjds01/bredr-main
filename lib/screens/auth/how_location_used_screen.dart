import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class HowLocationUsedScreen extends StatelessWidget {
  const HowLocationUsedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCECF0),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back arrow
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 8),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    const Text(
                      'How will we use\nyour location?',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // White card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Don't Worry
                          const Center(
                            child: Text(
                              "Don't Worry",
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Your location helps Breedr connect you with nearby pet owners, Breeders, and adoption, opportonities. This allows the app to show pets, breeders that are close, to you.',
                            textAlign: TextAlign.justify,
                            style: TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.6),
                          ),
                          const SizedBox(height: 20),
                          // What we use it for
                          const Text(
                            'What we use it for ?',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                          const SizedBox(height: 12),
                          _pawBullet('Show nearby Pet available for adoption or breeding.'),
                          _pawBullet('Connect you with Breeder in your area.'),
                          _pawBullet('Improve matchmaking accuracy'),
                          const SizedBox(height: 20),
                          // Privacy Assurance
                          const Text(
                            'Privacy Assurance',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Your location is not shored publicly with other users, it is only to improve the recommendation and match making inside the app.',
                            textAlign: TextAlign.justify,
                            style: TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.6),
                          ),
                        ],
                      ),
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

  Widget _pawBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🐾', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
