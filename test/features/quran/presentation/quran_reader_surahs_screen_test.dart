import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tafseer_audio/core/theme/app_theme.dart';
import 'package:tafseer_audio/features/player/presentation/providers/playback_providers.dart';
import 'package:tafseer_audio/features/player/presentation/widgets/mini_player.dart';
import 'package:tafseer_audio/features/quran/presentation/providers/quran_surah_providers.dart';
import 'package:tafseer_audio/features/quran/presentation/screens/quran_reader_screen.dart';
import 'package:tafseer_audio/features/quran/presentation/screens/quran_reader_surahs_screen.dart';
import 'package:tafseer_audio/features/surahs/domain/surah.dart';
import 'package:tafseer_audio/features/surahs/presentation/providers/surah_providers.dart';

import '../../player/support/fake_audio_engine.dart';
import 'support/quran_reader_test_support.dart';

void _setTestView(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _CatalogueHarness {
  const _CatalogueHarness({
    required this.engine,
    required this.source,
    required this.container,
  });

  final FakeAudioEngine engine;
  final FakeQuranSurahDataSource source;
  final ProviderContainer container;
}

Future<_CatalogueHarness> _pumpCatalogue(
  WidgetTester tester, {
  AsyncValue<List<Surah>>? surahs,
  FakeQuranSurahDataSource? source,
  bool settle = true,
}) async {
  _setTestView(tester);

  final engine = FakeAudioEngine();
  addTearDown(engine.dispose);
  final dataSource = source ?? FakeQuranSurahDataSource(testQuranContents());

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        surahsProvider.overrideWithValue(
          surahs ?? AsyncValue.data(buildCatalogueSurahs()),
        ),
        quranSurahDataSourceProvider.overrideWithValue(dataSource),
        audioEngineProvider.overrideWithValue(engine),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const QuranReaderSurahsScreen(),
      ),
    ),
  );

  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }

  final container = ProviderScope.containerOf(
    tester.element(find.byType(QuranReaderSurahsScreen)),
    listen: false,
  );

  return _CatalogueHarness(
    engine: engine,
    source: dataSource,
    container: container,
  );
}

void main() {
  testWidgets('lists all 114 reader Surahs with their metadata', (
    tester,
  ) async {
    await _pumpCatalogue(tester);

    expect(find.text('Qur’an Reading'), findsOneWidget);
    expect(find.text('Read the Arabic Qur’an'), findsOneWidget);
    expect(find.text('114 Surahs'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    expect(find.byKey(QuranReaderSurahsScreen.tileKey(1)), findsOneWidget);
    expect(find.text('Al-Faatiha'), findsOneWidget);
    expect(find.text('The Opening'), findsOneWidget);
    expect(find.text('الفاتحة'), findsOneWidget);
    expect(find.text('7 Ayahs'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(QuranReaderSurahsScreen.tileKey(1)),
        matching: find.text('Makki'),
      ),
      findsOneWidget,
    );

    final list = tester.widget<SliverList>(
      find.byKey(QuranReaderSurahsScreen.listKey),
    );
    expect(list.delegate.estimatedChildCount, 114);

    await tester.scrollUntilVisible(
      find.byKey(QuranReaderSurahsScreen.tileKey(114)),
      500,
      scrollable: find.byType(Scrollable),
      maxScrolls: 100,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(QuranReaderSurahsScreen.tileKey(114)), findsOneWidget);
    expect(find.text('An-Naas'), findsOneWidget);
    expect(find.text('Mankind'), findsOneWidget);
    expect(find.text('6 Ayahs'), findsOneWidget);
  });

  testWidgets('shows a loading state while the catalogue is read', (
    tester,
  ) async {
    await _pumpCatalogue(
      tester,
      surahs: const AsyncValue.loading(),
      settle: false,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading the Surah catalogue...'), findsOneWidget);
  });

  testWidgets('shows an error and retries the catalogue', (tester) async {
    _setTestView(tester);

    var attempts = 0;
    final engine = FakeAudioEngine();
    addTearDown(engine.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          surahsProvider.overrideWith((ref) async {
            attempts += 1;
            if (attempts == 1) {
              throw StateError('catalogue unavailable');
            }
            return buildCatalogueSurahs();
          }),
          quranSurahDataSourceProvider.overrideWithValue(
            FakeQuranSurahDataSource(testQuranContents()),
          ),
          audioEngineProvider.overrideWithValue(engine),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const QuranReaderSurahsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unable to load the Surah catalogue'), findsOneWidget);
    expect(find.byKey(QuranReaderSurahsScreen.retryButtonKey), findsOneWidget);

    await tester.tap(find.byKey(QuranReaderSurahsScreen.retryButtonKey));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.byKey(QuranReaderSurahsScreen.tileKey(1)), findsOneWidget);
    expect(find.text('114 Surahs'), findsOneWidget);
  });

  testWidgets(
    'opens the selected Surah without changing Tafseer selection or audio',
    (tester) async {
      final harness = await _pumpCatalogue(tester);

      harness.container.read(selectedSurahNumberProvider.notifier).select(112);

      await harness.container
          .read(playbackControllerProvider.notifier)
          .toggleSample();
      await tester.pump();

      final callsBefore = List<String>.of(harness.engine.calls);
      final stateBefore = harness.container.read(playbackControllerProvider);

      await tester.ensureVisible(
        find.byKey(QuranReaderSurahsScreen.tileKey(2)),
      );
      await tester.tap(find.byKey(QuranReaderSurahsScreen.tileKey(2)));
      await tester.pumpAndSettle();

      expect(find.byType(QuranReaderScreen), findsOneWidget);
      expect(find.text('Al-Baqara'), findsOneWidget);
      expect(find.text('SURAH 2'), findsOneWidget);
      expect(find.text('The Cow'), findsOneWidget);
      expect(find.text('الٓمٓ'), findsOneWidget);
      expect(find.byType(MiniPlayer), findsNothing);

      expect(harness.source.requestedNumbers, [2]);
      expect(harness.container.read(selectedSurahNumberProvider), 112);
      expect(harness.engine.calls, callsBefore);
      expect(harness.container.read(playbackControllerProvider), stateBefore);
    },
  );
}
