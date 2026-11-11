import 'dart:async';

import 'package:audio_session/audio_session.dart';

/// The subset of `audio_session` the engine needs.
///
/// Keeping this behind a port lets the audio handler be tested without a
/// platform plugin or method channel.
abstract interface class AudioSessionPort {
  Future<void> configure();

  Stream<AudioInterruptionEvent> get interruptionEvents;

  Stream<void> get becomingNoisyEvents;

  Future<void> dispose();
}

/// The production adapter over the process-wide `audio_session` singleton.
class SpeechAudioSessionPort implements AudioSessionPort {
  AudioSession? _session;

  Future<AudioSession> get _instance async {
    return _session ??= await AudioSession.instance;
  }

  @override
  Future<void> configure() async {
    final session = await _instance;
    await session.configure(const AudioSessionConfiguration.speech());
  }

  @override
  Stream<AudioInterruptionEvent> get interruptionEvents async* {
    final session = await _instance;
    yield* session.interruptionEventStream;
  }

  @override
  Stream<void> get becomingNoisyEvents async* {
    final session = await _instance;
    yield* session.becomingNoisyEventStream;
  }

  @override
  Future<void> dispose() async {
    // AudioSession is a process-wide singleton owned by the plugin. Do not
    // deactivate it here; the handler only releases its own subscriptions.
    _session = null;
  }
}
