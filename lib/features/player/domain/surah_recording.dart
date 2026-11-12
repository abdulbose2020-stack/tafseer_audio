import 'package:flutter/foundation.dart';

/// A local tafsir recording that belongs to exactly one Surah.
///
/// The temporary engine-test sample is deliberately not represented by this
/// model. Only real Surah recordings may be added to the recording repository.
@immutable
class SurahRecording {
  const SurahRecording({
    required this.surahNumber,
    required this.assetPath,
    this.duration,
  }) : assert(
         surahNumber >= 1 && surahNumber <= 114,
         'A Surah recording must belong to a Surah between 1 and 114.',
       ),
       assert(assetPath != '', 'A Surah recording needs a local asset path.');

  /// Position in the Mushaf, from 1 to 114.
  final int surahNumber;

  /// Bundled local asset path for this Surah's recording.
  final String assetPath;

  /// Duration when it is already known. The player fills this in after load.
  final Duration? duration;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SurahRecording &&
            other.surahNumber == surahNumber &&
            other.assetPath == assetPath &&
            other.duration == duration;
  }

  @override
  int get hashCode => Object.hash(surahNumber, assetPath, duration);

  @override
  String toString() =>
      'SurahRecording($surahNumber, $assetPath, duration: $duration)';
}
