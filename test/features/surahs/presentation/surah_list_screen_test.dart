import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tafseer_audio/core/constants/app_constants.dart';
import 'package:tafseer_audio/core/theme/app_theme.dart';
import 'package:tafseer_audio/features/player/data/local_surah_recording_repository.dart';
import 'package:tafseer_audio/features/player/data/sample_audio_track.dart';
import 'package:tafseer_audio/features/player/domain/playback_state.dart';
import 'package:tafseer_audio/features/player/domain/surah_recording.dart';
import 'package:tafseer_audio/features/player/domain/surah_tafseer_track.dart';
import 'package:tafseer_audio/features/player/presentation/providers/playback_providers.dart';
import 'package:tafseer_audio/features/player/presentation/providers/surah_recording_providers.dart';
import 'package:tafseer_audio/features/player/presentation/widgets/mini_player.dart';
import 'package:tafseer_audio/features/surahs/domain/revelation_place.dart';
import 'package:tafseer_audio/features/surahs/domain/surah.dart';
import 'package:tafseer_audio/features/surahs/presentation/providers/surah_providers.dart';
import 'package:tafseer_audio/features/surahs/presentation/screens/surah_list_screen.dart';

import '../../player/support/fake_audio_engine.dart';

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
    number: 36,
    arabicName: 'يس',
    transliteration: 'Yaseen',
    englishMeaning: 'Yaseen',
    ayahCount: 83,
    revelationPlace: RevelationPlace.makki,
  ),
  Surah(
    number: 55,
    arabicName: 'الرحمن',
    transliteration: 'Ar-Rahmaan',
    englishMeaning: 'The Beneficent',
    ayahCount: 78,
    revelationPlace: RevelationPlace.madani,
  ),
  Surah(
    number: 112,
    arabicName: 'الإخلاص',
    transliteration: 'Al-Ikhlaas',
    englishMeaning: 'Sincerity',
    ayahCount: 4,
    revelationPlace: RevelationPlace.makki,
  ),
];

const _surahTwoRecording = SurahRecording(
  surahNumber: 2,
  assetPath: 'assets/audio/tafseer/002.mp3',
  duration: Duration(minutes: 40),
);

Future<FakeAudioEngine> _pumpCatalogue(
  WidgetTester tester, {
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
        surahsProvider.overrideWithValue(AsyncValue.data(_surahs)),
        audioEngineProvider.overrideWithValue(audioEngine),
        surahRecordingRepositoryProvider.overrideWithValue(
          LocalSurahRecordingRepository(recordings: recordings),
        ),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const SurahListScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return audioEngine;
}

void main() {
  testWidgets('renders the complete catalogue with search and filters', (
    tester,
  ) async {
    await _pumpCatalogue(tester);

    expect(find.text('Surah catalog'), findsOneWidget);
    expect(find.text('All 5 Surahs'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'All'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Makki'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Madani'), findsOneWidget);
    expect(find.text('Al-Faatiha'), findsOneWidget);
    expect(find.text('الفاتحة'), findsOneWidget);
    expect(find.text('The Opening'), findsOneWidget);
    expect(find.text('7 Ayahs'), findsOneWidget);
  });

  testWidgets('removes the Listen, Reflect & Understand header tagline', (
    tester,
  ) async {
    await _pumpCatalogue(tester);

    expect(find.text('LISTEN  •  REFLECT  •  UNDERSTAND'), findsNothing);
    expect(find.text(AppConstants.appName), findsOneWidget);
    expect(find.text(AppConstants.appNameArabic), findsOneWidget);
    expect(find.text(AppConstants.tagline), findsOneWidget);
    expect(find.text('100% offline'), findsOneWidget);
    expect(find.text('114 Surahs'), findsOneWidget);
  });

  testWidgets('filters the catalogue by Makki and Madani', (tester) async {
    await _pumpCatalogue(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Madani'));
    await tester.pumpAndSettle();

    expect(find.text('2 Surahs found'), findsOneWidget);
    expect(find.text('Al-Baqara'), findsOneWidget);
    expect(find.text('Ar-Rahmaan'), findsOneWidget);
    expect(find.text('Al-Faatiha'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Makki'));
    await tester.pumpAndSettle();

    expect(find.text('3 Surahs found'), findsOneWidget);
    expect(find.text('Al-Faatiha'), findsOneWidget);
    expect(find.text('Al-Baqara'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
    await tester.pumpAndSettle();

    expect(find.text('All 5 Surahs'), findsOneWidget);
    expect(find.text('Al-Baqara'), findsOneWidget);
  });

  testWidgets('searches by number, Arabic name, transliteration, and meaning', (
    tester,
  ) async {
    await _pumpCatalogue(tester);
    final searchField = find.byType(TextField);

    await tester.enterText(searchField, '2');
    await tester.pumpAndSettle();
    expect(find.text('Al-Baqara'), findsOneWidget);
    expect(find.text('Al-Faatiha'), findsNothing);
    expect(find.text('1 Surah found'), findsOneWidget);

    await tester.enterText(searchField, 'الفاتحة');
    await tester.pumpAndSettle();
    expect(find.text('Al-Faatiha'), findsOneWidget);
    expect(find.text('Al-Baqara'), findsNothing);

    await tester.enterText(searchField, 'rahman');
    await tester.pumpAndSettle();
    expect(find.text('Ar-Rahmaan'), findsOneWidget);

    await tester.enterText(searchField, 'the cow');
    await tester.pumpAndSettle();
    expect(find.text('Al-Baqara'), findsOneWidget);
    expect(find.text('Ar-Rahmaan'), findsNothing);
  });

  testWidgets('shows an empty state and resets search and filters', (
    tester,
  ) async {
    await _pumpCatalogue(tester);
    final searchField = find.byType(TextField);

    await tester.enterText(searchField, 'zzzz');
    await tester.pumpAndSettle();

    expect(find.text('No Surahs found'), findsOneWidget);
    expect(find.text('Al-Faatiha'), findsNothing);

    final resetButton = find.text('Reset search and filters');
    await tester.ensureVisible(resetButton);
    await tester.pumpAndSettle();
    await tester.tap(resetButton);
    await tester.pumpAndSettle();

    expect(find.text('All 5 Surahs'), findsOneWidget);
    expect(find.text('Al-Faatiha'), findsOneWidget);
    expect(tester.widget<TextField>(searchField).controller?.text, isEmpty);
  });

  testWidgets('opens the player and preserves search when selecting a Surah', (
    tester,
  ) async {
    await _pumpCatalogue(tester);
    final searchField = find.byType(TextField);

    await tester.enterText(searchField, 'Faatiha');
    await tester.pumpAndSettle();
    expect(find.text('1 Surah found'), findsOneWidget);

    final surahTile = find.text('Al-Faatiha');
    await tester.ensureVisible(surahTile);
    await tester.pumpAndSettle();
    await tester.tap(surahTile);
    await tester.pumpAndSettle();

    expect(find.text('Surah player'), findsOneWidget);
    expect(find.text('Al-Faatiha'), findsOneWidget);
    expect(find.text('The Opening'), findsOneWidget);
    expect(find.text('Recording not yet available'), findsOneWidget);
    expect(find.text('SELECTED SURAH'), findsNothing);

    await tester.tap(find.byTooltip('Close player'));
    await tester.pumpAndSettle();

    expect(find.text('SELECTED SURAH'), findsOneWidget);
    expect(find.text('1. Al-Faatiha'), findsOneWidget);
    expect(find.text('Recording not yet available'), findsOneWidget);
    expect(find.text('1 Surah found'), findsOneWidget);
    expect(tester.widget<TextField>(searchField).controller?.text, 'Faatiha');
  });

  testWidgets('stops the temporary sample when a Surah is opened', (
    tester,
  ) async {
    final engine = await _pumpCatalogue(tester);

    await tester.tap(find.text('Play sample'));
    await tester.pumpAndSettle();
    expect(find.text('Pause'), findsOneWidget);

    final surahTile = find.text('Al-Faatiha');
    await tester.ensureVisible(surahTile);
    await tester.pumpAndSettle();
    await tester.tap(surahTile);
    await tester.pumpAndSettle();

    expect(engine.calls, contains('stop'));
    expect(find.text('Recording not yet available'), findsOneWidget);
    expect(find.text('Wedding sermon sample'), findsNothing);
    expect(find.text('Pause'), findsNothing);
  });

  testWidgets('labels the temporary sample and never assigns it to a Surah', (
    tester,
  ) async {
    final engine = FakeAudioEngine();
    await _pumpCatalogue(tester, engine: engine);

    expect(find.text('TEMPORARY AUDIO ENGINE TEST'), findsOneWidget);
    expect(find.text('Wedding sermon sample'), findsOneWidget);
    expect(find.text('NOT A SURAH'), findsOneWidget);
    expect(find.textContaining('not a Surah tafsir'), findsOneWidget);
    expect(find.text('Play sample'), findsOneWidget);
    expect(find.text('Surah catalog'), findsOneWidget);
    expect(find.byKey(MiniPlayer.widgetKey), findsNothing);

    await tester.tap(find.text('Play sample'));
    await tester.pumpAndSettle();

    expect(engine.calls, containsAllInOrder(['setQueue', 'play']));
    expect(engine.lastQueue, hasLength(1));
    expect(engine.lastQueue!.single.isTemporarySample, isTrue);
    expect(engine.lastQueue!.single.surahNumber, isNull);
    expect(find.text('Pause'), findsOneWidget);
    expect(find.byKey(MiniPlayer.widgetKey), findsNothing);

    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();

    expect(engine.calls, contains('pause'));
    expect(find.text('Resume'), findsOneWidget);
  });

  testWidgets('keeps the mini player hidden for the temporary sample', (
    tester,
  ) async {
    final engine = FakeAudioEngine(
      initial: const PlaybackState(
        phase: PlaybackPhase.ready,
        isPlaying: true,
        track: sampleAudioTrack,
        duration: Duration(minutes: 10),
        position: Duration(minutes: 1),
      ),
    );
    await _pumpCatalogue(tester, engine: engine);

    expect(find.byKey(MiniPlayer.widgetKey), findsNothing);
    expect(find.text('TEMPORARY AUDIO ENGINE TEST'), findsOneWidget);
    expect(find.text('Wedding sermon sample'), findsOneWidget);
  });

  testWidgets('shows and controls the mini player for a real Surah recording', (
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
    await _pumpCatalogue(
      tester,
      engine: engine,
      recordings: const [_surahTwoRecording],
    );

    final miniPlayer = find.byKey(MiniPlayer.widgetKey);
    expect(miniPlayer, findsOneWidget);
    expect(
      find.descendant(
        of: miniPlayer,
        matching: find.text('Surah 2 · Al-Baqara'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: miniPlayer,
        matching: find.textContaining('10:00 / 40:00'),
      ),
      findsOneWidget,
    );
    expect(find.text('Play sample'), findsOneWidget);

    await tester.tap(find.byKey(MiniPlayer.playPauseKey));
    await tester.pumpAndSettle();

    expect(engine.calls, contains('pause'));
    expect(
      find.descendant(
        of: miniPlayer,
        matching: find.byIcon(Icons.play_arrow_rounded),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(MiniPlayer.playPauseKey));
    await tester.pumpAndSettle();

    expect(engine.calls.where((call) => call == 'play'), hasLength(1));

    await tester.tap(find.byKey(MiniPlayer.openKey));
    await tester.pumpAndSettle();

    expect(find.text('Now playing'), findsOneWidget);
    expect(find.text('Al-Baqara'), findsOneWidget);
    expect(find.text('Recording not yet available'), findsNothing);
  });

  testWidgets('distinguishes the selected Surah from active playback', (
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
    await _pumpCatalogue(
      tester,
      engine: engine,
      recordings: const [_surahTwoRecording],
    );

    final surahTile = find.text('Al-Faatiha');
    await tester.ensureVisible(surahTile);
    await tester.pumpAndSettle();
    await tester.tap(surahTile);
    await tester.pumpAndSettle();

    expect(find.text('Surah player'), findsOneWidget);
    expect(find.text('Al-Faatiha'), findsOneWidget);
    expect(find.text('Recording not yet available'), findsOneWidget);
    expect(find.text('Currently playing: Surah 2 · Al-Baqara'), findsOneWidget);

    await tester.tap(find.byTooltip('Close player'));
    await tester.pumpAndSettle();

    expect(find.text('SELECTED SURAH'), findsOneWidget);
    expect(find.text('1. Al-Faatiha'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(MiniPlayer.widgetKey),
        matching: find.text('Surah 2 · Al-Baqara'),
      ),
      findsOneWidget,
    );
  });
}
