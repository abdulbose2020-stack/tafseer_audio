import '../domain/surah_recording.dart';
import '../domain/surah_recording_repository.dart';

/// The Surah recordings bundled with this build.
///
/// No Sheikh recordings are available yet, so the default list is empty and
/// every Surah correctly shows the unavailable state.
///
/// To add recordings later:
/// 1. Bundle the MP3 files locally (for example under `assets/audio/tafseer/`).
/// 2. Declare that directory in `pubspec.yaml`.
/// 3. Add a [SurahRecording] entry for each file below.
///
/// The player and mini-player need no changes when this list becomes non-empty.
class LocalSurahRecordingRepository implements SurahRecordingRepository {
  const LocalSurahRecordingRepository({this.recordings = const []});

  @override
  final List<SurahRecording> recordings;

  @override
  SurahRecording? recordingFor(int surahNumber) {
    for (final recording in recordings) {
      if (recording.surahNumber == surahNumber) {
        return recording;
      }
    }
    return null;
  }
}
