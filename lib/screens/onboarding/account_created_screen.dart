import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../home_screen.dart';
import '../pet/pet_registration_screen.dart';

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
      backgroundColor: const Color(0xFFFFF0F5),
      body: SafeArea(
        child: Stack(
          children: [
            // Scattered paw marks background
            const Positioned.fill(child: _PawBackground()),

            Column(
              children: [
                // Back arrow
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios,
                          color: AppColors.primary, size: 20),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // Profile photo circle
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFCDD5),
                    border: Border.all(
                      color: AppColors.primary,
                      width: 3,
                    ),
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

                const SizedBox(height: 32),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Welcome to\nBreedr $_firstName!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
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
                      fontSize: 14,
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
                                builder: (_) =>
                                    const PetRegistrationScreen()),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'Register My First Pet →',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
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
                                builder: (_) => const HomeScreen()),
                            (route) => false,
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: AppColors.primary, width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
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

                      const SizedBox(height: 32),
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

  const _ProfilePhoto({
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;

    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _FallbackProfilePhoto(),
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
      errorBuilder: (_, _, _) => const Icon(
        Icons.person,
        color: AppColors.primary,
        size: 64,
      ),
    );
  }
}

// Scattered paw marks painter
class _PawBackground extends StatelessWidget {
  const _PawBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _PawsPainter());
  }
}

class _PawsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paws = [
      // top right trail going diagonally down-left
      _PawData(Offset(size.width * 0.82, size.height * 0.04), 18, 0.3),
      _PawData(Offset(size.width * 0.72, size.height * 0.09), 16, 0.25),
      _PawData(Offset(size.width * 0.62, size.height * 0.14), 20, 0.3),
      _PawData(Offset(size.width * 0.52, size.height * 0.19), 15, 0.2),
      _PawData(Offset(size.width * 0.42, size.height * 0.24), 18, 0.28),
      // left side trail
      _PawData(Offset(size.width * 0.08, size.height * 0.38), 22, 0.3),
      _PawData(Offset(size.width * 0.14, size.height * 0.46), 16, 0.22),
      _PawData(Offset(size.width * 0.06, size.height * 0.54), 20, 0.28),
    ];

    for (final p in paws) {
      _drawPaw(canvas, p.offset, p.size, p.opacity);
    }
  }

  void _drawPaw(Canvas canvas, Offset center, double r, double opacity) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    // Palm
    canvas.drawCircle(center, r, paint);
    // Toe pads
    final toeR = r * 0.42;
    canvas.drawCircle(
        Offset(center.dx - r * 0.65, center.dy - r * 0.85), toeR, paint);
    canvas.drawCircle(
        Offset(center.dx, center.dy - r * 1.1), toeR, paint);
    canvas.drawCircle(
        Offset(center.dx + r * 0.65, center.dy - r * 0.85), toeR, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PawData {
  final Offset offset;
  final double size;
  final double opacity;
  const _PawData(this.offset, this.size, this.opacity);
}
