import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local_surah_recording_repository.dart';
import '../../domain/surah_recording.dart';
import '../../domain/surah_recording_repository.dart';

/// The local Surah recordings available to the player.
///
/// This currently contains no recordings. Tests and future builds override or
/// replace the repository without changing the player UI.
final surahRecordingRepositoryProvider = Provider<SurahRecordingRepository>((
  ref,
) {
  return const LocalSurahRecordingRepository();
});

/// The local recording for one Surah, or `null` when it is not available.
final surahRecordingProvider = Provider.family<SurahRecording?, int>((
  ref,
  surahNumber,
) {
  return ref.watch(surahRecordingRepositoryProvider).recordingFor(surahNumber);
});
