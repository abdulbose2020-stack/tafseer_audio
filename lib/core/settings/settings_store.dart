import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistence contract for user preferences.
///
/// Keeping this behind an interface lets tests use an in-memory store and lets
/// `main` fall back safely if platform persistence is unavailable.
abstract interface class SettingsStore {
  ThemeMode readThemeMode();

  Future<void> writeThemeMode(ThemeMode mode);
}

/// Stores preferences in the platform's SharedPreferences.
class SharedPreferencesSettingsStore implements SettingsStore {
  const SharedPreferencesSettingsStore(this._preferences);

  static const String themeModeKey = 'theme_mode';

  final SharedPreferences _preferences;

  @override
  ThemeMode readThemeMode() {
    final stored = _preferences.getString(themeModeKey);
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  @override
  Future<void> writeThemeMode(ThemeMode mode) async {
    final saved = await _preferences.setString(themeModeKey, _encode(mode));
    if (!saved) {
      throw StateError('Unable to persist the selected theme.');
    }
  }

  static String _encode(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }
}

/// A safe fallback used when platform preferences cannot be loaded.
class MemorySettingsStore implements SettingsStore {
  MemorySettingsStore({ThemeMode initialMode = ThemeMode.system})
    : _themeMode = initialMode;

  ThemeMode _themeMode;

  @override
  ThemeMode readThemeMode() => _themeMode;

  @override
  Future<void> writeThemeMode(ThemeMode mode) async {
    _themeMode = mode;
  }
}
