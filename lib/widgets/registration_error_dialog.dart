import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

Future<bool> showExistingAccountDialog(
  BuildContext context, {
  required String message,
}) async {
  final goToLogin = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Account already exists'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Stay here'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('Go to login'),
        ),
      ],
    ),
  );

  return goToLogin ?? false;
}

Future<void> showRegistrationErrorDialog(
  BuildContext context, {
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Unable to create account'),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
