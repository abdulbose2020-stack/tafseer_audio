import '../../../core/constants/asset_paths.dart';
import '../domain/audio_track.dart';

/// The temporary recording used only to verify the Phase 3 audio engine.
///
/// This is a real wedding-sermon MP3, not a Surah tafsir. It deliberately has
/// no [AudioTrack.surahNumber] and must never be mapped to a Surah or shipped
/// as catalogue content. Replace it with the Sheikh's recordings in a later
/// phase.
const AudioTrack sampleAudioTrack = AudioTrack(
  id: 'temporary-engine-sample',
  title: 'Wedding sermon sample',
  subtitle: 'Temporary engine test — not a Surah tafsir',
  album: 'Tafseer Audio engine test',
  artist: 'Temporary sample recording',
  assetPath: AssetPaths.sampleAudio,
  isTemporarySample: true,
);
