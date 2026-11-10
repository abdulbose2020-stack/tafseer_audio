import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/brand_mark.dart';
import '../../../../core/widgets/islamic_pattern.dart';
import '../../../player/presentation/screens/player_screen.dart';

class SurahListScreen extends StatelessWidget {
  const SurahListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: _SurahListHeader()),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.xl,
                AppSpacing.screenPadding,
                AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
              ),
              sliver: SliverList.list(
                children: [
                  const _SectionHeading(),
                  const SizedBox(height: AppSpacing.md),
                  _CatalogPlaceholder(
                    onPreviewPlayer: () {
                      Navigator.of(context).push(PlayerScreen.route());
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _OfflinePromiseCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SurahListHeader extends StatelessWidget {
  const _SurahListHeader();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.emerald, AppColors.emeraldDark],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: IslamicPattern(
              color: AppColors.gold,
              opacity: 0.14,
              spacing: 62,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              topInset + AppSpacing.lg,
              AppSpacing.screenPadding,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const BrandMark(size: 48),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppConstants.appName,
                            style: textTheme.titleLarge?.copyWith(
                              color: AppColors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'LISTEN  •  REFLECT  •  UNDERSTAND',
                            style: textTheme.labelSmall?.copyWith(
                              color: AppColors.gold,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  AppConstants.appNameArabic,
                  textDirection: TextDirection.rtl,
                  style: AppTypography.arabic(
                    fontSize: 36,
                    weight: 700,
                    color: AppColors.gold,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppConstants.tagline,
                  style: textTheme.bodyLarge?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.78),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _HeaderPill(
                      icon: Icons.offline_bolt_rounded,
                      label: '100% offline',
                    ),
                    _HeaderPill(
                      icon: Icons.menu_book_rounded,
                      label: '114 Surahs',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.gold),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppColors.white),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(child: Text('Surah catalog', style: textTheme.headlineMedium)),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'PHASE 2',
            style: textTheme.labelSmall?.copyWith(
              color: AppColors.goldDeep,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );
  }
}

class _CatalogPlaceholder extends StatelessWidget {
  const _CatalogPlaceholder({required this.onPreviewPlayer});

  final VoidCallback onPreviewPlayer;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: 0.09),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                color: AppColors.emerald,
                size: 26,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('The complete catalog is next', style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Phase 2 will add all 114 Surahs with verified names, ayah '
              'counts, search, and filtering. The final theme, typography, '
              'navigation, and offline foundation are already in place.',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPreviewPlayer,
                icon: const Icon(Icons.play_circle_outline_rounded),
                label: const Text('Preview player design'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflinePromiseCard extends StatelessWidget {
  const _OfflinePromiseCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.sand.withValues(alpha: 0.7),
        borderRadius: AppSpacing.cardBorderRadius,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.offline_bolt_rounded,
            color: AppColors.goldDeep,
            size: 24,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Offline by design', style: textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Every recording will live on your device. No account, '
                  'no network, and no distractions.',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
