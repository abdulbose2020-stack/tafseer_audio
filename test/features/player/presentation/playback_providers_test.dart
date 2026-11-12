import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tafseer_audio/core/constants/asset_paths.dart';
import 'package:tafseer_audio/features/player/data/local_surah_recording_repository.dart';
import 'package:tafseer_audio/features/player/domain/playback_state.dart';
import 'package:tafseer_audio/features/player/domain/surah_recording.dart';
import 'package:tafseer_audio/features/player/presentation/providers/playback_providers.dart';
import 'package:tafseer_audio/features/player/presentation/providers/surah_recording_providers.dart';
import 'package:tafseer_audio/features/surahs/domain/revelation_place.dart';
import 'package:tafseer_audio/features/surahs/domain/surah.dart';

import '../support/fake_audio_engine.dart';

const _surah = Surah(
  number: 1,
  arabicName: 'الفاتحة',
  transliteration: 'Al-Faatiha',
  englishMeaning: 'The Opening',
  ayahCount: 7,
  revelationPlace: RevelationPlace.makki,
);

const _recording = SurahRecording(
  surahNumber: 1,
  assetPath: 'assets/audio/tafseer/001.mp3',
  duration: Duration(minutes: 30),
);

Future<void> _flushEvents() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

ProviderContainer _createContainer({
  required FakeAudioEngine engine,
  List<SurahRecording> recordings = const [],
}) {
  return ProviderContainer(
    overrides: [
      audioEngineProvider.overrideWithValue(engine),
      surahRecordingRepositoryProvider.overrideWithValue(
        LocalSurahRecordingRepository(recordings: recordings),
      ),
    ],
  );
}

void main() {
  test('loads the unassigned sample and starts playback', () async {
    final engine = FakeAudioEngine();
    final container = ProviderContainer(
      overrides: [audioEngineProvider.overrideWithValue(engine)],
    );
    addTearDown(container.dispose);
    addTearDown(engine.dispose);

    await container.read(playbackControllerProvider.notifier).playSample();
    await _flushEvents();

    expect(engine.calls, ['setQueue', 'play']);
    expect(engine.lastQueue, hasLength(1));
    expect(engine.lastInitialIndex, 0);
    expect(engine.lastQueue!.single.isTemporarySample, isTrue);
    expect(engine.lastQueue!.single.surahNumber, isNull);
    expect(container.read(playbackControllerProvider).isPlaying, isTrue);
  });

  test('toggles pause and resume without reloading the sample', () async {
    final engine = FakeAudioEngine();
    final container = ProviderContainer(
      overrides: [audioEngineProvider.overrideWithValue(engine)],
    );
    addTearDown(container.dispose);
    addTearDown(engine.dispose);
    final controller = container.read(playbackControllerProvider.notifier);

    await controller.playSample();
    await _flushEvents();
    await controller.togglePlayback();
    await _flushEvents();

    expect(engine.calls.where((call) => call == 'pause'), hasLength(1));
    expect(container.read(playbackControllerProvider).isPlaying, isFalse);

    await controller.togglePlayback();
    await _flushEvents();

    expect(engine.calls.where((call) => call == 'setQueue'), hasLength(1));
    expect(container.read(playbackControllerProvider).isPlaying, isTrue);
  });

  test('mirrors external engine state and forwards seek and stop', () async {
    final engine = FakeAudioEngine();
    final container = ProviderContainer(
      overrides: [audioEngineProvider.overrideWithValue(engine)],
    );
    addTearDown(container.dispose);
    addTearDown(engine.dispose);
    final controller = container.read(playbackControllerProvider.notifier);

    await controller.playSample();
    await _flushEvents();
    await controller.seek(const Duration(minutes: 3));
    await _flushEvents();

    expect(engine.lastSeek, const Duration(minutes: 3));
    expect(
      container.read(playbackControllerProvider).position,
      const Duration(minutes: 3),
    );

    engine.emit(
      const PlaybackState(
        phase: PlaybackPhase.buffering,
        position: Duration(seconds: 4),
        duration: Duration(minutes: 30),
      ),
    );
    await _flushEvents();

    expect(
      container.read(playbackControllerProvider).phase,
      PlaybackPhase.buffering,
    );

    await controller.stop();
    await _flushEvents();

    expect(engine.calls, contains('stop'));
    expect(
      container.read(playbackControllerProvider).phase,
      PlaybackPhase.idle,
    );
  });

  test('loads and plays a real Surah recording', () async {
    final engine = FakeAudioEngine();
    final container = _createContainer(
      engine: engine,
      recordings: const [_recording],
    );
    addTearDown(container.dispose);
    addTearDown(engine.dispose);
    final controller = container.read(playbackControllerProvider.notifier);

    await controller.playSurah(_surah);
    await _flushEvents();

    expect(engine.calls, ['setQueue', 'play']);
    final track = engine.lastQueue!.single;
    expect(track.surahNumber, 1);
    expect(track.isTemporarySample, isFalse);
    expect(track.assetPath, _recording.assetPath);
    expect(track.title, contains('Al-Faatiha'));
    expect(container.read(playbackControllerProvider).isPlaying, isTrue);
  });

  test('never falls back to the sample for an unavailable Surah', () async {
    final engine = FakeAudioEngine();
    final container = _createContainer(engine: engine);
    addTearDown(container.dispose);
    addTearDown(engine.dispose);
    final controller = container.read(playbackControllerProvider.notifier);

    await controller.playSample();
    await _flushEvents();
    engine.calls.clear();

    await controller.playSurah(_surah);
    await _flushEvents();

    expect(engine.calls, isEmpty);
    expect(engine.currentState.track?.isTemporarySample, isTrue);
    expect(engine.currentState.track?.surahNumber, isNull);
  });

  test('refuses the temporary sample as a Surah recording asset', () async {
    final engine = FakeAudioEngine();
    const badRecording = SurahRecording(
      surahNumber: 1,
      assetPath: AssetPaths.sampleAudio,
    );
    final container = _createContainer(
      engine: engine,
      recordings: const [badRecording],
    );
    addTearDown(container.dispose);
    addTearDown(engine.dispose);
    final controller = container.read(playbackControllerProvider.notifier);

    await controller.playSurah(_surah);
    await _flushEvents();

    expect(engine.calls, isEmpty);
    expect(engine.currentState.track, isNull);
  });

  test('toggles a Surah recording without reloading it', () async {
    final engine = FakeAudioEngine();
    final container = _createContainer(
      engine: engine,
      recordings: const [_recording],
    );
    addTearDown(container.dispose);
    addTearDown(engine.dispose);
    final controller = container.read(playbackControllerProvider.notifier);

    await controller.playSurah(_surah);
    await _flushEvents();
    await controller.toggleSurah(_surah);
    await _flushEvents();

    expect(engine.calls.where((call) => call == 'pause'), hasLength(1));
    expect(container.read(playbackControllerProvider).isPlaying, isFalse);

    await controller.toggleSurah(_surah);
    await _flushEvents();

    expect(engine.calls.where((call) => call == 'setQueue'), hasLength(1));
    expect(container.read(playbackControllerProvider).isPlaying, isTrue);
  });

  test('mini-player toggle ignores the temporary sample', () async {
    final engine = FakeAudioEngine();
    final container = _createContainer(engine: engine);
    addTearDown(container.dispose);
    addTearDown(engine.dispose);
    final controller = container.read(playbackControllerProvider.notifier);

    await controller.playSample();
    await _flushEvents();
    engine.calls.clear();

    await controller.toggleCurrentSurah();
    await _flushEvents();

    expect(engine.calls, isEmpty);
    expect(container.read(playbackControllerProvider).isPlaying, isTrue);
  });

  test(
    'stops the sample on Surah selection but not a Surah recording',
    () async {
      final engine = FakeAudioEngine();
      final container = _createContainer(
        engine: engine,
        recordings: const [_recording],
      );
      addTearDown(container.dispose);
      addTearDown(engine.dispose);
      final controller = container.read(playbackControllerProvider.notifier);

      await controller.playSample();
      await _flushEvents();
      await controller.stopSampleIfLoaded();
      await _flushEvents();

      expect(engine.calls, contains('stop'));

      await controller.playSurah(_surah);
      await _flushEvents();
      engine.calls.clear();

      await controller.stopSampleIfLoaded();
      await _flushEvents();

      expect(engine.calls, isEmpty);
      expect(container.read(playbackControllerProvider).track?.surahNumber, 1);
    },
  );
}
