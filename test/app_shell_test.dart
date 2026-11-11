import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tafseer_audio/app.dart';
import 'package:tafseer_audio/core/theme/app_colors.dart';
import 'package:tafseer_audio/features/player/presentation/providers/playback_providers.dart';

import 'features/player/support/fake_audio_engine.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  final engine = FakeAudioEngine();
  addTearDown(engine.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [audioEngineProvider.overrideWithValue(engine)],
      child: const TafseerAudioApp(),
    ),
  );
}

void main() {
  testWidgets('renders the app shell with the offline Surah catalogue', (
    tester,
  ) async {
    await _pumpApp(tester);
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
    await _pumpApp(tester);
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
