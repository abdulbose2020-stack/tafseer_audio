import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sample_audio_track.dart';
import '../../domain/audio_engine.dart';
import '../../domain/audio_track.dart';
import '../../domain/playback_state.dart';

/// The single audio engine for the app.
///
/// `main` overrides this provider with the initialized [TafseerAudioHandler].
/// Tests override it with a fake so no platform audio plugin is needed.
final audioEngineProvider = Provider<AudioEngine>((ref) {
  throw UnimplementedError(
    'audioEngineProvider must be overridden with the initialized audio '
    'handler before the app is run.',
  );
});

/// The temporary recording used to verify the audio engine.
///
/// It is intentionally not connected to any Surah.
final sampleAudioTrackProvider = Provider<AudioTrack>((ref) {
  return sampleAudioTrack;
});

/// Mirrors the handler's authoritative playback state and exposes commands to
/// the UI. Screens never talk to `just_audio` or `audio_service` directly.
class PlaybackController extends Notifier<PlaybackState> {
  AudioEngine get _engine => ref.read(audioEngineProvider);

  @override
  PlaybackState build() {
    final engine = ref.watch(audioEngineProvider);
    final subscription = engine.stateStream.listen((next) {
      state = next;
    });
    ref.onDispose(subscription.cancel);
    return engine.currentState;
  }

  /// Loads the temporary sample if needed, then starts or resumes it.
  Future<void> playSample() async {
    final engine = _engine;
    final sample = ref.read(sampleAudioTrackProvider);
    if (engine.currentState.track?.id != sample.id) {
      await engine.setQueue([sample]);
    }
    await engine.play();
  }

  /// Pauses when playing; otherwise loads/resumes the sample.
  Future<void> togglePlayback() async {
    if (_engine.currentState.isPlaying) {
      await _engine.pause();
    } else {
      await playSample();
    }
  }

  Future<void> pause() => _engine.pause();

  Future<void> stop() => _engine.stop();

  Future<void> seek(Duration position) => _engine.seek(position);
}

final playbackControllerProvider =
    NotifierProvider<PlaybackController, PlaybackState>(PlaybackController.new);
