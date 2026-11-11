import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/player/data/audio_service_bootstrap.dart';
import 'features/player/data/tafseer_audio_handler.dart';
import 'features/player/presentation/providers/playback_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final audioHandler = await initializeTafseerAudioHandler();

  runApp(
    ProviderScope(
      overrides: [audioEngineProvider.overrideWithValue(audioHandler)],
      child: _AudioEngineHost(
        engine: audioHandler,
        child: const TafseerAudioApp(),
      ),
    ),
  );
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
