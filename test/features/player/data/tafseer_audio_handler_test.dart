import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tafseer_audio/core/constants/asset_paths.dart';
import 'package:tafseer_audio/features/player/data/audio_player_port.dart';
import 'package:tafseer_audio/features/player/data/sample_audio_track.dart';
import 'package:tafseer_audio/features/player/data/tafseer_audio_handler.dart';
import 'package:tafseer_audio/features/player/domain/audio_track.dart';
import 'package:tafseer_audio/features/player/domain/playback_state.dart';

import '../support/fake_audio_ports.dart';

Future<void> _flushEvents() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<(TafseerAudioHandler, FakeAudioPlayer, FakeAudioSession)>
_createHandler() async {
  final player = FakeAudioPlayer();
  final session = FakeAudioSession();
  final handler = TafseerAudioHandler(player: player, audioSession: session);
  await handler.audioSessionReady;
  return (handler, player, session);
}

const _secondTrack = AudioTrack(
  id: 'second-test-track',
  title: 'Second test track',
  assetPath: 'assets/audio/sample/second.mp3',
  duration: Duration(minutes: 2),
);

void main() {
  test('loads the bundled sample without assigning it to a Surah', () async {
    final (handler, player, _) = await _createHandler();
    addTearDown(handler.dispose);

    await handler.setQueue([sampleAudioTrack]);

    expect(player.loadedAssets, [AssetPaths.sampleAudio]);
    expect(handler.currentState.phase, PlaybackPhase.ready);
    expect(handler.currentState.duration, const Duration(minutes: 30));
    expect(handler.currentState.track?.isTemporarySample, isTrue);
    expect(handler.currentState.track?.surahNumber, isNull);
    expect(handler.queue.value, hasLength(1));
    expect(handler.queue.value.single.id, sampleAudioTrack.id);
    expect(handler.queueTitle.value, 'Tafseer Audio');
    expect(handler.mediaItem.value?.title, 'Wedding sermon sample');
    expect(handler.mediaItem.value?.extras?['isTemporarySample'], isTrue);
    expect(
      handler.mediaItem.value?.extras?.containsKey('surahNumber'),
      isFalse,
    );
    expect(
      handler.mediaItem.value?.displayDescription,
      contains('not a Surah tafsir'),
    );
  });

  test(
    'plays, pauses, seeks, and stops while publishing media state',
    () async {
      final (handler, player, _) = await _createHandler();
      addTearDown(handler.dispose);

      await handler.setQueue([sampleAudioTrack]);
      await handler.play();

      expect(handler.currentState.isPlaying, isTrue);
      expect(handler.playbackState.value.playing, isTrue);
      expect(handler.playbackState.value.queueIndex, 0);
      expect(
        handler.playbackState.value.controls,
        contains(audio_service.MediaControl.pause),
      );

      await handler.seek(const Duration(minutes: 2));

      expect(player.seeks.last, const Duration(minutes: 2));
      expect(handler.currentState.position, const Duration(minutes: 2));

      await handler.pause();

      expect(handler.currentState.isPlaying, isFalse);
      expect(handler.playbackState.value.playing, isFalse);
      expect(
        handler.playbackState.value.controls,
        contains(audio_service.MediaControl.play),
      );

      await handler.stop();

      expect(handler.currentState.phase, PlaybackPhase.idle);
      expect(handler.currentState.position, Duration.zero);
      expect(
        handler.playbackState.value.processingState,
        audio_service.AudioProcessingState.idle,
      );
    },
  );

  test('maps asset errors to an error state and media error', () async {
    final (handler, player, _) = await _createHandler();
    addTearDown(handler.dispose);
    player.setAssetError = Exception('asset missing');

    await handler.setQueue([sampleAudioTrack]);

    expect(handler.currentState.phase, PlaybackPhase.error);
    expect(handler.currentState.isPlaying, isFalse);
    expect(handler.currentState.errorMessage, contains('asset missing'));
    expect(handler.playbackState.value.errorMessage, contains('asset missing'));
  });

  test('pauses for interruptions and resumes after them', () async {
    final (handler, player, session) = await _createHandler();
    addTearDown(handler.dispose);

    await handler.setQueue([sampleAudioTrack]);
    await handler.play();

    session.emitInterruption(
      AudioInterruptionEvent(true, AudioInterruptionType.pause),
    );
    await _flushEvents();

    expect(handler.currentState.isPlaying, isFalse);
    expect(player.calls, contains('pause'));

    session.emitInterruption(
      AudioInterruptionEvent(false, AudioInterruptionType.pause),
    );
    await _flushEvents();

    expect(handler.currentState.isPlaying, isTrue);
  });

  test('ducks and restores volume for ducking interruptions', () async {
    final (handler, player, session) = await _createHandler();
    addTearDown(handler.dispose);

    await handler.setQueue([sampleAudioTrack]);
    await handler.play();

    session.emitInterruption(
      AudioInterruptionEvent(true, AudioInterruptionType.duck),
    );
    await _flushEvents();
    expect(player.volumes.last, 0.3);

    session.emitInterruption(
      AudioInterruptionEvent(false, AudioInterruptionType.duck),
    );
    await _flushEvents();
    expect(player.volumes.last, 1.0);
  });

  test('pauses when headphones are disconnected', () async {
    final (handler, player, session) = await _createHandler();
    addTearDown(handler.dispose);

    await handler.setQueue([sampleAudioTrack]);
    await handler.play();

    session.emitBecomingNoisy();
    await _flushEvents();

    expect(handler.currentState.isPlaying, isFalse);
    expect(player.calls, contains('pause'));
  });

  test('advances to the next queue item after completion', () async {
    final (handler, player, _) = await _createHandler();
    addTearDown(handler.dispose);

    await handler.setQueue([sampleAudioTrack, _secondTrack]);
    await handler.play();

    player.emit(
      const PlayerSnapshot(
        processingState: PlayerProcessingState.completed,
        position: Duration(minutes: 30),
        duration: Duration(minutes: 30),
      ),
    );
    await _flushEvents();

    expect(handler.currentState.track?.id, _secondTrack.id);
    expect(handler.currentState.queueIndex, 1);
    expect(player.loadedAssets.last, _secondTrack.assetPath);
    expect(handler.currentState.isPlaying, isTrue);
  });

  test('clears the queue and media item when given no tracks', () async {
    final (handler, player, _) = await _createHandler();
    addTearDown(handler.dispose);

    await handler.setQueue([sampleAudioTrack]);
    await handler.setQueue(const []);

    expect(handler.currentState.track, isNull);
    expect(handler.queue.value, isEmpty);
    expect(handler.mediaItem.value, isNull);
    expect(handler.queueTitle.value, isEmpty);
    expect(player.calls, contains('stop'));
  });

  test('dispose releases the player, session, and broadcast streams', () async {
    final (handler, player, session) = await _createHandler();

    await handler.setQueue([sampleAudioTrack]);
    await handler.dispose();

    expect(player.disposed, isTrue);
    expect(session.disposed, isTrue);
    expect(handler.playbackState.isClosed, isTrue);
    expect(handler.queue.isClosed, isTrue);

    final callsAfterDispose = player.calls.length;
    await handler.play();
    expect(player.calls.length, callsAfterDispose);
  });
}
