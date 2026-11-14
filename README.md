# Tafseer Audio

An Android-first Flutter application for reading the Qur’an offline and
listening to complete audio tafseer for all 114 Surahs of the Qur’an. It is
designed to work fully offline, with no account, Firebase, or online backend.

## Status

**Phases 0–4, the offline Qur’an reader, and the Qur’an data pipeline are
complete. Phase 5 — audio hardening — is next.**

- **Phase 0 — Foundation (complete):** project setup, Android application ID,
  audio-service configuration, dependencies, fonts, brand assets, and Git
  baseline.
- **Phase 1 — Design shell (complete):** theme, typography, Islamic geometric
  pattern, app shell, native splash, and launcher icon.
- **Phase 2 — Surah catalogue (complete):** all 114 Surahs, offline JSON
  metadata, search, Makki/Madani filters, selection highlighting, and automated
  tests. The catalogue was visually verified on the Android emulator: all 114
  Surahs render correctly, and search, filters, scrolling, and selection
  highlighting work.
- **Phase 3 — Audio playback (complete):** one process-wide
  `audio_service`/`just_audio` handler, offline asset playback, a playback queue
  and authoritative state model, background media notification,
  lock-screen/headset controls, audio-focus and headphone-disconnect handling,
  Riverpod integration, automated engine tests, and a temporary sample control
  in the catalogue screen. Basic playback, pause/resume, background playback,
  and the media notification were smoke-tested on the Android emulator.
- **Phase 4 — Player UI (complete):** a full Surah player with playback status,
  progress, seeking, and previous/next catalogue navigation, plus a mini player
  at the bottom of the catalogue for the currently loaded Surah recording. A
  recording repository resolves a Surah's local file when one is bundled and
  otherwise shows a clear unavailable state. Automated provider, repository, and
  widget tests cover the player and mini player.
- **Offline Qur’an reading (complete):** a separate Arabic reader for all 114
  Surahs, its own Surah catalogue and navigation, adjustable Arabic text size,
  the bundled English translation beneath each Ayah, a session-only translation
  visibility control, Basmala handling, Sajdah indicators, and an in-app sources
  and acknowledgements screen.
- **Qur’an data pipeline (complete):** reproducible source acquisition,
  generation, independent pre- and post-publish validation, staged publishing
  with backup and rollback, and an asset-integrity regression test.

The English translation is displayed beneath each Ayah by default and can be
shown or hidden for the current app session. Footnotes remain bundled and
parsed but are not displayed. The app supports Light, Dark, and System themes;
the selection is saved locally and System follows the device appearance setting.

The Android audio-service components are connected to a real handler, and the
player UI reads playback state through Riverpod. No real tafsir recordings are
bundled yet, so every Surah currently opens in the clearly labelled "Recording
not yet available" state; the player never falls back to the temporary sample.
Playback for engine verification still uses one temporary wedding-sermon
recording at `assets/audio/sample/sample_tafseer.mp3`. It is clearly labelled in
the app as an engine test, has no Surah number, is not assigned to any Surah, and
is not catalogue content. No tafsir audio has been synthesized or fabricated.

## Product principles

- **Offline first** — the Qur’an text, bundled translation data, Surah
  metadata, fonts, and artwork are stored locally. Playback is intended to work
  offline; the audio packaging decision is still pending (see the
  [distribution note](#distribution-note)).
- **Simple and focused** — the design target is one recording per Surah and one
  clear player.
- **Quietly Islamic** — emerald, ivory, and restrained gold; Amiri Arabic
  typography; geometric motifs instead of heavy ornamentation.
- **Maintainable** — feature-first structure, Riverpod state, and an audio layer
  isolated from the UI.

## Tech stack

- Flutter 3.44.1 / Dart 3.12.1
- Riverpod 3 for state management and dependency injection
- `just_audio`, `audio_service`, and `audio_session` for the playback engine;
  Android is configured for the background audio service
- `path_provider` installed for future asset-packaging work; it is not used by
  the current playback path
- `shared_preferences` for the saved Light/Dark/System theme preference
- Locally bundled Amiri and Inter fonts

## Qur’an reading

The app opens on the **Tafseer** tab. A persistent bottom bar switches between
**Tafseer**, **Qur’an**, and **Settings**; each tab keeps its own scroll and
in-screen state while the app is running. Reading has its own catalogue and
never changes the Tafseer selection, the playback queue, or the mini player.

- **Reader catalogue** — all 114 Surahs with Arabic name, transliteration,
  English meaning, Ayah count, and revelation place.
- **Arabic reader** — opens one bundled Surah at a time. The Arabic text is
  rendered exactly as supplied, with Ayah numbers in separate badges, the
  prefatory Basmala where the source provides one (all Surahs except 1 and 9),
  and a Sajdah indicator on Sajdah Ayahs.
- **Text size** — a session-only Arabic size control from 26 to 48. It is
  intentionally not persisted in Settings.
- **English translation** — the QuranEnc translation is shown beneath each
  Ayah by default. A reader app-bar control shows or hides it for the current
  session; the choice carries across Surahs and resets to visible after a full
  restart. It is rendered left-to-right and does not follow the Arabic text-size
  control. Prefatory Basmalas have no translation record and remain
  Arabic-only; Surah 1's Basmala is Ayah 1 and uses its normal translation, and
  Surah 9 has no Basmala.
- **Selection** — Arabic text, English translation, and the prefatory Basmala
  are selectable and copyable.
- **Sources** — the reader and Settings open the same acknowledgements screen,
  which reads versions and required notices from the bundled manifest.
- **Offline** — every Surah is a local JSON asset. The reader loads only the
  requested Surah; it does not enumerate the directory or download content.

Translation strings are rendered exactly as supplied, including inline
footnote markers such as `[2]`. Footnote text is bundled and parsed into the
domain model but is not displayed in this stage.

The app supports **Light**, **Dark**, and **System** themes. The selection is
saved with `SharedPreferences` and restored before the first frame; System
follows the device appearance setting.

## Qur’an data

The complete Qur’an dataset is bundled at `assets/data/quran/`:

- `manifest.json` — dataset and schema versions, generator metadata, source
  versions and required notices, totals, Basmala summary, 114 per-Surah
  SHA-256 digests, and the content checksum.
- `surahs/001.json` … `surahs/114.json` — Arabic text, English translation,
  footnotes, and Sajdah markers for each Surah.

The manifest and the 114 Surah files are the only runtime files. Each Surah
file is verified by its manifest digest, and the content checksum is SHA-256
over the sorted file names and digests. The data layout and fields are
documented in [`assets/data/README.md`](assets/data/README.md).

### Qur’an data provenance

- **Arabic text:** Tanzil Quran Text (Uthmani, Version 1.1), copyright
  (C) 2007-2026 Tanzil Project, licensed under CC BY 3.0.
- **English translation:** QuranEnc `english_saheeh` (Version 1.1.2,
  `v1.1.2-csv.1`), published by Noor International Center through QuranEnc.
- **Surah catalogue:** Tanzil Quran Metadata, copyright (C) 2008-2009
  Tanzil.info, licensed under CC BY; cross-checked with the Quran.com Chapters
  API.

The manifest stores the exact required notices. The app shows them under
**Settings → Qur’an sources** without duplicating the notice text in the UI.

## Qur’an data pipeline

The reviewed source files are processed by PowerShell scripts under
`tool/quran_data/generator/`. The scripts never repair or hand-edit source
data, and they derive the project root from their own location.

```powershell
# Acquire reviewed sources only when intentionally updating versions.
powershell -ExecutionPolicy Bypass -File tool/quran_data/generator/fetch-sources.ps1

# Generate the dataset and its validation reports.
powershell -ExecutionPolicy Bypass -File tool/quran_data/generator/generate.ps1

# Validate sources and generated output before publishing.
powershell -ExecutionPolicy Bypass -File tool/quran_data/generator/validate.ps1 -Mode pre-publish

# Stage, back up, verify, swap, and post-validate runtime assets.
powershell -ExecutionPolicy Bypass -File tool/quran_data/generator/publish.ps1

# Independently verify the published runtime assets.
powershell -ExecutionPolicy Bypass -File tool/quran_data/generator/validate.ps1 -Mode post-publish
```

`validate.ps1` defaults to `-Mode auto`, which selects post-publish validation
when `assets/data/quran` exists and pre-publish validation otherwise. A failed
run writes `independent-validation.failed.json` and never overwrites the last
successful report.

`publish.ps1` verifies generated data, stages a copy, verifies all 115 staged
files, backs up the current runtime directory to `tool/quran_data/backups/`,
swaps in the verified staging copy, and runs post-publish validation. Any
failure after the swap restores the backup; if no runtime directory existed,
the new copy is removed. The backup is kept by default; pass
`-RemoveBackupOnSuccess` after confirming a publish. Staging lives under
`tool/quran_data/publish-work/` and is cleaned up.

See [`tool/quran_data/README.md`](tool/quran_data/README.md) for the complete
workflow and safeguards.

## Tafseer catalogue

The complete Tafseer catalogue is bundled at
[`assets/data/surahs.json`](assets/data/surahs.json) and is loaded without
network access.

- **114 Surahs**, from Al-Faatiha (1) to An-Naas (114).
- **6,236 Ayahs** in total, across 86 Makki and 28 Madani Surahs.
- Search by Surah number, Arabic name, transliteration, or English meaning.
- Filter by All, Makki, or Madani.
- Tapping a Surah opens the player and highlights it in the catalogue. Opening
  the player does not start playback.

### Source and attribution

The catalogue metadata is derived from [Tanzil Quran
Metadata](https://tanzil.net/res/text/metadata/quran-data.xml), copyright
(C) 2008-2009 Tanzil.info, licensed under
[CC BY](https://creativecommons.org/licenses/by/3.0/). Tanzil provides the
Surah number, Arabic name, transliteration, English meaning, Ayah count, and
revelation place. Revelation place is normalized from Tanzil's `Meccan` and
`Medinan` values to `makki` and `madani`.

The [Quran.com Chapters API](https://api.quran.com/api/v4/chapters) was used as
an independent cross-check for Surah numbers, Arabic names, Ayah counts, and
revelation places. Tanzil remains the primary source for transliterations and
English meanings.

The `source` object at the top of `surahs.json` records this provenance. Field
definitions and validation are documented in
[`assets/data/README.md`](assets/data/README.md).

## Audio engine

The app uses one process-wide audio engine:

- `TafseerAudioHandler` extends `audio_service`'s `BaseAudioHandler` and owns one
  `just_audio` player, the queue, and the authoritative playback state.
- The handler publishes notification/lock-screen state and handles play, pause,
  resume, stop, seek, next/previous, completion, audio interruptions, and
  headphone disconnection.
- `main` initializes the handler once before `runApp` and overrides
  `audioEngineProvider`; `PlaybackController` mirrors the handler state for the
  UI. Screens never talk to the audio plugins directly.
- Playback uses bundled assets only. There is no streaming, remote URL, backend,
  or internet permission in the release manifest.
- Tests use fake player, session, and engine implementations; they do not
  initialize Android audio services.
- Audio asset layout and recording instructions are documented in
  [`assets/audio/README.md`](assets/audio/README.md).

## Player UI

Phase 4 connects the catalogue and the playback state:

- **Player screen** — shows the Surah medallion, Arabic name, transliteration,
  meaning, Ayah count, and revelation place; playback status, position,
  duration, and a seek slider; play/pause and previous/next controls. Previous
  and next move through the catalogue without starting playback, so browsing
  never unexpectedly plays a recording. If another Surah is playing, the screen
  says so and offers a shortcut to it.
- **Mini player** — appears at the bottom of the catalogue only for a real Surah
  recording. It shows Surah details, elapsed/total time, a thin progress bar,
  play/pause, and opens the full player. It is deliberately hidden for the
  temporary sample.
- **Recording resolution** — `SurahRecordingRepository` maps a Surah number to a
  bundled local file. The default repository is empty, so every Surah currently
  shows "Recording not yet available" and playback/seeking are disabled. Bundle
  the files, declare their asset directory in `pubspec.yaml`, and add entries in
  `LocalSurahRecordingRepository` to enable playback; the UI needs no changes.
- **Safety** — the temporary wedding-sermon sample can never be presented as a
  Surah recording. Opening any Surah stops the sample, the player refuses the
  sample asset as a Surah file, and the mini player ignores it.

### Temporary sample caveat

The card above the catalogue is a temporary engine check, not a Surah player. It
controls `assets/audio/sample/sample_tafseer.mp3`, a wedding sermon used only to
verify real playback. The track has `surahNumber == null` and
`isTemporarySample == true`, and it is never mapped to a Surah. Replace it with
the Sheikh's recordings before release; do not treat it as tafsir content.

## Project layout

```text
tafseer_audio/
├─ lib/                 Flutter application source
├─ test/                Unit, metadata, asset-integrity, provider, and widget tests
├─ assets/
│  ├─ audio/            Temporary sample and reserved Surah recordings
│  ├─ data/             surahs.json, Qur’an runtime data, and provenance notes
│  │  └─ quran/         manifest.json and 114 Surah JSON files
│  ├─ fonts/            Amiri and Inter, with OFL licenses
│  └─ images/           App icon, splash, and brand artwork
├─ docs/
│  └─ architecture.md
├─ tool/
│  ├─ generate_brand_assets.ps1
│  └─ quran_data/       Sources, generator, validator, publisher, and reports
├─ android/             Android host and audio-service configuration
├─ ios/                 Default Flutter platform folder
├─ linux/               Default Flutter platform folder
├─ macos/               Default Flutter platform folder
├─ web/                 Default Flutter platform folder
├─ windows/             Default Flutter platform folder
├─ pubspec.yaml
└─ README.md
```

The detailed `lib/` feature layout, current data flow, and current architecture
are documented in [`docs/architecture.md`](docs/architecture.md).

## Getting started

```bash
flutter pub get
flutter run
```

Useful checks:

```bash
dart format --set-exit-if-changed lib test
flutter analyze
flutter test test/assets/quran_assets_test.dart
flutter test --reporter expanded
flutter build apk --debug
```

## Android identity

- Application ID: `com.tafseeraudio.app`
- Display name: `Tafseer Audio`
- `MainActivity` extends `AudioServiceActivity` so the Flutter engine can be
  shared with the playback service.
- Android permissions are limited to wake lock and media playback foreground
  service permissions. The release manifest has no `INTERNET` permission;
  debug and profile builds add it only for Flutter tooling.

## Brand assets

The current geometric mark is generated reproducibly with:

```powershell
powershell -ExecutionPolicy Bypass -File tool/generate_brand_assets.ps1
```

Then regenerate the launcher icons and splash screen:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

The generated files are committed so a normal build does not need to run the
generators.

> The Flutter UI supports light, dark, and system themes. The native splash is
> still light-only; if you regenerate it, keep the `values-night` themes on
> `Theme.Light.NoTitleBar` and `@color/splash_background` so Android does not
> flash a dark window before Flutter starts.

## Fonts and licenses

- **Amiri** — Arabic typography. OFL license in
  `assets/fonts/OFL-Amiri.txt`.
- **Inter** — Latin UI typography. OFL license in
  `assets/fonts/OFL-Inter.txt`.

## Roadmap

Phases 0–4, the offline Qur’an reader, and the Qur’an data pipeline are
complete. Remaining work:

- **Phase 5 (next) — Hardening:** final full test pass, device verification, and
  documentation for adding the Sheikh's recordings. This includes replacing the
  temporary sample, populating `LocalSurahRecordingRepository`, and manually
  verifying notification, lock-screen, headset, and interruption behavior.
- **Reading follow-up:** add optional footnote display. Footnote text is
  bundled and parsed, and inline markers already render with the translation,
  but the footnotes themselves are not displayed yet.

## Distribution note

114 full tafseer recordings may total several gigabytes. Before real recordings
are added, the project must choose a packaging approach: Play Asset Delivery, a
fully bundled sideload build, or a subset-per-release approach. The Phase 4
`SurahRecordingRepository` keeps this decision isolated from the UI. No real
tafsir recordings are bundled today; only the temporary engine-test sample is
declared in `pubspec.yaml`.
