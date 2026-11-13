import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tafseer_audio/core/settings/settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to system when no preference is stored', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesSettingsStore(preferences);

    expect(store.readThemeMode(), ThemeMode.system);
  });

  test('persists and restores each theme mode', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesSettingsStore(preferences);

    for (final mode in ThemeMode.values) {
      await store.writeThemeMode(mode);

      final restoredPreferences = await SharedPreferences.getInstance();
      final restored = SharedPreferencesSettingsStore(restoredPreferences);

      expect(restored.readThemeMode(), mode);
    }
  });

  test('treats an unknown stored value as system', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesSettingsStore.themeModeKey: 'sepia',
    });
    final preferences = await SharedPreferences.getInstance();

    expect(
      SharedPreferencesSettingsStore(preferences).readThemeMode(),
      ThemeMode.system,
    );
  });

  test('memory store keeps the selected mode for the session', () async {
    final store = MemorySettingsStore();

    expect(store.readThemeMode(), ThemeMode.system);
    await store.writeThemeMode(ThemeMode.dark);
    expect(store.readThemeMode(), ThemeMode.dark);
  });
}
