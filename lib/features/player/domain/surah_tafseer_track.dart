import '../../surahs/domain/surah.dart';
import 'audio_track.dart';
import 'surah_recording.dart';

/// Builds the playable track for a real Surah recording.
///
/// The result always belongs to [surah] and is never marked as the temporary
/// engine sample.
AudioTrack buildSurahTafseerTrack(Surah surah, SurahRecording recording) {
  assert(
    recording.surahNumber == surah.number,
    'A Surah recording must be paired with the Surah it belongs to.',
  );

  return AudioTrack(
    id: 'surah-${surah.number}-tafseer',
    title: 'Surah ${surah.number} · ${surah.transliteration}',
    subtitle: '${surah.englishMeaning} · ${surah.revelationPlace.label}',
    album: 'Tafseer Audio',
    assetPath: recording.assetPath,
    duration: recording.duration,
    surahNumber: surah.number,
    isTemporarySample: false,
  );
}
