import 'package:flutter/material.dart';

abstract final class AppTypography {
  static const String latinFamily = 'Inter';
  static const String arabicFamily = 'Amiri';

  static TextStyle latin({
    double fontSize = 14,
    double weight = 400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: latinFamily,
      fontSize: fontSize,
      fontWeight: _fontWeight(weight),
      fontVariations: [FontVariation('wght', weight)],
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle arabic({
    double fontSize = 24,
    double weight = 400,
    Color? color,
    double? height,
  }) {
    return TextStyle(
      fontFamily: arabicFamily,
      fontSize: fontSize,
      fontWeight: weight >= 600 ? FontWeight.w700 : FontWeight.w400,
      color: color,
      height: height,
    );
  }

  static TextStyle arabicDisplay(Color color) {
    return arabic(fontSize: 44, weight: 700, color: color, height: 1.3);
  }

  static TextStyle arabicTitle(Color color) {
    return arabic(fontSize: 32, weight: 700, color: color, height: 1.35);
  }

  static TextTheme textTheme(Color color) {
    return TextTheme(
      displayLarge: latin(
        fontSize: 40,
        weight: 700,
        color: color,
        height: 1.1,
        letterSpacing: -0.8,
      ),
      displayMedium: latin(
        fontSize: 32,
        weight: 700,
        color: color,
        height: 1.15,
        letterSpacing: -0.4,
      ),
      headlineLarge: latin(
        fontSize: 28,
        weight: 700,
        color: color,
        height: 1.2,
      ),
      headlineMedium: latin(
        fontSize: 24,
        weight: 600,
        color: color,
        height: 1.25,
      ),
      titleLarge: latin(fontSize: 20, weight: 600, color: color, height: 1.3),
      titleMedium: latin(fontSize: 16, weight: 600, color: color, height: 1.35),
      bodyLarge: latin(fontSize: 16, weight: 400, color: color, height: 1.5),
      bodyMedium: latin(fontSize: 14, weight: 400, color: color, height: 1.45),
      bodySmall: latin(fontSize: 12, weight: 400, color: color, height: 1.4),
      labelLarge: latin(fontSize: 14, weight: 600, color: color, height: 1.2),
      labelMedium: latin(
        fontSize: 12,
        weight: 600,
        color: color,
        height: 1.2,
        letterSpacing: 0.3,
      ),
      labelSmall: latin(
        fontSize: 11,
        weight: 500,
        color: color,
        height: 1.2,
        letterSpacing: 0.3,
      ),
    );
  }

  static FontWeight _fontWeight(double weight) {
    if (weight >= 700) {
      return FontWeight.w700;
    }
    if (weight >= 600) {
      return FontWeight.w600;
    }
    if (weight >= 500) {
      return FontWeight.w500;
    }
    return FontWeight.w400;
  }
}
