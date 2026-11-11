# Surah metadata

`surahs.json` contains the complete catalogue of all 114 Surahs.

## Source

- **Primary source:** [Tanzil Quran Metadata](https://tanzil.net/res/text/metadata/quran-data.xml)
- **License:** CC BY
- **Copyright:** (C) 2008-2009 Tanzil.info
- **Cross-checked with:** [Quran.com Chapters API](https://api.quran.com/api/v4/chapters)

The two sources agree on all 114 Surah numbers, Arabic names, Ayah counts, and
revelation places. Tanzil is used consistently for the transliterations and
English meanings. The total Ayah count is 6,236: 86 Makki and 28 Madani
Surahs.

## Fields

- `number` — Mushaf position, 1 to 114
- `arabic_name` — Arabic Surah name
- `transliteration` — Tanzil Latin transliteration
- `english_meaning` — English translation of the name
- `ayah_count` — number of Ayahs
- `revelation_place` — `makki` or `madani`

The `source` object at the top of the file records provenance. The app reads
the catalogue from this bundled asset, so no network access is required.

## Validation

Automated tests verify:

- exactly 114 entries
- sequential numbering from 1 to 114
- unique Surah numbers
- total Ayah count of 6,236
- 86 Makki and 28 Madani Surahs
- known Surah values and non-empty metadata
- JSON parsing and repository behavior
