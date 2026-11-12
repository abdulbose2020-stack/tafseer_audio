import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../surahs/domain/surah.dart';
import '../../../surahs/presentation/providers/surah_providers.dart';
import '../providers/playback_providers.dart';
import '../screens/player_screen.dart';
import '../utils/playback_time.dart';

/// A compact player for the currently loaded real Surah recording.
///
/// The temporary engine sample is deliberately excluded. That sample keeps its
/// own labelled card and is never represented as a Surah here.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  static const Key widgetKey = Key('mini-player');
  static const Key openKey = Key('mini-player-open');
  static const Key playPauseKey = Key('mini-player-play-pause');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackControllerProvider);
    final track = playback.track;

    if (track == null || !track.isSurahRecording || track.isTemporarySample) {
      return const SizedBox.shrink();
    }

    final surah = ref.watch(surahByNumberProvider(track.surahNumber!));
    if (surah == null) {
      return const SizedBox.shrink();
    }

    final controller = ref.read(playbackControllerProvider.notifier);
    final textTheme = Theme.of(context).textTheme;
    final isBusy = playback.isBusy;

    return SafeArea(
      key: widgetKey,
      top: false,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.emerald, AppColors.emeraldDark],
          ),
          border: Border(
            top: BorderSide(
              color: AppColors.gold.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: playback.progress,
              minHeight: 3,
              backgroundColor: AppColors.white.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
            ),
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: openKey,
                      onTap: () {
                        ref
                            .read(selectedSurahNumberProvider.notifier)
                            .select(surah.number);
                        Navigator.of(
                          context,
                        ).push(PlayerScreen.route(surah: surah));
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenPadding,
                          AppSpacing.sm,
                          AppSpacing.sm,
                          AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            _MiniSurahBadge(surah: surah),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Surah ${surah.number} · '
                                    '${surah.transliteration}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.titleMedium?.copyWith(
                                      color: AppColors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${formatPlaybackDuration(playback.position)}'
                                    ' / ${formatPlaybackDuration(playback.duration)}'
                                    '  ·  ${surah.englishMeaning}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: AppColors.white.withValues(
                                        alpha: 0.72,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    right: AppSpacing.screenPadding,
                    left: AppSpacing.xs,
                  ),
                  child: IconButton(
                    key: playPauseKey,
                    onPressed: isBusy
                        ? null
                        : () {
                            unawaited(controller.toggleCurrentSurah());
                          },
                    tooltip: playback.isPlaying ? 'Pause' : 'Play',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.gold.withValues(alpha: 0.18),
                      foregroundColor: AppColors.gold,
                      disabledForegroundColor: AppColors.white.withValues(
                        alpha: 0.38,
                      ),
                    ),
                    icon: isBusy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.gold,
                            ),
                          )
                        : Icon(
                            playback.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniSurahBadge extends StatelessWidget {
  const _MiniSurahBadge({required this.surah});

  final Surah surah;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Text(
        '${surah.number}',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppColors.gold,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
