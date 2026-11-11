import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tafseer_audio/features/player/domain/playback_state.dart';
import 'package:tafseer_audio/features/player/presentation/providers/playback_providers.dart';

import '../support/fake_audio_engine.dart';

Future<void> _flushEvents() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
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
}
