import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/onboarding_data.dart';
import '../services/moderation_service.dart';
import '../services/user_session_service.dart';
import '../theme/app_colors.dart';
import '../widgets/breedr_logo.dart';
import '../widgets/onboarding_background.dart';
import 'admin/admin_dashboard_screen.dart';
import 'veterinary/veterinary_dashboard_screen.dart';
import 'auth/get_started_screen.dart';
import 'auth/login_screen.dart';
import 'auth/cabuyao_access_gate_screen.dart';
import 'auth/moderation_gate_screen.dart';
import 'auth/welcome_screen.dart';
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
      final restoration = await UserSessionService.instance.restoreSession();

      if (restoration.shouldRetry) {
        nextScreen = const _SessionRecoveryScreen();
      } else if (restoration.requiresGoogleConfirmation) {
        nextScreen = _GoogleSessionConfirmationScreen(
          expectedEmail: restoration.expectedEmail,
        );
      } else if (restoration.requiresReauthentication) {
        nextScreen = const LoginScreen(
          initialMessage:
              'Your saved session expired. Please sign in again to continue.',
        );
      } else if (restoration.isAuthenticated) {
        var hasProfile = true;
        try {
          hasProfile = await UserSessionService.instance.hasBreedrProfile();
        } catch (_) {
          // A temporary Firestore error must not invalidate a restored login.
        }

        final user = FirebaseAuth.instance.currentUser;
        final isIncompleteGoogleSignup =
            !hasProfile &&
            user != null &&
            user.providerData.any(
              (provider) => provider.providerId == 'google.com',
            );

        if (isIncompleteGoogleSignup) {
          final email = user.email ?? '';
          final emailName = email.split('@').first.toLowerCase();
          final username = emailName.replaceAll(RegExp(r'[^a-z0-9_]'), '_');
          final onboardingData = OnboardingData(
            authProvider: 'google',
            fullName: user.displayName ?? 'Breedr User',
            userName: username.isEmpty ? 'breedr_user' : username,
            email: email,
            password: '',
            profilePhoto: user.photoURL,
          );

          nextScreen = CabuyaoAccessGate(
            child: WelcomeScreen(
              onboardingData: onboardingData,
              photoUrl: onboardingData.profilePhoto,
            ),
          );
        } else if (hasProfile) {
          final isVetAdmin = await UserSessionService.instance
              .isCurrentUserVeterinaryAdmin();
          final isAdmin = await UserSessionService.instance
              .isCurrentUserAdmin();
          if (isVetAdmin) {
            nextScreen = const VeterinaryDashboardScreen();
          } else if (isAdmin) {
            nextScreen = const AdminDashboardScreen();
          } else {
            final moderation = await ModerationService.instance
                .getCurrentUserModeration();
            nextScreen = moderation?.isBlocked == true
                ? ModerationGateScreen(state: moderation!)
                : const CabuyaoAccessGate(child: HomeScreen());
          }
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
      body: OnboardingBackground(
        safeArea: false,
        child: FadeTransition(
          opacity: _fade,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final height = constraints.maxHeight;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: height * 0.20),
                    const Center(child: BreedrLogo(size: 205)),
                    SizedBox(height: height * 0.025),
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        'Breedr.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 54,
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
                    SizedBox(height: height * 0.055),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleSessionConfirmationScreen extends StatefulWidget {
  final String? expectedEmail;

  const _GoogleSessionConfirmationScreen({this.expectedEmail});

  @override
  State<_GoogleSessionConfirmationScreen> createState() =>
      _GoogleSessionConfirmationScreenState();
}

class _GoogleSessionConfirmationScreenState
    extends State<_GoogleSessionConfirmationScreen> {
  bool _working = false;

  Future<void> _confirmAccount() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await UserSessionService.instance.confirmSavedGoogleSession();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoadingScreen()),
      );
    } on SavedGoogleAccountMismatch catch (error) {
      if (!mounted) return;
      final expected = error.expectedEmail;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            expected == null || expected.isEmpty
                ? 'Please select the Google account previously used in Breedr.'
                : 'Please select $expected to restore this Breedr session.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'We could not confirm that Google account. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _useAnotherAccount() async {
    if (_working) return;
    setState(() => _working = true);
    await UserSessionService.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const GetStartedScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final expectedEmail = widget.expectedEmail;
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.manage_accounts_outlined,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: 20),
              const Text(
                'Confirm your Google account',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                expectedEmail == null || expectedEmail.isEmpty
                    ? 'This phone has multiple Google accounts. Select the account you previously used with Breedr.'
                    : 'This phone has multiple Google accounts. Select $expectedEmail to continue.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF666666),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _working ? null : _confirmAccount,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: _working
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Choose Google account'),
                ),
              ),
              TextButton(
                onPressed: _working ? null : _useAnotherAccount,
                child: const Text('Use another Breedr account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionRecoveryScreen extends StatefulWidget {
  const _SessionRecoveryScreen();

  @override
  State<_SessionRecoveryScreen> createState() => _SessionRecoveryScreenState();
}

class _SessionRecoveryScreenState extends State<_SessionRecoveryScreen> {
  bool _clearingSession = false;

  Future<void> _retry() async {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoadingScreen()),
    );
  }

  Future<void> _useAnotherAccount() async {
    if (_clearingSession) return;
    setState(() => _clearingSession = true);
    await UserSessionService.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const GetStartedScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: 20),
              const Text(
                'We could not restore your session',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your account has not been logged out. Check your internet connection, then try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF666666), height: 1.4),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _clearingSession ? null : _retry,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text('Try Again'),
                ),
              ),
              TextButton(
                onPressed: _clearingSession ? null : _useAnotherAccount,
                child: _clearingSession
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Use another account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
