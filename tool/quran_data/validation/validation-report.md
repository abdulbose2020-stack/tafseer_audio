# Qur'an Data Generation and Validation Report

- Status: **PASSED**
- Generated at (UTC): `2026-11-13T16:48:38Z`
- Schema version: `1.0.0`; dataset version: `1.0.0`
- Acquisition record: `validation/source-acquisition.json`

## Source provenance

| Source | Version | File | Size (bytes) | SHA-256 |
| --- | --- | --- | ---: | --- |
| Tanzil Uthmani | 1.1 | `sources/tanzil-uthmani-v1.1.xml` | 1541984 | `c5052534d63d3856ce25413ff464d0b609f90169a202a1615aa8707efec81244` |
| QuranEnc english_saheeh | 1.1.2 (v1.1.2-csv.1) | `sources/quranenc-english_saheeh-v1.1.2.csv` | 1146154 | `6029cb17db0365e93856f2fec15561db64f3609dba90e28c72358ce71cacbc5e` |

Tanzil: Copyright (C) 2007-2026 Tanzil Project. Licence: Creative Commons Attribution 3.0.
QuranEnc attribution: Noor International Center, through QuranEnc. Licence: QuranEnc Terms and Policies (https://quranenc.com/en/home/about).

## Totals

- Surahs: 114
- Ayahs: 6236
- Arabic records: 6236
- Translation records: 6236
- Footnote records: 6236 (non-empty: 1613; embedded newlines: 225; quotes: 294)
- Sajdah Ayahs: 15
- Pause marks: 4366; rub-el-hizb marks: 199; tatweel characters: 6736

## Sajdah locations

`7:206`, `13:15`, `16:50`, `17:109`, `19:58`, `22:18`, `22:77`, `25:60`, `27:26`, `32:15`, `38:24`, `41:38`, `53:62`, `84:21`, `96:19`

## Validation checks

| ID | Result | Description | Details |
| --- | --- | --- | --- |
| `sources.arabic.integrity` | PASS | Downloaded source file matches the acquisition record (size and SHA-256). | size=1541984 (expected 1541984); sha256=c5052534d63d3856ce25413ff464d0b609f90169a202a1615aa8707efec81244 (expected c5052534d63d3856ce25413ff464d0b609f90169a202a1615aa8707efec81244) |
| `sources.arabic.no_bom` | PASS | Source file has no UTF-8 BOM. | C:\Users\X390\Documents\FlutterProjects\tafseer_audio\tool\quran_data\sources\tanzil-uthmani-v1.1.xml |
| `sources.english.integrity` | PASS | Downloaded source file matches the acquisition record (size and SHA-256). | size=1146154 (expected 1146154); sha256=6029cb17db0365e93856f2fec15561db64f3609dba90e28c72358ce71cacbc5e (expected 6029cb17db0365e93856f2fec15561db64f3609dba90e28c72358ce71cacbc5e) |
| `sources.english.no_bom` | PASS | Source file has no UTF-8 BOM. | C:\Users\X390\Documents\FlutterProjects\tafseer_audio\tool\quran_data\sources\quranenc-english_saheeh-v1.1.2.csv |
| `sources.arabic.surah_count` | PASS | Tanzil XML contains exactly 114 Surahs. | found 114 |
| `sources.arabic.ayah_count` | PASS | Tanzil XML contains exactly 6,236 Ayahs. | found 6236 |
| `sources.english.row_count` | PASS | QuranEnc CSV contains exactly 6,236 data rows. | found 6236 |
| `sources.versions` | PASS | Acquisition metadata and source notices identify the reviewed versions. | Tanzil=1.1 (2021-02-12); QuranEnc=1.1.2 (v1.1.2-csv.1); last_update=2025-06-24T13:37:27Z |
| `sources.arabic.copyright_notice` | PASS | Tanzil copyright block is present and includes its preservation and licence notices. | Copyright (C) 2007-2026 Tanzil Project |
| `sources.english.source_notice` | PASS | QuranEnc preamble is present and includes its required preservation notice, ID, URL and version. | v1.1.2-csv.1 |
| `sources.english.attribution` | PASS | Official QuranEnc attribution is recorded without an unconfirmed translator claim. | Noor International Center, through QuranEnc. |
| `sources.english.license` | PASS | QuranEnc Terms and Policies are recorded with their official URL. | https://quranenc.com/en/home/about |
| `sources.encoding` | PASS | Tanzil XML declares UTF-8 and both sources are valid UTF-8 without BOM. | UTF-8, no BOM |
| `sources.english.record_order` | PASS | QuranEnc IDs run 1..6236 and map from 1:1 through 114:6. | first=1:1:1; last=6236:114:6 |
| `sources.arabic.surah_sequence` | PASS | Surah numbers are sequential from 1 to 114. | 1..114 |
| `sources.arabic.ayah_sequence` | PASS | Ayah numbers are sequential from 1 within every Surah. |  |
| `sources.arabic.no_duplicate_surahs` | PASS | Tanzil XML has no duplicate Surah numbers. |  |
| `catalogue.surah_count` | PASS | Existing assets/data/surahs.json contains 114 Surahs. | found 114 |
| `catalogue.total_ayahs` | PASS | Existing assets/data/surahs.json totals 6,236 Ayahs. | found 6236 |
| `catalogue.sequence` | PASS | Catalogue Surah numbers are complete and unique. |  |
| `mapping.one_to_one` | PASS | Every Arabic Ayah has exactly one English record and vice versa. | 6,236 matched records |
| `content.arabic_nonempty` | PASS | No generated Arabic record is empty. |  |
| `content.translation_nonempty` | PASS | No generated English translation record is empty. |  |
| `content.arabic_controls` | PASS | Arabic records contain no NUL, tab, CR or LF characters. |  |
| `content.translation_controls` | PASS | Translation and footnote records contain no NUL characters. |  |
| `content.arabic_exact` | PASS | All 6,236 generated Arabic strings match the Tanzil source exactly (ordinal comparison). |  |
| `content.translation_exact` | PASS | All 6,236 generated translations match the QuranEnc CSV exactly (ordinal comparison). |  |
| `content.footnotes_exact` | PASS | All 6,236 raw footnote strings match the QuranEnc CSV exactly (ordinal comparison). |  |
| `content.footnote_counts` | PASS | Raw footnotes are retained, including embedded newlines and quotation marks. | records=6236; non-empty=1613; with newlines=225; with quotes=294 |
| `content.catalogue_counts` | PASS | Every Surah Ayah count matches assets/data/surahs.json. |  |
| `json.in_memory_parse` | PASS | Every in-memory Surah JSON document parses successfully. |  |
| `json.in_memory_content` | PASS | Every in-memory Surah JSON round-trip preserves the generated values exactly. |  |
| `totals.surahs` | PASS | Generated dataset contains exactly 114 Surahs. | found 114 |
| `totals.ayahs` | PASS | Generated dataset contains exactly 6,236 Ayahs. | found 6236 |
| `totals.arabic_records` | PASS | Generated dataset contains exactly 6,236 Arabic records. | found 6236 |
| `totals.translation_records` | PASS | Generated dataset contains exactly 6,236 English translation records. | found 6236 |
| `basmala.attribute_count` | PASS | Tanzil source contains exactly 112 prefatory Basmala attributes, all on first Ayahs. | attributes=112; non-first= |
| `basmala.mode_counts` | PASS | Basmala modes are ayah=1, prefatory=112, none=1. | ayah=1; prefatory=112; none=1 |
| `basmala.surah_1` | PASS | Surah 1 uses mode ayah; its first Ayah is the source Basmala and is not duplicated. | Surah 1:1 equals the standard prefatory Basmala from Surah 2. |
| `basmala.surah_9` | PASS | Surah 9 uses mode none and has no prefatory Basmala. | Surah 9 has no Basmala attribute and its first Ayah does not start with the Basmala. |
| `basmala.not_prepended` | PASS | No prefatory Basmala is prepended to the first Ayah text. |  |
| `basmala.special_95_97` | PASS | Surahs 95 and 97 preserve their distinct Basmala spelling (extra shadda). | 95_len=40; 97_len=40; standard_len=39; 95_cp1=U+0651; standard_cp1=U+0650 |
| `sajdah.locations` | PASS | Exactly the 15 known Sajdah locations are marked and no others. | found: 7:206, 13:15, 16:50, 17:109, 19:58, 22:18, 22:77, 25:60, 27:26, 32:15, 38:24, 41:38, 53:62, 84:21, 96:19 |
| `sajdah.markers` | PASS | Each Sajdah Ayah contains exactly one U+06E9 mark and no other Ayah contains one. |  |
| `marks.source_totals` | PASS | Pause, rub-el-hizb, Sajdah and tatweel marker totals match the source. | pause=4366; rub=199; sajdah=15; tatweel=6736 |
| `marks.present` | PASS | Pause marks, rub-el-hizb signs and tatweel characters are present in the generated Arabic. | pause=4366; rub=199; tatweel=6736 |
| `generated.file_count` | PASS | Exactly 114 Surah JSON files exist with the expected names. | files=114 |
| `generated.file_hashes` | PASS | Every written Surah file has the recorded SHA-256 checksum. |  |
| `generated.json_parse` | PASS | Every written Surah JSON file parses successfully. |  |
| `generated.schema` | PASS | Every written Surah file has the required schema, types and Ayah shape. |  |
| `generated.ayah_sequence` | PASS | Every written Surah has sequential Ayah numbering. |  |
| `generated.arabic_exact` | PASS | Every written Arabic string matches the Tanzil source exactly. |  |
| `generated.translation_exact` | PASS | Every written translation matches the QuranEnc CSV exactly. |  |
| `generated.footnotes_exact` | PASS | Every written raw footnote string matches the QuranEnc CSV exactly. |  |
| `generated.sajdah_exact` | PASS | Every written sajdah flag matches the presence of the U+06E9 source mark. |  |
| `generated.basmala_exact` | PASS | Every written Basmala mode and text matches the source-derived values. |  |
| `generated.content_checksum` | PASS | Per-Surah checksums reproduce the pre-write content checksum. | actual=140a0c97a22bcb5c1227a5a7f05690ea498ec5d4c0de33f8c1270c8a91ae5ce6; expected=140a0c97a22bcb5c1227a5a7f05690ea498ec5d4c0de33f8c1270c8a91ae5ce6 |
| `spot.1_1` | PASS | Spot check 1:1 matches the original Arabic and English sources. | arabic=True; translation=True; footnotes=True; sajdah=True; starts_with_basmala=True; basmala_prepended=False |
| `spot.1_2` | PASS | Spot check 1:2 matches the original Arabic and English sources. | arabic=True; translation=True; footnotes=True; sajdah=True; starts_with_basmala=False; basmala_prepended=False |
| `spot.2_1` | PASS | Spot check 2:1 matches the original Arabic and English sources. | arabic=True; translation=True; footnotes=True; sajdah=True; starts_with_basmala=False; basmala_prepended=False |
| `spot.9_1` | PASS | Spot check 9:1 matches the original Arabic and English sources. | arabic=True; translation=True; footnotes=True; sajdah=True; starts_with_basmala=False; basmala_prepended=False |
| `spot.114_6` | PASS | Spot check 114:6 matches the original Arabic and English sources. | arabic=True; translation=True; footnotes=True; sajdah=True; starts_with_basmala=False; basmala_prepended=False |
| `spot_checks.all_match` | PASS | All required spot checks pass against the original sources. |  |
| `guard.catalogue_unchanged` | PASS | assets/data/surahs.json was not modified. | sha256=82f64df268291d5c803f60fdc1fac5235362f857139a436cc793e38ca9ffd59f |
| `guard.pubspec_unchanged` | PASS | pubspec.yaml was not modified. | sha256=c1b7d03463cfeb0a2e3822d877ef05682b787805e8975ff4abd09019a9485550 |
| `guard.no_app_quran_assets` | PASS | No files were added under assets/data/quran/. | exists=False |
| `generated.manifest_parse` | PASS | Generated manifest parses as JSON. | length=30176 |
| `generated.manifest_structure` | PASS | Manifest contains schema, timestamp, sources, totals, Basmala summary, Surah entries, checksums and validation. | required top-level fields present |
| `generated.manifest_totals` | PASS | Manifest totals are 114 Surahs, 6,236 Ayahs, 6,236 Arabic records, 6,236 translations and 15 Sajdah Ayahs. |  |
| `generated.manifest_surahs` | PASS | Manifest per-Surah counts, file names and SHA-256 checksums match the generated files. |  |
| `generated.manifest_checksums` | PASS | Manifest content checksum matches the post-write per-Surah checksums. | value=140a0c97a22bcb5c1227a5a7f05690ea498ec5d4c0de33f8c1270c8a91ae5ce6 |
| `generated.manifest_notices` | PASS | Manifest preserves the exact Tanzil copyright block, QuranEnc preamble, attribution and Terms and Policies. | notices compared with exact ordinal equality |
| `generated.manifest_readback` | PASS | Written manifest re-parses and preserves its required metadata. | sha256=752b56053cbf717d9454b7115b4766512b53a40d84f4696e546b70aa488b31ce; size=30176 |
| `generated.json_files_parse` | PASS | All 115 generated JSON files (114 Surahs plus the manifest) parse successfully. | 114 Surah files + manifest |

## Spot checks

| Key | Arabic | Translation | Footnotes | Sajdah | Starts with Basmala | Basmala prepended |
| --- | --- | --- | --- | --- | --- | --- |
| `1:1` | True | True | True | True | True | False |
| `1:2` | True | True | True | True | False | False |
| `2:1` | True | True | True | True | False | False |
| `9:1` | True | True | True | True | False | False |
| `114:6` | True | True | True | True | False | False |

## Generated output

- Surah JSON files: 114
- Surah files total size: 3167018 bytes
- Manifest: `generated/manifest.json` (30176 bytes, SHA-256 `752b56053cbf717d9454b7115b4766512b53a40d84f4696e546b70aa488b31ce`)
- Total generated size: 3197194 bytes
- Content checksum (timestamps excluded): `140a0c97a22bcb5c1227a5a7f05690ea498ec5d4c0de33f8c1270c8a91ae5ce6`

## Read-only guard

- `assets/data/surahs.json` unchanged: True (SHA-256 `82f64df268291d5c803f60fdc1fac5235362f857139a436cc793e38ca9ffd59f`)
- `pubspec.yaml` unchanged: True (SHA-256 `c1b7d03463cfeb0a2e3822d877ef05682b787805e8975ff4abd09019a9485550`)
- `assets/data/quran/` created by this run: False

## Notes

- The original XML and CSV remain unmodified under `sources/`; they are not bundled as Flutter assets.
- The English attribution is the official QuranEnc attribution; no unconfirmed translator identity is asserted.
- Surah JSON files contain no generation timestamp. The manifest timestamp is excluded from the content checksum.
- An independent verification pass is provided by `generator/validate.ps1` and writes `validation/independent-validation.json`.
- This run does not implement or modify reader UI, audio, Tafseer catalogue, navigation, theme, settings or `pubspec.yaml`.
