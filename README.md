# Tafseer Audio

An Android-first Flutter application for listening to complete audio tafseer
for all 114 Surahs of the Qur'an. It is designed to work fully offline, with no
account, Firebase, or online backend.

## Status

**Phases 0, 1, and 2 are complete. Phase 3 — audio playback — has not started.**

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

Phase 3 has not begun: there is no audio player instance, audio handler,
playback queue, or bundled recording. The Android audio-service components are
configured, but nothing connects them to playback. The existing `PlayerScreen`
is a static Phase 1 design preview; it is not reachable from the catalogue and
contains no playback logic.

## Product principles

- **Offline first** — Surah metadata, fonts, and artwork are bundled locally.
  Playback is intended to work offline; the audio packaging decision is still
  pending (see the [distribution note](#distribution-note)).
- **Simple and focused** — the design target is one recording per Surah and one
  clear player.
- **Quietly Islamic** — emerald, ivory, and restrained gold; Amiri Arabic
  typography; geometric motifs instead of heavy ornamentation.
- **Maintainable** — feature-first structure, Riverpod state, and an audio layer
  isolated from the UI in Phase 3.

## Tech stack

- Flutter 3.44.1 / Dart 3.12.1
- Riverpod 3 for state management and dependency injection
- `just_audio`, `audio_service`, `audio_session`, and `path_provider` installed;
  Android is configured for the Phase 3 audio service, but no playback code
  exists yet
- Locally bundled Amiri and Inter fonts

## Surah catalogue

The complete catalogue is bundled at
[`assets/data/surahs.json`](assets/data/surahs.json) and is loaded without
network access.

- **114 Surahs**, from Al-Faatiha (1) to An-Naas (114).
- **6,236 Ayahs** in total, across 86 Makki and 28 Madani Surahs.
- Search by Surah number, Arabic name, transliteration, or English meaning.
- Filter by All, Makki, or Madani.
- Selecting a Surah highlights it and shows a selected-Surah summary. Selection
  does not navigate or start playback.

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

## Project layout

```text
tafseer_audio/
├─ lib/                 Flutter application source
├─ test/                Unit, metadata, repository, and widget tests
├─ assets/
│  ├─ audio/            Reserved for Phase 3; no recordings bundled
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

The detailed `lib/` feature layout, current data flow, and planned Phase 3
architecture are documented in [`docs/architecture.md`](docs/architecture.md).

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
  shared with the Phase 3 playback service.
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

Phases 0–2 are complete. Remaining work:

- **Phase 3 (next) — Audio playback:** audio engine, sample audio, playback
  queue, background playback, and notification/lock-screen controls. Not
  started.
- **Phase 4 — Player UI:** mini player and a player screen connected to the
  catalogue and playback state.
- **Phase 5 — Hardening:** full test pass, device verification, and
  documentation for adding the Sheikh's recordings.

## Distribution note

114 full tafseer recordings may total several gigabytes. Before real recordings
are added, the project must choose a packaging approach: Play Asset Delivery, a
fully bundled sideload build, or a subset-per-release approach. The Phase 3
audio layer will keep this decision isolated from the UI. No audio is bundled
or declared in `pubspec.yaml` today.
