import 'dart:math';
import 'package:breedr/models/onboarding_data.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/breedr_network_image.dart';
import '../signup/about_you.dart';

// enum _WelcomeStep { greeting, withPhoto, loading }
enum _WelcomeStep { withPhoto, loading }

class WelcomeScreen extends StatefulWidget {
  final OnboardingData onboardingData;
  final String? photoUrl;

  const WelcomeScreen({super.key, required this.onboardingData, this.photoUrl});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  // _WelcomeStep _step = _WelcomeStep.greeting;
  _WelcomeStep _step = _WelcomeStep.withPhoto;

  late final AnimationController _spinCtrl;

  String get _signInMethod {
    switch (widget.onboardingData.authProvider.toLowerCase()) {
      case 'google':
        return 'Google';
      case 'email':
        return 'Email';
      default:
        return 'Breedr';
    }
  }

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    super.dispose();
  }

  // void _onOk() => setState(() => _step = _WelcomeStep.withPhoto);

  void _onContinue() async {
    setState(() => _step = _WelcomeStep.loading);
    _spinCtrl.repeat();
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            Step2ReviewProfile(onboardingData: widget.onboardingData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _buildStep(),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      // case _WelcomeStep.greeting:
      //   return _GreetingScreen(
      //     key: const ValueKey('greeting'),
      //     name: widget.onboardingData.fullName,
      //     email: widget.onboardingData.email,
      //     authProvider: widget.onboardingData.authProvider,
      //     signInMethod: _signInMethod,
      //     onOk: _onOk,
      //   );
      case _WelcomeStep.withPhoto:
        return _WithPhotoScreen(
          key: const ValueKey('withPhoto'),
          name: widget.onboardingData.fullName,
          email: widget.onboardingData.email,
          photoUrl: widget.photoUrl,
          authProvider: widget.onboardingData.authProvider,
          signInMethod: _signInMethod,
          onContinue: _onContinue,
        );
      case _WelcomeStep.loading:
        return _LoadingScreen(
          key: const ValueKey('loading'),
          name: widget.onboardingData.fullName,
          email: widget.onboardingData.email,
          photoUrl: widget.photoUrl,
          authProvider: widget.onboardingData.authProvider,
          signInMethod: _signInMethod,
          spinCtrl: _spinCtrl,
        );
    }
  }
}

// ── Shared plain background ───────────────────────────────────────

class _BgShell extends StatelessWidget {
  final Widget child;
  const _BgShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFFFF0F5),
      child: SafeArea(child: child),
    );
  }
}

// ── Step 1: Greeting (no photo) ───────────────────────────────────

// class _GreetingScreen extends StatelessWidget {
//   final String name;
//   final String email;
//   final VoidCallback onOk;
//   final String authProvider;
//   final String signInMethod;

//   const _GreetingScreen({
//     super.key,
//     required this.name,
//     required this.email,
//     required this.onOk,
//     required this.authProvider,
//     required this.signInMethod,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return _BgShell(
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 28),
//         child: Column(
//           children: [
//             const Spacer(flex: 2),

//             // Name + verified badge
//             Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Text(
//                   'Welcome, $name',
//                   style: const TextStyle(
//                     fontSize: 28,
//                     fontWeight: FontWeight.bold,
//                     color: AppColors.primary,
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 Container(
//                   width: 26,
//                   height: 26,
//                   decoration: const BoxDecoration(
//                     shape: BoxShape.circle,
//                     color: Color(0xFF1DA1F2),
//                   ),
//                   child: const Icon(Icons.check,
//                       color: Colors.white, size: 15),
//                 ),
//               ],
//             ),

//             const SizedBox(height: 6),

//             Text(
//               email,
//               style: const TextStyle(
//                   fontSize: 13, color: Color(0xFF888888)),
//             ),

//             const SizedBox(height: 28),

//             // Message card
//             Container(
//               width: double.infinity,
//               padding: const EdgeInsets.symmetric(
//                   horizontal: 20, vertical: 20),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(16),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withValues(alpha: 0.05),
//                     blurRadius: 12,
//                     offset: const Offset(0, 4),
//                   ),
//                 ],
//               ),
//               child:  Text(
//                 "Success! You're now signed in with $signInMethod. Now let's proceed to the next step — Breedr wants to know more about you!",
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   fontSize: 14,
//                   color: Color(0xFF555555),
//                   height: 1.7,
//                 ),
//               ),
//             ),

//             const Spacer(flex: 3),

//             SizedBox(
//               width: double.infinity,
//               height: 54,
//               child: ElevatedButton(
//                 onPressed: onOk,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: AppColors.primary,
//                   foregroundColor: Colors.white,
//                   elevation: 0,
//                   shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12)),
//                 ),
//                 child: const Text(
//                   'OK',
//                   style: TextStyle(
//                       fontSize: 18, fontWeight: FontWeight.bold),
//                 ),
//               ),
//             ),

//             const SizedBox(height: 40),
//           ],
//         ),
//       ),
//     );
//   }
// }

// ── Step 2: With starburst photo ──────────────────────────────────

class _WithPhotoScreen extends StatelessWidget {
  final String name;
  final String email;
  final String? photoUrl;
  final VoidCallback onContinue;
  final String authProvider;
  final String signInMethod;

  const _WithPhotoScreen({
    super.key,
    required this.name,
    required this.email,
    this.photoUrl,
    required this.onContinue,
    required this.authProvider,
    required this.signInMethod,
  });

  @override
  Widget build(BuildContext context) {
    return _BgShell(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          children: [
            const Spacer(flex: 2),

            _StarburstAvatar(photoUrl: photoUrl),

            const SizedBox(height: 24),

            Text(
              'Welcome, $name',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              email,
              style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
            ),

            const SizedBox(height: 24),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                authProvider.toLowerCase() == 'email'
                    ? "Your email details are ready. Let's continue setting up your Breedr account."
                    : "Success! You're now signed in with $signInMethod. Now let's proceed to the next step — Breedr wants to know more about you!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF555555),
                  height: 1.7,
                ),
              ),
            ),

            const Spacer(flex: 3),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Continue to next step →',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── Step 3: Loading ───────────────────────────────────────────────

class _LoadingScreen extends StatelessWidget {
  final String name;
  final String email;
  final String? photoUrl;
  final AnimationController spinCtrl;
  final String authProvider;
  final String signInMethod;

  const _LoadingScreen({
    super.key,
    required this.name,
    required this.email,
    this.photoUrl,
    required this.spinCtrl,
    required this.authProvider,
    required this.signInMethod,
  });

  @override
  Widget build(BuildContext context) {
    return _BgShell(
      child: Stack(
        children: [
          // Faded step 2 content
          Opacity(
            opacity: 0.25,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  _StarburstAvatar(photoUrl: photoUrl),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome, $name',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF888888),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      authProvider.toLowerCase() == 'email'
                          ? "Your email details are ready. Let's continue setting up your Breedr account."
                          : "Success! You're now signed in with $signInMethod. Now let's proceed to the next step — Breedr wants to know more about you!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF555555),
                        height: 1.7,
                      ),
                    ),
                  ),
                  const Spacer(flex: 3),
                  Container(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'Continue to next step →',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // Spinning paw centered
          Center(
            child: RotationTransition(
              turns: spinCtrl,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.45),
                      blurRadius: 24,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(Icons.pets, color: Colors.white, size: 36),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Starburst Avatar ──────────────────────────────────────────────

class _StarburstAvatar extends StatelessWidget {
  final String? photoUrl;
  const _StarburstAvatar({this.photoUrl});

  @override
  Widget build(BuildContext context) {
    const double size = 140;
    return SizedBox(
      width: size + 20,
      height: size + 20,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Starburst background
          CustomPaint(
            size: const Size(size, size),
            painter: _StarburstPainter(
              color: AppColors.primary.withValues(alpha: 0.85),
            ),
          ),
          // Circular photo
          ClipOval(
            child: SizedBox(
              width: size * 0.76,
              height: size * 0.76,
              child: photoUrl != null
                  ? BreedrNetworkImage(
                      imageUrl: photoUrl!,
                      width: size * 0.76,
                      height: size * 0.76,
                      fallback: Image.asset(
                        'assets/images/profile.png',
                        fit: BoxFit.cover,
                      ),
                    )
                  : Image.asset('assets/images/profile.png', fit: BoxFit.cover),
            ),
          ),
          // Blue verified badge
          Positioned(
            bottom: 6,
            right: 6,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1DA1F2),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 17),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarburstPainter extends CustomPainter {
  final Color color;
  const _StarburstPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final cx = size.width / 2;
    final cy = size.height / 2;
    const int points = 16;
    final double outerR = size.width / 2;
    final double innerR = size.width / 2 * 0.84;
    final path = Path();

    for (int i = 0; i < points * 2; i++) {
      final angle = (pi / points) * i - pi / 2;
      final r = i.isEven ? outerR : innerR;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
