import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tafseer_audio/features/player/data/local_surah_recording_repository.dart';
import 'package:tafseer_audio/features/player/domain/surah_recording.dart';
import 'package:tafseer_audio/features/player/presentation/providers/surah_recording_providers.dart';

const _recording = SurahRecording(
  surahNumber: 36,
  assetPath: 'assets/audio/tafseer/036.mp3',
  duration: Duration(minutes: 25),
);

void main() {
  test('reports no recordings by default', () {
    final container = ProviderContainer.test();

    for (var number = 1; number <= 114; number++) {
      expect(container.read(surahRecordingProvider(number)), isNull);
    }
  });

  test('resolves only the recordings supplied by the repository', () {
    final container = ProviderContainer.test(
      overrides: [
        surahRecordingRepositoryProvider.overrideWithValue(
          const LocalSurahRecordingRepository(recordings: [_recording]),
        ),
      ],
    );

    expect(container.read(surahRecordingProvider(36)), _recording);
    expect(container.read(surahRecordingProvider(1)), isNull);
    expect(container.read(surahRecordingProvider(114)), isNull);
  });

  test('the local repository looks up recordings by Surah number', () {
    const repository = LocalSurahRecordingRepository(recordings: [_recording]);

    expect(repository.recordings, const [_recording]);
    expect(repository.recordingFor(36), _recording);
    expect(repository.recordingFor(37), isNull);
  });
}
