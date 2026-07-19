import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../auth/welcome_screen.dart';
import '../auth/login_screen.dart';
import '../../models/onboarding_data.dart';
import '../../services/user_session_service.dart';

//done 5/28
class Step1AboutYou extends StatefulWidget {
  const Step1AboutYou({super.key});

  @override
  State<Step1AboutYou> createState() => _Step1AboutYouState();
}

class _Step1AboutYouState extends State<Step1AboutYou> {
  bool _obscurePassword = true;
  bool _isGoogleLoading = false;
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // void _goNext() => Navigator.push(
  //       context,
  //       MaterialPageRoute(
  //         builder: (_) => WelcomeScreen(
  //           name: _nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'User',
  //           email: _emailCtrl.text.isNotEmpty ? _emailCtrl.text : '',
  //         ),
  //       ),
  //     ); old go next code 5/25
  
  void _goNext() {

  // VALIDATION

  if (_nameCtrl.text.trim().isEmpty ||
      _emailCtrl.text.trim().isEmpty ||
      _usernameCtrl.text.trim().isEmpty ||
      _passCtrl.text.trim().isEmpty) {

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please fill in all fields'),
      ),
    );

    return;
  }

  // PASSWORD LENGTH CHECK

  if (_passCtrl.text.trim().length < 6) {

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password must be at least 6 characters'),
      ),
    );

    return;
  }

  // NAVIGATE TO NEXT SCREEN ONLY

  final onboardingData = OnboardingData(
  authProvider: 'email',
  fullName: _nameCtrl.text.trim(),

  userName: _usernameCtrl.text
      .trim()
      .toLowerCase(),

  email: _emailCtrl.text.trim(),

  password: _passCtrl.text.trim(),
);

Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => WelcomeScreen(
      onboardingData: onboardingData,
    ),
  ),
);
}

  Future<void> _signUpWithGoogle() async {
    setState(() => _isGoogleLoading = true);

    try {
      final userCredential =
          await UserSessionService.instance.signInWithGoogle();
      final user = userCredential.user;

      if (user == null) {
        throw Exception('Unable to sign in with Google');
      }

      final email = user.email ?? '';
      final fullName = user.displayName ?? 'Breedr User';

      final onboardingData = OnboardingData(
        authProvider: 'google',
        fullName: fullName,
        userName: _usernameFromEmail(email),
        email: email,
        password: '',
        profilePhoto: user.photoURL,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WelcomeScreen(
            onboardingData: onboardingData,
            photoUrl: onboardingData.profilePhoto,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      debugPrint('Google sign up error: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_googleSignInMessage(e, signingUp: true)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  String _usernameFromEmail(String email) {
    final name = email.split('@').first.toLowerCase();
    final cleaned = name.replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    return cleaned.isEmpty ? 'breedr_user' : cleaned;
  }

  String _googleSignInMessage(Object error, {required bool signingUp}) {
    final action = signingUp ? 'sign-up' : 'login';
    final message = error.toString().toLowerCase();

    if (message.contains('canceled') || message.contains('cancelled')) {
      return 'Google $action was cancelled.';
    }
    if (message.contains('clientconfigurationerror') ||
        message.contains('providerconfigurationerror') ||
        message.contains('developer console')) {
      return 'Google $action is not configured correctly yet. Please contact support.';
    }
    if (message.contains('uiunavailable')) {
      return 'Google $action is unavailable on this device. Please try email sign-up.';
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

    return 'Google $action could not be completed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back arrow
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 0),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios,
                            color: AppColors.primary, size: 20),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Step progress bar
                    _StepProgressBar(currentStep: 1),

                    // Step label
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Step 1 of 3',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Left accent bar + title block
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 4,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Create an Account',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Sign up quickly with Google, or create an account manually. One tap and join the Breedr community!',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF666666),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // FULL NAME
                    _FieldLabel('FULL NAME'),
                    const SizedBox(height: 6),
                    _InputField(
                      controller: _nameCtrl,
                      hint: 'Enter your full name...',
                      prefixIcon: Icons.person_outline,
                    ),
                    const SizedBox(height: 16),

                    // EMAIL ADDRESS
                    _FieldLabel('EMAIL ADDRESS'),
                    const SizedBox(height: 6),
                    _InputField(
                      controller: _emailCtrl,
                      hint: 'Enter your email...',
                      prefixIcon: Icons.alternate_email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      enableSuggestions: false,
                    ),
                    const SizedBox(height: 16),

                    // USERNAME
                    _FieldLabel('USERNAME'),
                    const SizedBox(height: 6),
                    _InputField(
                      controller: _usernameCtrl,
                      hint: 'Enter your username...',
                      prefixIcon: Icons.person_outline,
                      autocorrect: false,
                      enableSuggestions: false,
                    ),
                    const SizedBox(height: 16),

                    // PASSWORD
                    _FieldLabel('PASSWORD'),
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
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Sign up button (outlined)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _goNext,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: AppColors.primary, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          'Sign up',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Already have account
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                        ),
                        child: RichText(
                          text: const TextSpan(
                            text: 'Already have an account? ',
                            style: TextStyle(
                                color: Color(0xFF999999), fontSize: 13),
                            children: [
                              TextSpan(
                                text: 'Log in here.',
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

                    const SizedBox(height: 20),

                    // OR divider
                    Row(
                      children: const [
                        Expanded(child: Divider(color: Color(0xFFDDDDDD))),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('or',
                              style: TextStyle(
                                  color: Color(0xFF999999), fontSize: 13)),
                        ),
                        Expanded(child: Divider(color: Color(0xFFDDDDDD))),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Continue with Google
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed:
                            _isGoogleLoading ? null : _signUpWithGoogle,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: AppColors.primary, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
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

                    const SizedBox(height: 14),

                    // Terms note
                    Center(
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: const TextSpan(
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF999999)),
                          children: [
                            TextSpan(text: "By signing up, you agree to Breedr's "),
                            TextSpan(
                              text: 'Terms of Service and Privacy Policy',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF666666)),
                            ),
                            TextSpan(
                                text:
                                    '. Your Google account will only be used for authentication.'),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Continue to next step — pinned at bottom
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _goNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Continue to next step →',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Color(0xFF444444),
        letterSpacing: 0.8,
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final bool obscure;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final bool autocorrect;
  final bool enableSuggestions;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.obscure = false,
    this.suffixIcon,
    this.keyboardType,
    this.autocorrect = true,
    this.enableSuggestions = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
        prefixIcon:
            Icon(prefixIcon, color: const Color(0xFFBBBBBB), size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.2),
        ),
      ),
    );
  }
}

// Step progress bar with paw icons
class _StepProgressBar extends StatelessWidget {
  final int currentStep;
  const _StepProgressBar({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Lines drawn behind the dots
          Positioned.fill(
            child: Row(
              children: [
                const SizedBox(width: 36),
                Expanded(child: _StepLine(active: currentStep > 1)),
                const SizedBox(width: 72),
                Expanded(child: _StepLine(active: currentStep > 2)),
                const SizedBox(width: 36),
              ],
            ),
          ),
          // Dots on top
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StepDot(step: 1, current: currentStep),
              const Spacer(),
              _StepDot(step: 2, current: currentStep),
              const Spacer(),
              _StepDot(step: 3, current: currentStep),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int step;
  final int current;
  const _StepDot({required this.step, required this.current});

  @override
  Widget build(BuildContext context) {
    final isActive = step <= current;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? AppColors.primary : const Color(0xFFFFF0F5),
        border: Border.all(
          color: isActive ? AppColors.primary : const Color(0xFFFFB3C1),
          width: isActive ? 0 : 2,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.45),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: Icon(
        Icons.pets,
        size: 26,
        color: isActive ? Colors.white : const Color(0xFFFFB3C1),
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool active;
  const _StepLine({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : const Color(0xFFFFCDD5),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
