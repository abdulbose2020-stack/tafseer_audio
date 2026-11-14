import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/islamic_pattern.dart';
import '../../../surahs/domain/surah.dart';
import '../../../surahs/presentation/providers/surah_providers.dart';
import 'quran_reader_screen.dart';

/// The reader's own catalogue of all 114 Surahs.
///
/// This deliberately does not share the Tafseer catalogue's search, filter, or
/// selected-Surah state, and it never touches audio playback.
class QuranReaderSurahsScreen extends ConsumerWidget {
  const QuranReaderSurahsScreen({super.key});

  static const Key retryButtonKey = Key('quran-reader-surahs-retry');
  static const Key listKey = Key('quran-reader-surahs-list');

  static Key tileKey(int number) => ValueKey('quran-reader-surah-$number');

  void _openReader(BuildContext context, Surah surah) {
    Navigator.of(context).push(QuranReaderScreen.route(surah));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surahs = ref.watch(surahsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Qur’an Reading')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.contentMaxWidth,
            ),
            child: surahs.when(
              data: (items) => _CatalogueList(
                surahs: items,
                onOpen: (surah) => _openReader(context, surah),
              ),
              loading: () => const _CatalogueLoading(),
              error: (error, stackTrace) => _CatalogueError(
                onRetry: () => ref.invalidate(surahsProvider),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CatalogueList extends StatelessWidget {
  const _CatalogueList({required this.surahs, required this.onOpen});

  final List<Surah> surahs;
  final ValueChanged<Surah> onOpen;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _CatalogueHeader(count: surahs.length)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            0,
            AppSpacing.screenPadding,
            AppSpacing.xxl,
          ),
          sliver: SliverList(
            key: QuranReaderSurahsScreen.listKey,
            delegate: SliverChildBuilderDelegate((context, index) {
              final surah = surahs[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == surahs.length - 1 ? 0 : AppSpacing.sm,
                ),
                child: _ReaderSurahTile(
                  surah: surah,
                  onTap: () => onOpen(surah),
                ),
              );
            }, childCount: surahs.length),
          ),
        ),
      ],
    );
  }
}

class _CatalogueHeader extends StatelessWidget {
  const _CatalogueHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.sm,
        AppSpacing.screenPadding,
        AppSpacing.lg,
      ),
      child: ClipRRect(
        borderRadius: AppSpacing.cardBorderRadius,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.headerStart, colors.headerEnd],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: IslamicPattern(
                  color: colors.gold,
                  opacity: 0.12,
                  spacing: 52,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: colors.gold.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: colors.gold.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Icon(
                            Icons.menu_book_rounded,
                            color: colors.gold,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Read the Arabic Qur’an',
                                style: textTheme.titleLarge?.copyWith(
                                  color: colors.onBrand,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'The complete Mushaf is available offline. '
                                'Choose a Surah to begin reading.',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colors.onBrand.withValues(alpha: 0.78),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        _ReaderPill(
                          icon: Icons.auto_stories_rounded,
                          label: '$count Surahs',
                        ),
                        const _ReaderPill(
                          icon: Icons.offline_bolt_rounded,
                          label: 'Offline',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReaderSurahTile extends StatelessWidget {
  const _ReaderSurahTile({required this.surah, required this.onTap});

  final Surah surah;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label:
          'Surah ${surah.number}: ${surah.transliteration}. '
          '${surah.englishMeaning}. ${surah.ayahCount} Ayahs. '
          '${surah.revelationPlace.label}.',
      excludeSemantics: true,
      child: Card(
        elevation: 0,
        color: colors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: colors.border),
        ),
        child: InkWell(
          key: QuranReaderSurahsScreen.tileKey(surah.number),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                _SurahNumberBadge(number: surah.number),
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
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        surah.englishMeaning,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _ReaderMetaPill(
                            icon: Icons.menu_book_rounded,
                            label: '${surah.ayahCount} Ayahs',
                          ),
                          _ReaderMetaPill(
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
                            color: colors.goldStrong,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: colors.textSecondary,
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
  const _SurahNumberBadge({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: colors.accent.withValues(alpha: 0.2)),
      ),
      child: Text(
        '$number',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: colors.accent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReaderPill extends StatelessWidget {
  const _ReaderPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: colors.onBrand.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.onBrand.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: colors.gold),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onBrand.withValues(alpha: 0.88),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReaderMetaPill extends StatelessWidget {
  const _ReaderMetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _CatalogueLoading extends StatelessWidget {
  const _CatalogueLoading();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Loading the Surah catalogue...',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _CatalogueError extends StatelessWidget {
  const _CatalogueError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppSpacing.cardBorderRadius,
            border: Border.all(color: colors.error.withValues(alpha: 0.24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, color: colors.error, size: 32),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Unable to load the Surah catalogue',
                textAlign: TextAlign.center,
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'The bundled Surah metadata could not be read. Please try '
                'again.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                key: QuranReaderSurahsScreen.retryButtonKey,
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
