import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../domain/quran_ayah.dart';

/// The English translation displayed beneath one Ayah's Arabic text.
///
/// The translation is rendered exactly as bundled, including inline footnote
/// markers. Footnotes themselves are intentionally not displayed in this
/// stage. Arabic font-size settings do not affect this text.
class QuranAyahTranslationView extends StatelessWidget {
  const QuranAyahTranslationView({super.key, required this.ayah});

  final QuranAyah ayah;

  static Key textKey(int number) => ValueKey('quran-ayah-translation-$number');

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, color: colors.gold.withValues(alpha: 0.25)),
        const SizedBox(height: AppSpacing.md),
        SelectionArea(
          child: Text(
            ayah.translation,
            key: textKey(ayah.number),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.start,
            style: textTheme.bodyLarge?.copyWith(
              color: colors.textPrimary,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }
}
