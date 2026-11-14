import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tafseer_audio/app.dart';
import 'package:tafseer_audio/core/settings/settings_store.dart';
import 'package:tafseer_audio/core/theme/app_colors.dart';
import 'package:tafseer_audio/core/theme/app_theme_colors.dart';
import 'package:tafseer_audio/features/home/presentation/screens/main_shell.dart';
import 'package:tafseer_audio/features/player/presentation/providers/playback_providers.dart';
import 'package:tafseer_audio/features/player/presentation/screens/player_screen.dart';
import 'package:tafseer_audio/features/quran/presentation/providers/quran_surah_providers.dart';
import 'package:tafseer_audio/features/quran/presentation/screens/quran_reader_screen.dart';
import 'package:tafseer_audio/features/quran/presentation/screens/quran_reader_surahs_screen.dart';
import 'package:tafseer_audio/features/settings/presentation/providers/theme_providers.dart';
import 'package:tafseer_audio/features/settings/presentation/screens/settings_screen.dart';
import 'package:tafseer_audio/features/surahs/domain/revelation_place.dart';
import 'package:tafseer_audio/features/surahs/domain/surah.dart';
import 'package:tafseer_audio/features/surahs/presentation/providers/surah_providers.dart';
import 'package:tafseer_audio/features/surahs/presentation/screens/surah_list_screen.dart';

import 'features/player/support/fake_audio_engine.dart';
import 'features/quran/presentation/support/quran_reader_test_support.dart';

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
        quranSurahDataSourceProvider.overrideWithValue(
          FakeQuranSurahDataSource(testQuranContents()),
        ),
      ],
      child: const TafseerAudioApp(),
    ),
  );
  await tester.pumpAndSettle();
  return engine;
}

int _tabIndex(WidgetTester tester) {
  final stack = tester.widget<IndexedStack>(find.byKey(MainShell.tabStackKey));
  return stack.index!;
}

NavigationBar _navigationBar(WidgetTester tester) {
  return tester.widget<NavigationBar>(find.byKey(MainShell.navigationBarKey));
}

void main() {
  testWidgets('launches on the Tafseer tab with three destinations', (
    tester,
  ) async {
    await _pumpApp(tester);

    final navigationBar = _navigationBar(tester);
    expect(navigationBar.destinations, hasLength(3));
    expect(navigationBar.selectedIndex, MainShell.tafseerIndex);
    expect(_tabIndex(tester), MainShell.tafseerIndex);

    final labels = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((destination) => destination.label)
        .toList();
    expect(labels, const ['Tafseer', 'Qur’an', 'Settings']);

    expect(find.byKey(MainShell.tafseerDestinationKey), findsOneWidget);
    expect(find.byKey(MainShell.quranDestinationKey), findsOneWidget);
    expect(find.byKey(MainShell.settingsDestinationKey), findsOneWidget);

    expect(find.byType(SurahListScreen, skipOffstage: false), findsOneWidget);
    expect(
      find.byType(QuranReaderSurahsScreen, skipOffstage: false),
      findsOneWidget,
    );
    expect(find.byType(SettingsScreen, skipOffstage: false), findsOneWidget);

    expect(find.byType(SurahListScreen), findsOneWidget);
    expect(find.text('Surah catalog'), findsOneWidget);
    expect(find.byType(QuranReaderSurahsScreen), findsNothing);
    expect(find.byType(SettingsScreen), findsNothing);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);
  });

  testWidgets('uses the Tafseer Audio visual theme', (tester) async {
    await _pumpApp(tester, initialMode: ThemeMode.light);

    final context = tester.element(find.byKey(MainShell.navigationBarKey));
    final theme = Theme.of(context);

    expect(theme.useMaterial3, isTrue);
    expect(theme.scaffoldBackgroundColor, AppColors.ivory);
    expect(theme.colorScheme.primary, AppColors.emerald);
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter');
    expect(theme.extension<AppThemeColors>(), AppThemeColors.light);
  });

  testWidgets('switches tabs without routes and keeps each tab alive', (
    tester,
  ) async {
    await _pumpApp(tester);

    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    expect(navigator.canPop(), isFalse);
    expect(_tabIndex(tester), MainShell.tafseerIndex);
    expect(_navigationBar(tester).selectedIndex, MainShell.tafseerIndex);

    final tafseerSearch = find.descendant(
      of: find.byType(SurahListScreen),
      matching: find.byType(TextField),
    );
    expect(tafseerSearch, findsOneWidget);

    final tafseerScrollView = find.descendant(
      of: find.byType(SurahListScreen),
      matching: find.byType(CustomScrollView),
    );
    final scrollableState = tester.state<ScrollableState>(
      find
          .descendant(of: tafseerScrollView, matching: find.byType(Scrollable))
          .first,
    );

    await tester.enterText(tafseerSearch, 'Faatiha');
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(SurahListScreen),
        matching: find.text('1 Surah found'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(MainShell.quranDestinationKey));
    await tester.pumpAndSettle();

    expect(_tabIndex(tester), MainShell.quranIndex);
    expect(_navigationBar(tester).selectedIndex, MainShell.quranIndex);
    expect(find.byType(QuranReaderSurahsScreen), findsOneWidget);
    expect(find.byType(SurahListScreen), findsNothing);
    expect(navigator.canPop(), isFalse);

    await tester.tap(find.byKey(MainShell.settingsDestinationKey));
    await tester.pumpAndSettle();

    expect(_tabIndex(tester), MainShell.settingsIndex);
    expect(_navigationBar(tester).selectedIndex, MainShell.settingsIndex);
    expect(navigator.canPop(), isFalse);
    expect(find.byType(SurahListScreen), findsNothing);
    expect(find.byType(SurahListScreen, skipOffstage: false), findsOneWidget);

    await tester.tap(find.byKey(MainShell.tafseerDestinationKey));
    await tester.pumpAndSettle();

    expect(_tabIndex(tester), MainShell.tafseerIndex);
    expect(
      identical(
        tester.state<ScrollableState>(
          find
              .descendant(
                of: tafseerScrollView,
                matching: find.byType(Scrollable),
              )
              .first,
        ),
        scrollableState,
      ),
      isTrue,
    );
    expect(tester.widget<TextField>(tafseerSearch).controller?.text, 'Faatiha');
  });

  testWidgets('selects Settings from the navigation bar and persists themes', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.byKey(MainShell.settingsDestinationKey));
    await tester.pumpAndSettle();

    expect(_tabIndex(tester), MainShell.settingsIndex);
    expect(find.byKey(SettingsScreen.themeSelectorKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(SettingsScreen.themeSelectorKey),
        matching: find.byType(ChoiceChip),
      ),
      findsNWidgets(3),
    );
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.textContaining('Choose how the app looks'), findsNothing);
    expect(find.textContaining('System follows'), findsNothing);
    expect(find.text('Qur’an sources'), findsOneWidget);
    expect(find.text('Qur’an reading'), findsNothing);
    expect(find.text('Tafseer audio'), findsNothing);
    expect(find.textContaining('Offline by design'), findsNothing);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    var app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);

    final darkContext = tester.element(find.byType(SettingsScreen));
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

  testWidgets('keeps detail routes above the shell', (tester) async {
    await _pumpApp(tester);

    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );

    await tester.tap(find.byKey(MainShell.quranDestinationKey));
    await tester.pumpAndSettle();
    expect(_tabIndex(tester), MainShell.quranIndex);

    await tester.tap(find.byKey(QuranReaderSurahsScreen.tileKey(1)));
    await tester.pumpAndSettle();

    expect(find.byType(QuranReaderScreen), findsOneWidget);
    expect(find.byKey(MainShell.navigationBarKey).hitTestable(), findsNothing);

    navigator.pop();
    await tester.pumpAndSettle();

    expect(find.byType(QuranReaderScreen), findsNothing);
    expect(
      find.byKey(MainShell.navigationBarKey).hitTestable(),
      findsOneWidget,
    );
    expect(_tabIndex(tester), MainShell.quranIndex);

    await tester.tap(find.byKey(MainShell.tafseerDestinationKey));
    await tester.pumpAndSettle();

    final tafseerSurah = find.descendant(
      of: find.byType(SurahListScreen),
      matching: find.text('Al-Faatiha'),
    );
    await tester.ensureVisible(tafseerSurah);
    await tester.pumpAndSettle();
    await tester.tap(tafseerSurah);
    await tester.pumpAndSettle();

    expect(find.byType(PlayerScreen), findsOneWidget);
    expect(find.text('Surah player'), findsOneWidget);
    expect(find.byKey(MainShell.navigationBarKey).hitTestable(), findsNothing);

    navigator.pop();
    await tester.pumpAndSettle();

    expect(find.byType(PlayerScreen), findsNothing);
    expect(
      find.byKey(MainShell.navigationBarKey).hitTestable(),
      findsOneWidget,
    );
    expect(_tabIndex(tester), MainShell.tafseerIndex);
  });

  testWidgets('back returns the Qur’an and Settings tabs to Tafseer', (
    tester,
  ) async {
    await _pumpApp(tester);

    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );

    expect(_tabIndex(tester), MainShell.tafseerIndex);
    expect(await navigator.maybePop(), isFalse);
    await tester.pumpAndSettle();
    expect(_tabIndex(tester), MainShell.tafseerIndex);

    await tester.tap(find.byKey(MainShell.settingsDestinationKey));
    await tester.pumpAndSettle();
    expect(_tabIndex(tester), MainShell.settingsIndex);

    expect(await navigator.maybePop(), isTrue);
    await tester.pumpAndSettle();
    expect(_tabIndex(tester), MainShell.tafseerIndex);

    await tester.tap(find.byKey(MainShell.quranDestinationKey));
    await tester.pumpAndSettle();
    expect(_tabIndex(tester), MainShell.quranIndex);

    expect(await navigator.maybePop(), isTrue);
    await tester.pumpAndSettle();
    expect(_tabIndex(tester), MainShell.tafseerIndex);

    expect(await navigator.maybePop(), isFalse);
    await tester.pumpAndSettle();
    expect(_tabIndex(tester), MainShell.tafseerIndex);
  });
}
