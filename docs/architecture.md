# Architecture

## Phase status

Phases 0, 1, and 2 are complete. **Phase 3 — audio playback — has not
started.** The codebase currently contains the foundation, design shell, and
Surah catalogue only. Everything described below as planned or future is design
intent, not implemented code.

| Phase | Status | Scope |
| --- | --- | --- |
| 0 — Foundation | Complete | Project setup, Android identity, audio-service configuration, dependencies, fonts, brand assets, and Git baseline. |
| 1 — Design shell | Complete | Theme, typography, Islamic pattern, app shell, native splash, and launcher icon. |
| 2 — Surah catalogue | Complete; verified on the Android emulator | 114-Surah metadata, offline JSON catalogue, search, Makki/Madani filters, selection highlighting, and automated tests. |
| 3 — Audio playback | Not started | Audio engine, sample audio, playback queue, background playback, and notification/lock-screen controls. |
| 4 — Player UI | Planned | Mini player and a player screen connected to the catalogue and playback state. |
| 5 — Hardening | Planned | Full test pass, device verification, and documentation for adding the Sheikh's recordings. |

The app launches into `SurahListScreen`. The existing `PlayerScreen` is a static
Phase 1 design preview: it is not reachable from the catalogue and contains no
playback logic. The Android audio-service components are configured, but no
audio handler, player instance, or queue connects to them yet.

## Approach

Tafseer Audio uses a pragmatic, feature-first clean architecture. The goal is
clear boundaries without adding ceremony that the app does not need.

- **Domain** — immutable models, search and filter logic, and repository
  interfaces. Pure Dart.
- **Data** — bundled JSON loading and repository implementations. Phase 3 will
  add the audio handler and playback queue here.
- **Presentation** — Riverpod providers, screens, and reusable widgets.
- **Core** — theme, typography, spacing, constants, and shared widgets.

## Current catalogue data flow

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

## Catalogue data and attribution

The catalogue is bundled at `assets/data/surahs.json` and loaded without
network access.

The metadata is derived from [Tanzil Quran
Metadata](https://tanzil.net/res/text/metadata/quran-data.xml), copyright
(C) 2008-2009 Tanzil.info, licensed under
[CC BY](https://creativecommons.org/licenses/by/3.0/). The [Quran.com Chapters
API](https://api.quran.com/api/v4/chapters) was used as an independent
cross-check. The `source` object at the top of the JSON file records this
provenance.

The catalogue contains 114 Surahs and 6,236 Ayahs in total: 86 Makki and 28
Madani Surahs. Field definitions, attribution details, and validation coverage
are documented in [`assets/data/README.md`](../assets/data/README.md).

## Current lib layout

This tree reflects the files that exist today.

```text
lib/
├─ main.dart
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
      └─ presentation/
         └─ screens/player_screen.dart
```

## Planned Phase 3 layout

Phase 3 will add the audio layer under the existing `player` feature. The names
below are proposals; none of the proposed new files or folders exist yet.
`player_screen.dart` already exists as the static Phase 1 preview.

```text
lib/features/player/
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
   ├─ screens/          # player_screen.dart exists; connection is Phase 4
   └─ widgets/          # planned for Phase 4
```

## State management

Current:

- `flutter_riverpod` with manually written providers. No code generation.
- Surah metadata is loaded once at startup from `surahsProvider`.
- `surahCatalogControllerProvider` owns the search query and revelation filter.
- `filteredSurahsProvider` derives the visible list from the catalogue and the
  current query/filter.
- `selectedSurahNumberProvider` and `selectedSurahProvider` track selection for
  highlighting and the selected-Surah summary only.

Planned for Phase 3:

- Player commands will go through a `PlayerController`; the UI will never talk
  to `just_audio` directly.
- The audio handler will own playback state and publish app-owned state models,
  so the UI does not depend on `audio_service` types.
- Playback position will be exposed separately from the main player state to
  avoid rebuilding the whole player UI on every position tick.
- Riverpod will mirror handler state for the UI.

## Planned Phase 3 data flow

```text
player command (from the Phase 4 UI)
        │
        ▼
PlayerController
        │ commands
        ▼
TafseerAudioHandler
├─ just_audio
├─ PlaybackQueue
├─ audio_session
└─ audio_service notification
        │ state + position streams
        ▼
Riverpod player providers
        │
        └──► PlayerScreen / MiniPlayer (Phase 4)
```

The audio handler will be the single source of truth for playback. Riverpod
will mirror its state for the UI and send commands through the thin controller.

## Audio design (planned, not implemented)

- One `just_audio` player instance.
- One recording per Surah in v1.
- A pure `PlaybackQueue` will handle current index, next, previous, and boundary
  rules so it can be unit tested without platform plugins.
- `audio_session` will be configured for speech playback, audio focus loss, and
  headphone disconnection.
- `audio_service` will provide notification, lock-screen, headset, and
  background controls.
- Sample audio will be mapped to all 114 Surahs until the Sheikh's recordings
  are available. No sample recording is bundled yet; the project will not
  synthesize or fabricate recordings.

## Offline guarantees

Current:

- No Firebase, authentication, analytics, or HTTP client.
- No `INTERNET` permission in the release manifest. Debug and profile builds
  retain the Flutter tooling's development `INTERNET` permission.
- Fonts, artwork, and Surah metadata are local assets.

Planned for Phase 3:

- Playback will not require network access. Audio packaging (base bundle, Play
  Asset Delivery, or a sideload build) is not yet decided.
- Notification artwork will use bundled or locally cached assets, not network
  downloads.

## Testing strategy

Current:

- Metadata tests validate all 114 entries, sequential numbering, unique
  numbers, the 6,236 total Ayah count, revelation-place counts, known values,
  and the recorded source.
- Unit tests cover search normalization, filtering, repository behavior, JSON
  parsing, and Riverpod state.
- Widget tests cover catalogue rendering, search, filters, empty state, and
  selection highlighting using ProviderScope overrides.
- The catalogue was also manually verified on the Android emulator.

Planned:

- Phase 3 unit tests will cover playback queue behavior and audio-handler
  state mapping.
- Phase 4 widget tests will cover the mini player and player controls.
- Phase 5 will include a full manual pass for background playback,
  notifications, lock screen, headset controls, interruptions, seeking, and
  catalogue regression.

## Distribution constraint

The base Play Store module is not intended to carry several gigabytes of audio.
The packaging approach will be chosen before real recordings are added. Keeping
audio paths behind a manifest/resolver will keep the UI independent of that
decision. See the [README distribution
note](../README.md#distribution-note) for the current options.

## Related documentation

- [`README.md`](../README.md) — project status, setup, catalogue attribution,
  roadmap, and distribution note.
- [`assets/data/README.md`](../assets/data/README.md) — catalogue provenance,
  fields, and validation.
