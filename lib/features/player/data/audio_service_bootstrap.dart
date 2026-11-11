import 'package:audio_service/audio_service.dart';

import 'tafseer_audio_handler.dart';

/// The Android notification channel used for offline playback controls.
const String audioNotificationChannelId = 'com.tafseeraudio.app.playback';

/// The user-visible name of the playback notification channel.
const String audioNotificationChannelName = 'Tafseer Audio playback';

/// Initializes the one audio handler for the process.
///
/// This must be called exactly once, before `runApp`, so that the Flutter
/// engine is shared with the Android media service. Tests never call this;
/// they override `audioEngineProvider` with a fake engine instead.
Future<TafseerAudioHandler> initializeTafseerAudioHandler() {
  return AudioService.init<TafseerAudioHandler>(
    builder: TafseerAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: audioNotificationChannelId,
      androidNotificationChannelName: audioNotificationChannelName,
      androidNotificationChannelDescription:
          'Playback controls for offline tafseer audio',
      androidNotificationIcon: 'mipmap/ic_launcher',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}
