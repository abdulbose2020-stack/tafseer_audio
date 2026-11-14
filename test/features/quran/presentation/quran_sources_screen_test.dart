import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tafseer_audio/core/settings/settings_store.dart';
import 'package:tafseer_audio/core/theme/app_theme.dart';
import 'package:tafseer_audio/core/theme/app_theme_colors.dart';
import 'package:tafseer_audio/features/quran/domain/quran_source_manifest.dart';
import 'package:tafseer_audio/features/quran/presentation/providers/quran_sources_providers.dart';
import 'package:tafseer_audio/features/quran/presentation/screens/quran_sources_screen.dart';
import 'package:tafseer_audio/features/settings/presentation/providers/theme_providers.dart';
import 'package:tafseer_audio/features/settings/presentation/screens/settings_screen.dart';

const _arabicNotice =
    '\n\n# PLEASE DO NOT REMOVE OR CHANGE THIS COPYRIGHT BLOCK\n'
    '#  Tanzil test text\n'
    '#  Copyright (C) 2007-2026 Tanzil Project\n'
    '#  License: Creative Commons Attribution 3.0\n'
    '#  CHANGING IT IS NOT ALLOWED.\n';

const _englishInfo =
    'Translation Info:\r\n'
    '#---------------------------\r\n'
    '# Translation of the meanings of the Noble Qur\'an\r\n'
    '# Source: https://quranenc.com\r\n'
    "# PLEASE DON'T REMOVE THIS IMPORTANT INFORMATION!\r\n"
    '#---------------------------';

const _englishTerms =
    'Contents of the translations can be downloaded and re-published, with '
    'the following terms and conditions: 1. No modification, addition, or '
    'deletion of the content. 2. Clearly referring to the publisher and the '
    'source (QuranEnc.com).';

const _catalogueNotice =
    'Derived from Tanzil Quran Metadata; revelation place is '
    "normalized from Tanzil's Meccan and Medinan values to "
    'makki and madani.';

const _manifest = QuranSourceManifest(
  schemaVersion: '1.0.0',
  datasetVersion: '9.9.9-test',
  generatedAtUtc: '2026-11-13T16:48:38Z',
  surahCount: 114,
  ayahCount: 6236,
  arabic: QuranArabicSource(
    name: 'Tanzil test Uthmani text',
    provider: 'Tanzil Project',
    version: '1.1-test',
    releaseDate: '2021-02-12',
    copyright: 'Copyright (C) 2007-2026 Tanzil Project',
    license: 'Creative Commons Attribution 3.0',
    notice: _arabicNotice,
  ),
  english: QuranEnglishSource(
    name: 'QuranEnc English translation (english_saheeh)',
    provider: 'QuranEnc',
    publisher: 'Noor International Center',
    attribution: 'Noor International Center, through QuranEnc.',
    version: '1.1.2-test',
    revision: 'v1.1.2-csv.1-test',
    lastUpdateUtc: '2025-06-24T13:37:27Z',
    license: 'QuranEnc Terms and Policies',
    licenseUrl: 'https://quranenc.com/en/home/about',
    licenseTerms: _englishTerms,
    sourceInfoBlock: _englishInfo,
  ),
  catalogue: QuranCatalogueSource(
    name: 'Tanzil Quran Metadata',
    url: 'https://tanzil.net/res/text/metadata/quran-data.xml',
    license: 'CC BY',
    copyright: '(C) 2008-2009 Tanzil.info',
  ),
);

Future<void> _pumpSources(
  WidgetTester tester, {
  AsyncValue<QuranSourceManifest>? manifest,
  ThemeMode themeMode = ThemeMode.light,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(1000, 7000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        quranSourceManifestProvider.overrideWithValue(
          manifest ?? const AsyncValue.data(_manifest),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        home: const QuranSourcesScreen(),
      ),
    ),
  );

  if (settle) {
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('shows the exact attribution, versions, notices, and links', (
    tester,
  ) async {
    await _pumpSources(tester);

    expect(find.text('Sources & Acknowledgements'), findsOneWidget);
    expect(find.text('Source acknowledgements'), findsOneWidget);
    expect(find.text('Dataset 9.9.9-test'), findsOneWidget);
    expect(find.text('6,236 Ayahs'), findsOneWidget);

    expect(find.text('Tanzil Project'), findsOneWidget);
    expect(find.text('Tanzil test Uthmani text'), findsOneWidget);
    expect(find.text('1.1-test'), findsOneWidget);
    expect(find.text('Copyright (C) 2007-2026 Tanzil Project'), findsOneWidget);
    expect(find.text('Creative Commons Attribution 3.0'), findsOneWidget);

    expect(
      find.text('Noor International Center, through QuranEnc.'),
      findsOneWidget,
    );
    expect(
      find.text('QuranEnc English translation (english_saheeh)'),
      findsOneWidget,
    );
    expect(find.text('1.1.2-test'), findsOneWidget);
    expect(find.text('v1.1.2-csv.1-test'), findsOneWidget);
    expect(find.text('2025-06-24T13:37:27Z'), findsOneWidget);
    expect(find.text('QuranEnc Terms and Policies'), findsOneWidget);

    expect(find.text('SURAH CATALOGUE'), findsOneWidget);
    expect(find.text('Tanzil Quran Metadata'), findsOneWidget);
    expect(
      find.text('Surah names, numbers, Ayah counts, and revelation place.'),
      findsOneWidget,
    );
    expect(find.text('(C) 2008-2009 Tanzil.info'), findsOneWidget);
    expect(find.text('CC BY'), findsOneWidget);
    expect(
      find.text('https://tanzil.net/res/text/metadata/quran-data.xml'),
      findsOneWidget,
    );
    expect(
      find.text('https://creativecommons.org/licenses/by/3.0/'),
      findsOneWidget,
    );

    final arabicNotice = tester.widget<Text>(
      find.byKey(QuranSourcesScreen.arabicNoticeKey),
    );
    expect(arabicNotice.data, _arabicNotice);

    final englishInfo = tester.widget<Text>(
      find.byKey(QuranSourcesScreen.englishInfoKey),
    );
    expect(englishInfo.data, _englishInfo);

    final englishTerms = tester.widget<Text>(
      find.byKey(QuranSourcesScreen.englishTermsKey),
    );
    expect(englishTerms.data, _englishTerms);

    final catalogueLink = tester.widget<Text>(
      find.byKey(QuranSourcesScreen.catalogueLinkKey),
    );
    expect(
      catalogueLink.data,
      'https://tanzil.net/res/text/metadata/quran-data.xml',
    );

    final catalogueNotice = tester.widget<Text>(
      find.byKey(QuranSourcesScreen.catalogueNoticeKey),
    );
    expect(catalogueNotice.data, _catalogueNotice);

    final tanzilLink = tester.widget<Text>(
      find.byKey(QuranSourcesScreen.tanzilLinkKey),
    );
    expect(tanzilLink.data, 'https://tanzil.net');

    final quranEncLink = tester.widget<Text>(
      find.byKey(QuranSourcesScreen.quranEncLinkKey),
    );
    expect(quranEncLink.data, 'https://quranenc.com');

    expect(find.text('https://quranenc.com/en/home/about'), findsOneWidget);
    expect(find.textContaining('Saheeh International'), findsNothing);
  });

  testWidgets('uses the light and dark theme colours', (tester) async {
    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      await _pumpSources(tester, themeMode: themeMode);

      final context = tester.element(find.byType(QuranSourcesScreen));
      final theme = Theme.of(context);
      final expectedColors = themeMode == ThemeMode.dark
          ? AppThemeColors.dark
          : AppThemeColors.light;

      expect(
        theme.brightness,
        themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light,
      );
      expect(theme.extension<AppThemeColors>(), expectedColors);
      expect(find.text('Tanzil Project'), findsOneWidget);
    }
  });

  testWidgets('follows the platform brightness in System mode', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await _pumpSources(tester, themeMode: ThemeMode.system);

    final context = tester.element(find.byType(QuranSourcesScreen));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(Theme.of(context).extension<AppThemeColors>(), AppThemeColors.dark);
  });

  testWidgets('shows a loading state', (tester) async {
    await _pumpSources(
      tester,
      manifest: const AsyncValue.loading(),
      settle: false,
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading source acknowledgements...'), findsOneWidget);
  });

  testWidgets('shows an error state when the manifest cannot be read', (
    tester,
  ) async {
    await _pumpSources(
      tester,
      manifest: AsyncValue.error(
        StateError('missing manifest'),
        StackTrace.empty,
      ),
    );

    expect(find.text('Unable to load source acknowledgements'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('opens the same acknowledgement screen from Settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 7000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsStoreProvider.overrideWithValue(MemorySettingsStore()),
          quranSourceManifestProvider.overrideWithValue(
            const AsyncValue.data(_manifest),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SOURCES & ACKNOWLEDGEMENTS'), findsOneWidget);
    expect(find.byKey(SettingsScreen.quranSourcesKey), findsOneWidget);

    await tester.tap(find.byKey(SettingsScreen.quranSourcesKey));
    await tester.pumpAndSettle();

    expect(find.byType(QuranSourcesScreen), findsOneWidget);
    expect(find.text('Sources & Acknowledgements'), findsOneWidget);
    expect(find.text('Tanzil Project'), findsOneWidget);
  });
}
