import 'surah_recording.dart';

/// Resolves the local tafsir recording for a Surah, if one has been bundled.
///
/// Keeping this behind an interface lets the player remain unchanged when the
/// Sheikh's recordings are added later, whether they are bundled directly or
/// delivered through a future asset-packaging strategy.
abstract interface class SurahRecordingRepository {
  /// Every real Surah recording currently available locally.
  List<SurahRecording> get recordings;

  /// The recording for [surahNumber], or `null` when it is not available.
  SurahRecording? recordingFor(int surahNumber);
}
