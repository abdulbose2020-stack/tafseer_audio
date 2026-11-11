import 'package:flutter/foundation.dart';

import 'audio_track.dart';

/// The app-owned playback phase. This mirrors the useful states of the audio
/// plugin without exposing plugin types to the UI.
enum PlaybackPhase { idle, loading, buffering, ready, completed, error }

/// The single authoritative playback state for the app.
///
/// The audio handler owns this model. Riverpod mirrors it for the UI; screens
/// never talk to `just_audio` or `audio_service` directly.
@immutable
class PlaybackState {
  const PlaybackState({
    this.phase = PlaybackPhase.idle,
    this.isPlaying = false,
    this.track,
    this.queueIndex,
    this.position = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.duration,
    this.errorMessage,
  });

  final PlaybackPhase phase;
  final bool isPlaying;
  final AudioTrack? track;
  final int? queueIndex;
  final Duration position;
  final Duration bufferedPosition;
  final Duration? duration;
  final String? errorMessage;

  bool get hasTrack => track != null;

  bool get isBusy =>
      phase == PlaybackPhase.loading || phase == PlaybackPhase.buffering;

  bool get isCompleted => phase == PlaybackPhase.completed;

  bool get hasError => phase == PlaybackPhase.error;

  bool get canSeek => duration != null && duration! > Duration.zero;

  /// Playback progress in the range 0.0–1.0.
  double get progress {
    final total = duration?.inMilliseconds ?? 0;
    if (total <= 0) {
      return 0;
    }
    return (position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  static const Object _unset = Object();

  PlaybackState copyWith({
    PlaybackPhase? phase,
    bool? isPlaying,
    Object? track = _unset,
    Object? queueIndex = _unset,
    Duration? position,
    Duration? bufferedPosition,
    Object? duration = _unset,
    Object? errorMessage = _unset,
  }) {
    return PlaybackState(
      phase: phase ?? this.phase,
      isPlaying: isPlaying ?? this.isPlaying,
      track: identical(track, _unset) ? this.track : track as AudioTrack?,
      queueIndex: identical(queueIndex, _unset)
          ? this.queueIndex
          : queueIndex as int?,
      position: position ?? this.position,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      duration: identical(duration, _unset)
          ? this.duration
          : duration as Duration?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PlaybackState &&
            other.phase == phase &&
            other.isPlaying == isPlaying &&
            other.track == track &&
            other.queueIndex == queueIndex &&
            other.position == position &&
            other.bufferedPosition == bufferedPosition &&
            other.duration == duration &&
            other.errorMessage == errorMessage;
  }

  @override
  int get hashCode => Object.hash(
    phase,
    isPlaying,
    track,
    queueIndex,
    position,
    bufferedPosition,
    duration,
    errorMessage,
  );

  @override
  String toString() {
    return 'PlaybackState(phase: $phase, isPlaying: $isPlaying, '
        'track: ${track?.id}, position: $position, duration: $duration)';
  }
}
