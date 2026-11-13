import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Semantic colours shared by the light and dark themes.
///
/// Screens should read these values through [AppThemeColors.of] instead of
/// hard-coding palette colours. This keeps the emerald/gold identity while
/// allowing surfaces and text to adapt to the active brightness.
@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  const AppThemeColors({
    required this.canvas,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.onAccent,
    required this.onBrand,
    required this.gold,
    required this.goldStrong,
    required this.error,
    required this.headerStart,
    required this.headerEnd,
  });

  static const AppThemeColors light = AppThemeColors(
    canvas: AppColors.ivory,
    surface: AppColors.white,
    surfaceMuted: AppColors.sand,
    border: AppColors.sand,
    textPrimary: AppColors.charcoal,
    textSecondary: AppColors.muted,
    accent: AppColors.emerald,
    onAccent: AppColors.white,
    onBrand: AppColors.white,
    gold: AppColors.gold,
    goldStrong: Color(0xFF8A6520),
    error: AppColors.error,
    headerStart: AppColors.emerald,
    headerEnd: AppColors.emeraldDark,
  );

  static const AppThemeColors dark = AppThemeColors(
    canvas: Color(0xFF0C1210),
    surface: Color(0xFF141D19),
    surfaceMuted: Color(0xFF1C2923),
    border: Color(0xFF2B3C34),
    textPrimary: Color(0xFFF4F0E7),
    textSecondary: Color(0xFFA9BCB2),
    accent: Color(0xFF5BC9A4),
    onAccent: Color(0xFF06110D),
    onBrand: AppColors.white,
    gold: Color(0xFFD9B873),
    goldStrong: Color(0xFFE8CD96),
    error: Color(0xFFFFB4AB),
    headerStart: Color(0xFF0A3B2E),
    headerEnd: Color(0xFF06251D),
  );

  /// The page background.
  final Color canvas;

  /// Cards, sheets, and other raised containers.
  final Color surface;

  /// Subtle fills such as chips, meta pills, and disabled controls.
  final Color surfaceMuted;

  /// Dividers and container borders.
  final Color border;

  final Color textPrimary;
  final Color textSecondary;

  /// Interactive green used for icons, links, and selected states.
  final Color accent;

  /// Text/icon colour placed on [accent].
  final Color onAccent;

  /// Text/icon colour placed on the emerald brand header.
  final Color onBrand;

  final Color gold;
  final Color goldStrong;
  final Color error;

  /// Gradient used by the brand header and medallion.
  final Color headerStart;
  final Color headerEnd;

  static AppThemeColors of(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>();
    assert(colors != null, 'AppThemeColors must be registered on ThemeData.');
    return colors ?? light;
  }

  @override
  AppThemeColors copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? accent,
    Color? onAccent,
    Color? onBrand,
    Color? gold,
    Color? goldStrong,
    Color? error,
    Color? headerStart,
    Color? headerEnd,
  }) {
    return AppThemeColors(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      onBrand: onBrand ?? this.onBrand,
      gold: gold ?? this.gold,
      goldStrong: goldStrong ?? this.goldStrong,
      error: error ?? this.error,
      headerStart: headerStart ?? this.headerStart,
      headerEnd: headerEnd ?? this.headerEnd,
    );
  }

  @override
  AppThemeColors lerp(covariant AppThemeColors? other, double t) {
    if (other == null) {
      return this;
    }

    return AppThemeColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      goldStrong: Color.lerp(goldStrong, other.goldStrong, t)!,
      error: Color.lerp(error, other.error, t)!,
      headerStart: Color.lerp(headerStart, other.headerStart, t)!,
      headerEnd: Color.lerp(headerEnd, other.headerEnd, t)!,
    );
  }
}

extension AppThemeColorsContext on BuildContext {
  AppThemeColors get appColors => AppThemeColors.of(this);
}
