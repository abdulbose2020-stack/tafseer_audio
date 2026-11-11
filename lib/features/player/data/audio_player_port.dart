import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as just_audio;

/// Plugin-independent processing states used by the audio engine.
enum PlayerProcessingState { idle, loading, buffering, ready, completed, error }

/// A small snapshot of the underlying player.
///
/// The real adapter combines several `just_audio` streams into this model so
/// the handler and its tests do not depend on the plugin directly.
@immutable
class PlayerSnapshot {
  const PlayerSnapshot({
    this.processingState = PlayerProcessingState.idle,
    this.playing = false,
    this.position = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.duration,
    this.errorMessage,
  });

  final PlayerProcessingState processingState;
  final bool playing;
  final Duration position;
  final Duration bufferedPosition;
  final Duration? duration;
  final String? errorMessage;

  static const Object _unset = Object();

  PlayerSnapshot copyWith({
    PlayerProcessingState? processingState,
    bool? playing,
    Duration? position,
    Duration? bufferedPosition,
    Object? duration = _unset,
    Object? errorMessage = _unset,
  }) {
    return PlayerSnapshot(
      processingState: processingState ?? this.processingState,
      playing: playing ?? this.playing,
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
        other is PlayerSnapshot &&
            other.processingState == processingState &&
            other.playing == playing &&
            other.position == position &&
            other.bufferedPosition == bufferedPosition &&
            other.duration == duration &&
            other.errorMessage == errorMessage;
  }

  @override
  int get hashCode => Object.hash(
    processingState,
    playing,
    position,
    bufferedPosition,
    duration,
    errorMessage,
  );
}

/// The subset of `just_audio` the engine needs.
abstract interface class AudioPlayerPort {
  Stream<PlayerSnapshot> get snapshots;

  PlayerSnapshot get currentSnapshot;

  Future<Duration?> setAsset(String assetPath);

  Future<void> play();

  Future<void> pause();

  Future<void> stop();

  Future<void> seek(Duration position);

  Future<void> setVolume(double volume);

  Future<void> dispose();
}

/// The production adapter over a single `just_audio` player.
class JustAudioPlayerPort implements AudioPlayerPort {
  JustAudioPlayerPort({just_audio.AudioPlayer? player})
    : _player =
          player ??
          just_audio.AudioPlayer(
            // The handler owns interruption handling through AudioSessionPort.
            handleInterruptions: false,
          ) {
    _subscriptions.addAll([
      _player.playerStateStream.listen(_onPlayerState),
      _player.playbackEventStream.listen(_onPlaybackEvent),
      _player.positionStream.listen(_onPosition),
    ]);
  }

  final just_audio.AudioPlayer _player;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final StreamController<PlayerSnapshot> _snapshots =
      StreamController<PlayerSnapshot>.broadcast();

  PlayerSnapshot _currentSnapshot = const PlayerSnapshot();
  bool _disposed = false;

  @override
  Stream<PlayerSnapshot> get snapshots => _snapshots.stream;

  @override
  PlayerSnapshot get currentSnapshot => _currentSnapshot;

  @override
  Future<Duration?> setAsset(String assetPath) {
    return _player.setAsset(assetPath);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  void _onPlayerState(just_audio.PlayerState state) {
    _emit(
      _currentSnapshot.copyWith(
        processingState: _mapProcessingState(state.processingState),
        playing: state.playing,
      ),
    );
  }

  void _onPlaybackEvent(just_audio.PlaybackEvent event) {
    _emit(
      _currentSnapshot.copyWith(
        processingState: _mapProcessingState(event.processingState),
        // Read the live playing flag so a delayed processing-state event does
        // not temporarily revert a newer play/pause command.
        playing: _player.playing,
        bufferedPosition: event.bufferedPosition,
        duration: event.duration,
        errorMessage: event.errorMessage,
      ),
    );
  }

  void _onPosition(Duration position) {
    _emit(
      _currentSnapshot.copyWith(position: position, playing: _player.playing),
    );
  }

  void _emit(PlayerSnapshot snapshot) {
    if (_disposed || snapshot == _currentSnapshot) {
      return;
    }
    _currentSnapshot = snapshot;
    _snapshots.add(snapshot);
  }

  static PlayerProcessingState _mapProcessingState(
    just_audio.ProcessingState state,
  ) {
    return switch (state) {
      just_audio.ProcessingState.idle => PlayerProcessingState.idle,
      just_audio.ProcessingState.loading => PlayerProcessingState.loading,
      just_audio.ProcessingState.buffering => PlayerProcessingState.buffering,
      just_audio.ProcessingState.ready => PlayerProcessingState.ready,
      just_audio.ProcessingState.completed => PlayerProcessingState.completed,
    };
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
    await _snapshots.close();
  }
}
