import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.emerald,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.emerald,
          onPrimary: AppColors.white,
          primaryContainer: AppColors.emeraldLight,
          onPrimaryContainer: AppColors.white,
          secondary: AppColors.gold,
          onSecondary: AppColors.charcoal,
          secondaryContainer: AppColors.sand,
          onSecondaryContainer: AppColors.charcoal,
          surface: AppColors.ivory,
          onSurface: AppColors.charcoal,
          error: AppColors.error,
        );

    final textTheme = AppTypography.textTheme(AppColors.charcoal);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.ivory,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.charcoal,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.cardBorderRadius,
          side: const BorderSide(color: AppColors.sand),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.emerald,
          foregroundColor: AppColors.white,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.emerald,
          minimumSize: const Size(48, 52),
          side: const BorderSide(color: AppColors.emerald),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.emerald,
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.charcoal),
      dividerTheme: const DividerThemeData(
        color: AppColors.sand,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.sand,
        selectedColor: AppColors.emerald,
        disabledColor: AppColors.sand,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: textTheme.labelMedium?.copyWith(color: AppColors.charcoal),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: AppColors.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.gold,
        inactiveTrackColor: AppColors.sand,
        thumbColor: AppColors.emerald,
        overlayColor: AppColors.emerald.withValues(alpha: 0.12),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.charcoal,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.gold,
        linearTrackColor: AppColors.sand,
      ),
    );
  }
}
