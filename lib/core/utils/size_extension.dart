import 'package:flutter/material.dart';

// Extension for Common Sizes
extension SizeExtension on double {
  double get smallPadding => 8.0;
  double get mediumPadding => 16.0;
  double get largePadding => 24.0;

  double get smallMargin => 8.0;
  double get mediumMargin => 16.0;
  double get largeMargin => 24.0;

  double get smallFontSize => 12.0;
  double get mediumFontSize => 16.0;
  double get largeFontSize => 20.0;

  double get buttonHeight => 48.0;
  double get appBarHeight => 56.0;
  double get cardElevation => 4.0;
   SizedBox get hs => SizedBox(height: this);

  // Create SizedBox with Width
  SizedBox get ws => SizedBox(width: this);
}
