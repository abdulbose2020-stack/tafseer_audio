import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tafseer_audio/app.dart';
import 'package:tafseer_audio/core/settings/settings_store.dart';
import 'package:tafseer_audio/core/theme/app_colors.dart';
import 'package:tafseer_audio/core/theme/app_theme_colors.dart';
import 'package:tafseer_audio/features/home/presentation/screens/home_screen.dart';
import 'package:tafseer_audio/features/player/presentation/providers/playback_providers.dart';
import 'package:tafseer_audio/features/settings/presentation/providers/theme_providers.dart';
import 'package:tafseer_audio/features/surahs/domain/revelation_place.dart';
import 'package:tafseer_audio/features/surahs/domain/surah.dart';
import 'package:tafseer_audio/features/surahs/presentation/providers/surah_providers.dart';

import 'features/player/support/fake_audio_engine.dart';

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
    number: 112,
    arabicName: 'الإخلاص',
    transliteration: 'Al-Ikhlaas',
    englishMeaning: 'Sincerity',
    ayahCount: 4,
    revelationPlace: RevelationPlace.makki,
  ),
];

Future<FakeAudioEngine> _pumpApp(
  WidgetTester tester, {
  ThemeMode initialMode = ThemeMode.system,
}) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final engine = FakeAudioEngine();
  addTearDown(engine.dispose);
  final settingsStore = MemorySettingsStore(initialMode: initialMode);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        audioEngineProvider.overrideWithValue(engine),
        settingsStoreProvider.overrideWithValue(settingsStore),
        surahsProvider.overrideWithValue(const AsyncValue.data(_surahs)),
      ],
      child: const TafseerAudioApp(),
    ),
  );
  await tester.pumpAndSettle();
  return engine;
}

void main() {
  testWidgets('renders the Home screen with both modules and Settings', (
    tester,
  ) async {
    await _pumpApp(tester);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);

    expect(find.text('Tafseer Audio'), findsOneWidget);
    expect(find.text('تفسير القرآن الكريم'), findsOneWidget);
    expect(find.text('Choose a module'), findsOneWidget);
    expect(find.text('Read the Qur’an'), findsOneWidget);
    expect(find.text('Listen to Tafseer'), findsOneWidget);
    expect(find.byKey(HomeScreen.readingCardKey), findsOneWidget);
    expect(find.byKey(HomeScreen.tafseerCardKey), findsOneWidget);
    expect(find.byKey(HomeScreen.settingsKey), findsOneWidget);
  });

  testWidgets('uses the Tafseer Audio visual theme', (tester) async {
    await _pumpApp(tester, initialMode: ThemeMode.light);

    final context = tester.element(find.byType(Scaffold));
    final theme = Theme.of(context);

    expect(theme.useMaterial3, isTrue);
    expect(theme.scaffoldBackgroundColor, AppColors.ivory);
    expect(theme.colorScheme.primary, AppColors.emerald);
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter');
    expect(theme.extension<AppThemeColors>(), AppThemeColors.light);
  });

  testWidgets(
    'opens the existing Surah catalogue and the reading placeholder',
    (tester) async {
      await _pumpApp(tester);

      await tester.ensureVisible(find.byKey(HomeScreen.tafseerCardKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HomeScreen.tafseerCardKey));
      await tester.pumpAndSettle();

      expect(find.text('Surah catalog'), findsOneWidget);
      expect(find.text('All 3 Surahs'), findsOneWidget);
      expect(find.text('Al-Faatiha'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byTooltip('Back to home'), findsOneWidget);

      await tester.tap(find.byTooltip('Back to home'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(HomeScreen.readingCardKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HomeScreen.readingCardKey));
      await tester.pumpAndSettle();

      expect(find.text('Reading content is being prepared'), findsOneWidget);
      expect(
        find.textContaining('No Qur’an text or translation has been added'),
        findsOneWidget,
      );

      await tester.tap(find.text('Back to Home'));
      await tester.pumpAndSettle();

      expect(find.text('Choose a module'), findsOneWidget);
    },
  );

  testWidgets('selects and persists Light, Dark, and System themes', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.ensureVisible(find.byKey(HomeScreen.settingsKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(HomeScreen.settingsKey));
    await tester.pumpAndSettle();

    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    var app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);

    final darkContext = tester.element(find.byType(Scaffold).last);
    expect(Theme.of(darkContext).brightness, Brightness.dark);
    expect(
      Theme.of(darkContext).extension<AppThemeColors>(),
      AppThemeColors.dark,
    );

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);

    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();

    app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);
  });

  testWidgets('opens a Surah player from the catalogue', (tester) async {
    final engine = await _pumpApp(tester);

    await tester.ensureVisible(find.byKey(HomeScreen.tafseerCardKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(HomeScreen.tafseerCardKey));
    await tester.pumpAndSettle();

    final surahTile = find.text('Al-Faatiha');
    await tester.ensureVisible(surahTile);
    await tester.pumpAndSettle();
    await tester.tap(surahTile);
    await tester.pumpAndSettle();

    expect(find.text('Surah player'), findsOneWidget);
    expect(find.text('Recording not yet available'), findsOneWidget);
    expect(engine.calls, isEmpty);
  });
}
