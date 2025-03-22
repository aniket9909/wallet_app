import 'package:flutter/material.dart';

@immutable
class CustomColors extends ThemeExtension<CustomColors> {
  final Color? textColor;
  final Color? buttonColor;
  final Color? cardColor;
  final Color? greenColor;
  final Color? redColor;
  final Color? titleColor;
  final Color? subtitleColor;
  final Color? secondaryColor;

  const CustomColors({
    required this.textColor,
    required this.buttonColor,
    required this.cardColor,
    required this.greenColor,
    required this.redColor,
    required this.titleColor,
    required this.subtitleColor,
    required this.secondaryColor,
  });

  @override
  CustomColors copyWith({
    Color? textColor,
    Color? buttonColor,
    Color? cardColor,
    Color? greenColor,
    Color? redColor,
    Color? titleColor,
    Color? subtitleColor,
    Color? secondaryColor,
  }) {
    return CustomColors(
      textColor: textColor ?? this.textColor,
      buttonColor: buttonColor ?? this.buttonColor,
      cardColor: cardColor ?? this.cardColor,
      greenColor: greenColor ?? this.greenColor,
      redColor: redColor ?? this.redColor,
      titleColor: titleColor ?? this.titleColor,
      subtitleColor: subtitleColor ?? this.subtitleColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
    );
  }

  @override
  CustomColors lerp(CustomColors? other, double t) {
    if (other is! CustomColors) return this;
    return CustomColors(
      textColor: Color.lerp(textColor, other.textColor, t),
      buttonColor: Color.lerp(buttonColor, other.buttonColor, t),
      cardColor: Color.lerp(cardColor, other.cardColor, t),
      greenColor: Color.lerp(greenColor, other.greenColor, t),
      redColor: Color.lerp(redColor, other.redColor, t),
      titleColor: Color.lerp(titleColor, other.titleColor, t),
      subtitleColor: Color.lerp(subtitleColor, other.subtitleColor, t),
      secondaryColor: Color.lerp(secondaryColor, other.secondaryColor, t),
    );
  }
}
