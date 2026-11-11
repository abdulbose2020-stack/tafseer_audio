import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/playback_state.dart';
import '../providers/playback_providers.dart';

/// A small, explicitly temporary control for verifying the Phase 3 engine.
///
/// This card is not a Surah player. The recording it controls has no Surah
/// number and is never shown as a Surah tafsir.
class SampleAudioCard extends ConsumerStatefulWidget {
  const SampleAudioCard({super.key});

  @override
  ConsumerState<SampleAudioCard> createState() => _SampleAudioCardState();
}

class _SampleAudioCardState extends ConsumerState<SampleAudioCard> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playbackControllerProvider);
    final controller = ref.read(playbackControllerProvider.notifier);
    final textTheme = Theme.of(context).textTheme;
    final duration = state.duration;
    final maxMilliseconds = duration != null && duration > Duration.zero
        ? duration.inMilliseconds.toDouble()
        : 1.0;
    final currentMilliseconds =
        (_dragValue ?? state.position.inMilliseconds.toDouble())
            .clamp(0.0, maxMilliseconds)
            .toDouble();
    final displayPosition = Duration(milliseconds: currentMilliseconds.round());
    final canSeek = state.canSeek && !state.isBusy;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppSpacing.cardBorderRadius,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.graphic_eq_rounded,
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
                      'TEMPORARY AUDIO ENGINE TEST',
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.goldDeep,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('Wedding sermon sample', style: textTheme.titleMedium),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.sand,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'NOT A SURAH',
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.goldDeep,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'This recording only verifies Phase 3 playback. It is not a Surah '
            'tafsir and is not linked to any Surah.',
            style: textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              FilledButton.icon(
                onPressed: state.isBusy ? null : controller.togglePlayback,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 10,
                  ),
                ),
                icon: state.isBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : Icon(
                        state.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 20,
                      ),
                label: Text(_buttonLabel(state)),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                onPressed: state.hasTrack && !state.isBusy
                    ? controller.stop
                    : null,
                tooltip: 'Stop sample',
                icon: const Icon(Icons.stop_rounded),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${_formatDuration(displayPosition)} / '
                  '${_formatDuration(duration)}',
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(
                    color: AppColors.muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: currentMilliseconds,
              max: maxMilliseconds,
              activeColor: AppColors.emerald,
              inactiveColor: AppColors.sand,
              onChanged: canSeek
                  ? (value) {
                      setState(() {
                        _dragValue = value;
                      });
                    }
                  : null,
              onChangeEnd: canSeek
                  ? (value) {
                      setState(() {
                        _dragValue = null;
                      });
                      controller.seek(Duration(milliseconds: value.round()));
                    }
                  : null,
            ),
          ),
          if (state.hasError)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 16,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      state.errorMessage ?? 'Unable to play the sample.',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _buttonLabel(PlaybackState state) {
    if (state.isBusy) {
      return 'Preparing...';
    }
    if (state.isPlaying) {
      return 'Pause';
    }
    if (state.isCompleted) {
      return 'Replay';
    }
    if (state.hasTrack) {
      return 'Resume';
    }
    return 'Play sample';
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) {
      return '--:--';
    }
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours > 0) {
      return '$hours:${remainingMinutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
