# Audio assets

Playback is fully offline. This directory contains the temporary engine-test
sample and the reserved location for the Sheikh's Surah recordings. No real
Surah recordings are bundled yet.

```text
assets/audio/
├─ README.md
├─ sample/
│  └─ sample_tafseer.mp3   # temporary engine test; not a Surah tafsir
└─ surahs/                 # reserved for real Surah recordings
```

`sample_tafseer.mp3` is a wedding sermon used only to verify the audio engine.
It has no Surah number, is never shown as catalogue content, and must never be
presented as tafsir. Replace it before release.

## Adding real recordings

The player resolves recordings through `SurahRecordingRepository`, implemented
by `LocalSurahRecordingRepository` in
`lib/features/player/data/local_surah_recording_repository.dart`.

1. Add the recording under `assets/audio/surahs/`, for example `001.mp3`.
2. Declare that directory in `pubspec.yaml` under `flutter.assets`. Only
   `assets/audio/sample/` is declared today.
3. Add a `SurahRecording` entry in `LocalSurahRecordingRepository` with the
   Surah number, asset path, and optional duration.
4. Run `flutter test` and verify the Surah's player state.

The catalogue JSON does not contain audio paths. Adding recordings through the
repository leaves the player and mini player unchanged.

Recommended format: mono MP3 or AAC/M4A at 48–64 kbps for speech, which keeps
the bundle smaller without compromising spoken-word clarity.
