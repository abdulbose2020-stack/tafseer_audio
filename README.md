# Tafseer Audio

An Android-first Flutter application for listening to complete audio tafseer
for all 114 Surahs of the Qur'an — fully offline, with no account, Firebase,
or online backend.

## Current status

**Phase 0 and Phase 1 are complete.**

- Phase 0: project foundation, Android application ID, audio-service
  configuration, dependencies, fonts, brand assets, and Git baseline.
- Phase 1: design system, app shell, Islamic geometric pattern, navigation,
  splash screen, and launcher icon.

Audio playback and the 114-Surah catalog are intentionally **not implemented
yet**. They belong to Phase 2 and Phase 3.

## Product principles

- **Offline first** — all metadata, fonts, artwork, and audio will be bundled
  locally. The release app will not request network access.
- **Simple and focused** — one recording per Surah, one clear player.
- **Quietly Islamic** — emerald, ivory, and restrained gold; Amiri Arabic
  typography; geometric motifs instead of heavy ornamentation.
- **Maintainable** — feature-first structure, Riverpod for state, and a
  dedicated audio layer that the UI does not need to know about.

## Tech stack

- Flutter 3.44 / Dart 3.12
- Riverpod 3 for state management and dependency injection
- `just_audio` for playback
- `audio_service` for background playback, notifications, and lock-screen
  controls
- `audio_session` for audio focus and interruption handling
- Locally bundled Amiri and Inter fonts

Audio packages are installed and Android is configured for them, but no
playback code exists yet.

## Project structure

```text
lib/
├─ main.dart
├─ app.dart
├─ core/
│  ├─ constants/
│  ├─ theme/
│  └─ widgets/
└─ features/
   ├─ surahs/
   │  └─ presentation/screens/surah_list_screen.dart
   └─ player/
      └─ presentation/screens/player_screen.dart
```

The planned domain/data/presentation layers for Surahs and playback are
documented in [`docs/architecture.md`](docs/architecture.md).

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
- `MainActivity` extends `AudioServiceActivity` so the Flutter engine is
  shared with the playback service.
- Android permissions are limited to wake lock and media playback foreground
  service permissions. There is no `INTERNET` permission in the release
  manifest.

## Brand assets

The temporary geometric mark is generated reproducibly with:

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

- **Phase 2** — verified 114-Surah metadata, catalog, search, and filters.
- **Phase 3** — audio engine, sample audio, background playback, notification
  and lock-screen controls.
- **Phase 4** — mini player and fully connected player UI.
- **Phase 5** — full test pass, device verification, and documentation for
  adding the Sheikh's recordings.

## Important distribution note

114 full tafseer recordings may total several gigabytes. Before the real
recordings are bundled, the project will need a distribution decision:
Play Asset Delivery, a fully bundled sideload build, or a subset-per-release
approach. The audio layer will keep this decision isolated from the UI.
