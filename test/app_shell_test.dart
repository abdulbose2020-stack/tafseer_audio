import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tafseer_audio/app.dart';
import 'package:tafseer_audio/core/theme/app_colors.dart';

void main() {
  testWidgets('renders the app shell with the offline Surah catalogue', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: TafseerAudioApp()));
    await tester.pumpAndSettle();

    expect(find.text('Tafseer Audio'), findsOneWidget);
    expect(find.text('تفسير القرآن الكريم'), findsOneWidget);
    expect(find.text('Surah catalog'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('All 114 Surahs'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Makki'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Madani'), findsOneWidget);
  });

  testWidgets('uses the Tafseer Audio visual theme', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TafseerAudioApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final context = tester.element(find.byType(Scaffold));
    final theme = Theme.of(context);

    expect(theme.useMaterial3, isTrue);
    expect(theme.scaffoldBackgroundColor, AppColors.ivory);
    expect(theme.colorScheme.primary, AppColors.emerald);
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter');
  });
}
