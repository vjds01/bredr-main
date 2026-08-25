import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/moderation_service.dart';
import '../services/user_session_service.dart';
import '../theme/app_colors.dart';
import '../widgets/breedr_logo.dart';
import 'admin/admin_dashboard_screen.dart';
import 'auth/get_started_screen.dart';
import 'auth/cabuyao_access_gate_screen.dart';
import 'auth/moderation_gate_screen.dart';
import 'home_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    _routeAfterSplash();
  }

  Future<void> _routeAfterSplash() async {
    final start = DateTime.now();
    Widget nextScreen = const GetStartedScreen();

    try {
      final canAutoLogin = await UserSessionService.instance.shouldAutoLogin();

      if (canAutoLogin) {
        final isAdmin = await UserSessionService.instance.isCurrentUserAdmin();
        if (isAdmin) {
          nextScreen = const AdminDashboardScreen();
        } else {
          final moderation =
              await ModerationService.instance.getCurrentUserModeration();
          nextScreen = moderation?.isBlocked == true
              ? ModerationGateScreen(state: moderation!)
              : const CabuyaoAccessGate(child: HomeScreen());
        }
      }
    } catch (e) {
      debugPrint('Auto login check failed: $e');
      nextScreen = UserSessionService.instance.currentUser == null
          ? const GetStartedScreen()
          : const CabuyaoAccessGate(child: HomeScreen());
    }

    final elapsed = DateTime.now().difference(start);
    const minimumSplashTime = Duration(seconds: 2);

    if (elapsed < minimumSplashTime) {
      await Future.delayed(minimumSplashTime - elapsed);
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => nextScreen),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FC),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF9FD), Color(0xFFFFFFFF), Color(0xFFFFEEF7)],
            stops: [0, 0.58, 1],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: _SplashBackground()),
            FadeTransition(
              opacity: _fade,
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final height = constraints.maxHeight;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: height * 0.22),
                        const Center(child: BreedrLogo(size: 190)),
                        SizedBox(height: height * 0.04),
                        SizedBox(
                          width: double.infinity,
                          child: Text(
                            'Breedr.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 52,
                              height: 1,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          child: Text(
                            'powered by',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.urbanist(
                              fontSize: 13,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: Text(
                            'GROUP 10',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        SizedBox(height: height * 0.08),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashBackground extends StatelessWidget {
  const _SplashBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SplashBackgroundPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _SplashBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cloudPaint = Paint()..color = Colors.white.withValues(alpha: 0.72);
    final skylinePaint = Paint()..color = const Color(0xFFFFDDEB);
    final wavePaint = Paint()..color = const Color(0xFFFFE2EF);

    _drawCloud(
      canvas,
      Offset(size.width * 0.18, size.height * 0.30),
      1.0,
      cloudPaint,
    );
    _drawCloud(
      canvas,
      Offset(size.width * 0.82, size.height * 0.33),
      0.85,
      cloudPaint,
    );

    final skylineTop = size.height * 0.46;
    final buildingWidth = size.width / 13;
    for (var i = 0; i < 13; i++) {
      final heightFactor = 0.035 + (i % 4) * 0.015;
      final left = i * buildingWidth;
      final top = skylineTop - size.height * heightFactor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, buildingWidth * 0.72, skylineTop - top),
          const Radius.circular(2),
        ),
        skylinePaint,
      );
    }

    final leftWave = Path()
      ..moveTo(0, size.height * 0.78)
      ..cubicTo(
        size.width * 0.12,
        size.height * 0.77,
        size.width * 0.16,
        size.height * 0.91,
        size.width * 0.32,
        size.height * 0.88,
      )
      ..cubicTo(
        size.width * 0.45,
        size.height * 0.86,
        size.width * 0.48,
        size.height,
        size.width * 0.58,
        size.height,
      )
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(leftWave, wavePaint);

    final rightWave = Path()
      ..moveTo(size.width, size.height * 0.77)
      ..cubicTo(
        size.width * 0.86,
        size.height * 0.76,
        size.width * 0.84,
        size.height * 0.91,
        size.width * 0.68,
        size.height * 0.89,
      )
      ..cubicTo(
        size.width * 0.55,
        size.height * 0.87,
        size.width * 0.52,
        size.height,
        size.width * 0.42,
        size.height,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(rightWave, wavePaint);
  }

  void _drawCloud(Canvas canvas, Offset center, double scale, Paint paint) {
    canvas.drawCircle(
      center.translate(-18 * scale, 5 * scale),
      10 * scale,
      paint,
    );
    canvas.drawCircle(
      center.translate(-4 * scale, -3 * scale),
      14 * scale,
      paint,
    );
    canvas.drawCircle(
      center.translate(13 * scale, 6 * scale),
      9 * scale,
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center.translate(-2 * scale, 9 * scale),
          width: 48 * scale,
          height: 16 * scale,
        ),
        Radius.circular(12 * scale),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
