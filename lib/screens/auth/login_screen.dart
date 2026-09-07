import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../admin/admin_dashboard_screen.dart';
import '../veterinary/veterinary_dashboard_screen.dart';
import '../home_screen.dart';
import '../signup/create_account.dart';
import '../../services/location_service.dart';
import '../../services/moderation_service.dart';
import '../../services/user_session_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'forgot_password_screen.dart';
import 'cabuyao_access_gate_screen.dart';
import 'location_permission_screen.dart';
import 'moderation_gate_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.initialMessage});

  final String? initialMessage;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    final initialMessage = widget.initialMessage;
    if (initialMessage != null && initialMessage.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(initialMessage)));
      });
    }

    debugPrint('===== LOGIN SCREEN LOCATION CHECK =====');
    debugPrint('Latitude: ${LocationService.instance.latitude}');
    debugPrint('Longitude: ${LocationService.instance.longitude}');
    debugPrint('Location: ${LocationService.instance.locationName}');
    debugPrint('=======================================');
  }

  //login code
  Future<void> _login() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email and password.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('===== LOGIN ATTEMPT =====');
      debugPrint('Email: ${_emailCtrl.text.trim()}');

      final credential = await UserSessionService.instance.signInWithEmail(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      debugPrint('Login successful: ${credential.user?.uid}');
      debugPrint('Email: ${credential.user?.email}');

      final hasProfile = await UserSessionService.instance.hasBreedrProfile();

      if (!hasProfile) {
        await UserSessionService.instance.signOut();
        throw Exception('No Breedr account found. Please sign up first.');
      }

      if (!mounted) return;

      final isVetAdmin = await UserSessionService.instance
          .isCurrentUserVeterinaryAdmin();
      final isAdmin = await UserSessionService.instance.isCurrentUserAdmin();
      Widget destination = const CabuyaoAccessGate(child: HomeScreen());

      if (isVetAdmin) {
        destination = const VeterinaryDashboardScreen();
      } else if (isAdmin) {
        destination = const AdminDashboardScreen();
      } else {
        final moderation = await ModerationService.instance
            .getCurrentUserModeration();
        if (moderation?.isBlocked == true) {
          destination = ModerationGateScreen(state: moderation!);
        }
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => destination),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase login error: ${e.code}');

      String message;

      switch (e.code) {
        case 'user-not-found':
          message = 'No Breedr account was found. Please sign up first.';
          break;

        case 'wrong-password':
        case 'invalid-credential':
          message = 'Incorrect email or password.';
          break;

        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;

        case 'user-disabled':
          message = 'This account has been disabled. Please contact support.';
          break;

        case 'too-many-requests':
          message = 'Too many sign-in attempts. Please wait and try again.';
          break;

        case 'network-request-failed':
          message = 'Please check your internet connection and try again.';
          break;

        case 'operation-not-allowed':
          message =
              'Email sign-in is currently unavailable. Please contact support.';
          break;

        default:
          message = 'Unable to sign in right now. Please try again.';
          break;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      debugPrint('Unexpected login error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_loginErrorMessage(e))));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
    });

    try {
      final userCredential = await UserSessionService.instance
          .signInWithGoogle();
      final user = userCredential.user;

      if (user == null) {
        throw Exception('Unable to sign in with Google');
      }

      final hasProfile = await UserSessionService.instance.hasBreedrProfile();

      if (!hasProfile) {
        await UserSessionService.instance.signOut();
        throw Exception('No Breedr account found. Please sign up first.');
      }

      if (!mounted) return;

      final isVetAdmin = await UserSessionService.instance
          .isCurrentUserVeterinaryAdmin();
      final isAdmin = await UserSessionService.instance.isCurrentUserAdmin();
      Widget destination = const CabuyaoAccessGate(child: HomeScreen());

      if (isVetAdmin) {
        destination = const VeterinaryDashboardScreen();
      } else if (isAdmin) {
        destination = const AdminDashboardScreen();
      } else {
        final moderation = await ModerationService.instance
            .getCurrentUserModeration();
        if (moderation?.isBlocked == true) {
          destination = ModerationGateScreen(state: moderation!);
        }
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => destination),
      );
    } catch (e) {
      if (!mounted) return;

      debugPrint('Google login error: $e');

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_googleSignInMessage(e))));
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  void _openSignUp() {
    final destination = LocationService.instance.hasVerifiedLocation
        ? const Step1AboutYou()
        : const LocationPermissionScreen(destination: Step1AboutYou());

    Navigator.push(context, MaterialPageRoute(builder: (_) => destination));
  }

  String _loginErrorMessage(Object error) {
    final message = error.toString().toLowerCase();

    if (message.contains('no breedr account')) {
      return 'No Breedr account was found. Please sign up first.';
    }
    if (message.contains('network')) {
      return 'Please check your internet connection and try again.';
    }

    return 'Unable to sign in right now. Please try again.';
  }

  String _googleSignInMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-disabled':
          return 'This account has been disabled. Please contact support.';
        case 'too-many-requests':
          return 'Too many sign-in attempts. Please wait and try again.';
        case 'network-request-failed':
          return 'Please check your internet connection and try again.';
        case 'account-exists-with-different-credential':
          return 'An account with this email already exists. Please use its original sign-in method.';
        case 'operation-not-allowed':
          return 'Google sign-in is currently unavailable. Please contact support.';
      }
    }

    final message = error.toString().toLowerCase();
    if (message.contains('canceled') || message.contains('cancelled')) {
      return 'Google sign-in was cancelled.';
    }
    if (message.contains('clientconfigurationerror') ||
        message.contains('providerconfigurationerror') ||
        message.contains('developer console')) {
      return 'Google sign-in is not configured correctly. Please contact support.';
    }
    if (message.contains('uiunavailable')) {
      return 'Google sign-in is unavailable on this device. Please use email sign-in.';
    }
    if (message.contains('usermismatch')) {
      return 'Please use the same Google account and try again.';
    }
    if (message.contains('no breedr account')) {
      return 'No Breedr account was found. Please sign up first.';
    }
    if (message.contains('network')) {
      return 'Please check your internet connection and try again.';
    }

    return 'Google sign-in could not be completed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Back arrow
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 8),
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),

              // Hero illustration — Welcome.png only (dog + heart + cat)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Image.asset(
                  'assets/images/Welcome.png',
                  width: double.infinity,
                  height: 160,
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(height: 16),

              // Welcome back title
              const Text(
                'Welcome back!',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'We missed you — Sign in to continue connecting with pets in the Breedr Community',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF666666),
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Paw marks trail — Welcome1.png, between subtitle and form
              Padding(
                padding: const EdgeInsets.only(left: 24, right: 0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Image.asset(
                    'assets/images/Welcome1.png',
                    width: double.infinity,
                    height: 80,
                    fit: BoxFit.contain,
                    alignment: Alignment.centerRight,
                  ),
                ),
              ),

              // Form fields
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Email label
                    const Text(
                      'EMAIL ADDRESS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF444444),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _InputField(
                      controller: _emailCtrl,
                      hint: 'Enter your email...',
                      prefixIcon: Icons.alternate_email,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),

                    // Password label
                    const Text(
                      'PASSWORD',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF444444),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _InputField(
                      controller: _passCtrl,
                      hint: 'Enter your password',
                      prefixIcon: Icons.lock_outline,
                      obscure: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: const Color(0xFF999999),
                          size: 20,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen(),
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Log in button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _login,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'LOG IN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Don't have account
                    Center(
                      child: GestureDetector(
                        onTap: _openSignUp,
                        child: RichText(
                          text: const TextSpan(
                            text: "Don't have an account? ",
                            style: TextStyle(
                              color: Color(0xFF999999),
                              fontSize: 13,
                            ),
                            children: [
                              TextSpan(
                                text: 'Sign up here.',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // OR divider
                    Row(
                      children: [
                        const Expanded(
                          child: Divider(color: Color(0xFFDDDDDD)),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'or',
                            style: TextStyle(
                              color: Color(0xFF999999),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Divider(color: Color(0xFFDDDDDD)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Continue with Google
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _isGoogleLoading ? null : _loginWithGoogle,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          backgroundColor: Colors.white,
                        ),
                        child: _isGoogleLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Google G logo
                                  Image.asset(
                                    'assets/images/google_logo.png',
                                    width: 22,
                                    height: 22,
                                    errorBuilder: (context, error, stack) =>
                                        const Text(
                                          'G',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF4285F4),
                                          ),
                                        ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Continue with Google',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Terms note
                    Center(
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: const TextSpan(
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF999999),
                          ),
                          children: [
                            TextSpan(
                              text: "By signing up, you agree to Breedr's ",
                            ),
                            TextSpan(
                              text: 'Terms of Service and Privacy Policy',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF666666),
                              ),
                            ),
                            TextSpan(
                              text:
                                  '. Your Google account will only be used for authentication.',
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Reusable input field
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final bool obscure;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.obscure = false,
    this.suffixIcon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
        prefixIcon: Icon(prefixIcon, color: const Color(0xFFBBBBBB), size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
        ),
      ),
    );
  }
}
