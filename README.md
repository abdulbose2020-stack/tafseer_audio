# Tafseer Audio

An Android-first Flutter application for listening to complete audio tafseer
for all 114 Surahs of the Qur'an. It is designed to work fully offline, with no
account, Firebase, or online backend.

## Status

**Phases 0–4 are complete. Phase 5 — hardening — is next.**

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

The Android audio-service components are connected to a real handler, and the
player UI reads playback state through Riverpod. No real tafsir recordings are
bundled yet, so every Surah currently opens in the clearly labelled "Recording
not yet available" state; the player never falls back to the temporary sample.
Playback for engine verification still uses one temporary wedding-sermon
recording at `assets/audio/sample/sample_tafseer.mp3`. It is clearly labelled in
the app as an engine test, has no Surah number, is not assigned to any Surah, and
is not catalogue content. No tafsir audio has been synthesized or fabricated.

## Product principles

- **Offline first** — Surah metadata, fonts, and artwork are bundled locally.
  Playback is intended to work offline; the audio packaging decision is still
  pending (see the [distribution note](#distribution-note)).
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
- Locally bundled Amiri and Inter fonts

## Surah catalogue

The complete catalogue is bundled at
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
├─ test/                Unit, metadata, provider, repository, and widget tests
├─ assets/
│  ├─ audio/            Temporary sample and reserved Surah recordings
│  ├─ data/             surahs.json and provenance notes
│  ├─ fonts/            Amiri and Inter, with OFL licenses
│  └─ images/           App icon, splash, and brand artwork
├─ docs/
│  └─ architecture.md
├─ tool/
│  └─ generate_brand_assets.ps1
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
flutter test
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

> The app is intentionally light-only for now. If you regenerate the native
> splash, keep the `values-night` themes on `Theme.Light.NoTitleBar` and
> `@color/splash_background` so Android does not flash a dark window before
> Flutter starts.

## Fonts and licenses

- **Amiri** — Arabic typography. OFL license in
  `assets/fonts/OFL-Amiri.txt`.
- **Inter** — Latin UI typography. OFL license in
  `assets/fonts/OFL-Inter.txt`.

## Roadmap

Phases 0–4 are complete. Remaining work:

- **Phase 5 (next) — Hardening:** final full test pass, device verification, and
  documentation for adding the Sheikh's recordings. This includes replacing the
  temporary sample, populating `LocalSurahRecordingRepository`, and manually
  verifying notification, lock-screen, headset, and interruption behavior.

## Distribution note

114 full tafseer recordings may total several gigabytes. Before real recordings
are added, the project must choose a packaging approach: Play Asset Delivery, a
fully bundled sideload build, or a subset-per-release approach. The Phase 4
`SurahRecordingRepository` keeps this decision isolated from the UI. No real
tafsir recordings are bundled today; only the temporary engine-test sample is
declared in `pubspec.yaml`.
