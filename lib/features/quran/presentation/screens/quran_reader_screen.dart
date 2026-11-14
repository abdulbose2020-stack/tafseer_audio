import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/islamic_pattern.dart';
import '../../../surahs/domain/surah.dart';
import '../../domain/quran_surah.dart';
import '../providers/quran_reader_providers.dart';
import '../providers/quran_surah_providers.dart';
import '../widgets/quran_ayah_view.dart';
import 'quran_sources_screen.dart';

/// The Arabic Qur'an reader for one selected Surah.
///
/// The screen watches only [quranSurahProvider] for the Surah passed to it.
/// Reading navigation deliberately does not read or write Tafseer selection,
/// playback state, or the mini player.
class QuranReaderScreen extends ConsumerWidget {
  const QuranReaderScreen({super.key, required this.surah});

  final Surah surah;

  static const Key fontSizeButtonKey = Key('quran-reader-font-size-button');
  static const Key fontSizeSliderKey = Key('quran-reader-font-size-slider');
  static const Key fontSizeValueKey = Key('quran-reader-font-size-value');
  static const Key fontSizeResetKey = Key('quran-reader-font-size-reset');
  static const Key sourcesButtonKey = Key('quran-reader-sources-button');
  static const Key retryButtonKey = Key('quran-reader-retry');
  static const Key basmalaKey = Key('quran-reader-basmala');

  static Route<void> route(Surah surah) {
    return MaterialPageRoute<void>(
      builder: (context) => QuranReaderScreen(surah: surah),
    );
  }

  Future<void> _openFontSizeSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _ReaderFontSizeSheet(),
    );
  }

  void _openSources(BuildContext context) {
    Navigator.of(context).push(QuranSourcesScreen.route());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(quranSurahProvider(surah.number));
    final fontSize = ref.watch(quranReaderFontSizeProvider);

    final contentSlivers = content.when<List<Widget>>(
      data: (quranSurah) => _contentSlivers(quranSurah, fontSize),
      loading: () => const [
        SliverFillRemaining(hasScrollBody: false, child: _ReaderLoading()),
      ],
      error: (error, stackTrace) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _ReaderError(
            onRetry: () {
              ref.invalidate(quranSurahProvider(surah.number));
            },
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(surah.transliteration),
        actions: [
          IconButton(
            key: fontSizeButtonKey,
            tooltip: 'Arabic text size',
            onPressed: () => _openFontSizeSheet(context),
            icon: const Icon(Icons.format_size_rounded),
          ),
          IconButton(
            key: sourcesButtonKey,
            tooltip: 'Sources & Acknowledgements',
            onPressed: () => _openSources(context),
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.contentMaxWidth,
            ),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _ReaderHeader(surah: surah)),
                ...contentSlivers,
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _contentSlivers(QuranSurah quranSurah, double fontSize) {
    return [
      if (quranSurah.basmalaMode == BasmalaMode.prefatory)
        SliverToBoxAdapter(
          child: _BasmalaLine(
            text: quranSurah.basmalaText!,
            fontSize: fontSize,
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          AppSpacing.lg,
          AppSpacing.screenPadding,
          AppSpacing.xxl,
        ),
        sliver: SliverList.builder(
          itemCount: quranSurah.ayahs.length,
          itemBuilder: (context, index) {
            final ayah = quranSurah.ayahs[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == quranSurah.ayahs.length - 1
                    ? 0
                    : AppSpacing.md,
              ),
              child: QuranAyahView(ayah: ayah, fontSize: fontSize),
            );
          },
        ),
      ),
    ];
  }
}

class _ReaderHeader extends StatelessWidget {
  const _ReaderHeader({required this.surah});

  final Surah surah;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.sm,
        AppSpacing.screenPadding,
        0,
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
                  children: [
                    Text(
                      'SURAH ${surah.number}',
                      style: textTheme.labelSmall?.copyWith(
                        color: colors.gold,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Text(
                          surah.arabicName,
                          textDirection: TextDirection.rtl,
                          style: AppTypography.arabic(
                            fontSize: 42,
                            weight: 700,
                            color: colors.gold,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      surah.englishMeaning,
                      textAlign: TextAlign.center,
                      style: textTheme.titleLarge?.copyWith(
                        color: colors.onBrand,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        _ReaderMetaPill(
                          icon: Icons.menu_book_rounded,
                          label: '${surah.ayahCount} Ayahs',
                        ),
                        _ReaderMetaPill(
                          icon: Icons.place_rounded,
                          label: surah.revelationPlace.label,
                        ),
                        const _ReaderMetaPill(
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

class _ReaderMetaPill extends StatelessWidget {
  const _ReaderMetaPill({required this.icon, required this.label});

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

class _BasmalaLine extends StatelessWidget {
  const _BasmalaLine({required this.text, required this.fontSize});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.lg,
        AppSpacing.screenPadding,
        0,
      ),
      child: Column(
        children: [
          SelectionArea(
            child: Text(
              text,
              key: QuranReaderScreen.basmalaKey,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: AppTypography.arabic(
                fontSize: fontSize,
                color: colors.goldStrong,
                height: 1.9,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(color: colors.gold.withValues(alpha: 0.3), height: 1),
        ],
      ),
    );
  }
}

class _ReaderLoading extends StatelessWidget {
  const _ReaderLoading();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
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
              'Loading Surah text...',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderError extends StatelessWidget {
  const _ReaderError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          AppSpacing.lg,
          AppSpacing.screenPadding,
          AppSpacing.xxl,
        ),
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
                'Unable to load this Surah',
                textAlign: TextAlign.center,
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'The bundled Arabic text could not be read. Please try again.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                key: QuranReaderScreen.retryButtonKey,
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

class _ReaderFontSizeSheet extends ConsumerWidget {
  const _ReaderFontSizeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSize = ref.watch(quranReaderFontSizeProvider);
    final controller = ref.read(quranReaderFontSizeProvider.notifier);
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          0,
          AppSpacing.screenPadding,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Arabic text size', style: textTheme.titleLarge),
                ),
                Text(
                  '${fontSize.round()}',
                  key: QuranReaderScreen.fontSizeValueKey,
                  style: textTheme.titleMedium?.copyWith(
                    color: colors.goldStrong,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Slider(
              key: QuranReaderScreen.fontSizeSliderKey,
              value: fontSize,
              min: QuranReaderFontSizes.minimum,
              max: QuranReaderFontSizes.maximum,
              divisions: 22,
              label: '${fontSize.round()}',
              onChanged: controller.setFontSize,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${QuranReaderFontSizes.minimum.round()}',
                  style: textTheme.labelMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                Text(
                  '${QuranReaderFontSizes.maximum.round()}',
                  style: textTheme.labelMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: QuranReaderScreen.fontSizeResetKey,
                onPressed: controller.reset,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Reset'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
