import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/settings/settings_store.dart';
import 'features/player/data/audio_service_bootstrap.dart';
import 'features/player/data/tafseer_audio_handler.dart';
import 'features/player/presentation/providers/playback_providers.dart';
import 'features/settings/presentation/providers/theme_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settingsStore = await _loadSettingsStore();
  final audioHandler = await initializeTafseerAudioHandler();

  runApp(
    ProviderScope(
      overrides: [
        audioEngineProvider.overrideWithValue(audioHandler),
        settingsStoreProvider.overrideWithValue(settingsStore),
      ],
      child: _AudioEngineHost(
        engine: audioHandler,
        child: const TafseerAudioApp(),
      ),
    ),
  );
}

/// Loads preferences before the first frame so the saved theme is applied
/// without a visible light-to-dark flash.
Future<SettingsStore> _loadSettingsStore() async {
  try {
    final preferences = await SharedPreferences.getInstance();
    return SharedPreferencesSettingsStore(preferences);
  } catch (error) {
    debugPrint('Unable to load saved settings; using defaults: $error');
    return MemorySettingsStore();
  }
}

/// Owns the lifecycle of the process-wide audio handler.
class _AudioEngineHost extends StatefulWidget {
  const _AudioEngineHost({required this.engine, required this.child});

  final TafseerAudioHandler engine;
  final Widget child;

  @override
  State<_AudioEngineHost> createState() => _AudioEngineHostState();
}

class _AudioEngineHostState extends State<_AudioEngineHost> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onDetach: () => unawaited(widget.engine.dispose()),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    unawaited(widget.engine.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
