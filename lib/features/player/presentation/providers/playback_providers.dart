import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/asset_paths.dart';
import '../../../surahs/domain/surah.dart';
import '../../data/sample_audio_track.dart';
import '../../domain/audio_engine.dart';
import '../../domain/audio_track.dart';
import '../../domain/playback_state.dart';
import '../../domain/surah_tafseer_track.dart';
import 'surah_recording_providers.dart';

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

  /// Pauses the temporary sample when it is playing; otherwise loads it.
  Future<void> toggleSample() async {
    final engine = _engine;
    final current = engine.currentState;
    if (current.track?.isTemporarySample == true && current.isPlaying) {
      await engine.pause();
    } else {
      await playSample();
    }
  }

  /// Pauses when the sample is playing; otherwise loads/resumes the sample.
  ///
  /// Kept for the temporary sample card and its existing tests. Surah playback
  /// must use [toggleSurah] instead.
  Future<void> togglePlayback() => toggleSample();

  /// Stops the temporary sample if it is the loaded track.
  ///
  /// Opening a Surah calls this so the wedding-sermon sample can never be
  /// mistaken for that Surah's tafsir.
  Future<void> stopSampleIfLoaded() async {
    if (_engine.currentState.track?.isTemporarySample == true) {
      await _engine.stop();
    }
  }

  /// Loads and plays the local recording for [surah].
  ///
  /// Does nothing when no real recording is available. The temporary sample is
  /// never used as a fallback.
  Future<void> playSurah(Surah surah) async {
    final track = _trackForSurah(surah);
    if (track == null) {
      return;
    }
    await _playTrack(track);
  }

  /// Pauses the displayed Surah when it is playing, or loads and plays it.
  ///
  /// Does nothing when no real recording is available.
  Future<void> toggleSurah(Surah surah) async {
    final track = _trackForSurah(surah);
    if (track == null) {
      return;
    }

    final current = _engine.currentState;
    if (current.track?.id == track.id && current.isPlaying) {
      await _engine.pause();
    } else {
      await _playTrack(track);
    }
  }

  /// Pauses or resumes the loaded track only when it is a real Surah recording.
  ///
  /// Used by the mini-player, which must never control the temporary sample.
  Future<void> toggleCurrentSurah() async {
    final engine = _engine;
    final track = engine.currentState.track;
    if (track == null || !track.isSurahRecording || track.isTemporarySample) {
      return;
    }

    if (engine.currentState.isPlaying) {
      await engine.pause();
    } else {
      await engine.play();
    }
  }

  Future<void> pause() => _engine.pause();

  Future<void> stop() => _engine.stop();

  Future<void> seek(Duration position) => _engine.seek(position);

  Future<void> _playTrack(AudioTrack track) async {
    final engine = _engine;
    if (engine.currentState.track?.id != track.id) {
      await engine.setQueue([track]);
    }
    await engine.play();
  }

  AudioTrack? _trackForSurah(Surah surah) {
    final recording = ref.read(surahRecordingProvider(surah.number));
    if (recording == null || recording.assetPath == AssetPaths.sampleAudio) {
      return null;
    }
    return buildSurahTafseerTrack(surah, recording);
  }
}

final playbackControllerProvider =
    NotifierProvider<PlaybackController, PlaybackState>(PlaybackController.new);
