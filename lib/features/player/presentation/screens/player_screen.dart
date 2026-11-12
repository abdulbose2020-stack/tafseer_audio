import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/islamic_pattern.dart';
import '../../../surahs/domain/surah.dart';
import '../../../surahs/presentation/providers/surah_providers.dart';
import '../providers/playback_providers.dart';
import '../providers/surah_recording_providers.dart';
import '../utils/playback_time.dart';

/// The full player for one Surah.
///
/// The displayed Surah and the actively playing recording are separate states.
/// Navigating through the catalogue only changes the displayed Surah; it never
/// starts playback, and an unavailable recording never falls back to the
/// temporary engine sample.
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key, required this.surah});

  static const Key previousKey = Key('player-previous');
  static const Key nextKey = Key('player-next');
  static const Key playPauseKey = Key('player-play-pause');
  static const Key seekSliderKey = Key('player-seek-slider');

  final Surah surah;

  static Route<void> route({required Surah surah}) {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          PlayerScreen(surah: surah),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final offset =
            Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 240),
    );
  }

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late Surah _surah;
  double? _dragValue;

  @override
  void initState() {
    super.initState();
    _surah = widget.surah;
  }

  void _showSurah(Surah surah) {
    if (surah.number == _surah.number) {
      return;
    }
    setState(() {
      _surah = surah;
      _dragValue = null;
    });
    ref.read(selectedSurahNumberProvider.notifier).select(surah.number);
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackControllerProvider);
    final controller = ref.read(playbackControllerProvider.notifier);
    final recording = ref.watch(surahRecordingProvider(_surah.number));
    final hasRecording = recording != null;

    final currentTrack = playback.track;
    final isCurrentSurah =
        currentTrack != null &&
        !currentTrack.isTemporarySample &&
        currentTrack.surahNumber == _surah.number;
    final isBusy = isCurrentSurah && playback.isBusy;
    final isPlaying = isCurrentSurah && playback.isPlaying;
    final hasError = isCurrentSurah && playback.hasError;

    final duration = isCurrentSurah ? playback.duration : recording?.duration;
    final position = isCurrentSurah ? playback.position : Duration.zero;
    final maxMilliseconds = duration != null && duration > Duration.zero
        ? duration.inMilliseconds.toDouble()
        : 1.0;
    final currentMilliseconds =
        (_dragValue ?? position.inMilliseconds.toDouble())
            .clamp(0.0, maxMilliseconds)
            .toDouble();
    final canSeek =
        hasRecording && isCurrentSurah && playback.canSeek && !playback.isBusy;

    final otherPlayingSurah =
        currentTrack != null &&
            currentTrack.isSurahRecording &&
            !currentTrack.isTemporarySample &&
            currentTrack.surahNumber != _surah.number
        ? ref.watch(surahByNumberProvider(currentTrack.surahNumber!))
        : null;

    final catalog = ref.watch(surahsProvider).value ?? const <Surah>[];
    final currentIndex = catalog.indexWhere(
      (surah) => surah.number == _surah.number,
    );
    final previousSurah = currentIndex > 0 ? catalog[currentIndex - 1] : null;
    final nextSurah = currentIndex >= 0 && currentIndex < catalog.length - 1
        ? catalog[currentIndex + 1]
        : null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _PlayerTopBar(
                title: isCurrentSurah ? 'Now playing' : 'Surah player',
                onClose: () {
                  Navigator.of(context).pop();
                },
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    AppSpacing.sm,
                    AppSpacing.screenPadding,
                    AppSpacing.xl,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        children: [
                          _SurahMedallion(surah: _surah),
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            _surah.transliteration,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            _surah.englishMeaning,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.muted),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            alignment: WrapAlignment.center,
                            children: [
                              _InfoPill(
                                icon: Icons.menu_book_rounded,
                                label: 'Surah ${_surah.number}',
                              ),
                              _InfoPill(
                                icon: Icons.format_list_numbered_rounded,
                                label: '${_surah.ayahCount} Ayahs',
                              ),
                              _InfoPill(
                                icon: Icons.place_rounded,
                                label: _surah.revelationPlace.label,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _PlaybackStatusChip(
                            hasRecording: hasRecording,
                            isCurrentSurah: isCurrentSurah,
                            isPlaying: isPlaying,
                            isBusy: isBusy,
                            hasError: hasError,
                          ),
                          if (otherPlayingSurah != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            _OtherPlaybackNotice(
                              surah: otherPlayingSurah,
                              onView: () {
                                _showSurah(otherPlayingSurah);
                              },
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xl),
                          if (!hasRecording) ...[
                            _UnavailableRecordingCard(surah: _surah),
                            const SizedBox(height: AppSpacing.lg),
                          ] else if (hasError) ...[
                            _PlaybackErrorCard(
                              message:
                                  playback.errorMessage ??
                                  'Unable to play this recording.',
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          _PlaybackProgress(
                            position: Duration(
                              milliseconds: currentMilliseconds.round(),
                            ),
                            duration: duration,
                            value: currentMilliseconds,
                            max: maxMilliseconds,
                            canSeek: canSeek,
                            onChanged: (value) {
                              setState(() {
                                _dragValue = value;
                              });
                            },
                            onChangeEnd: (value) {
                              setState(() {
                                _dragValue = null;
                              });
                              unawaited(
                                controller.seek(
                                  Duration(milliseconds: value.round()),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _TransportControls(
                            hasRecording: hasRecording,
                            isPlaying: isPlaying,
                            isBusy: isBusy,
                            onPlayPause: () {
                              unawaited(controller.toggleSurah(_surah));
                            },
                            onPrevious: previousSurah == null
                                ? null
                                : () {
                                    _showSurah(previousSurah);
                                  },
                            onNext: nextSurah == null
                                ? null
                                : () {
                                    _showSurah(nextSurah);
                                  },
                            previousTooltip: previousSurah == null
                                ? 'First Surah'
                                : 'Previous: ${previousSurah.transliteration}',
                            nextTooltip: nextSurah == null
                                ? 'Last Surah'
                                : 'Next: ${nextSurah.transliteration}',
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            hasRecording
                                ? 'Plays from the bundled local recording.'
                                : 'Playback and seeking are disabled until the '
                                      'recording is added.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.muted),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: const Text('Back to Surah list'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerTopBar extends StatelessWidget {
  const _PlayerTopBar({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.screenPadding,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            tooltip: 'Close player',
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _SurahMedallion extends StatelessWidget {
  const _SurahMedallion({required this.surah});

  final Surah surah;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 232,
      height: 232,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.emerald, AppColors.emeraldDark],
        ),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.55),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.emerald.withValues(alpha: 0.18),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: IslamicPattern(
              color: AppColors.gold,
              opacity: 0.16,
              spacing: 40,
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      surah.arabicName,
                      textDirection: TextDirection.rtl,
                      style: AppTypography.arabic(
                        fontSize: 52,
                        weight: 700,
                        color: AppColors.gold,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SURAH ${surah.number.toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.white.withValues(alpha: 0.78),
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.sand.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.sand),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.muted),
          const SizedBox(width: 5),
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

class _PlaybackStatusChip extends StatelessWidget {
  const _PlaybackStatusChip({
    required this.hasRecording,
    required this.isCurrentSurah,
    required this.isPlaying,
    required this.isBusy,
    required this.hasError,
  });

  final bool hasRecording;
  final bool isCurrentSurah;
  final bool isPlaying;
  final bool isBusy;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final String label;
    final Color foreground;
    final Color background;

    if (!hasRecording) {
      icon = Icons.hourglass_empty_rounded;
      label = 'NOT YET AVAILABLE';
      foreground = AppColors.goldDeep;
      background = AppColors.gold.withValues(alpha: 0.14);
    } else if (hasError) {
      icon = Icons.error_outline_rounded;
      label = 'PLAYBACK ERROR';
      foreground = AppColors.error;
      background = AppColors.error.withValues(alpha: 0.08);
    } else if (isBusy) {
      icon = Icons.graphic_eq_rounded;
      label = 'PREPARING RECORDING';
      foreground = AppColors.emerald;
      background = AppColors.emerald.withValues(alpha: 0.08);
    } else if (isPlaying) {
      icon = Icons.graphic_eq_rounded;
      label = 'PLAYING THIS SURAH';
      foreground = AppColors.emerald;
      background = AppColors.emerald.withValues(alpha: 0.08);
    } else if (isCurrentSurah) {
      icon = Icons.pause_circle_outline_rounded;
      label = 'PAUSED';
      foreground = AppColors.emerald;
      background = AppColors.emerald.withValues(alpha: 0.08);
    } else {
      icon = Icons.offline_pin_rounded;
      label = 'LOCAL RECORDING READY';
      foreground = AppColors.emerald;
      background = AppColors.emerald.withValues(alpha: 0.08);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              letterSpacing: 0.9,
            ),
          ),
        ],
      ),
    );
  }
}

class _OtherPlaybackNotice extends StatelessWidget {
  const _OtherPlaybackNotice({required this.surah, required this.onView});

  final Surah surah;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.emerald.withValues(alpha: 0.06),
        borderRadius: AppSpacing.cardBorderRadius,
        border: Border.all(color: AppColors.emerald.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.graphic_eq_rounded,
            size: 18,
            color: AppColors.emerald,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Currently playing: Surah ${surah.number} · '
              '${surah.transliteration}',
              style: textTheme.bodySmall?.copyWith(color: AppColors.charcoal),
            ),
          ),
          TextButton(
            onPressed: onView,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('View'),
          ),
        ],
      ),
    );
  }
}

class _UnavailableRecordingCard extends StatelessWidget {
  const _UnavailableRecordingCard({required this.surah});

  final Surah surah;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.sand.withValues(alpha: 0.7),
        borderRadius: AppSpacing.cardBorderRadius,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hourglass_empty_rounded,
              color: AppColors.goldDeep,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recording not yet available',
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  "The Sheikh's tafsir recording for Surah ${surah.number} has "
                  'not been added to the app yet. Playback and seeking will '
                  'unlock when the local recording is bundled.',
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

class _PlaybackErrorCard extends StatelessWidget {
  const _PlaybackErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: AppSpacing.cardBorderRadius,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unable to play this recording',
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.error),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaybackProgress extends StatelessWidget {
  const _PlaybackProgress({
    required this.position,
    required this.duration,
    required this.value,
    required this.max,
    required this.canSeek,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final Duration position;
  final Duration? duration;
  final double value;
  final double max;
  final bool canSeek;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'PLAYBACK',
          style: textTheme.labelSmall?.copyWith(
            color: AppColors.muted,
            letterSpacing: 1,
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            disabledActiveTrackColor: AppColors.gold.withValues(alpha: 0.45),
            disabledInactiveTrackColor: AppColors.sand,
            disabledThumbColor: AppColors.muted.withValues(alpha: 0.5),
          ),
          child: Slider(
            key: PlayerScreen.seekSliderKey,
            value: value,
            max: max,
            activeColor: AppColors.emerald,
            inactiveColor: AppColors.sand,
            onChanged: canSeek ? onChanged : null,
            onChangeEnd: canSeek ? onChangeEnd : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatPlaybackDuration(position),
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.muted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                formatPlaybackDuration(duration),
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.muted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TransportControls extends StatelessWidget {
  const _TransportControls({
    required this.hasRecording,
    required this.isPlaying,
    required this.isBusy,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.previousTooltip,
    required this.nextTooltip,
  });

  final bool hasRecording;
  final bool isPlaying;
  final bool isBusy;
  final VoidCallback onPlayPause;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final String previousTooltip;
  final String nextTooltip;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          key: PlayerScreen.previousKey,
          onPressed: onPrevious,
          tooltip: previousTooltip,
          iconSize: 36,
          style: IconButton.styleFrom(
            foregroundColor: AppColors.emerald,
            disabledForegroundColor: AppColors.muted.withValues(alpha: 0.35),
          ),
          icon: const Icon(Icons.skip_previous_rounded),
        ),
        const SizedBox(width: AppSpacing.lg),
        Container(
          width: 78,
          height: 78,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: hasRecording ? AppColors.emerald : AppColors.sand,
            shape: BoxShape.circle,
            boxShadow: hasRecording
                ? [
                    BoxShadow(
                      color: AppColors.emerald.withValues(alpha: 0.18),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: IconButton(
            key: PlayerScreen.playPauseKey,
            onPressed: hasRecording && !isBusy ? onPlayPause : null,
            tooltip: !hasRecording
                ? 'Recording not yet available'
                : (isPlaying ? 'Pause' : 'Play'),
            color: AppColors.white,
            disabledColor: AppColors.muted,
            icon: isBusy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppColors.white,
                    ),
                  )
                : Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 44,
                  ),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        IconButton(
          key: PlayerScreen.nextKey,
          onPressed: onNext,
          tooltip: nextTooltip,
          iconSize: 36,
          style: IconButton.styleFrom(
            foregroundColor: AppColors.emerald,
            disabledForegroundColor: AppColors.muted.withValues(alpha: 0.35),
          ),
          icon: const Icon(Icons.skip_next_rounded),
        ),
      ],
    );
  }
}
