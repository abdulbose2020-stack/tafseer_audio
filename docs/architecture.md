# Architecture

## Phase status

Phases 0–4 are complete, along with the offline Qur’an reader and the Qur’an
data pipeline. Phase 5 is the remaining audio hardening pass. The reader
displays Arabic with the bundled English translation beneath each Ayah by
default; translation visibility is session-only, and footnotes are parsed but
not rendered.

| Phase | Status | Scope |
| --- | --- | --- |
| 0 — Foundation | Complete | Project setup, Android identity, audio-service configuration, dependencies, fonts, brand assets, and Git baseline. |
| 1 — Design shell | Complete | Theme, typography, Islamic pattern, app shell, native splash, and launcher icon. |
| 2 — Surah catalogue | Complete; verified on the Android emulator | 114-Surah metadata, offline JSON catalogue, search, Makki/Madani filters, selection highlighting, and automated tests. |
| 3 — Audio playback | Complete; automated tests pass and basic playback smoke-tested on the Android emulator | Audio engine, temporary sample audio, playback queue, background playback, notification/lock-screen controls, and Riverpod integration. |
| 4 — Player UI | Complete; automated tests pass | Full player screen, mini player, recording resolution, unavailable/error states, seeking, and catalogue navigation. Device verification is part of Phase 5. |
| 5 — Hardening | Planned | Final full test pass, device verification, and documentation for adding the Sheikh's recordings. |
| Qur’an reader | Complete | Offline Arabic reader for all 114 Surahs, reader catalogue/navigation, default-visible English translation with session-only visibility, Basmala and Sajdah handling, Arabic text-size control, source acknowledgements, and Light/Dark/System themes. |
| Qur’an data pipeline | Complete | Source acquisition, generation, independent pre/post-publish validation, staged publishing with backup/rollback, and asset-integrity tests. |

The app launches into `MainShell`, a persistent three-destination shell:
Tafseer (index 0), Qur’an (index 1, default), and Settings (index 2). Each
destination is a separate root screen kept alive by an `IndexedStack`, so tab
switches preserve scroll position and in-screen state without pushing routes.
Tapping a Surah in the Tafseer catalogue opens `PlayerScreen`; the
selected-Surah summary and mini player keep that catalogue connected to
playback. The Qur’an catalogue opens `QuranReaderScreen`, and Settings opens
`QuranSourcesScreen`; all detail routes sit above the shell. A `PopScope` policy
returns the Tafseer and Settings tabs to Qur’an on back, while back on the
Qur’an root follows the platform default. A small card above the Tafseer
catalogue remains a temporary control for the Phase 3 engine. It is explicitly
labelled as an engine test and is not connected to any Surah. No real Surah
recordings are bundled yet, so the player shows its unavailable state for every
Surah until the Sheikh's files are added.

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

## Offline Qur’an reading

Reading is a separate feature module with its own catalogue and state. It never
reads or writes Tafseer selection, playback state, or the mini player.

```text
assets/data/surahs.json
        │
        ▼
surahsProvider ──► QuranReaderSurahsScreen
        │                  │ selected Surah
        │                  ▼
        │            QuranReaderScreen
        │                  │
        │                  ├── quranSurahProvider(number)
        │                  │        │
        │                  │        ▼
        │                  │   quranSurahRepositoryProvider
        │                  │        │
        │                  │        ▼
        │                  │   QuranSurahAssetDataSource
        │                  │   assets/data/quran/surahs/NNN.json
        │                  │
        │                  ├── quranReaderFontSizeProvider (session only)
        │                  └── quranReaderShowTranslationProvider
        │                           (session only, visible by default)

assets/data/quran/manifest.json
        │
        ▼
quranSourceManifestProvider ──► QuranSourcesScreen
```

- The reader catalogue uses the same 114-Surah metadata as the Tafseer
  catalogue but has independent navigation.
- `QuranReaderScreen` loads only the requested Surah.
  `QuranSurahAssetDataSource` validates the Surah number and JSON shape; the
  manifest is not consulted for reading.
- `QuranSurah` enforces the Basmala mode rules (Ayah for Surah 1, none for
  Surah 9, prefatory for the rest), sequential Ayah numbers, and non-empty
  Arabic and translation values.
- `QuranAyahView` renders the Arabic string exactly as supplied. When translation
  visibility is on, the reader passes a `QuranAyahTranslationView` into the
  Ayah's optional translation slot. It renders `QuranAyah.translation` exactly
  as bundled, left-to-right and selectable, beneath the Arabic text. Inline
  footnote markers such as `[2]` are preserved. `QuranAyah.footnotes` is parsed
  but not displayed.
- The translation view has its own typography and does not follow the Arabic
  text-size control. The reader shows the translation by default and offers a
  session-only show/hide action in the app bar. The choice is shared across
  Surahs and resets after a full restart. Prefatory Basmalas remain
  Arabic-only; Surah 1's Basmala is Ayah 1 and uses its normal translation, and
  Surah 9 has no Basmala.
- The source acknowledgements screen loads `manifest.json` lazily and renders
  the exact versions, notices, licence terms, and links recorded there. The same
  screen is reachable from Settings and the reader.
- Reader font size and translation visibility are session-only Riverpod state;
  they are deliberately not persisted.

### Themes

`themeModeControllerProvider` reads and writes `ThemeMode` through
`SettingsStore`. `main` supplies a `SharedPreferencesSettingsStore` (falling
back to `MemorySettingsStore`), and `TafseerAudioApp` passes the mode to
`MaterialApp` with light and dark themes. Light, Dark, and System are
supported; System is the default.

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

## Qur’an data architecture

Generated data and runtime data are separate outputs of one validated pipeline:

```text
tool/quran_data/sources (reviewed XML/CSV)
        │
        ▼
generate.ps1 ──► tool/quran_data/generated/
        │          manifest.json + surahs/001..114.json
        │
        ▼
validate.ps1 -Mode pre-publish
        │
        ▼
publish.ps1 ──► staging verification
        │           backup existing runtime
        │           swap assets/data/quran
        │           validate.ps1 -Mode post-publish
        │           rollback on failure
        ▼
assets/data/quran/
```

- The generator validates sources and in-memory records before writing, records
  per-Surah SHA-256 values and a content checksum in the manifest, and writes
  validation reports and `checksums.sha256`.
- `validate.ps1` is independent of the generator's control flow: it re-parses
  both sources and re-derives counts, mappings, Basmala rules, markers,
  footnotes, spot checks, and checksums. `-Mode auto` selects post-publish when
  the runtime directory exists.
- Post-publish mode verifies the runtime file set, the runtime manifest, all 114
  per-Surah hashes, byte identity with the generated dataset, and the content
  checksum.
- A failed validation writes `independent-validation.failed.json` and preserves
  the last successful `independent-validation.json`.
- `publish.ps1` verifies generated data, stages and verifies all 115 files,
  backs up the existing runtime to `tool/quran_data/backups/`, swaps in the
  staged copy, and rolls back on any post-swap failure. The backup is retained
  unless `-RemoveBackupOnSuccess` is passed.
- The app reads only `assets/data/quran`; it never reads `tool/` at runtime.
  Commands and safeguards are documented in
  [`tool/quran_data/README.md`](../tool/quran_data/README.md).

## Current lib layout

```text
lib/
├─ main.dart                 # settings/audio initialization and app lifecycle
├─ app.dart                  # MaterialApp, light/dark themes, theme mode
├─ core/
│  ├─ constants/
│  │  ├─ app_constants.dart
│  │  └─ asset_paths.dart
│  ├─ settings/
│  │  └─ settings_store.dart
│  ├─ theme/
│  │  ├─ app_colors.dart
│  │  ├─ app_spacing.dart
│  │  ├─ app_theme.dart
│  │  ├─ app_theme_colors.dart
│  │  └─ app_typography.dart
│  └─ widgets/
│     ├─ brand_mark.dart
│     └─ islamic_pattern.dart
└─ features/
   ├─ home/
   │  └─ presentation/screens/home_screen.dart
   ├─ quran/
   │  ├─ domain/
   │  │  ├─ quran_ayah.dart
   │  │  ├─ quran_repository.dart
   │  │  ├─ quran_source_manifest.dart
   │  │  └─ quran_surah.dart
   │  ├─ data/
   │  │  ├─ asset_quran_repository.dart
   │  │  ├─ quran_manifest_data_source.dart
   │  │  ├─ quran_surah_asset_data_source.dart
   │  │  └─ quran_surah_data_source.dart
   │  └─ presentation/
   │     ├─ providers/
   │     │  ├─ quran_reader_providers.dart
   │     │  ├─ quran_sources_providers.dart
   │     │  └─ quran_surah_providers.dart
   │     ├─ screens/
   │     │  ├─ quran_reader_screen.dart
   │     │  ├─ quran_reader_surahs_screen.dart
   │     │  └─ quran_sources_screen.dart
   │     └─ widgets/quran_ayah_view.dart
   ├─ settings/
   │  └─ presentation/
   │     ├─ providers/theme_providers.dart
   │     └─ screens/settings_screen.dart
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
- `quranSurahProvider(number)` lazily loads one Surah through
  `QuranRepository`; each family instance reads only its own asset.
- `quranReaderFontSizeProvider` holds the reader's session-only Arabic size.
- `quranReaderShowTranslationProvider` holds the reader's session-only English
  translation visibility, defaulting to visible.
- `quranSourceManifestProvider` lazily loads the source manifest for the
  acknowledgements screen.
- `themeModeControllerProvider` reads and persists the Light/Dark/System
  selection through `settingsStoreProvider`. `main` overrides the store with
  SharedPreferences; tests use `MemorySettingsStore`.
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
- Fonts, artwork, Surah metadata, the Qur’an text, bundled English translation
  data, and the temporary sample are local assets.
- The reader and acknowledgements screen read only bundled JSON; they make no
  network requests.
- The audio notification uses local app resources only.

## Testing strategy

- Metadata tests validate all 114 entries, sequential numbering, unique
  numbers, the 6,236 total Ayah count, revelation-place counts, known values,
  and the recorded source.
- The asset-integrity suite verifies that exactly 115 Qur’an assets are bundled,
  that every Surah file matches its manifest SHA-256, and that the content
  checksum recomputed from the bundled files matches the manifest. It also
  checks known SHA-256 vectors and rejects raw XML/CSV sources in the bundle.
- Reader tests cover the 114-Surah reading catalogue, loading and error states,
  Basmala modes, exact Arabic text, separate Ayah numbers, Sajdah indicators,
  default-visible English translation, show/hide behavior, translation and
  footnote-marker preservation, session persistence across Surahs, session
  font-size controls, source acknowledgements, and isolation from playback
  state.
- Theme tests cover Light, Dark, and System, persistence, and following platform
  brightness.
- Unit tests cover search normalization, filtering, repository behavior, JSON
  parsing, and Riverpod state.
- App-shell widget tests cover the three destinations, the default Qur’an tab,
  tab switching without route pushes, retained tab state, the navigation bar
  being covered by detail routes, and back-to-Qur’an behaviour.
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

- [`README.md`](../README.md) — project status, setup, reader and catalogue
  behaviour, data pipeline commands, audio engine, roadmap, and distribution
  note.
- [`assets/data/README.md`](../assets/data/README.md) — bundled Qur’an data
  layout, field definitions, provenance, and integrity checks.
- [`tool/quran_data/README.md`](../tool/quran_data/README.md) — source
  acquisition, generation, validation, publishing, and rollback workflow.
- [`assets/audio/README.md`](../assets/audio/README.md) — audio asset layout
  and instructions for adding real Surah recordings.
