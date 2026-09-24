import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/breedr_network_image.dart';
import '../home_screen.dart';
import '../auth/cabuyao_access_gate_screen.dart';
import '../pet/pet_registration_screen.dart';
import '../../widgets/onboarding_background.dart';

class AccountCreatedScreen extends StatelessWidget {
  final String fullName;
  final String? profilePhotoUrl;

  const AccountCreatedScreen({
    super.key,
    required this.fullName,
    this.profilePhotoUrl,
  });

  String get _firstName {
    final trimmed = fullName.trim();

    if (trimmed.isEmpty) {
      return 'there';
    }

    return trimmed.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OnboardingBackground(
        child: Stack(
          children: [
            Column(
              children: [
                // Back arrow
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // Profile photo circle
                Container(
                  width: 125,
                  height: 125,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFCDD5),
                    border: Border.all(color: AppColors.primary, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _ProfilePhoto(photoUrl: profilePhotoUrl),
                  ),
                ),

                const SizedBox(height: 40),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Welcome to\nBreedr $_firstName!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      height: 1.2,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    "Your account is ready. Now let's add your first pet!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF555555),
                      height: 1.6,
                    ),
                  ),
                ),

                const Spacer(flex: 3),

                // Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      // Register My First Pet
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PetRegistrationScreen(),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            'Register My First Pet →',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Skip for now
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const CabuyaoAccessGate(child: HomeScreen()),
                            ),
                            (route) => false,
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            'Skip for now',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 72),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfilePhoto extends StatelessWidget {
  final String? photoUrl;

  const _ProfilePhoto({this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;

    if (url != null && url.isNotEmpty) {
      return BreedrNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        fallback: const _FallbackProfilePhoto(),
      );
    }

    return const _FallbackProfilePhoto();
  }
}

class _FallbackProfilePhoto extends StatelessWidget {
  const _FallbackProfilePhoto();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/profile.png',
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) =>
          const Icon(Icons.person, color: AppColors.primary, size: 64),
    );
  }
}
