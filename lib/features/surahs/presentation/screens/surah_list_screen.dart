import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/brand_mark.dart';
import '../../../../core/widgets/islamic_pattern.dart';
import '../../../player/presentation/providers/playback_providers.dart';
import '../../../player/presentation/providers/surah_recording_providers.dart';
import '../../../player/presentation/screens/player_screen.dart';
import '../../../player/presentation/widgets/mini_player.dart';
import '../../../player/presentation/widgets/sample_audio_card.dart';
import '../../domain/surah.dart';
import '../../domain/surah_filter.dart';
import '../providers/surah_providers.dart';
import '../widgets/surah_tile.dart';

void _openPlayer(BuildContext context, WidgetRef ref, Surah surah) {
  ref.read(selectedSurahNumberProvider.notifier).select(surah.number);
  unawaited(ref.read(playbackControllerProvider.notifier).stopSampleIfLoaded());
  Navigator.of(context).push(PlayerScreen.route(surah: surah));
}

class SurahListScreen extends ConsumerWidget {
  const SurahListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredSurahs = ref.watch(filteredSurahsProvider);
    final selectedSurah = ref.watch(selectedSurahProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final catalogSlivers = filteredSurahs.when<List<Widget>>(
      data: (surahs) {
        if (surahs.isEmpty) {
          return [
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
              ),
              sliver: SliverToBoxAdapter(
                child: _EmptyCatalog(
                  onReset: () {
                    ref.read(surahCatalogControllerProvider.notifier).clear();
                  },
                ),
              ),
            ),
          ];
        }

        return [
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
            ),
            sliver: SliverList.builder(
              itemCount: surahs.length,
              itemBuilder: (context, index) {
                final surah = surahs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: SurahTile(
                    surah: surah,
                    isSelected: selectedSurah?.number == surah.number,
                    onTap: () {
                      _openPlayer(context, ref, surah);
                    },
                  ),
                );
              },
            ),
          ),
        ];
      },
      loading: () => [
        const SliverPadding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          sliver: SliverToBoxAdapter(child: _LoadingCatalog()),
        ),
      ],
      error: (error, stackTrace) => [
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
          ),
          sliver: SliverToBoxAdapter(
            child: _CatalogError(
              onRetry: () {
                ref.invalidate(surahsProvider);
              },
            ),
          ),
        ),
      ],
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        bottomNavigationBar: const MiniPlayer(),
        body: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            const SliverToBoxAdapter(child: _SurahListHeader()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.xl,
                AppSpacing.screenPadding,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SampleAudioCard(),
                    const SizedBox(height: AppSpacing.xl),
                    const _SectionHeading(),
                    const SizedBox(height: AppSpacing.md),
                    const _SearchAndFilterCard(),
                    const SizedBox(height: AppSpacing.md),
                    if (selectedSurah != null) ...[
                      _SelectedSurahCard(surah: selectedSurah),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    const _ResultSummary(),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ),
              ),
            ),
            ...catalogSlivers,
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.xl,
                AppSpacing.screenPadding,
                AppSpacing.xxl + bottomInset,
              ),
              sliver: const SliverToBoxAdapter(child: _OfflinePromiseCard()),
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
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    const _HeaderPill(
                      icon: Icons.offline_bolt_rounded,
                      label: '100% offline',
                    ),
                    _HeaderPill(
                      icon: Icons.menu_book_rounded,
                      label: '${AppConstants.surahCount} Surahs',
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
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Surah catalog', style: textTheme.headlineMedium),
              const SizedBox(height: 2),
              Text(
                'All Surahs in Mushaf order',
                style: textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
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
            '${AppConstants.surahCount} SURAHS',
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

class _SearchAndFilterCard extends StatelessWidget {
  const _SearchAndFilterCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppSpacing.cardBorderRadius,
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SurahSearchField(),
          const SizedBox(height: AppSpacing.md),
          Text(
            'FILTER BY REVELATION',
            style: textTheme.labelSmall?.copyWith(
              color: AppColors.muted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const _SurahFilterBar(),
        ],
      ),
    );
  }
}

class _SurahSearchField extends ConsumerStatefulWidget {
  const _SurahSearchField();

  @override
  ConsumerState<_SurahSearchField> createState() => _SurahSearchFieldState();
}

class _SurahSearchFieldState extends ConsumerState<_SurahSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(surahCatalogControllerProvider).query,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    ref.read(surahCatalogControllerProvider.notifier).setQuery('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(
      surahCatalogControllerProvider.select((state) => state.query),
      (previous, next) {
        if (_controller.text == next) {
          return;
        }
        _controller.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
        setState(() {});
      },
    );

    final textTheme = Theme.of(context).textTheme;
    final hasText = _controller.text.isNotEmpty;

    return TextField(
      controller: _controller,
      onChanged: (value) {
        ref.read(surahCatalogControllerProvider.notifier).setQuery(value);
        setState(() {});
      },
      textInputAction: TextInputAction.search,
      cursorColor: AppColors.emerald,
      style: textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: 'Search by name, number, or meaning',
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.emerald),
        suffixIcon: hasText
            ? IconButton(
                onPressed: _clear,
                tooltip: 'Clear search',
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        filled: true,
        fillColor: AppColors.ivory,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.sand),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.sand),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.emerald, width: 1.5),
        ),
      ),
    );
  }
}

class _SurahFilterBar extends ConsumerWidget {
  const _SurahFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFilter = ref.watch(
      surahCatalogControllerProvider.select((state) => state.filter),
    );

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final filter in SurahFilter.values)
          ChoiceChip(
            label: Text(filter.label),
            selected: filter == selectedFilter,
            showCheckmark: false,
            onSelected: (_) {
              ref
                  .read(surahCatalogControllerProvider.notifier)
                  .setFilter(filter);
            },
            selectedColor: AppColors.emerald,
            backgroundColor: AppColors.ivory,
            side: BorderSide(
              color: filter == selectedFilter
                  ? AppColors.emerald
                  : AppColors.sand,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: filter == selectedFilter
                  ? AppColors.white
                  : AppColors.charcoal,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
      ],
    );
  }
}

class _SelectedSurahCard extends ConsumerWidget {
  const _SelectedSurahCard({required this.surah});

  final Surah surah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final hasRecording =
        ref.watch(surahRecordingProvider(surah.number)) != null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.emerald, AppColors.emeraldDark],
        ),
        borderRadius: AppSpacing.cardBorderRadius,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.gold,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SELECTED SURAH',
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.gold,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${surah.number}. ${surah.transliteration}',
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${surah.englishMeaning}  •  ${surah.ayahCount} Ayahs  •  '
                  '${surah.revelationPlace.label}',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      hasRecording
                          ? Icons.offline_pin_rounded
                          : Icons.schedule_rounded,
                      size: 14,
                      color: AppColors.gold,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        hasRecording
                            ? 'Local recording available'
                            : 'Recording not yet available',
                        style: textTheme.labelSmall?.copyWith(
                          color: AppColors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          IconButton(
            onPressed: () {
              _openPlayer(context, ref, surah);
            },
            tooltip: 'Open player',
            color: AppColors.white,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.arrow_forward_rounded, size: 20),
          ),
          IconButton(
            onPressed: () {
              ref.read(selectedSurahNumberProvider.notifier).clear();
            },
            tooltip: 'Clear selection',
            color: AppColors.white.withValues(alpha: 0.82),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class _ResultSummary extends ConsumerWidget {
  const _ResultSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogState = ref.watch(surahCatalogControllerProvider);
    final count = ref.watch(filteredSurahsProvider).value?.length;

    return Row(
      children: [
        Expanded(
          child: Text(
            _summaryLabel(count, catalogState),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.muted),
          ),
        ),
        if (catalogState.hasActiveFilters)
          TextButton.icon(
            onPressed: () {
              ref.read(surahCatalogControllerProvider.notifier).clear();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.emerald,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
            label: const Text('Clear'),
          ),
      ],
    );
  }

  String _summaryLabel(int? count, SurahCatalogState state) {
    if (count == null) {
      return 'Loading Surahs...';
    }
    if (!state.hasActiveFilters) {
      return 'All $count Surahs';
    }
    final noun = count == 1 ? 'Surah' : 'Surahs';
    return '$count $noun found';
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppSpacing.cardBorderRadius,
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.sand.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off_rounded, color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('No Surahs found', style: textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Try a different name, number, or revelation filter.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Reset search and filters'),
          ),
        ],
      ),
    );
  }
}

class _LoadingCatalog extends StatelessWidget {
  const _LoadingCatalog();

  @override
  Widget build(BuildContext context) {
    return Column(
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
          ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppSpacing.cardBorderRadius,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.24)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 32,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Unable to load the Surah catalogue',
            textAlign: TextAlign.center,
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'The bundled metadata could not be read. Please try again.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
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
                  'All 114 Surahs and their metadata are stored on your '
                  'device. No account, no network, and no distractions.',
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
