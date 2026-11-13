import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/settings_store.dart';

/// The preference store used by the settings feature.
///
/// `main` overrides this provider with a SharedPreferences-backed store before
/// the first frame. Tests override it with [MemorySettingsStore].
final settingsStoreProvider = Provider<SettingsStore>((ref) {
  throw UnimplementedError(
    'settingsStoreProvider must be overridden before the app is run.',
  );
});

/// The selected application theme mode, restored from local preferences.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    try {
      return ref.watch(settingsStoreProvider).readThemeMode();
    } catch (error) {
      debugPrint('Unable to read the saved theme preference: $error');
      return ThemeMode.system;
    }
  }

  /// Applies [mode] immediately and persists it in the background.
  ///
  /// A persistence failure never breaks the active selection; the app keeps the
  /// chosen mode for the current session and falls back to the saved/default
  /// mode on the next launch.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (state == mode) {
      return;
    }

    state = mode;

    try {
      await ref.read(settingsStoreProvider).writeThemeMode(mode);
    } catch (error) {
      debugPrint('Unable to persist the theme preference: $error');
    }
  }
}

final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
