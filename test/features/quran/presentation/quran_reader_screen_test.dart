import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tafseer_audio/core/constants/asset_paths.dart';
import 'package:tafseer_audio/core/theme/app_theme.dart';
import 'package:tafseer_audio/features/quran/data/quran_surah_asset_data_source.dart';
import 'package:tafseer_audio/features/quran/presentation/providers/quran_reader_providers.dart';
import 'package:tafseer_audio/features/quran/presentation/providers/quran_sources_providers.dart';
import 'package:tafseer_audio/features/quran/presentation/providers/quran_surah_providers.dart';
import 'package:tafseer_audio/features/quran/presentation/screens/quran_reader_screen.dart';
import 'package:tafseer_audio/features/quran/presentation/screens/quran_sources_screen.dart';
import 'package:tafseer_audio/features/quran/presentation/widgets/quran_ayah_view.dart';
import 'package:tafseer_audio/features/surahs/domain/surah.dart';

import 'support/quran_reader_test_support.dart';

void _setTestView(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<FakeQuranSurahDataSource> _pumpReader(
  WidgetTester tester, {
  required Surah surah,
  FakeQuranSurahDataSource? source,
  bool settle = true,
}) async {
  _setTestView(tester);

  final dataSource = source ?? FakeQuranSurahDataSource(testQuranContents());

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        quranSurahDataSourceProvider.overrideWithValue(dataSource),
        quranSourceManifestProvider.overrideWithValue(
          AsyncValue.error(
            StateError('sources unavailable in this test'),
            StackTrace.empty,
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: QuranReaderScreen(surah: surah),
      ),
    ),
  );

  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }

  return dataSource;
}

void main() {
  test('reader font size defaults, clamps, and resets', () {
    final container = ProviderContainer.test();

    expect(
      container.read(quranReaderFontSizeProvider),
      QuranReaderFontSizes.defaultSize,
    );

    final controller = container.read(quranReaderFontSizeProvider.notifier);
    controller.setFontSize(40);
    expect(container.read(quranReaderFontSizeProvider), 40);

    controller.setFontSize(0);
    expect(
      container.read(quranReaderFontSizeProvider),
      QuranReaderFontSizes.minimum,
    );

    controller.setFontSize(100);
    expect(
      container.read(quranReaderFontSizeProvider),
      QuranReaderFontSizes.maximum,
    );

    controller.reset();
    expect(
      container.read(quranReaderFontSizeProvider),
      QuranReaderFontSizes.defaultSize,
    );
  });

  testWidgets('shows Surah metadata, exact Arabic, and separate Ayah numbers', (
    tester,
  ) async {
    final source = await _pumpReader(tester, surah: testSurah2);

    expect(find.text('Al-Baqara'), findsOneWidget);
    expect(find.text('SURAH 2'), findsOneWidget);
    expect(find.text('البقرة'), findsOneWidget);
    expect(find.text('The Cow'), findsOneWidget);
    expect(find.text('286 Ayahs'), findsOneWidget);
    expect(find.text('Madani'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);

    final arabic = tester.widget<Text>(find.byKey(QuranAyahView.arabicKey(2)));
    expect(arabic.data, testComplexAyahText);
    expect(find.text(testComplexAyahText), findsOneWidget);
    expect(find.byType(SelectionArea), findsWidgets);

    expect(
      find.descendant(
        of: find.byKey(QuranAyahView.numberBadgeKey(1)),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(QuranAyahView.numberBadgeKey(2)),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );

    expect(find.text(testHiddenTranslation), findsNothing);
    expect(find.text(testHiddenFootnotes), findsNothing);
    expect(source.requestedNumbers, [2]);
  });

  testWidgets('keeps the header visible while the Surah is loading', (
    tester,
  ) async {
    final gate = Completer<void>();
    final source = FakeQuranSurahDataSource(
      testQuranContents(),
      loadingCompleter: gate,
    );

    await _pumpReader(tester, surah: testSurah2, source: source, settle: false);

    expect(find.text('Loading Surah text...'), findsOneWidget);
    expect(find.text('البقرة'), findsOneWidget);
    expect(find.text('The Cow'), findsOneWidget);
    expect(find.text('SURAH 2'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('الٓمٓ'), findsOneWidget);
    expect(find.text(testComplexAyahText), findsOneWidget);
    expect(source.requestedNumbers, [2]);
  });

  testWidgets('shows an error, keeps the header, and retries only this Surah', (
    tester,
  ) async {
    final source = FakeQuranSurahDataSource(
      testQuranContents(),
      failuresBeforeSuccess: 1,
    );

    await _pumpReader(tester, surah: testSurah2, source: source);

    expect(find.text('Unable to load this Surah'), findsOneWidget);
    expect(find.text('البقرة'), findsOneWidget);
    expect(find.text('The Cow'), findsOneWidget);
    expect(find.byKey(QuranReaderScreen.retryButtonKey), findsOneWidget);

    await tester.tap(find.byKey(QuranReaderScreen.retryButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Unable to load this Surah'), findsNothing);
    expect(find.text('الٓمٓ'), findsOneWidget);
    expect(find.text(testComplexAyahText), findsOneWidget);
    expect(source.requestedNumbers, [2, 2]);
  });

  testWidgets('Surah 1 does not add a separate Basmala line', (tester) async {
    await _pumpReader(tester, surah: testSurah1);

    expect(find.byKey(QuranReaderScreen.basmalaKey), findsNothing);
    expect(find.text(testBasmalaText), findsOneWidget);
    expect(find.text('SURAH 1'), findsOneWidget);
  });

  testWidgets('prefatory Basmala is shown exactly and centered', (
    tester,
  ) async {
    await _pumpReader(tester, surah: testSurah2);

    final basmala = tester.widget<Text>(
      find.byKey(QuranReaderScreen.basmalaKey),
    );
    expect(basmala.data, testBasmalaText);
    expect(basmala.textAlign, TextAlign.center);
    expect(basmala.textDirection, TextDirection.rtl);
    expect(find.text(testBasmalaText), findsOneWidget);
    expect(find.text('الٓمٓ'), findsOneWidget);
  });

  testWidgets('Surah 9 has no Basmala line', (tester) async {
    await _pumpReader(tester, surah: testSurah9);

    expect(find.byKey(QuranReaderScreen.basmalaKey), findsNothing);
    expect(find.text(testBasmalaText), findsNothing);
    expect(find.text('SURAH 9'), findsOneWidget);
    expect(find.text('بَرَآءَةٌ مِّنَ ٱللَّهِ وَرَسُولِهِ'), findsOneWidget);
  });

  testWidgets('shows a Sajdah indicator only for Sajdah Ayahs', (tester) async {
    await _pumpReader(tester, surah: testSurah2);

    expect(find.byKey(QuranAyahView.sajdahKey(1)), findsNothing);
    expect(find.byKey(QuranAyahView.sajdahKey(2)), findsOneWidget);
    expect(find.text('Sajdah'), findsOneWidget);
  });

  testWidgets('font-size controls update, clamp, and reset the Arabic text', (
    tester,
  ) async {
    await _pumpReader(tester, surah: testSurah2);

    Text arabicText() =>
        tester.widget<Text>(find.byKey(QuranAyahView.arabicKey(1)));

    expect(arabicText().style?.fontSize, 34);
    expect(arabicText().style?.height, 1.95);

    await tester.tap(find.byKey(QuranReaderScreen.fontSizeButtonKey));
    await tester.pumpAndSettle();

    var slider = tester.widget<Slider>(
      find.byKey(QuranReaderScreen.fontSizeSliderKey),
    );
    expect(slider.min, 26);
    expect(slider.max, 48);
    expect(slider.value, 34);

    slider.onChanged!(48);
    await tester.pump();

    expect(
      tester.widget<Text>(find.byKey(QuranReaderScreen.fontSizeValueKey)).data,
      '48',
    );
    expect(arabicText().style?.fontSize, 48);

    slider = tester.widget<Slider>(
      find.byKey(QuranReaderScreen.fontSizeSliderKey),
    );
    slider.onChanged!(10);
    await tester.pump();

    expect(
      tester.widget<Text>(find.byKey(QuranReaderScreen.fontSizeValueKey)).data,
      '26',
    );
    expect(arabicText().style?.fontSize, 26);

    slider = tester.widget<Slider>(
      find.byKey(QuranReaderScreen.fontSizeSliderKey),
    );
    slider.onChanged!(100);
    await tester.pump();

    expect(
      tester.widget<Text>(find.byKey(QuranReaderScreen.fontSizeValueKey)).data,
      '48',
    );
    expect(arabicText().style?.fontSize, 48);

    await tester.tap(find.byKey(QuranReaderScreen.fontSizeResetKey));
    await tester.pump();

    expect(
      tester.widget<Text>(find.byKey(QuranReaderScreen.fontSizeValueKey)).data,
      '34',
    );
    expect(arabicText().style?.fontSize, 34);
  });

  testWidgets('opens Sources & Acknowledgements from the reader', (
    tester,
  ) async {
    await _pumpReader(tester, surah: testSurah2);

    await tester.tap(find.byKey(QuranReaderScreen.sourcesButtonKey));
    await tester.pumpAndSettle();

    expect(find.byType(QuranSourcesScreen), findsOneWidget);
    expect(find.text('Sources & Acknowledgements'), findsOneWidget);
  });

  testWidgets('loads only the selected Surah asset, not the manifest', (
    tester,
  ) async {
    _setTestView(tester);

    final bundle = RecordingAssetBundle({
      AssetPaths.quranSurah(1): quranSurahJsonFor(testQuranSurah1()),
      AssetPaths.quranSurah(2): quranSurahJsonFor(testQuranSurah2()),
      AssetPaths.quranSurah(9): quranSurahJsonFor(testQuranSurah9()),
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quranSurahDataSourceProvider.overrideWithValue(
            QuranSurahAssetDataSource(bundle: bundle),
          ),
          quranSourceManifestProvider.overrideWithValue(
            AsyncValue.error(
              StateError('sources unavailable in this test'),
              StackTrace.empty,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const QuranReaderScreen(surah: testSurah2),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(bundle.loadedKeys, [AssetPaths.quranSurah(2)]);
    expect(bundle.loadedKeys, isNot(contains(AssetPaths.quranManifest)));
    expect(bundle.loadedKeys, isNot(contains(AssetPaths.quranSurah(1))));
    expect(bundle.loadedKeys, isNot(contains(AssetPaths.quranSurah(9))));
    expect(find.text('الٓمٓ'), findsOneWidget);
    expect(find.text(testComplexAyahText), findsOneWidget);
  });
}
