import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:tafseer_audio/features/player/data/audio_player_port.dart';
import 'package:tafseer_audio/features/player/data/audio_session_port.dart';

/// A controllable `AudioPlayerPort` for handler tests.
class FakeAudioPlayer implements AudioPlayerPort {
  final StreamController<PlayerSnapshot> _snapshots =
      StreamController<PlayerSnapshot>.broadcast();

  PlayerSnapshot _currentSnapshot = const PlayerSnapshot();

  final List<String> calls = [];
  final List<String> loadedAssets = [];
  final List<Duration> seeks = [];
  final List<double> volumes = [];

  Duration? assetDuration = const Duration(minutes: 30);
  Object? setAssetError;
  Completer<void>? assetLoadGate;
  bool disposed = false;

  @override
  Stream<PlayerSnapshot> get snapshots => _snapshots.stream;

  @override
  PlayerSnapshot get currentSnapshot => _currentSnapshot;

  /// Emits a snapshot as if the underlying plugin had reported it.
  void emit(PlayerSnapshot snapshot) {
    _currentSnapshot = snapshot;
    if (!_snapshots.isClosed) {
      _snapshots.add(snapshot);
    }
  }

  @override
  Future<Duration?> setAsset(String assetPath) async {
    calls.add('setAsset');
    loadedAssets.add(assetPath);
    final gate = assetLoadGate;
    if (gate != null) {
      await gate.future;
    }
    final error = setAssetError;
    if (error != null) {
      throw error;
    }

    // The handler publishes its own loading/ready state around this future.
    _currentSnapshot = _currentSnapshot.copyWith(
      processingState: PlayerProcessingState.ready,
      playing: false,
      position: Duration.zero,
      duration: assetDuration,
      errorMessage: null,
    );
    return assetDuration;
  }

  @override
  Future<void> play() async {
    calls.add('play');
    emit(
      _currentSnapshot.copyWith(
        processingState: PlayerProcessingState.ready,
        playing: true,
      ),
    );
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    emit(_currentSnapshot.copyWith(playing: false));
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    emit(
      _currentSnapshot.copyWith(
        processingState: PlayerProcessingState.idle,
        playing: false,
        position: Duration.zero,
      ),
    );
  }

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek');
    seeks.add(position);
    emit(_currentSnapshot.copyWith(position: position));
  }

  @override
  Future<void> setVolume(double volume) async {
    calls.add('setVolume');
    volumes.add(volume);
  }

  @override
  Future<void> dispose() async {
    calls.add('dispose');
    disposed = true;
    await _snapshots.close();
  }
}

/// A controllable `AudioSessionPort` for handler tests.
class FakeAudioSession implements AudioSessionPort {
  final StreamController<AudioInterruptionEvent> _interruptions =
      StreamController<AudioInterruptionEvent>.broadcast();
  final StreamController<void> _noisy = StreamController<void>.broadcast();

  int configureCalls = 0;
  Object? configureError;
  bool disposed = false;

  @override
  Future<void> configure() async {
    configureCalls++;
    final error = configureError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Stream<AudioInterruptionEvent> get interruptionEvents =>
      _interruptions.stream;

  @override
  Stream<void> get becomingNoisyEvents => _noisy.stream;

  void emitInterruption(AudioInterruptionEvent event) {
    _interruptions.add(event);
  }

  void emitBecomingNoisy() {
    _noisy.add(null);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _interruptions.close();
    await _noisy.close();
  }
}
