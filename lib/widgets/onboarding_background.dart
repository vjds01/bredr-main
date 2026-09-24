import 'package:flutter/material.dart';

/// Shared artwork used by the public onboarding and authentication screens.
class OnboardingBackground extends StatelessWidget {
  const OnboardingBackground({
    super.key,
    required this.child,
    this.safeArea = true,
  });

  final Widget child;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final content = safeArea ? SafeArea(child: child) : child;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFFFF8FC),
        image: DecorationImage(
          image: AssetImage('assets/images/background_onboarding.png'),
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
      ),
      child: content,
    );
  }
}
