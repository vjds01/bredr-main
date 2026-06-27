import 'package:flutter/material.dart';
import '../services/user_session_service.dart';
import '../theme/app_colors.dart';
import '../widgets/breedr_logo.dart';
import 'auth/get_started_screen.dart';
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
      final canAutoLogin =
          await UserSessionService.instance.shouldAutoLogin();

      if (canAutoLogin) {
        nextScreen = const HomeScreen();
      }
    } catch (e) {
      debugPrint('Auto login check failed: $e');
      await UserSessionService.instance.signOut();
      nextScreen = const GetStartedScreen();
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.1,
            colors: [Colors.white, Color(0xFFFCE4EC)],
          ),
        ),
        child: FadeTransition(
          opacity: _fade,
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),
                // Logo PNG - Centered properly
                Center(child: const BreedrLogo(size: 150)),
                const SizedBox(height: 20),
                // Wordmark
                const Text(
                  'Breedr.',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(flex: 3),
                // powered by GROUP 10
                const Text(
                  'powered by',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const Text(
                  'GROUP 10',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
