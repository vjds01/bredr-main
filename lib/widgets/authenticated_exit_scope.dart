import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

typedef BeforeAppExit = FutureOr<bool> Function();

/// Protects an authenticated root route from revealing an authentication or
/// onboarding screen when Android Back is pressed.
class AuthenticatedExitScope extends StatefulWidget {
  const AuthenticatedExitScope({
    super.key,
    required this.child,
    this.beforeExit,
    this.onExit,
  });

  final Widget child;
  final BeforeAppExit? beforeExit;
  final FutureOr<void> Function()? onExit;

  @override
  State<AuthenticatedExitScope> createState() => _AuthenticatedExitScopeState();
}

class _AuthenticatedExitScopeState extends State<AuthenticatedExitScope> {
  bool _handlingBack = false;

  Future<void> _handleBack() async {
    if (_handlingBack) return;
    _handlingBack = true;

    try {
      final shouldContinue = await widget.beforeExit?.call() ?? true;
      if (!shouldContinue || !mounted) return;

      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Exit Breedr?'),
          content: const Text(
            'Are you sure you want to exit the app? You will remain signed in.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Stay'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Exit app'),
            ),
          ],
        ),
      );

      if (shouldExit != true) return;
      final exit = widget.onExit;
      if (exit != null) {
        await exit();
      } else {
        await SystemNavigator.pop();
      }
    } finally {
      _handlingBack = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_handleBack());
      },
      child: widget.child,
    );
  }
}
