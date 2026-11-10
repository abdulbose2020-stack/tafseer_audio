# Architecture

## Approach

Tafseer Audio uses a pragmatic, feature-first clean architecture. The goal is
clear boundaries without adding ceremony that the app does not need.

- **Domain** — immutable models and repository interfaces. Pure Dart.
- **Data** — JSON asset loading, audio handler, queue logic, and mappers.
- **Presentation** — Riverpod providers, screens, and reusable widgets.
- **Core** — theme, typography, spacing, constants, and shared widgets.

## Planned data flow

```text
assets/data/surahs.json
        │
        ▼
JsonSurahRepository ──► surahsProvider ──► SurahListScreen
                                              │
                                              │ tap Surah
                                              ▼
                                      PlayerController
                                              │
                                              ▼
                                  TafseerAudioHandler
                                   ├─ just_audio
                                   ├─ queue / next / previous
                                   ├─ audio_session
                                   └─ audio_service notification
                                              │
                                              ▼
                              player state + position streams
                                              │
                                ┌─────────────┴─────────────┐
                                ▼                           ▼
                           MiniPlayer                  PlayerScreen
```

The audio handler is the single source of truth for playback. Riverpod mirrors
its state for the UI and sends commands through a thin controller.

## Feature layout

```text
lib/features/
├─ surahs/
│  ├─ domain/
│  │  ├─ surah.dart
│  │  └─ surah_repository.dart
│  ├─ data/
│  │  ├─ json_surah_repository.dart
│  │  └─ surah_asset_data_source.dart
│  └─ presentation/
│     ├─ providers/
│     ├─ screens/
│     └─ widgets/
└─ player/
   ├─ domain/
   │  ├─ playback_track.dart
   │  ├─ playback_state.dart
   │  └─ playback_service.dart
   ├─ data/
   │  ├─ tafseer_audio_handler.dart
   │  ├─ audio_service_bootstrap.dart
   │  ├─ playback_queue.dart
   │  └─ surah_track_mapper.dart
   └─ presentation/
      ├─ providers/
      ├─ screens/
      └─ widgets/
```

## State management

- `flutter_riverpod` with manually written providers. No code generation.
- Surah metadata is loaded once at startup.
- Player commands go through a `PlayerController`; the UI never talks to
  `just_audio` directly.
- Playback position is exposed separately from the main player state to avoid
  rebuilding the whole player screen on every position tick.
- The handler publishes app-owned state models so the UI does not depend on
  `audio_service` types.

## Audio design

- One `just_audio` player instance.
- One recording per Surah in v1.
- A pure `PlaybackQueue` handles current index, next, previous, and boundary
  rules so it can be unit tested without platform plugins.
- `audio_session` is configured for speech playback, audio focus loss, and
  headphone disconnection.
- `audio_service` provides notification, lock-screen, headset, and background
  controls.
- The sample audio asset will be mapped to all 114 Surahs until the Sheikh's
  recordings are available.

## Offline guarantees

- No Firebase, authentication, analytics, or HTTP client.
- No `INTERNET` permission in the release manifest.
- Fonts, artwork, metadata, and audio are local assets.
- Notification artwork will be cached from a bundled asset, not downloaded.

## Testing strategy

- Unit tests for Surah metadata validation, search/filter logic, and playback
  queue behavior.
- Widget tests for the catalog, mini player, and player controls using
  ProviderScope overrides.
- Manual device verification for background playback, notifications, lock
  screen, headset controls, interruptions, and seeking.

## Distribution constraint

The base Play Store module is not intended to carry several gigabytes of
audio. The final packaging approach will be decided before real recordings are
added. Keeping audio paths behind a manifest/resolver keeps the UI independent
of that decision.
