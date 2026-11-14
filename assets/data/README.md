# Bundled Qur’an data

This directory contains the offline data that ships with the app:

- `surahs.json` — the 114-Surah catalogue used by the Tafseer and reading
  catalogues.
- `quran/manifest.json` and `quran/surahs/001.json` … `114.json` — the Arabic
  Qur’an text, bundled English translation, footnotes, and Sajdah markers.

All data is read from local Flutter assets. Nothing is downloaded at runtime.

## Surah catalogue

`surahs.json` contains the complete catalogue of all 114 Surahs.

### Source

- **Primary source:** [Tanzil Quran Metadata](https://tanzil.net/res/text/metadata/quran-data.xml)
- **License:** CC BY
- **Copyright:** (C) 2008-2009 Tanzil.info
- **Cross-checked with:** [Quran.com Chapters API](https://api.quran.com/api/v4/chapters)

The two sources agree on all 114 Surah numbers, Arabic names, Ayah counts, and
revelation places. Tanzil is used consistently for the transliterations and
English meanings. The total Ayah count is 6,236: 86 Makki and 28 Madani
Surahs.

### Fields

- `number` — Mushaf position, 1 to 114
- `arabic_name` — Arabic Surah name
- `transliteration` — Tanzil Latin transliteration
- `english_meaning` — English translation of the name
- `ayah_count` — number of Ayahs
- `revelation_place` — `makki` or `madani`

The `source` object at the top of the file records provenance. The app reads
the catalogue from this bundled asset, so no network access is required.

## Qur’an reader data

`quran/` contains 115 files: one manifest and one JSON file per Surah.

### Manifest

`quran/manifest.json` records:

- `schema_version`, `dataset_version`, and `generated_at_utc`
- the generator entry point and acquisition record
- `sources.arabic`, `sources.english`, and `sources.catalogue`, including
  versions, source hashes, licences, and required notices
- totals for Surahs, Ayahs, Arabic records, translations, footnotes, and
  markers
- the Basmala summary
- `surahs`: 114 entries with `number`, `ayah_count`, `basmala_mode`, `file`, and
  `sha256`
- `content_checksum`: the SHA-256 value, algorithm, scope, and file count
- a validation summary

The app reads the manifest only when the source acknowledgements screen is
opened; the reader does not need it to display a Surah.

### Surah files

Each `quran/surahs/NNN.json` contains:

- `surah_number` — Mushaf position, 1 to 114
- `basmala_mode` — `ayah` (Surah 1), `prefatory` (the Basmala is shown before
  Ayah 1), or `none` (Surah 9)
- `basmala_text` — the exact prefatory Basmala, or `null`
- `ayahs` — the Ayahs in order, each with:
  - `number` — position within the Surah, starting at 1
  - `arabic` — the exact Tanzil Uthmani text
  - `translation` — the exact QuranEnc English translation
  - `footnotes` — the complete QuranEnc footnote text, or an empty string
  - `sajdah` — whether the Ayah includes a Sajdah

The reader displays the Arabic text, Ayah numbers, Basmala, and Sajdah
indicator, plus the bundled English translation beneath each Ayah by default.
Translation display can be shown or hidden for the current session from the
reader app bar; that choice is not persisted. The English text is rendered
exactly as bundled, including inline footnote markers such as `[2]`, but the
footnote text itself is not displayed. The prefatory Basmala has no English
translation record and remains Arabic-only. Surah 1's Basmala is Ayah 1 and uses
that Ayah's normal translation, and Surah 9 has no Basmala.

### Source and attribution

- **Arabic text:** Tanzil Quran Text (Uthmani, Version 1.1), copyright
  (C) 2007-2026 Tanzil Project, licensed under
  [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/).
- **English translation:** QuranEnc `english_saheeh` (Version 1.1.2,
  `v1.1.2-csv.1`), published by Noor International Center through
  [QuranEnc](https://quranenc.com/). Attribution: "Noor International Center,
  through QuranEnc."
- **Surah catalogue:** Tanzil Quran Metadata, copyright (C) 2008-2009
  Tanzil.info, licensed under CC BY; cross-checked with the Quran.com Chapters
  API.

The complete copyright blocks, translation information, usage terms, and source
hashes are stored in the manifest and shown in the app under **Settings →
Qur’an sources**.

### Integrity

- Every Surah file is covered by a lowercase SHA-256 digest in the manifest.
- `content_checksum` is SHA-256 over each sorted Surah file name
  (`001.json` … `114.json`) followed by its digest, each followed by a newline.
  Timestamps are excluded, so regenerating the manifest metadata does not
  change the content checksum.
- [`test/assets/quran_assets_test.dart`](../../test/assets/quran_assets_test.dart)
  independently recomputes the 114 hashes and the content checksum from the
  bundled Flutter assets. It also checks that exactly 115 Qur’an files are
  declared and that no raw XML/CSV sources are bundled. A missing, modified, or
  unexpected file fails the test.
- Source acquisition, generation, validation, publishing, and rollback are
  documented in [`tool/quran_data/README.md`](../../tool/quran_data/README.md).

## Validation

Automated tests verify:

- exactly 114 catalogue entries
- sequential numbering from 1 to 114
- unique Surah numbers
- total Ayah count of 6,236
- 86 Makki and 28 Madani Surahs
- known Surah values and non-empty metadata
- JSON parsing and repository behaviour
- all 114 Qur’an Surah assets, their manifest SHA-256 values, and the content
  checksum
