import 'dart:async';

import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

import '../domain/audio_engine.dart';
import '../domain/audio_track.dart';
import '../domain/playback_state.dart';
import 'audio_player_port.dart';
import 'audio_session_port.dart';

/// The single `audio_service` handler and audio engine for the app.
///
/// It owns one `just_audio` player, the playback queue, the media notification
/// state, and the audio-session interruption/headphone handling. UI code talks
/// to this through [AudioEngine] and the Riverpod playback controller only.
class TafseerAudioHandler extends audio_service.BaseAudioHandler
    implements AudioEngine {
  TafseerAudioHandler({AudioPlayerPort? player, AudioSessionPort? audioSession})
    : _player = player ?? JustAudioPlayerPort(),
      _audioSession = audioSession ?? SpeechAudioSessionPort() {
    _playerSubscription = _player.snapshots.listen(_onPlayerSnapshot);
    _audioSessionReady = _initializeAudioSession();
  }

  final AudioPlayerPort _player;
  final AudioSessionPort _audioSession;
  final StreamController<PlaybackState> _stateController =
      StreamController<PlaybackState>.broadcast();

  late final StreamSubscription<PlayerSnapshot> _playerSubscription;
  late final Future<void> _audioSessionReady;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSubscription;
  StreamSubscription<void>? _noisySubscription;

  PlaybackState _state = const PlaybackState();
  List<AudioTrack> _tracks = const [];
  int _currentIndex = 0;
  int _loadGeneration = 0;
  bool _playWhenReady = false;
  bool _resumeAfterInterruption = false;
  bool _handlingCompletion = false;
  bool _disposed = false;

  @override
  PlaybackState get currentState => _state;

  @override
  Stream<PlaybackState> get stateStream => _stateController.stream;

  /// Completes when the audio session has been configured and its event
  /// streams have been connected. Exposed for startup and tests.
  @visibleForTesting
  Future<void> get audioSessionReady => _audioSessionReady;

  AudioTrack? get _currentTrack {
    if (_currentIndex < 0 || _currentIndex >= _tracks.length) {
      return null;
    }
    return _tracks[_currentIndex];
  }

  @override
  Future<void> setQueue(List<AudioTrack> tracks, {int initialIndex = 0}) async {
    if (_disposed) {
      return;
    }

    if (tracks.isEmpty) {
      _tracks = const [];
      _currentIndex = 0;
      _loadGeneration++;
      _playWhenReady = false;
      await _player.stop();
      if (_disposed) {
        return;
      }
      queue.add(const []);
      queueTitle.add('');
      mediaItem.add(null);
      _emit(const PlaybackState());
      return;
    }

    _tracks = List<AudioTrack>.unmodifiable(tracks);
    _currentIndex = initialIndex < 0
        ? 0
        : (initialIndex >= _tracks.length ? _tracks.length - 1 : initialIndex);
    _playWhenReady = false;
    queueTitle.add('Tafseer Audio');
    queue.add(_tracks.map(_toMediaItem).toList());
    _publishCurrentItem();
    await _loadCurrentTrack(autoPlay: false);
  }

  Future<void> _loadCurrentTrack({required bool autoPlay}) async {
    final track = _currentTrack;
    if (track == null || _disposed) {
      return;
    }

    final generation = ++_loadGeneration;
    _playWhenReady = autoPlay || _playWhenReady;
    _publishCurrentItem();
    _emit(
      _state.copyWith(
        phase: PlaybackPhase.loading,
        isPlaying: false,
        track: track,
        queueIndex: _currentIndex,
        position: Duration.zero,
        bufferedPosition: Duration.zero,
        duration: track.duration,
        errorMessage: null,
      ),
    );

    try {
      final duration = await _player.setAsset(track.assetPath);
      if (_disposed || generation != _loadGeneration) {
        return;
      }

      final resolvedDuration = duration ?? track.duration;
      _emit(
        _state.copyWith(
          phase: PlaybackPhase.ready,
          duration: resolvedDuration,
          position: Duration.zero,
          bufferedPosition: Duration.zero,
        ),
      );
      if (resolvedDuration != null) {
        _publishCurrentItem(duration: resolvedDuration);
      }

      if (_playWhenReady) {
        _playWhenReady = false;
        await _startPlayback();
      }
    } catch (error) {
      if (_disposed || generation != _loadGeneration) {
        return;
      }
      _playWhenReady = false;
      _emitError(_describeError(error));
    }
  }

  @override
  Future<void> play() async {
    if (_disposed || _tracks.isEmpty) {
      return;
    }

    _resumeAfterInterruption = false;

    if (_state.isBusy) {
      _playWhenReady = true;
      return;
    }

    if (_state.hasError) {
      await _loadCurrentTrack(autoPlay: true);
      return;
    }

    await _startPlayback();
  }

  @override
  Future<void> resume() => play();

  Future<void> _startPlayback() async {
    if (_disposed || _currentTrack == null) {
      return;
    }

    if (_state.phase == PlaybackPhase.completed) {
      await _player.seek(Duration.zero);
      if (_disposed) {
        return;
      }
      _emit(
        _state.copyWith(phase: PlaybackPhase.ready, position: Duration.zero),
      );
    }

    _emit(
      _state.copyWith(
        phase: PlaybackPhase.ready,
        isPlaying: true,
        errorMessage: null,
      ),
    );

    unawaited(
      _player.play().catchError((Object error) {
        if (!_disposed) {
          _emitError(_describeError(error));
        }
      }),
    );
  }

  @override
  Future<void> pause() => _pause(fromInterruption: false);

  Future<void> _pause({required bool fromInterruption}) async {
    if (_disposed) {
      return;
    }
    if (!fromInterruption) {
      _resumeAfterInterruption = false;
    }
    _playWhenReady = false;
    await _player.pause();
    if (_disposed) {
      return;
    }

    final nextPhase = switch (_state.phase) {
      PlaybackPhase.idle => PlaybackPhase.idle,
      PlaybackPhase.completed => PlaybackPhase.completed,
      PlaybackPhase.error => PlaybackPhase.error,
      _ => PlaybackPhase.ready,
    };
    _emit(_state.copyWith(isPlaying: false, phase: nextPhase));
  }

  @override
  Future<void> stop() async {
    if (_disposed) {
      return;
    }

    _playWhenReady = false;
    _resumeAfterInterruption = false;
    _loadGeneration++;
    await _player.stop();

    if (_currentTrack != null) {
      try {
        await _player.seek(Duration.zero);
      } catch (_) {
        // The state below still resets the UI; a failed reset is non-fatal.
      }
    }

    if (_disposed) {
      return;
    }
    _emit(
      _state.copyWith(
        phase: PlaybackPhase.idle,
        isPlaying: false,
        position: Duration.zero,
        bufferedPosition: Duration.zero,
      ),
    );
  }

  @override
  Future<void> seek(Duration position) async {
    if (_disposed || _currentTrack == null) {
      return;
    }

    var target = position < Duration.zero ? Duration.zero : position;
    final duration = _state.duration;
    if (duration != null && target > duration) {
      target = duration;
    }

    await _player.seek(target);
    if (_disposed) {
      return;
    }
    _emit(
      _state.copyWith(
        position: target,
        phase: _state.phase == PlaybackPhase.completed
            ? PlaybackPhase.ready
            : _state.phase,
      ),
    );
  }

  @override
  Future<void> skipToNext() async {
    if (_disposed || _currentIndex >= _tracks.length - 1) {
      return;
    }
    final wasPlaying = _state.isPlaying || _playWhenReady;
    _currentIndex++;
    await _loadCurrentTrack(autoPlay: wasPlaying);
  }

  @override
  Future<void> skipToPrevious() async {
    if (_disposed || _tracks.isEmpty) {
      return;
    }
    if (_state.position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
      return;
    }
    if (_currentIndex <= 0) {
      await seek(Duration.zero);
      return;
    }
    final wasPlaying = _state.isPlaying || _playWhenReady;
    _currentIndex--;
    await _loadCurrentTrack(autoPlay: wasPlaying);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (_disposed || index < 0 || index >= _tracks.length) {
      return;
    }
    if (index == _currentIndex) {
      return;
    }
    final wasPlaying = _state.isPlaying || _playWhenReady;
    _currentIndex = index;
    await _loadCurrentTrack(autoPlay: wasPlaying);
  }

  void _onPlayerSnapshot(PlayerSnapshot snapshot) {
    if (_disposed) {
      return;
    }

    final phase = _phaseFromSnapshot(snapshot);
    final duration = snapshot.duration ?? _state.duration;
    _emit(
      _state.copyWith(
        phase: phase,
        isPlaying: snapshot.playing && phase != PlaybackPhase.completed,
        position: snapshot.position,
        bufferedPosition: snapshot.bufferedPosition,
        duration: duration,
        errorMessage: snapshot.errorMessage,
      ),
    );

    if (duration != null && mediaItem.value?.duration != duration) {
      _publishCurrentItem(duration: duration);
    }

    if (phase == PlaybackPhase.completed) {
      unawaited(_handleCompletion());
    }
  }

  PlaybackPhase _phaseFromSnapshot(PlayerSnapshot snapshot) {
    if (snapshot.errorMessage != null ||
        snapshot.processingState == PlayerProcessingState.error) {
      return PlaybackPhase.error;
    }
    return switch (snapshot.processingState) {
      PlayerProcessingState.idle => PlaybackPhase.idle,
      PlayerProcessingState.loading => PlaybackPhase.loading,
      PlayerProcessingState.buffering => PlaybackPhase.buffering,
      PlayerProcessingState.ready => PlaybackPhase.ready,
      PlayerProcessingState.completed => PlaybackPhase.completed,
      PlayerProcessingState.error => PlaybackPhase.error,
    };
  }

  Future<void> _handleCompletion() async {
    if (_disposed || _handlingCompletion) {
      return;
    }
    _handlingCompletion = true;
    try {
      if (_currentIndex < _tracks.length - 1) {
        _currentIndex++;
        await _loadCurrentTrack(autoPlay: true);
      }
    } finally {
      _handlingCompletion = false;
    }
  }

  Future<void> _initializeAudioSession() async {
    try {
      await _audioSession.configure();
    } catch (_) {
      // Playback still works through just_audio's own session activation.
    }

    if (_disposed) {
      return;
    }
    _interruptionSubscription = _audioSession.interruptionEvents.listen(
      _onInterruption,
    );
    _noisySubscription = _audioSession.becomingNoisyEvents.listen(
      (_) => _onBecomingNoisy(),
    );
  }

  void _onInterruption(AudioInterruptionEvent event) {
    if (_disposed) {
      return;
    }

    if (event.begin) {
      if (event.type == AudioInterruptionType.duck) {
        unawaited(_player.setVolume(0.3));
        return;
      }
      _resumeAfterInterruption = _state.isPlaying;
      if (_state.isPlaying) {
        unawaited(_pause(fromInterruption: true));
      }
      return;
    }

    if (event.type == AudioInterruptionType.duck) {
      unawaited(_player.setVolume(1.0));
      return;
    }

    if (event.type == AudioInterruptionType.pause && _resumeAfterInterruption) {
      _resumeAfterInterruption = false;
      unawaited(play());
      return;
    }

    _resumeAfterInterruption = false;
  }

  void _onBecomingNoisy() {
    _resumeAfterInterruption = false;
    if (_state.isPlaying) {
      unawaited(_pause(fromInterruption: false));
    }
  }

  void _emit(PlaybackState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
    _publishPlaybackState();
  }

  void _emitError(String message) {
    _emit(
      _state.copyWith(
        phase: PlaybackPhase.error,
        isPlaying: false,
        errorMessage: message,
      ),
    );
  }

  void _publishPlaybackState() {
    final controls = _controlsForState();
    final hasError = _state.hasError;
    playbackState.add(
      audio_service.PlaybackState(
        processingState: _audioProcessingState(_state.phase),
        playing: _state.isPlaying,
        controls: controls,
        androidCompactActionIndices: _compactIndices(controls.length),
        systemActions: const {audio_service.MediaAction.seek},
        updatePosition: _state.position,
        bufferedPosition: _state.bufferedPosition,
        queueIndex: _state.track == null ? null : _currentIndex,
        errorCode: hasError ? 1 : null,
        errorMessage: hasError
            ? (_state.errorMessage ?? 'Unable to play the audio sample.')
            : null,
      ),
    );
  }

  List<audio_service.MediaControl> _controlsForState() {
    if (_state.track == null) {
      return const [];
    }

    final controls = <audio_service.MediaControl>[];
    if (_tracks.length > 1) {
      controls.add(audio_service.MediaControl.skipToPrevious);
    }
    controls.add(
      _state.isPlaying
          ? audio_service.MediaControl.pause
          : audio_service.MediaControl.play,
    );
    if (_tracks.length > 1) {
      controls.add(audio_service.MediaControl.skipToNext);
    }
    controls.add(audio_service.MediaControl.stop);
    return controls;
  }

  List<int>? _compactIndices(int count) {
    if (count == 0) {
      return null;
    }
    if (count <= 3) {
      return List<int>.generate(count, (index) => index);
    }
    return const [1, 2];
  }

  audio_service.AudioProcessingState _audioProcessingState(
    PlaybackPhase phase,
  ) {
    return switch (phase) {
      PlaybackPhase.idle => audio_service.AudioProcessingState.idle,
      PlaybackPhase.loading => audio_service.AudioProcessingState.loading,
      PlaybackPhase.buffering => audio_service.AudioProcessingState.buffering,
      PlaybackPhase.ready => audio_service.AudioProcessingState.ready,
      PlaybackPhase.completed => audio_service.AudioProcessingState.completed,
      PlaybackPhase.error => audio_service.AudioProcessingState.error,
    };
  }

  audio_service.MediaItem _toMediaItem(AudioTrack track, {Duration? duration}) {
    return audio_service.MediaItem(
      id: track.id,
      title: track.title,
      album: track.album ?? 'Tafseer Audio',
      artist: track.artist,
      duration: duration ?? track.duration,
      displaySubtitle: track.subtitle,
      displayDescription: track.isTemporarySample
          ? 'Temporary engine test — not a Surah tafsir'
          : null,
      extras: {
        'assetPath': track.assetPath,
        'isTemporarySample': track.isTemporarySample,
        if (track.surahNumber != null) 'surahNumber': track.surahNumber!,
      },
    );
  }

  void _publishCurrentItem({Duration? duration}) {
    final track = _currentTrack;
    if (track == null) {
      mediaItem.add(null);
      return;
    }
    mediaItem.add(_toMediaItem(track, duration: duration ?? _state.duration));
  }

  static String _describeError(Object error) {
    final message = error.toString().trim();
    if (message.isEmpty) {
      return 'Unable to load the bundled audio sample.';
    }
    return message.replaceFirst(RegExp(r'^Exception:\s*'), '');
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _loadGeneration++;
    _playWhenReady = false;

    await _audioSessionReady;
    await _playerSubscription.cancel();
    await _interruptionSubscription?.cancel();
    await _noisySubscription?.cancel();
    await _player.dispose();
    await _audioSession.dispose();
    await _stateController.close();

    await Future.wait([
      playbackState.close(),
      queue.close(),
      queueTitle.close(),
      mediaItem.close(),
      androidPlaybackInfo.close(),
      ratingStyle.close(),
      customEvent.close(),
      customState.close(),
    ]);
  }
}
