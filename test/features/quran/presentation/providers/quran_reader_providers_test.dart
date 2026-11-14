import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tafseer_audio/features/quran/presentation/providers/quran_reader_providers.dart';

void main() {
  test('translation is visible by default and toggles off and on', () {
    final container = ProviderContainer.test();

    expect(container.read(quranReaderShowTranslationProvider), isTrue);

    final controller = container.read(
      quranReaderShowTranslationProvider.notifier,
    );
    controller.toggle();
    expect(container.read(quranReaderShowTranslationProvider), isFalse);

    controller.toggle();
    expect(container.read(quranReaderShowTranslationProvider), isTrue);
  });

  test('a fresh session starts with translation visible again', () {
    final firstSession = ProviderContainer.test();
    firstSession.read(quranReaderShowTranslationProvider.notifier).toggle();
    expect(firstSession.read(quranReaderShowTranslationProvider), isFalse);

    final restartedSession = ProviderContainer.test();
    expect(restartedSession.read(quranReaderShowTranslationProvider), isTrue);
  });
}
