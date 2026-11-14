import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tafseer_audio/core/theme/app_theme.dart';
import 'package:tafseer_audio/features/quran/domain/quran_ayah.dart';
import 'package:tafseer_audio/features/quran/presentation/widgets/quran_ayah_view.dart';

import '../support/quran_reader_test_support.dart';

Future<void> _pumpAyah(WidgetTester tester, QuranAyah ayah) async {
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
          child: QuranAyahView(ayah: ayah),
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
      translation: testHiddenTranslation,
      footnotes: testHiddenFootnotes,
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
      translation: testHiddenTranslation,
      footnotes: testHiddenFootnotes,
      sajdah: false,
    );

    await _pumpAyah(tester, ayah);

    expect(find.text(testHiddenTranslation), findsNothing);
    expect(find.text(testHiddenFootnotes), findsNothing);
    expect(find.text('Sajdah'), findsNothing);
    expect(find.byKey(QuranAyahView.sajdahKey(3)), findsNothing);
    expect(find.text(ayah.arabic), findsOneWidget);
  });
}
