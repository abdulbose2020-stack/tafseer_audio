import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tafseer_audio/core/theme/app_theme.dart';
import 'package:tafseer_audio/features/quran/domain/quran_ayah.dart';
import 'package:tafseer_audio/features/quran/presentation/widgets/quran_ayah_translation_view.dart';
import 'package:tafseer_audio/features/quran/presentation/widgets/quran_ayah_view.dart';

import '../support/quran_reader_test_support.dart';

Future<void> _pumpAyah(
  WidgetTester tester,
  QuranAyah ayah, {
  Widget? translation,
}) async {
  tester.view.physicalSize = const Size(800, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: QuranAyahView(ayah: ayah, translation: translation),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders exact Arabic, a separate number, and a Sajdah marker', (
    tester,
  ) async {
    const ayah = QuranAyah(
      number: 7,
      arabic: testComplexAyahText,
      translation: testSurah2Ayah1Translation,
      footnotes: testSurah2Ayah1Footnotes,
      sajdah: true,
    );

    await _pumpAyah(tester, ayah);

    final arabic = tester.widget<Text>(find.byKey(QuranAyahView.arabicKey(7)));
    expect(arabic.data, testComplexAyahText);
    expect(arabic.textDirection, TextDirection.rtl);
    expect(arabic.style?.fontSize, 34);
    expect(arabic.style?.height, 1.95);
    expect(find.byType(SelectionArea), findsOneWidget);

    expect(
      find.descendant(
        of: find.byKey(QuranAyahView.numberBadgeKey(7)),
        matching: find.text('7'),
      ),
      findsOneWidget,
    );
    expect(arabic.data, isNot(contains('7')));
    expect(find.text('Sajdah'), findsOneWidget);
    expect(find.byKey(QuranAyahView.sajdahKey(7)), findsOneWidget);
  });

  testWidgets('does not display translation, footnotes, or a false Sajdah', (
    tester,
  ) async {
    const ayah = QuranAyah(
      number: 3,
      arabic: 'وَمَآ أَدْرَىٰكَ مَا ٱلْقَارِعَةُ',
      translation: testSurah2Ayah1Translation,
      footnotes: testSurah2Ayah1Footnotes,
      sajdah: false,
    );

    await _pumpAyah(tester, ayah);

    expect(find.text(testSurah2Ayah1Translation), findsNothing);
    expect(find.text(testSurah2Ayah1Footnotes), findsNothing);
    expect(find.text('Sajdah'), findsNothing);
    expect(find.byKey(QuranAyahView.sajdahKey(3)), findsNothing);
    expect(find.text(ayah.arabic), findsOneWidget);
  });

  testWidgets(
    'renders a supplied translation LTR, selectable, and beneath the Arabic',
    (tester) async {
      const ayah = QuranAyah(
        number: 7,
        arabic: testComplexAyahText,
        translation: testSurah2Ayah2Translation,
        footnotes: testSurah2Ayah2Footnotes,
        sajdah: false,
      );

      await _pumpAyah(
        tester,
        ayah,
        translation: const QuranAyahTranslationView(ayah: ayah),
      );

      final translation = tester.widget<Text>(
        find.byKey(QuranAyahTranslationView.textKey(7)),
      );
      expect(translation.data, testSurah2Ayah2Translation);
      expect(translation.textDirection, TextDirection.ltr);
      expect(
        find.ancestor(
          of: find.byKey(QuranAyahTranslationView.textKey(7)),
          matching: find.byType(SelectionArea),
        ),
        findsOneWidget,
      );
      expect(find.text(testSurah2Ayah2Footnotes), findsNothing);
      expect(
        tester.getTopLeft(find.byKey(QuranAyahTranslationView.textKey(7))).dy,
        greaterThan(
          tester.getTopLeft(find.byKey(QuranAyahView.arabicKey(7))).dy,
        ),
      );
    },
  );
}
