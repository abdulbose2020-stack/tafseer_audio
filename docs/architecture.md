# Architecture

## Phase status

Phases 0–4 are complete. The codebase contains the foundation, design shell,
Surah catalogue, audio engine, and the Phase 4 player UI. Phase 5 is the
remaining hardening pass.

| Phase | Status | Scope |
| --- | --- | --- |
| 0 — Foundation | Complete | Project setup, Android identity, audio-service configuration, dependencies, fonts, brand assets, and Git baseline. |
| 1 — Design shell | Complete | Theme, typography, Islamic pattern, app shell, native splash, and launcher icon. |
| 2 — Surah catalogue | Complete; verified on the Android emulator | 114-Surah metadata, offline JSON catalogue, search, Makki/Madani filters, selection highlighting, and automated tests. |
| 3 — Audio playback | Complete; automated tests pass and basic playback smoke-tested on the Android emulator | Audio engine, temporary sample audio, playback queue, background playback, notification/lock-screen controls, and Riverpod integration. |
| 4 — Player UI | Complete; automated tests pass | Full player screen, mini player, recording resolution, unavailable/error states, seeking, and catalogue navigation. Device verification is part of Phase 5. |
| 5 — Hardening | Planned | Final full test pass, device verification, and documentation for adding the Sheikh's recordings. |

The app launches into `SurahListScreen`. Tapping a Surah opens `PlayerScreen`;
the selected-Surah summary and mini player keep the catalogue connected to
playback. A small card above the catalogue remains a temporary control for the
Phase 3 engine. It is explicitly labelled as an engine test and is not connected
to any Surah. No real Surah recordings are bundled yet, so the player shows its
unavailable state for every Surah until the Sheikh's files are added.

## Approach

Tafseer Audio uses a pragmatic, feature-first clean architecture. The goal is
clear boundaries without adding ceremony that the app does not need.

- **Domain** — immutable models, search and filter logic, repository interfaces,
  and the `AudioEngine` contract. No widget or plugin dependencies.
- **Data** — bundled JSON loading, the local recording index, the `audio_service`
  handler, and adapters over `just_audio` and `audio_session`.
- **Presentation** — Riverpod providers, screens, and reusable widgets.
- **Core** — theme, typography, spacing, constants, and shared widgets.

## Catalogue data flow

```text
assets/data/surahs.json
        │
        ▼
SurahAssetDataSource
        │
        ▼
JsonSurahRepository
        │
        ▼
surahsProvider
        │
        ├──► filteredSurahsProvider ──► SurahListScreen
        │         ▲
        │         │ query + filter
        │    surahCatalogControllerProvider
        │
        └──► selectedSurahProvider ──► SurahListScreen
                  ▲                    (tile highlight + summary)
                  │ selected number
             selectedSurahNumberProvider
```

The catalogue is read once from a bundled JSON asset. Search and filtering are
pure domain functions. Selection is UI state only; it does not create an audio
player or start playback.

## Audio data flow

```text
main()
  │ initializes exactly once
  ▼
AudioService.init ──► TafseerAudioHandler (BaseAudioHandler + AudioEngine)
                         ├─ JustAudioPlayerPort ──► one just_audio player
                         ├─ SpeechAudioSessionPort ──► audio_session
                         └─ audio_service notification / lock screen
                                    │
                                    │ stateStream
                                    ▼
                         playbackControllerProvider
                                    │ PlaybackState + commands
                                    ▼
                    ┌───────────────┼────────────────┐
                    ▼               ▼                ▼
            SampleAudioCard     MiniPlayer      PlayerScreen
            (engine test)     (real Surah)     (full player)
```

`PlaybackController` mirrors the handler's `PlaybackState` and forwards the
commands exposed to the UI. Screens do not import `just_audio` or
`audio_service`. The handler is the single source of truth for queue position,
playback phase, position, duration, errors, and the media notification.

## Player UI and recording resolution

```text
Surah selected in catalogue
        │
        ▼
PlayerScreen(surah)
        │
        ├──► surahRecordingProvider(number)
        │         │
        │         ▼
        │    SurahRecordingRepository
        │    (LocalSurahRecordingRepository, currently empty)
        │
        └──► playbackControllerProvider
                  │
                  ├── play/pause/seek
                  └── current track + position/duration/error
```

- `PlayerScreen` separates the **displayed** Surah from the **playing** track.
  Previous/next navigate the displayed Surah only and never start playback.
- `buildSurahTafseerTrack` creates a Surah-owned `AudioTrack`. The player refuses
  the temporary sample asset as a Surah recording, so the sample can never be
  presented as tafsir.
- `MiniPlayer` is the catalogue's bottom bar and only appears for a real Surah
  recording. It is hidden for the temporary sample and when nothing is loaded.
- `surahByNumberProvider` provides metadata lookups without duplicating the
  catalogue.
- The recording repository keeps the future packaging decision isolated from the
  UI: adding bundled files or an asset-pack resolver does not require player
  changes.
- Playback position updates rebuild the player and mini player from the existing
  `PlaybackState`; no separate position provider is needed at this scale.

## Audio design

- One `just_audio` player per process, wrapped by `JustAudioPlayerPort`.
- One `audio_service` handler, `TafseerAudioHandler`, initialized before
  `runApp`; tests override `audioEngineProvider` instead.
- A queue of `AudioTrack` models with next/previous, seek-to-item, completion
  auto-advance, and boundary handling.
- `audio_session` configured for speech playback, with audio-focus interruption
  handling (pause/resume and ducking) and headphone-disconnect pausing.
- `audio_service` publishes playback state, controls, current media item, and
  queue metadata for the media notification and lock screen.
- Loading, ready, buffering, completed, error, and idle phases are mapped to
  app-owned `PlaybackPhase` values.
- Playback is from bundled assets only. There are no remote URLs or network
  streams.
- The handler is disposable: it cancels subscriptions, releases the player and
  session, and closes all broadcast streams.

### Temporary sample

The app currently uses one temporary recording at
`assets/audio/sample/sample_tafseer.mp3` to verify the engine. It is a wedding
sermon, not a Surah tafsir. The `AudioTrack` has `surahNumber == null` and
`isTemporarySample == true`; it is never assigned to a Surah, never shown as
catalogue content, and no tafsir audio is synthesized or fabricated. The sample
must be replaced with the Sheikh's recordings before release.

## Current lib layout

```text
lib/
├─ main.dart                 # initializes the handler and app lifecycle
├─ app.dart
├─ core/
│  ├─ constants/
│  │  ├─ app_constants.dart
│  │  └─ asset_paths.dart
│  ├─ theme/
│  │  ├─ app_colors.dart
│  │  ├─ app_spacing.dart
│  │  ├─ app_theme.dart
│  │  └─ app_typography.dart
│  └─ widgets/
│     ├─ brand_mark.dart
│     └─ islamic_pattern.dart
└─ features/
   ├─ surahs/
   │  ├─ domain/
   │  │  ├─ revelation_place.dart
   │  │  ├─ surah.dart
   │  │  ├─ surah_filter.dart
   │  │  ├─ surah_repository.dart
   │  │  └─ surah_search.dart
   │  ├─ data/
   │  │  ├─ json_surah_repository.dart
   │  │  ├─ surah_asset_data_source.dart
   │  │  └─ surah_data_source.dart
   │  └─ presentation/
   │     ├─ providers/surah_providers.dart
   │     ├─ screens/surah_list_screen.dart
   │     └─ widgets/surah_tile.dart
   └─ player/
      ├─ domain/
      │  ├─ audio_engine.dart
      │  ├─ audio_track.dart
      │  ├─ playback_state.dart
      │  ├─ surah_recording.dart
      │  ├─ surah_recording_repository.dart
      │  └─ surah_tafseer_track.dart
      ├─ data/
      │  ├─ audio_player_port.dart
      │  ├─ audio_service_bootstrap.dart
      │  ├─ audio_session_port.dart
      │  ├─ local_surah_recording_repository.dart
      │  ├─ sample_audio_track.dart
      │  └─ tafseer_audio_handler.dart
      └─ presentation/
         ├─ providers/
         │  ├─ playback_providers.dart
         │  └─ surah_recording_providers.dart
         ├─ screens/player_screen.dart
         ├─ utils/playback_time.dart
         └─ widgets/
            ├─ mini_player.dart
            └─ sample_audio_card.dart
```

## State management

- `flutter_riverpod` with manually written providers. No code generation.
- Surah metadata is loaded once from `surahsProvider`.
- `surahCatalogControllerProvider` owns the search query and revelation filter.
- `filteredSurahsProvider` derives the visible list.
- `selectedSurahNumberProvider` and `selectedSurahProvider` track catalogue
  selection, and `surahByNumberProvider` looks up metadata by Mushaf number.
- `audioEngineProvider` is overridden in `main` with the initialized
  `TafseerAudioHandler`.
- `playbackControllerProvider` mirrors the handler's authoritative
  `PlaybackState` and exposes sample commands, Surah playback, toggling,
  stopping the sample, pause, stop, and seek.
- `surahRecordingRepositoryProvider` supplies the local recording index, and
  `surahRecordingProvider(number)` resolves one Surah's file. Tests override the
  repository with fixture recordings.
- Position updates flow through the same playback state; the player and mini
  player rebuild from it directly. No separate position provider is needed at
  the current scale.

## Offline guarantees

- No Firebase, authentication, analytics, HTTP client, or remote audio URL.
- No `INTERNET` permission in the release manifest. Debug and profile builds
  retain the Flutter tooling's development `INTERNET` permission.
- Fonts, artwork, Surah metadata, and the temporary sample are local assets.
- The audio notification uses local app resources only.

## Testing strategy

- Metadata tests validate all 114 entries, sequential numbering, unique
  numbers, the 6,236 total Ayah count, revelation-place counts, known values,
  and the recorded source.
- Unit tests cover search normalization, filtering, repository behavior, JSON
  parsing, and Riverpod state.
- Widget tests cover catalogue rendering, search, filters, empty state,
  selection, the temporary sample card, the mini player, and the full player.
  They verify unavailable and ready states, seeking, catalogue navigation,
  hiding the mini player for the sample, and distinguishing the displayed Surah
  from another playing Surah. Widget tests override `audioEngineProvider` with a
  fake; the catalogue and player suites also override the recording repository
  with fixture recordings.
- Phase 3 handler tests use fake `AudioPlayerPort` and `AudioSessionPort`
  implementations to verify asset loading, the unassigned sample, media
  notification state, play/pause/seek/stop, errors, interruptions, ducking,
  headphone disconnect, completion auto-advance, queue clearing, and disposal.
- `PlaybackController` tests verify sample loading, pause/resume without
  reloading, external state mirroring, seek, stop, Surah playback, refusing the
  sample as a Surah asset, mini-player toggling, and stopping the sample when a
  Surah is opened.
- `LocalSurahRecordingRepository` and provider tests verify the default empty
  catalogue and lookups by Surah number.
- Basic playback, pause/resume, background playback, and the media notification
  were manually smoke-tested on the Android emulator. Notification actions,
  lock-screen controls, headset buttons, headphone disconnection, and audio
  interruptions still require a full manual pass in Phase 5.

## Distribution constraint

The base Play Store module is not intended to carry several gigabytes of audio.
The packaging approach will be chosen before real recordings are added. The
Phase 4 `SurahRecordingRepository` is the seam for that decision: bundled files
and a future asset-pack resolver both feed the same provider, so the player UI
stays unchanged. See the [README distribution
note](../README.md#distribution-note) for the current options.

## Related documentation

- [`README.md`](../README.md) — project status, setup, catalogue attribution,
  audio engine, roadmap, and distribution note.
- [`assets/data/README.md`](../assets/data/README.md) — catalogue provenance,
  fields, and validation.
- [`assets/audio/README.md`](../assets/audio/README.md) — audio asset layout
  and instructions for adding real Surah recordings.
