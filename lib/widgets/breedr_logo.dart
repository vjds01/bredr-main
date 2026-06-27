import 'package:flutter/material.dart';

/// Displays the Breedr logo from the PNG asset.
/// Place the logo PNG at: assets/images/logo.png
class BreedrLogo extends StatelessWidget {
  final double size;
  const BreedrLogo({super.key, this.size = 160});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
