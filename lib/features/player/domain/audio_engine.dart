import 'audio_track.dart';
import 'playback_state.dart';

/// The playback contract used by the app.
///
/// The real implementation is [TafseerAudioHandler], which also acts as the
/// `audio_service` handler. Keeping the UI behind this interface makes the
/// playback layer testable without platform audio plugins.
abstract interface class AudioEngine {
  /// The current authoritative playback state.
  PlaybackState get currentState;

  /// Broadcasts every authoritative playback-state change.
  Stream<PlaybackState> get stateStream;

  /// Replaces the queue and loads [initialIndex] without starting playback.
  Future<void> setQueue(List<AudioTrack> tracks, {int initialIndex = 0});

  /// Starts playback, or resumes from the current position.
  Future<void> play();

  /// Resumes a paused track. Equivalent to [play], named for clarity.
  Future<void> resume();

  /// Pauses without clearing the current track.
  Future<void> pause();

  /// Stops playback, resets the position, and hides the media notification.
  Future<void> stop();

  /// Seeks within the current track.
  Future<void> seek(Duration position);

  Future<void> skipToNext();

  Future<void> skipToPrevious();

  Future<void> skipToQueueItem(int index);

  /// Releases the player, session subscriptions, and broadcast streams.
  Future<void> dispose();
}
