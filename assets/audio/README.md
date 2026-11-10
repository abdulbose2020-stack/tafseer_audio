# Audio assets

Audio playback is not connected yet. This directory reserves the final layout:

```text
assets/audio/
├─ sample/
│  └─ tafseer_sample.m4a        # Phase 3 placeholder
└─ surahs/
   ├─ 001.m4a                   # real recordings, added later
   ├─ 002.m4a
   └─ ...
```

## Adding real recordings

1. Place the recording in `assets/audio/surahs/` using the zero-padded Surah
   number, for example `001.m4a`.
2. Update the Surah's `audioAsset` path in `assets/data/surahs.json`.
3. Set `isSample` to `false` for that Surah.
4. Run the asset validation tests.

Recommended format: mono AAC/M4A at 48–64 kbps for speech, which keeps the
bundle smaller without compromising spoken-word clarity. The final format can
be changed without touching the UI because the path is stored in metadata.
