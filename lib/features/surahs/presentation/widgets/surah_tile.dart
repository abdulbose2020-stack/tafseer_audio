import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/surah.dart';

class SurahTile extends StatelessWidget {
  const SurahTile({
    super.key,
    required this.surah,
    required this.isSelected,
    required this.onTap,
  });

  final Surah surah;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: isSelected,
      label:
          'Surah ${surah.number}: ${surah.transliteration}. '
          '${surah.englishMeaning}. ${surah.ayahCount} Ayahs. '
          '${surah.revelationPlace.label}.',
      excludeSemantics: true,
      child: Card(
        color: isSelected
            ? AppColors.emerald.withValues(alpha: 0.06)
            : AppColors.white,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isSelected ? AppColors.emerald : AppColors.sand,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                _SurahNumberBadge(number: surah.number, isSelected: isSelected),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        surah.transliteration,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          color: isSelected
                              ? AppColors.emerald
                              : AppColors.charcoal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        surah.englishMeaning,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _MetaPill(
                            icon: Icons.menu_book_rounded,
                            label: '${surah.ayahCount} Ayahs',
                          ),
                          _MetaPill(
                            icon: Icons.place_rounded,
                            label: surah.revelationPlace.label,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 88,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          surah.arabicName,
                          textDirection: TextDirection.rtl,
                          style: AppTypography.arabic(
                            fontSize: 26,
                            weight: 700,
                            color: isSelected
                                ? AppColors.emerald
                                : AppColors.charcoal,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 18,
                        color: isSelected ? AppColors.emerald : AppColors.sand,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SurahNumberBadge extends StatelessWidget {
  const _SurahNumberBadge({required this.number, required this.isSelected});

  final int number;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.emerald
            : AppColors.emerald.withValues(alpha: 0.08),
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected
              ? AppColors.gold
              : AppColors.emerald.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        '$number',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: isSelected ? AppColors.white : AppColors.emerald,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.sand.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.muted),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
