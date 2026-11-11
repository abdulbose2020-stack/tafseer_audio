import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tafseer_audio/core/theme/app_theme.dart';
import 'package:tafseer_audio/features/player/presentation/providers/playback_providers.dart';
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

Future<FakeAudioEngine> _pumpCatalogue(
  WidgetTester tester, {
  FakeAudioEngine? engine,
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

  testWidgets('selects and highlights a Surah without navigating to playback', (
    tester,
  ) async {
    await _pumpCatalogue(tester);
    final surahTile = find.text('Al-Faatiha');

    await tester.ensureVisible(surahTile);
    await tester.pumpAndSettle();
    await tester.tap(surahTile);
    await tester.pumpAndSettle();

    expect(find.text('SELECTED SURAH'), findsOneWidget);
    expect(find.text('1. Al-Faatiha'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.text('Surah catalog'), findsOneWidget);
    expect(find.text('Now playing'), findsNothing);

    await tester.ensureVisible(surahTile);
    await tester.pumpAndSettle();
    await tester.tap(surahTile);
    await tester.pumpAndSettle();

    expect(find.text('SELECTED SURAH'), findsNothing);
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

    await tester.tap(find.text('Play sample'));
    await tester.pumpAndSettle();

    expect(engine.calls, containsAllInOrder(['setQueue', 'play']));
    expect(engine.lastQueue, hasLength(1));
    expect(engine.lastQueue!.single.isTemporarySample, isTrue);
    expect(engine.lastQueue!.single.surahNumber, isNull);
    expect(find.text('Pause'), findsOneWidget);

    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();

    expect(engine.calls, contains('pause'));
    expect(find.text('Resume'), findsOneWidget);
  });
}
