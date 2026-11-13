import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tafseer_audio/core/settings/settings_store.dart';
import 'package:tafseer_audio/features/settings/presentation/providers/theme_providers.dart';

class _ThrowingReadStore implements SettingsStore {
  @override
  ThemeMode readThemeMode() => throw StateError('read failed');

  @override
  Future<void> writeThemeMode(ThemeMode mode) async {}
}

class _ThrowingWriteStore implements SettingsStore {
  @override
  ThemeMode readThemeMode() => ThemeMode.system;

  @override
  Future<void> writeThemeMode(ThemeMode mode) async {
    throw StateError('write failed');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('restores the saved theme before the first read', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesSettingsStore.themeModeKey: 'dark',
    });
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(
          SharedPreferencesSettingsStore(preferences),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(themeModeControllerProvider), ThemeMode.dark);
  });

  test('persists a theme selection for the next launch', () async {
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(
          SharedPreferencesSettingsStore(preferences),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(themeModeControllerProvider), ThemeMode.system);
    await container
        .read(themeModeControllerProvider.notifier)
        .setThemeMode(ThemeMode.dark);

    expect(container.read(themeModeControllerProvider), ThemeMode.dark);

    final restoredPreferences = await SharedPreferences.getInstance();
    final restored = SharedPreferencesSettingsStore(restoredPreferences);
    expect(restored.readThemeMode(), ThemeMode.dark);
  });

  test('falls back to system when the preference cannot be read', () {
    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(_ThrowingReadStore()),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(themeModeControllerProvider), ThemeMode.system);
  });

  test('keeps the selected mode when persistence fails', () async {
    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(_ThrowingWriteStore()),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(themeModeControllerProvider.notifier)
        .setThemeMode(ThemeMode.dark);

    expect(container.read(themeModeControllerProvider), ThemeMode.dark);
  });
}
