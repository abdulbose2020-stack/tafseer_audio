import 'dart:async';

import 'package:tafseer_audio/features/player/domain/audio_engine.dart';
import 'package:tafseer_audio/features/player/domain/audio_track.dart';
import 'package:tafseer_audio/features/player/domain/playback_state.dart';

/// An in-memory engine for provider and widget tests.
class FakeAudioEngine implements AudioEngine {
  FakeAudioEngine({PlaybackState initial = const PlaybackState()})
    : _state = initial;

  final StreamController<PlaybackState> _states =
      StreamController<PlaybackState>.broadcast();

  PlaybackState _state;
  bool disposed = false;

  final List<String> calls = [];
  List<AudioTrack>? lastQueue;
  int? lastInitialIndex;
  Duration? lastSeek;

  @override
  PlaybackState get currentState => _state;

  @override
  Stream<PlaybackState> get stateStream => _states.stream;

  /// Emits a state as if the real engine had changed it.
  void emit(PlaybackState next) {
    _state = next;
    if (!_states.isClosed) {
      _states.add(next);
    }
  }

  @override
  Future<void> setQueue(List<AudioTrack> tracks, {int initialIndex = 0}) async {
    calls.add('setQueue');
    lastQueue = List<AudioTrack>.unmodifiable(tracks);
    lastInitialIndex = initialIndex;
    if (tracks.isEmpty) {
      emit(const PlaybackState());
      return;
    }
    final index = initialIndex.clamp(0, tracks.length - 1).toInt();
    final track = tracks[index];
    emit(
      PlaybackState(
        phase: PlaybackPhase.ready,
        track: track,
        queueIndex: index,
        duration: track.duration ?? const Duration(minutes: 30),
      ),
    );
  }

  @override
  Future<void> play() async {
    calls.add('play');
    final track =
        _state.track ??
        (lastQueue?.isNotEmpty == true ? lastQueue!.first : null);
    if (track == null) {
      return;
    }
    emit(
      _state.copyWith(
        phase: PlaybackPhase.ready,
        isPlaying: true,
        track: track,
      ),
    );
  }

  @override
  Future<void> resume() => play();

  @override
  Future<void> pause() async {
    calls.add('pause');
    emit(_state.copyWith(isPlaying: false, phase: PlaybackPhase.ready));
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    emit(
      _state.copyWith(
        phase: PlaybackPhase.idle,
        isPlaying: false,
        position: Duration.zero,
      ),
    );
  }

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek');
    lastSeek = position;
    emit(_state.copyWith(position: position));
  }

  @override
  Future<void> skipToNext() async {
    calls.add('skipToNext');
  }

  @override
  Future<void> skipToPrevious() async {
    calls.add('skipToPrevious');
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    calls.add('skipToQueueItem');
  }

  @override
  Future<void> dispose() async {
    calls.add('dispose');
    disposed = true;
    await _states.close();
  }
}
