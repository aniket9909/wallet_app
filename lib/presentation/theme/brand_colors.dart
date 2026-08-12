import 'package:flutter/material.dart';

class BrandColors {
  BrandColors._();

  static const blue = Color(0xFF0B4FBF);
  static const cyan = Color(0xFF00B8C4);
  static const green = Color(0xFF2ECC71);
  static const navy = Color(0xFF0A2540);
  static const surface = Color(0xFFF7FBFF);
  static const muted = Color(0xFF5B6B80);

  static const logoGradient = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [blue, cyan, green],
  );

  static const washGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFEAF3FF),
      Color(0xFFFFFFFF),
      Color(0xFFE8FBF1),
    ],
  );
}

class BrandLogo extends StatelessWidget {
  final double width;

  const BrandLogo({super.key, this.width = 240});

  static const assetPath = 'assets/logo/logo.jpeg';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}
