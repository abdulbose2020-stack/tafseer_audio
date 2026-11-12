import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tafseer_audio/core/theme/app_theme.dart';
import 'package:tafseer_audio/features/player/data/local_surah_recording_repository.dart';
import 'package:tafseer_audio/features/player/data/sample_audio_track.dart';
import 'package:tafseer_audio/features/player/domain/playback_state.dart';
import 'package:tafseer_audio/features/player/domain/surah_recording.dart';
import 'package:tafseer_audio/features/player/domain/surah_tafseer_track.dart';
import 'package:tafseer_audio/features/player/presentation/providers/playback_providers.dart';
import 'package:tafseer_audio/features/player/presentation/providers/surah_recording_providers.dart';
import 'package:tafseer_audio/features/player/presentation/screens/player_screen.dart';
import 'package:tafseer_audio/features/surahs/domain/revelation_place.dart';
import 'package:tafseer_audio/features/surahs/domain/surah.dart';
import 'package:tafseer_audio/features/surahs/presentation/providers/surah_providers.dart';

import '../support/fake_audio_engine.dart';

const _surahs = [
  Surah(
    number: 1,
    arabicName: 'الفاتحة',
    transliteration: 'Al-Faatiha',
    englishMeaning: 'The Opening',
    ayahCount: 7,
    revelationPlace: RevelationPlace.makki,
  ),
  Surah(
    number: 2,
    arabicName: 'البقرة',
    transliteration: 'Al-Baqara',
    englishMeaning: 'The Cow',
    ayahCount: 286,
    revelationPlace: RevelationPlace.madani,
  ),
  Surah(
    number: 3,
    arabicName: 'آل عمران',
    transliteration: 'Aal-i-Imraan',
    englishMeaning: 'The Family of Imraan',
    ayahCount: 200,
    revelationPlace: RevelationPlace.madani,
  ),
];

const _surahOneRecording = SurahRecording(
  surahNumber: 1,
  assetPath: 'assets/audio/tafseer/001.mp3',
  duration: Duration(minutes: 30),
);

const _surahTwoRecording = SurahRecording(
  surahNumber: 2,
  assetPath: 'assets/audio/tafseer/002.mp3',
  duration: Duration(minutes: 40),
);

Future<FakeAudioEngine> _pumpPlayer(
  WidgetTester tester, {
  required Surah surah,
  FakeAudioEngine? engine,
  List<SurahRecording> recordings = const [],
}) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final audioEngine = engine ?? FakeAudioEngine();
  addTearDown(audioEngine.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        surahsProvider.overrideWithValue(const AsyncValue.data(_surahs)),
        audioEngineProvider.overrideWithValue(audioEngine),
        surahRecordingRepositoryProvider.overrideWithValue(
          LocalSurahRecordingRepository(recordings: recordings),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: PlayerScreen(surah: surah),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return audioEngine;
}

void main() {
  testWidgets('renders Surah information and the unavailable state', (
    tester,
  ) async {
    final engine = await _pumpPlayer(tester, surah: _surahs[0]);

    expect(find.text('Surah player'), findsOneWidget);
    expect(find.text('الفاتحة'), findsOneWidget);
    expect(find.text('Al-Faatiha'), findsOneWidget);
    expect(find.text('The Opening'), findsOneWidget);
    expect(find.text('Surah 1'), findsOneWidget);
    expect(find.text('7 Ayahs'), findsOneWidget);
    expect(find.text('Makki'), findsOneWidget);
    expect(find.text('Recording not yet available'), findsOneWidget);
    expect(find.text('NOT YET AVAILABLE'), findsOneWidget);
    expect(find.text('0:00'), findsOneWidget);
    expect(find.text('--:--'), findsOneWidget);
    expect(engine.calls, isEmpty);
  });

  testWidgets('disables playback and seeking without a recording', (
    tester,
  ) async {
    final engine = await _pumpPlayer(tester, surah: _surahs[0]);

    final playButton = tester.widget<IconButton>(
      find.byKey(PlayerScreen.playPauseKey),
    );
    final slider = tester.widget<Slider>(
      find.byKey(PlayerScreen.seekSliderKey),
    );

    expect(playButton.onPressed, isNull);
    expect(slider.onChanged, isNull);
    expect(slider.onChangeEnd, isNull);

    await tester.tap(find.byKey(PlayerScreen.playPauseKey));
    await tester.pumpAndSettle();

    expect(engine.calls, isEmpty);
  });

  testWidgets('navigates the catalogue without starting playback', (
    tester,
  ) async {
    final engine = await _pumpPlayer(tester, surah: _surahs[0]);

    IconButton previousButton() =>
        tester.widget<IconButton>(find.byKey(PlayerScreen.previousKey));
    IconButton nextButton() =>
        tester.widget<IconButton>(find.byKey(PlayerScreen.nextKey));

    expect(previousButton().onPressed, isNull);
    expect(nextButton().onPressed, isNotNull);

    await tester.tap(find.byKey(PlayerScreen.nextKey));
    await tester.pumpAndSettle();

    expect(find.text('Al-Baqara'), findsOneWidget);
    expect(find.text('The Cow'), findsOneWidget);
    expect(previousButton().onPressed, isNotNull);
    expect(nextButton().onPressed, isNotNull);
    expect(engine.calls, isEmpty);

    await tester.tap(find.byKey(PlayerScreen.nextKey));
    await tester.pumpAndSettle();

    expect(find.text('Aal-i-Imraan'), findsOneWidget);
    expect(nextButton().onPressed, isNull);
    expect(previousButton().onPressed, isNotNull);
    expect(engine.calls, isEmpty);

    await tester.tap(find.byKey(PlayerScreen.previousKey));
    await tester.pumpAndSettle();

    expect(find.text('Al-Baqara'), findsOneWidget);
  });

  testWidgets('plays and seeks a real Surah recording', (tester) async {
    final engine = await _pumpPlayer(
      tester,
      surah: _surahs[0],
      recordings: const [_surahOneRecording],
    );

    expect(find.text('Recording not yet available'), findsNothing);
    expect(find.text('LOCAL RECORDING READY'), findsOneWidget);
    expect(find.text('30:00'), findsOneWidget);

    final playButton = tester.widget<IconButton>(
      find.byKey(PlayerScreen.playPauseKey),
    );
    expect(playButton.onPressed, isNotNull);

    await tester.tap(find.byKey(PlayerScreen.playPauseKey));
    await tester.pumpAndSettle();

    expect(engine.calls, ['setQueue', 'play']);
    expect(engine.lastQueue, hasLength(1));
    expect(engine.lastQueue!.single.surahNumber, 1);
    expect(engine.lastQueue!.single.isTemporarySample, isFalse);
    expect(find.text('PLAYING THIS SURAH'), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    var slider = tester.widget<Slider>(find.byKey(PlayerScreen.seekSliderKey));
    expect(slider.onChanged, isNotNull);

    slider.onChanged!(15000);
    await tester.pump();

    slider = tester.widget<Slider>(find.byKey(PlayerScreen.seekSliderKey));
    slider.onChangeEnd!(15000);
    await tester.pumpAndSettle();

    expect(engine.lastSeek, const Duration(seconds: 15));
    expect(find.text('0:15'), findsOneWidget);
  });

  testWidgets('never presents the temporary sample as the displayed Surah', (
    tester,
  ) async {
    final engine = FakeAudioEngine(
      initial: const PlaybackState(
        phase: PlaybackPhase.ready,
        isPlaying: true,
        track: sampleAudioTrack,
        duration: Duration(minutes: 10),
        position: Duration(minutes: 2),
      ),
    );
    await _pumpPlayer(tester, surah: _surahs[0], engine: engine);

    expect(find.text('Recording not yet available'), findsOneWidget);
    expect(find.text('Wedding sermon sample'), findsNothing);
    expect(find.text('2:00'), findsNothing);
    expect(find.text('0:00'), findsOneWidget);
    expect(find.text('--:--'), findsOneWidget);

    final playButton = tester.widget<IconButton>(
      find.byKey(PlayerScreen.playPauseKey),
    );
    expect(playButton.onPressed, isNull);

    await tester.tap(find.byKey(PlayerScreen.playPauseKey));
    await tester.pumpAndSettle();

    expect(engine.calls, isEmpty);
  });

  testWidgets('distinguishes the displayed Surah from another playing Surah', (
    tester,
  ) async {
    final track = buildSurahTafseerTrack(_surahs[1], _surahTwoRecording);
    final engine = FakeAudioEngine(
      initial: PlaybackState(
        phase: PlaybackPhase.ready,
        isPlaying: true,
        track: track,
        queueIndex: 0,
        duration: const Duration(minutes: 40),
        position: const Duration(minutes: 10),
      ),
    );
    await _pumpPlayer(
      tester,
      surah: _surahs[0],
      engine: engine,
      recordings: const [_surahTwoRecording],
    );

    expect(find.text('Surah player'), findsOneWidget);
    expect(find.text('Al-Faatiha'), findsOneWidget);
    expect(find.text('Recording not yet available'), findsOneWidget);
    expect(find.text('Currently playing: Surah 2 · Al-Baqara'), findsOneWidget);

    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();

    expect(find.text('Now playing'), findsOneWidget);
    expect(find.text('Al-Baqara'), findsOneWidget);
    expect(find.text('PLAYING THIS SURAH'), findsOneWidget);
    expect(find.textContaining('Currently playing:'), findsNothing);
  });
}
