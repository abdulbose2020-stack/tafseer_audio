/// Formats a playback position or duration for the player UI.
String formatPlaybackDuration(Duration? duration) {
  if (duration == null) {
    return '--:--';
  }

  final totalSeconds = duration.inSeconds;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;

  if (hours > 0) {
    return '$hours:${remainingMinutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
