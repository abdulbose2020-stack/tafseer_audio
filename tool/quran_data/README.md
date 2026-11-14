# Qur’an data pipeline

This directory owns the offline Qur’an dataset that is bundled at
[`assets/data/quran`](../../assets/data/quran). The generated files and the
published runtime files are outputs: do not edit them by hand.

The pipeline is reproducible from the reviewed sources in
[`sources/`](sources), and every stage records hashes and validation results so
the published data can be checked independently.

## Layout

```text
tool/quran_data/
├─ sources/                  Reviewed source XML/CSV files
├─ generator/
│  ├─ fetch-sources.ps1      Acquires and records the reviewed sources
│  ├─ generate.ps1           Generates and validates the 114 Surah files
│  ├─ validate.ps1           Independent pre-/post-publish validation
│  ├─ publish.ps1            Stages, backs up, swaps, and verifies runtime data
│  └─ quran_data_lib.psm1    Shared UTF-8, JSON, and SHA-256 helpers
├─ generated/                manifest.json and 114 generated Surah files
├─ validation/               Reports, spot checks, and checksums
├─ backups/                  Created by publish.ps1 (operational, not source)
└─ publish-work/             Staging area used by publish.ps1
```

All scripts derive the project root from their own location, so they can be run
from any working directory. The commands below are written for PowerShell 5.1
and are run from the project root.

## Sources and attribution

| Content | Source | Version | Licence |
| --- | --- | --- | --- |
| Arabic Qur’an text | Tanzil Quran Text (Uthmani) | 1.1 | Creative Commons Attribution 3.0 |
| English translation | QuranEnc `english_saheeh`, Noor International Center | 1.1.2 (`v1.1.2-csv.1`) | QuranEnc Terms and Policies |
| Surah catalogue | Tanzil Quran Metadata; cross-checked with the Quran.com Chapters API | — | CC BY |

The required copyright blocks, translation information, usage terms, and source
hashes are stored in [`generated/manifest.json`](generated/manifest.json) and
shown in the app under **Settings → Qur’an sources**. The bundled data layout
and field definitions are documented in
[`assets/data/README.md`](../../assets/data/README.md).

## Workflow

### 1. Acquire the reviewed sources

Only run this when intentionally updating to a reviewed upstream version.
`fetch-sources.ps1` refuses to overwrite existing source files and fails before
writing anything if the upstream version differs from the expected reviewed
version.

```powershell
powershell -ExecutionPolicy Bypass -File tool/quran_data/generator/fetch-sources.ps1
```

It writes the source files under `sources/` and the acquisition record to
`validation/source-acquisition.json`.

### 2. Generate the dataset

```powershell
powershell -ExecutionPolicy Bypass -File tool/quran_data/generator/generate.ps1
```

The generator validates the sources and every in-memory record before writing.
It produces:

- [`generated/manifest.json`](generated/manifest.json) — schema, provenance,
  totals, Basmala summary, per-Surah hashes, content checksum, and validation
  summary.
- `generated/surahs/001.json` … `generated/surahs/114.json`.
- `validation/validation-report.json` and `validation-report.md`.
- `validation/spot-checks.json` and `validation/checksums.sha256`.

It does not modify `assets/data/quran` or `pubspec.yaml`. Existing generated
files with different content are not replaced unless `-Force` is supplied.
`-GeneratedAtUtc` can pin the manifest timestamp.

### 3. Validate before publishing

```powershell
powershell -ExecutionPolicy Bypass -File tool/quran_data/generator/validate.ps1 -Mode pre-publish
```

`validate.ps1` is independent of the generator: it re-parses the original XML
and CSV, recomputes counts and hashes, and verifies the manifest, the 114
generated Surah files, the content checksum, the checksum file, and the
generation report. It does not modify source or generated data.

### 4. Publish to the Flutter runtime assets

```powershell
powershell -ExecutionPolicy Bypass -File tool/quran_data/generator/publish.ps1
```

`publish.ps1` performs the following steps:

1. Runs `validate.ps1 -Mode pre-publish`.
2. Re-reads the generated manifest and verifies every generated Surah SHA-256
   and the content checksum.
3. Copies the output into `publish-work/staging-<run-id>/` and verifies all 115
   files there.
4. Moves the existing `assets/data/quran` to
   `tool/quran_data/backups/quran-<run-id>/`.
5. Swaps the verified staging copy into `assets/data/quran`.
6. Runs `validate.ps1 -Mode post-publish`, which verifies the runtime file set,
   the runtime manifest and all 114 per-Surah hashes, byte identity with the
   generated dataset, and the recomputed content checksum.
7. Restores the backup if any step after the swap fails.

The previous runtime backup is kept by default. Pass
`-RemoveBackupOnSuccess` only when the published result has been confirmed:

```powershell
powershell -ExecutionPolicy Bypass -File tool/quran_data/generator/publish.ps1 -RemoveBackupOnSuccess
```

Staging and work directories are cleaned after success or failure. If there was
no previous runtime directory, a failed publish removes the newly installed
copy instead of restoring a backup.

### 5. Validate the published assets

```powershell
powershell -ExecutionPolicy Bypass -File tool/quran_data/generator/validate.ps1 -Mode post-publish
```

`-Mode auto` is the default: it selects post-publish validation when
`assets/data/quran` exists, and pre-publish validation otherwise. The explicit
modes are useful in CI and when checking a fresh checkout.

## Validation reports

- Success: `validation/independent-validation.json`.
- Failure: `validation/independent-validation.failed.json`.
- A failed run never overwrites a previously successful report. The report
  records the requested and resolved mode, the runtime result, and every check.

## Integrity guarantees

- The runtime bundle contains exactly 115 files: `manifest.json` plus the 114
  Surah JSON files.
- Every Surah file is covered by a lowercase SHA-256 digest in the manifest.
- The overall content checksum is SHA-256 over each sorted file name
  (`001.json` … `114.json`) followed by its SHA-256 digest, each followed by a
  newline. Timestamps and other manifest metadata are excluded.
- `test/assets/quran_assets_test.dart` independently recomputes the per-file
  hashes and content checksum from the bundled Flutter assets, and checks the
  asset count and paths. It fails if a file is missing, modified, or extra.
- The generator, validator, publisher, and asset test all use the same
  convention: SHA-256 over exact file bytes, except the content checksum, which
  hashes the UTF-8 bytes of the canonical `file name`, digest, newline
  sequence.
