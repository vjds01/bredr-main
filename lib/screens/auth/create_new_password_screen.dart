import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/user_session_service.dart';
import '../../theme/app_colors.dart';
import 'password_updated_screen.dart';

class CreateNewPasswordScreen extends StatefulWidget {
  final String resetCode;

  const CreateNewPasswordScreen({
    super.key,
    required this.resetCode,
  });

  @override
  State<CreateNewPasswordScreen> createState() =>
      _CreateNewPasswordScreenState();
}

class _CreateNewPasswordScreenState extends State<CreateNewPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _checkingCode = true;
  bool _saving = false;
  String? _email;
  String? _codeError;

  @override
  void initState() {
    super.initState();
    _verifyCode();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    try {
      final email = await UserSessionService.instance.verifyPasswordResetCode(
        widget.resetCode,
      );
      if (!mounted) return;
      setState(() {
        _email = email;
        _checkingCode = false;
      });
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _codeError = _codeMessage(error);
        _checkingCode = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _codeError = 'This reset link could not be verified.';
        _checkingCode = false;
      });
    }
  }

  Future<void> _savePassword() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.length < 6) {
      _showMessage('Password must be at least 6 characters.');
      return;
    }
    if (password != confirm) {
      _showMessage('Passwords do not match.');
      return;
    }

    setState(() => _saving = true);
    try {
      await UserSessionService.instance.confirmPasswordReset(
        resetCode: widget.resetCode,
        newPassword: password,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PasswordUpdatedScreen()),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      _showMessage(_saveMessage(error));
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to update your password. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _codeMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'expired-action-code':
        return 'This reset link has expired. Please request a new one.';
      case 'invalid-action-code':
        return 'This reset link is invalid or has already been used.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No Breedr account was found for this reset link.';
      default:
        return error.message?.trim().isNotEmpty == true
            ? error.message!
            : 'This reset link could not be verified.';
    }
  }

  String _saveMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'weak-password':
        return 'Please choose a stronger password.';
      case 'expired-action-code':
        return 'This reset link has expired. Please request a new one.';
      case 'invalid-action-code':
        return 'This reset link is invalid or has already been used.';
      case 'network-request-failed':
        return 'Please check your internet connection and try again.';
      default:
        return error.message?.trim().isNotEmpty == true
            ? error.message!
            : 'Unable to update your password. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 18, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Create New Password',
                      style: TextStyle(
                        color: Color(0xFF222222),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              if (_checkingCode)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (_codeError != null)
                _InvalidResetLink(message: _codeError!)
              else
                _NewPasswordForm(
                  email: _email ?? '',
                  passwordController: _passwordController,
                  confirmController: _confirmController,
                  obscurePassword: _obscurePassword,
                  obscureConfirm: _obscureConfirm,
                  saving: _saving,
                  onTogglePassword: () => setState(
                    () => _obscurePassword = !_obscurePassword,
                  ),
                  onToggleConfirm: () => setState(
                    () => _obscureConfirm = !_obscureConfirm,
                  ),
                  onSubmit: _savePassword,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewPasswordForm extends StatelessWidget {
  final String email;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final bool obscurePassword;
  final bool obscureConfirm;
  final bool saving;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirm;
  final VoidCallback onSubmit;

  const _NewPasswordForm({
    required this.email,
    required this.passwordController,
    required this.confirmController,
    required this.obscurePassword,
    required this.obscureConfirm,
    required this.saving,
    required this.onTogglePassword,
    required this.onToggleConfirm,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          email.isEmpty
              ? 'Choose a strong password to keep your Breedr account secure.'
              : 'Choose a strong password for $email to keep your Breedr account secure.',
          style: const TextStyle(
            color: Color(0xFF777777),
            fontSize: 15,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 34),
        const _AuthLabel('NEW PASSWORD'),
        const SizedBox(height: 8),
        _AuthInput(
          controller: passwordController,
          hint: 'Enter your new password',
          icon: Icons.lock_outline,
          obscureText: obscurePassword,
          suffix: IconButton(
            onPressed: onTogglePassword,
            icon: Icon(
              obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: const Color(0xFFAAAAAA),
            ),
          ),
        ),
        const SizedBox(height: 22),
        const _AuthLabel('CONFIRM PASSWORD'),
        const SizedBox(height: 8),
        _AuthInput(
          controller: confirmController,
          hint: 'Re-enter your new password',
          icon: Icons.lock_outline,
          obscureText: obscureConfirm,
          suffix: IconButton(
            onPressed: onToggleConfirm,
            icon: Icon(
              obscureConfirm
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: const Color(0xFFAAAAAA),
            ),
          ),
        ),
        const SizedBox(height: 42),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: saving ? null : onSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'CONTINUE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _InvalidResetLink extends StatelessWidget {
  final String message;

  const _InvalidResetLink({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 72),
        child: Column(
          children: [
            const Icon(
              Icons.link_off_outlined,
              color: AppColors.primary,
              size: 64,
            ),
            const SizedBox(height: 18),
            const Text(
              'Reset link unavailable',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF777777),
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('Back'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthLabel extends StatelessWidget {
  final String text;

  const _AuthLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF555555),
        fontSize: 11,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _AuthInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final Widget? suffix;

  const _AuthInput({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
        prefixIcon: Icon(icon, color: const Color(0xFFB0B0B0), size: 19),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFFFCDD5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
