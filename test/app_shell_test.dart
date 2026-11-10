import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tafseer_audio/app.dart';
import 'package:tafseer_audio/core/theme/app_colors.dart';

void main() {
  testWidgets('renders the app shell and opens the player preview', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: TafseerAudioApp()));
    await tester.pumpAndSettle();

    expect(find.text('Tafseer Audio'), findsOneWidget);
    expect(find.text('تفسير القرآن الكريم'), findsOneWidget);
    expect(find.text('Surah catalog'), findsOneWidget);

    final previewButton = find.text('Preview player design');
    await tester.ensureVisible(previewButton);
    await tester.pumpAndSettle();
    await tester.tap(previewButton);
    await tester.pumpAndSettle();

    expect(find.text('Now playing'), findsOneWidget);
    expect(find.text('الفاتحة'), findsOneWidget);
    expect(
      find.text('Playback controls will be connected in Phase 3.'),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Surah catalog'), findsOneWidget);
  });

  testWidgets('uses the Tafseer Audio visual theme', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TafseerAudioApp()));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Scaffold));
    final theme = Theme.of(context);

    expect(theme.useMaterial3, isTrue);
    expect(theme.scaffoldBackgroundColor, AppColors.ivory);
    expect(theme.colorScheme.primary, AppColors.emerald);
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter');
  });
}
