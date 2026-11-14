import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reader-local Arabic text-size bounds.
///
/// This is session state only. It is deliberately not persisted through
/// `SettingsStore` or SharedPreferences.
abstract final class QuranReaderFontSizes {
  static const double defaultSize = 34;
  static const double minimum = 26;
  static const double maximum = 48;
}

/// The Arabic text size used by the Qur'an reader for the current session.
class QuranReaderFontSizeController extends Notifier<double> {
  @override
  double build() => QuranReaderFontSizes.defaultSize;

  /// Applies [size], clamped to the supported reader range.
  void setFontSize(double size) {
    state = size
        .clamp(QuranReaderFontSizes.minimum, QuranReaderFontSizes.maximum)
        .toDouble();
  }

  /// Restores the default Arabic text size.
  void reset() {
    state = QuranReaderFontSizes.defaultSize;
  }
}

final quranReaderFontSizeProvider =
    NotifierProvider<QuranReaderFontSizeController, double>(
      QuranReaderFontSizeController.new,
    );

/// Whether the reader displays the bundled English translation.
///
/// This is session state, like [QuranReaderFontSizeController]. The choice is
/// shared by every Surah opened during the same app session and resets to
/// visible after a full restart.
class QuranReaderTranslationVisibilityController extends Notifier<bool> {
  @override
  bool build() => true;

  /// Shows the translation when hidden, or hides it when visible.
  void toggle() {
    state = !state;
  }
}

final quranReaderShowTranslationProvider =
    NotifierProvider<QuranReaderTranslationVisibilityController, bool>(
      QuranReaderTranslationVisibilityController.new,
    );
