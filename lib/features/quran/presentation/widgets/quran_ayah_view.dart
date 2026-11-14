import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/quran_ayah.dart';
import '../providers/quran_reader_providers.dart';

/// One Ayah in the Qur'an reader.
///
/// The Arabic source string is rendered exactly as supplied. The Ayah number is
/// a separate widget, so no number, Sajdah mark, or other character is ever
/// inserted into the revealed text.
class QuranAyahView extends StatelessWidget {
  const QuranAyahView({
    super.key,
    required this.ayah,
    this.fontSize = QuranReaderFontSizes.defaultSize,
    this.translation,
  });

  final QuranAyah ayah;

  /// Arabic text size supplied by the reader's session font-size control.
  final double fontSize;

  /// Optional content reserved for a future English translation section.
  ///
  /// Stage 2 intentionally leaves this null: neither
  /// [QuranAyah.translation] nor [QuranAyah.footnotes] is displayed yet.
  final Widget? translation;

  static Key cardKey(int number) => ValueKey('quran-ayah-$number');

  static Key arabicKey(int number) => ValueKey('quran-ayah-arabic-$number');

  static Key numberBadgeKey(int number) =>
      ValueKey('quran-ayah-number-$number');

  static Key sajdahKey(int number) => ValueKey('quran-ayah-sajdah-$number');

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      key: cardKey(ayah.number),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppSpacing.cardBorderRadius,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _AyahNumberBadge(number: ayah.number),
              const Spacer(),
              if (ayah.sajdah) _SajdahIndicator(number: ayah.number),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Directionality(
            textDirection: TextDirection.rtl,
            child: SelectionArea(
              child: Text(
                ayah.arabic,
                key: arabicKey(ayah.number),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.start,
                style: AppTypography.arabic(
                  fontSize: fontSize,
                  color: colors.textPrimary,
                  height: 1.95,
                ),
              ),
            ),
          ),
          if (translation != null) ...[
            const SizedBox(height: AppSpacing.lg),
            translation!,
          ],
        ],
      ),
    );
  }
}

class _AyahNumberBadge extends StatelessWidget {
  const _AyahNumberBadge({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      label: 'Ayah $number',
      child: ExcludeSemantics(
        child: Container(
          key: QuranAyahView.numberBadgeKey(number),
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.gold.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(color: colors.gold.withValues(alpha: 0.4)),
          ),
          child: Text(
            '$number',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colors.goldStrong,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _SajdahIndicator extends StatelessWidget {
  const _SajdahIndicator({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      key: QuranAyahView.sajdahKey(number),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.gold.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.self_improvement_rounded,
            size: 14,
            color: colors.goldStrong,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Sajdah',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.goldStrong,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
