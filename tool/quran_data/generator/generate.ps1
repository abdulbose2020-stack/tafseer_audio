# Generates the validated Qur'an dataset from the acquired source files.
# Run from anywhere:
#   powershell -ExecutionPolicy Bypass -File tool/quran_data/generator/generate.ps1
#
# The script validates the source files and all in-memory records before writing
# generated output. It never repairs source data. Existing generated files with
# different content are not overwritten unless -Force is supplied.

[CmdletBinding()]
param(
    [string]$GeneratedAtUtc = '',
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'quran_data_lib.psm1') -Force

$quranDataRoot = Split-Path -Parent $PSScriptRoot
$toolRoot = Split-Path -Parent $quranDataRoot
$projectRoot = Split-Path -Parent $toolRoot

$sourcesDir = Join-Path $quranDataRoot 'sources'
$generatedDir = Join-Path $quranDataRoot 'generated'
$surahsOutDir = Join-Path $generatedDir 'surahs'
$validationDir = Join-Path $quranDataRoot 'validation'
$acquisitionPath = Join-Path $validationDir 'source-acquisition.json'
$manifestPath = Join-Path $generatedDir 'manifest.json'
$cataloguePath = Join-Path $projectRoot 'assets\data\surahs.json'
$pubspecPath = Join-Path $projectRoot 'pubspec.yaml'
$appQuranDir = Join-Path $projectRoot 'assets\data\quran'

if ([string]::IsNullOrEmpty($GeneratedAtUtc)) {
    if (-not [string]::IsNullOrEmpty($env:QURAN_DATA_GENERATED_AT)) {
        $GeneratedAtUtc = $env:QURAN_DATA_GENERATED_AT
    }
    else {
        $GeneratedAtUtc = Get-UtcTimestamp
    }
}

if ($GeneratedAtUtc -notmatch '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$') {
    throw 'GeneratedAtUtc must look like 2026-11-13T12:34:56Z.'
}

$catalogueHashBefore = Get-Sha256Hex -Path $cataloguePath
$pubspecHashBefore = ''
if ([System.IO.File]::Exists($pubspecPath)) {
    $pubspecHashBefore = Get-Sha256Hex -Path $pubspecPath
}
$appQuranDirExistedBefore = [System.IO.Directory]::Exists($appQuranDir)

$script:checks = New-Object System.Collections.ArrayList
$script:failures = New-Object System.Collections.ArrayList

function Add-Check {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id,
        [Parameter(Mandatory = $true)]
        [string]$Category,
        [Parameter(Mandatory = $true)]
        [string]$Description,
        [Parameter(Mandatory = $true)]
        [bool]$Passed,
        [string]$Details = ''
    )

    $check = [ordered]@{
        id = $Id
        category = $Category
        description = $Description
        passed = $Passed
        details = $Details
    }

    [void]$script:checks.Add($check)
    if (-not $Passed) {
        [void]$script:failures.Add($check)
    }
}

function Write-FailureReport {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Stage,
        [string]$Message = ''
    )

    $report = [ordered]@{
        status = 'failed'
        stage = $Stage
        message = $Message
        generated_at_utc = $GeneratedAtUtc
        checks_total = $script:checks.Count
        checks_passed = @($script:checks | Where-Object { $_.passed }).Count
        checks_failed = $script:failures.Count
        checks = $script:checks.ToArray()
    }

    $path = Join-Path $validationDir 'generation-failure.json'
    Write-Utf8TextFile -Path $path -Text ((ConvertTo-JsonText -Value $report) + "`n")
}

function Assert-NoFailures {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Stage
    )

    if ($script:failures.Count -gt 0) {
        Write-FailureReport -Stage $Stage -Message ("$($script:failures.Count) validation check(s) failed.")
        $summary = (@($script:failures | Select-Object -First 8 | ForEach-Object {
            '{0}: {1}' -f $_.id, $_.details
        }) -join ' | ')
        throw "Validation failed at '$Stage'. $summary"
    }
}

function Test-Utf8Bom {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    return (
        $bytes.Length -ge 3 -and
        $bytes[0] -eq 0xEF -and
        $bytes[1] -eq 0xBB -and
        $bytes[2] -eq 0xBF
    )
}

function Get-TextFileLength {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return [long](Get-Item -LiteralPath $Path).Length
}

function Format-KeyList {
    param(
        [System.Collections.ArrayList]$Items,
        [int]$Maximum = 5
    )

    if ($null -eq $Items -or $Items.Count -eq 0) {
        return ''
    }

    $sample = @($Items | Select-Object -First $Maximum) -join ', '
    if ($Items.Count -gt $Maximum) {
        return ('{0} (and {1} more)' -f $sample, ($Items.Count - $Maximum))
    }
    return $sample
}

try {
    # ---------------------------------------------------------------
    # Provenance and source integrity
    # ---------------------------------------------------------------

    if (-not [System.IO.File]::Exists($acquisitionPath)) {
        throw "Missing acquisition record: $acquisitionPath. Run fetch-sources.ps1 first."
    }

    $acquisition = (Read-Utf8TextFile -Path $acquisitionPath) | ConvertFrom-Json
    if ($null -eq $acquisition.arabic -or $null -eq $acquisition.english) {
        throw "Acquisition record '$acquisitionPath' is missing arabic or english metadata."
    }

    $arabicRelative = ([string]$acquisition.arabic.file).Replace('/', '\')
    $englishRelative = ([string]$acquisition.english.file).Replace('/', '\')
    $arabicPath = Join-Path $quranDataRoot $arabicRelative
    $englishPath = Join-Path $quranDataRoot $englishRelative

    foreach ($source in @(
        @{ Name = 'arabic'; Path = $arabicPath; Meta = $acquisition.arabic },
        @{ Name = 'english'; Path = $englishPath; Meta = $acquisition.english }
    )) {
        if (-not [System.IO.File]::Exists($source.Path)) {
            throw "Source file is missing: $($source.Path)"
        }

        $actualSize = Get-TextFileLength -Path $source.Path
        $actualHash = Get-Sha256Hex -Path $source.Path
        $expectedSize = [long]$source.Meta.size_bytes
        $expectedHash = [string]$source.Meta.sha256

        Add-Check -Id ("sources.{0}.integrity" -f $source.Name) -Category 'sources' -Description 'Downloaded source file matches the acquisition record (size and SHA-256).' -Passed (
            $actualSize -eq $expectedSize -and (Test-OrdinalEqual -Left $actualHash -Right $expectedHash)
        ) -Details (
            'size={0} (expected {1}); sha256={2} (expected {3})' -f $actualSize, $expectedSize, $actualHash, $expectedHash
        )

        Add-Check -Id ("sources.{0}.no_bom" -f $source.Name) -Category 'sources' -Description 'Source file has no UTF-8 BOM.' -Passed (-not (Test-Utf8Bom -Path $source.Path)) -Details $source.Path
    }

    Assert-NoFailures -Stage 'source-integrity'

    # ---------------------------------------------------------------
    # Parse the original sources
    # ---------------------------------------------------------------

    $xml = Read-TanzilXml -Path $arabicPath
    $csv = Read-QuranEncCsv -Path $englishPath

    $xmlHeader = Read-Utf8TextFile -Path $arabicPath
    $xmlHeader = $xmlHeader.Substring(0, [System.Math]::Min(200, $xmlHeader.Length))
    $xmlDeclaresUtf8 = ($xmlHeader -match 'encoding="utf-8"')

    $totalSourceAyahs = 0
    foreach ($sura in $xml.Suras) {
        $totalSourceAyahs += $sura.Ayahs.Count
    }

    Add-Check -Id 'sources.arabic.surah_count' -Category 'sources' -Description 'Tanzil XML contains exactly 114 Surahs.' -Passed ($xml.Suras.Count -eq 114) -Details ("found {0}" -f $xml.Suras.Count)
    Add-Check -Id 'sources.arabic.ayah_count' -Category 'sources' -Description 'Tanzil XML contains exactly 6,236 Ayahs.' -Passed ($totalSourceAyahs -eq 6236) -Details ("found {0}" -f $totalSourceAyahs)
    Add-Check -Id 'sources.english.row_count' -Category 'sources' -Description 'QuranEnc CSV contains exactly 6,236 data rows.' -Passed ($csv.Rows.Count -eq 6236) -Details ("found {0}" -f $csv.Rows.Count)

    $expectedTanzilVersion = '1.1'
    $expectedQuranEncVersion = '1.1.2'
    $expectedQuranEncRevision = 'v1.1.2-csv.1'
    $expectedQuranEncLastUpdate = 1750772247
    $expectedAttribution = 'Noor International Center, through QuranEnc.'
    $expectedQuranEncTermsPrefix = 'Contents of the translations can be downloaded and re-published'

    Add-Check -Id 'sources.versions' -Category 'sources' -Description 'Acquisition metadata and source notices identify the reviewed versions.' -Passed (
        [string]$acquisition.arabic.version -eq $expectedTanzilVersion -and
        [string]$acquisition.english.version -eq $expectedQuranEncVersion -and
        [string]$acquisition.english.revision -eq $expectedQuranEncRevision -and
        [long]$acquisition.english.last_update_unix -eq $expectedQuranEncLastUpdate -and
        $xml.CopyrightBlock -match ('Version\s+' + [regex]::Escape($expectedTanzilVersion)) -and
        $csv.InfoBlock -match [regex]::Escape($expectedQuranEncRevision)
    ) -Details (
        'Tanzil={0} ({1}); QuranEnc={2} ({3}); last_update={4}' -f $acquisition.arabic.version, $acquisition.arabic.release_date, $acquisition.english.version, $acquisition.english.revision, $acquisition.english.last_update_utc
    )

    Add-Check -Id 'sources.arabic.copyright_notice' -Category 'sources' -Description 'Tanzil copyright block is present and includes its preservation and licence notices.' -Passed (
        -not [string]::IsNullOrEmpty($xml.CopyrightBlock) -and
        $xml.CopyrightBlock -match 'PLEASE DO NOT REMOVE OR CHANGE THIS COPYRIGHT BLOCK' -and
        $xml.CopyrightBlock -match 'License:\s+Creative Commons Attribution 3\.0' -and
        $xml.CopyrightBlock -match 'CHANGING IT IS NOT ALLOWED' -and
        $xml.CopyrightBlock -match 'tanzil\.net'
    ) -Details ([string]$acquisition.arabic.copyright)

    Add-Check -Id 'sources.english.source_notice' -Category 'sources' -Description 'QuranEnc preamble is present and includes its required preservation notice, ID, URL and version.' -Passed (
        -not [string]::IsNullOrEmpty($csv.InfoBlock) -and
        $csv.InfoBlock -match 'Translation ID:\s+english_saheeh' -and
        $csv.InfoBlock -match [regex]::Escape('https://quranenc.com/en/browse/english_saheeh') -and
        $csv.InfoBlock -match [regex]::Escape($expectedQuranEncRevision) -and
        $csv.InfoBlock -match 'PLEASE DON''T REMOVE THIS IMPORTANT INFORMATION!'
    ) -Details $expectedQuranEncRevision

    Add-Check -Id 'sources.english.attribution' -Category 'sources' -Description 'Official QuranEnc attribution is recorded without an unconfirmed translator claim.' -Passed (
        (Test-OrdinalEqual -Left ([string]$acquisition.english.attribution) -Right $expectedAttribution) -and
        (Test-OrdinalEqual -Left ([string]$acquisition.english.publisher) -Right 'Noor International Center')
    ) -Details ([string]$acquisition.english.attribution)

    Add-Check -Id 'sources.english.license' -Category 'sources' -Description 'QuranEnc Terms and Policies are recorded with their official URL.' -Passed (
        (Test-OrdinalEqual -Left ([string]$acquisition.english.license) -Right 'QuranEnc Terms and Policies') -and
        (Test-OrdinalEqual -Left ([string]$acquisition.english.license_url) -Right 'https://quranenc.com/en/home/about') -and
        ([string]$acquisition.english.license_terms).StartsWith($expectedQuranEncTermsPrefix, [System.StringComparison]::Ordinal)
    ) -Details ([string]$acquisition.english.license_url)

    Add-Check -Id 'sources.encoding' -Category 'sources' -Description 'Tanzil XML declares UTF-8 and both sources are valid UTF-8 without BOM.' -Passed (
        $xmlDeclaresUtf8 -and
        -not (Test-Utf8Bom -Path $arabicPath) -and
        -not (Test-Utf8Bom -Path $englishPath)
    ) -Details 'UTF-8, no BOM'

    $firstCsv = $csv.Rows[0]
    $lastCsv = $csv.Rows[$csv.Rows.Count - 1]
    Add-Check -Id 'sources.english.record_order' -Category 'sources' -Description 'QuranEnc IDs run 1..6236 and map from 1:1 through 114:6.' -Passed (
        [int]$firstCsv.Id -eq 1 -and [int]$firstCsv.Sura -eq 1 -and [int]$firstCsv.Aya -eq 1 -and
        [int]$lastCsv.Id -eq 6236 -and [int]$lastCsv.Sura -eq 114 -and [int]$lastCsv.Aya -eq 6
    ) -Details ("first={0}:{1}:{2}; last={3}:{4}:{5}" -f $firstCsv.Id, $firstCsv.Sura, $firstCsv.Aya, $lastCsv.Id, $lastCsv.Sura, $lastCsv.Aya)

    Assert-NoFailures -Stage 'source-structure'

    # ---------------------------------------------------------------
    # Sequence checks
    # ---------------------------------------------------------------

    $actualSuraNumbers = @($xml.Suras | ForEach-Object { [int]$_.Number })
    $expectedSuraNumbers = @(1..114)
    $suraSequenceOk = (($actualSuraNumbers -join ',') -eq ($expectedSuraNumbers -join ','))

    $suraSequenceDetails = if ($suraSequenceOk) { '1..114' } else { 'unexpected order or gaps' }
    Add-Check -Id 'sources.arabic.surah_sequence' -Category 'sources' -Description 'Surah numbers are sequential from 1 to 114.' -Passed $suraSequenceOk -Details $suraSequenceDetails

    $ayahSequenceIssues = New-Object System.Collections.ArrayList
    foreach ($sura in $xml.Suras) {
        $actualNumbers = @($sura.Ayahs | ForEach-Object { [int]$_.Number })
        $expectedNumbers = @(1..$sura.Ayahs.Count)
        if (($actualNumbers -join ',') -ne ($expectedNumbers -join ',')) {
            [void]$ayahSequenceIssues.Add(('Surah {0}' -f $sura.Number))
        }
    }

    Add-Check -Id 'sources.arabic.ayah_sequence' -Category 'sources' -Description 'Ayah numbers are sequential from 1 within every Surah.' -Passed ($ayahSequenceIssues.Count -eq 0) -Details (Format-KeyList -Items $ayahSequenceIssues)

    $duplicateSuraNumbers = New-Object System.Collections.ArrayList
    $seenSuraNumbers = New-Object 'System.Collections.Generic.HashSet[int]'
    foreach ($sura in $xml.Suras) {
        if (-not $seenSuraNumbers.Add([int]$sura.Number)) {
            [void]$duplicateSuraNumbers.Add([int]$sura.Number)
        }
    }

    Add-Check -Id 'sources.arabic.no_duplicate_surahs' -Category 'sources' -Description 'Tanzil XML has no duplicate Surah numbers.' -Passed ($duplicateSuraNumbers.Count -eq 0) -Details (Format-KeyList -Items $duplicateSuraNumbers)

    Assert-NoFailures -Stage 'source-sequences'

    # ---------------------------------------------------------------
    # Existing app catalogue (read-only)
    # ---------------------------------------------------------------

    $catalogue = (Read-Utf8TextFile -Path $cataloguePath) | ConvertFrom-Json
    $catalogueSurahs = @($catalogue.surahs)
    $catalogueTotal = 0
    foreach ($entry in $catalogueSurahs) {
        $catalogueTotal += [int]$entry.ayah_count
    }

    Add-Check -Id 'catalogue.surah_count' -Category 'catalogue' -Description 'Existing assets/data/surahs.json contains 114 Surahs.' -Passed ($catalogueSurahs.Count -eq 114) -Details ("found {0}" -f $catalogueSurahs.Count)
    Add-Check -Id 'catalogue.total_ayahs' -Category 'catalogue' -Description 'Existing assets/data/surahs.json totals 6,236 Ayahs.' -Passed ($catalogueTotal -eq 6236) -Details ("found {0}" -f $catalogueTotal)

    $catalogueByNumber = @{}
    $catalogueSequenceIssues = New-Object System.Collections.ArrayList
    foreach ($entry in $catalogueSurahs) {
        $number = [int]$entry.number
        if ($catalogueByNumber.ContainsKey($number)) {
            [void]$catalogueSequenceIssues.Add(('duplicate {0}' -f $number))
            continue
        }
        $catalogueByNumber[$number] = $entry
    }
    for ($n = 1; $n -le 114; $n++) {
        if (-not $catalogueByNumber.ContainsKey($n)) {
            [void]$catalogueSequenceIssues.Add(('missing {0}' -f $n))
        }
    }

    Add-Check -Id 'catalogue.sequence' -Category 'catalogue' -Description 'Catalogue Surah numbers are complete and unique.' -Passed ($catalogueSequenceIssues.Count -eq 0) -Details (Format-KeyList -Items $catalogueSequenceIssues)

    Assert-NoFailures -Stage 'catalogue'

    # ---------------------------------------------------------------
    # One-to-one source mapping
    # ---------------------------------------------------------------

    $xmlBySura = @{}
    foreach ($sura in $xml.Suras) {
        if ($xmlBySura.ContainsKey([int]$sura.Number)) {
            throw ('Duplicate Surah {0} in Tanzil XML.' -f $sura.Number)
        }
        $xmlBySura[[int]$sura.Number] = $sura
    }

    $csvByKey = @{}
    foreach ($row in $csv.Rows) {
        $key = '{0}:{1}' -f $row.Sura, $row.Aya
        if ($csvByKey.ContainsKey($key)) {
            throw ('Duplicate English record for {0}.' -f $key)
        }
        $csvByKey[$key] = $row
    }

    $xmlKeys = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($sura in $xml.Suras) {
        foreach ($ayah in $sura.Ayahs) {
            [void]$xmlKeys.Add(('{0}:{1}' -f $sura.Number, $ayah.Number))
        }
    }

    $missingEnglish = New-Object System.Collections.ArrayList
    foreach ($key in $xmlKeys) {
        if (-not $csvByKey.ContainsKey($key)) {
            [void]$missingEnglish.Add($key)
        }
    }

    $extraEnglish = New-Object System.Collections.ArrayList
    foreach ($row in $csv.Rows) {
        $key = '{0}:{1}' -f $row.Sura, $row.Aya
        if (-not $xmlKeys.Contains($key)) {
            [void]$extraEnglish.Add($key)
        }
    }

    $mappingOk = ($missingEnglish.Count -eq 0 -and $extraEnglish.Count -eq 0 -and $csv.Rows.Count -eq 6236)
    $mappingDetails = if ($mappingOk) {
        '6,236 matched records'
    }
    else {
        'missing=[{0}]; extra=[{1}]' -f (Format-KeyList -Items $missingEnglish), (Format-KeyList -Items $extraEnglish)
    }
    Add-Check -Id 'mapping.one_to_one' -Category 'mapping' -Description 'Every Arabic Ayah has exactly one English record and vice versa.' -Passed $mappingOk -Details $mappingDetails

    Assert-NoFailures -Stage 'mapping'

    # ---------------------------------------------------------------
    # Build the generated dataset in memory
    # ---------------------------------------------------------------

    $surahRecords = New-Object System.Collections.ArrayList
    $surahRecordByNumber = @{}
    $basmalaModeBySura = @{}
    $basmalaTextBySura = @{}
    $expectedAyahByKey = @{}

    $emptyArabic = New-Object System.Collections.ArrayList
    $emptyTranslations = New-Object System.Collections.ArrayList
    $arabicControlIssues = New-Object System.Collections.ArrayList
    $translationControlIssues = New-Object System.Collections.ArrayList
    $sajdahMarkerIssues = New-Object System.Collections.ArrayList
    $basmalaNonFirst = New-Object System.Collections.ArrayList
    $basmalaMissing = New-Object System.Collections.ArrayList
    $basmalaPrepended = New-Object System.Collections.ArrayList
    $jsonParseIssues = New-Object System.Collections.ArrayList
    $jsonContentIssues = New-Object System.Collections.ArrayList
    $catalogueMismatches = New-Object System.Collections.ArrayList

    $markerTotals = @{
        PauseMarks = 0
        RubElHizb = 0
        Sajdah = 0
        Tatweel = 0
    }

    $sajdahLocations = New-Object System.Collections.ArrayList
    $totalGeneratedAyahs = 0
    $totalTranslations = 0
    $totalFootnotes = 0
    $footnoteNonEmpty = 0
    $footnoteNewlines = 0
    $footnoteQuotes = 0
    $basmalaAttributeCount = 0

    for ($suraNumber = 1; $suraNumber -le 114; $suraNumber++) {
        if (-not $xmlBySura.ContainsKey($suraNumber)) {
            throw ('Tanzil XML is missing Surah {0}.' -f $suraNumber)
        }

        $sourceSura = $xmlBySura[$suraNumber]
        $sourceAyahs = @($sourceSura.Ayahs)
        $sourceAyahCount = $sourceAyahs.Count

        if (-not $catalogueByNumber.ContainsKey($suraNumber)) {
            [void]$catalogueMismatches.Add(('Surah {0} missing from catalogue' -f $suraNumber))
        }
        elseif ([int]$catalogueByNumber[$suraNumber].ayah_count -ne $sourceAyahCount) {
            [void]$catalogueMismatches.Add((
                'Surah {0}: source={1}, catalogue={2}' -f $suraNumber, $sourceAyahCount, [int]$catalogueByNumber[$suraNumber].ayah_count
            ))
        }

        $bismillahAyahs = @($sourceAyahs | Where-Object { $null -ne $_.Bismillah })
        $basmalaAttributeCount += $bismillahAyahs.Count

        foreach ($bismillahAyah in $bismillahAyahs) {
            if ([int]$bismillahAyah.Number -ne 1) {
                [void]$basmalaNonFirst.Add(('{0}:{1}' -f $suraNumber, $bismillahAyah.Number))
            }
        }

        if ($suraNumber -eq 1) {
            if ($bismillahAyahs.Count -ne 0) {
                throw 'Surah 1 unexpectedly has a prefatory bismillah attribute.'
            }
            $basmalaMode = 'ayah'
            $basmalaText = $null
        }
        elseif ($suraNumber -eq 9) {
            if ($bismillahAyahs.Count -ne 0) {
                throw 'Surah 9 unexpectedly has a prefatory bismillah attribute.'
            }
            $basmalaMode = 'none'
            $basmalaText = $null
        }
        else {
            if ($bismillahAyahs.Count -ne 1) {
                [void]$basmalaMissing.Add([string]$suraNumber)
                throw ('Surah {0} has {1} prefatory bismillah attributes; expected exactly 1.' -f $suraNumber, $bismillahAyahs.Count)
            }
            if ([int]$bismillahAyahs[0].Number -ne 1) {
                throw ('Surah {0} has its prefatory bismillah on ayah {1}; expected ayah 1.' -f $suraNumber, $bismillahAyahs[0].Number)
            }

            $basmalaMode = 'prefatory'
            $basmalaText = [string]$bismillahAyahs[0].Bismillah
            if ([string]::IsNullOrEmpty($basmalaText)) {
                throw ('Surah {0} has an empty prefatory Basmala.' -f $suraNumber)
            }
            if ($sourceAyahs[0].Text.StartsWith($basmalaText, [System.StringComparison]::Ordinal)) {
                [void]$basmalaPrepended.Add(('Surah {0}' -f $suraNumber))
            }
        }

        $basmalaModeBySura[$suraNumber] = $basmalaMode
        $basmalaTextBySura[$suraNumber] = $basmalaText

        $ayahObjects = New-Object System.Collections.ArrayList

        foreach ($sourceAyah in $sourceAyahs) {
            $key = '{0}:{1}' -f $suraNumber, $sourceAyah.Number
            if (-not $csvByKey.ContainsKey($key)) {
                throw ('Missing English record for {0}.' -f $key)
            }

            $englishRow = $csvByKey[$key]
            if ([int]$englishRow.Sura -ne $suraNumber -or [int]$englishRow.Aya -ne [int]$sourceAyah.Number) {
                throw ('English record {0} is mislabeled as {1}:{2}.' -f $key, $englishRow.Sura, $englishRow.Aya)
            }

            $arabic = [string]$sourceAyah.Text
            $translation = [string]$englishRow.Translation
            $footnotes = [string]$englishRow.Footnotes

            if ([string]::IsNullOrEmpty($arabic)) {
                [void]$emptyArabic.Add($key)
            }
            if ([string]::IsNullOrEmpty($translation)) {
                [void]$emptyTranslations.Add($key)
            }

            $hasArabicControl = $false
            for ($characterIndex = 0; $characterIndex -lt $arabic.Length; $characterIndex++) {
                $codePoint = [int]$arabic[$characterIndex]
                if ($codePoint -eq 0 -or $codePoint -eq 9 -or $codePoint -eq 10 -or $codePoint -eq 13) {
                    $hasArabicControl = $true
                    break
                }
            }
            if ($hasArabicControl) {
                [void]$arabicControlIssues.Add($key)
            }

            if ($translation.IndexOf([char]0x0000) -ge 0) {
                [void]$translationControlIssues.Add(('{0} (NUL)' -f $key))
            }
            if ($footnotes.IndexOf([char]0x0000) -ge 0) {
                [void]$translationControlIssues.Add(('{0} footnotes (NUL)' -f $key))
            }

            $sajdah = Test-HasChar -Text $arabic -Character ([char]0x06E9)
            $markerCounts = Get-QuranMarkerCounts -Text $arabic

            if ($sajdah) {
                [void]$sajdahLocations.Add($key)
                if ($markerCounts.Sajdah -ne 1) {
                    [void]$sajdahMarkerIssues.Add(('{0} has {1} Sajdah signs' -f $key, $markerCounts.Sajdah))
                }
            }
            elseif ($markerCounts.Sajdah -ne 0) {
                [void]$sajdahMarkerIssues.Add(('{0} has an unclassified Sajdah sign' -f $key))
            }

            $markerTotals.PauseMarks += $markerCounts.PauseMarks
            $markerTotals.RubElHizb += $markerCounts.RubElHizb
            $markerTotals.Sajdah += $markerCounts.Sajdah
            $markerTotals.Tatweel += $markerCounts.Tatweel

            $totalFootnotes++
            if ($footnotes.Length -gt 0) {
                $footnoteNonEmpty++
            }
            if ($footnotes.IndexOf([char]0x000A) -ge 0 -or $footnotes.IndexOf([char]0x000D) -ge 0) {
                $footnoteNewlines++
            }
            if ($footnotes.IndexOf([char]0x0022) -ge 0) {
                $footnoteQuotes++
            }

            $ayahObject = [ordered]@{
                number = [int]$sourceAyah.Number
                arabic = $arabic
                translation = $translation
                footnotes = $footnotes
                sajdah = [bool]$sajdah
            }

            [void]$ayahObjects.Add($ayahObject)
            $totalGeneratedAyahs++
            $totalTranslations++

            $expectedAyahByKey[$key] = [pscustomobject]@{
                Sura = $suraNumber
                Aya = [int]$sourceAyah.Number
                Arabic = $arabic
                Translation = $translation
                Footnotes = $footnotes
                Sajdah = [bool]$sajdah
            }
        }

        $surahObject = [ordered]@{
            surah_number = $suraNumber
            basmala_mode = $basmalaMode
            basmala_text = $basmalaText
            ayahs = $ayahObjects.ToArray()
        }

        $surahJson = (ConvertTo-JsonText -Value $surahObject) + "`n"

        $parsedSurah = $null
        try {
            $parsedSurah = $surahJson | ConvertFrom-Json
        }
        catch {
            [void]$jsonParseIssues.Add(('Surah {0}: {1}' -f $suraNumber, $_.Exception.Message))
        }

        if ($null -ne $parsedSurah) {
            $topLevelKeys = @($parsedSurah.PSObject.Properties.Name)
            $expectedTopLevelKeys = @('surah_number', 'basmala_mode', 'basmala_text', 'ayahs')
            $topLevelKeysOk = ($topLevelKeys.Count -eq 4)
            foreach ($expectedKey in $expectedTopLevelKeys) {
                if ($topLevelKeys -notcontains $expectedKey) {
                    $topLevelKeysOk = $false
                }
            }
            if (-not $topLevelKeysOk) {
                [void]$jsonContentIssues.Add(('Surah {0}: unexpected top-level keys {1}' -f $suraNumber, ($topLevelKeys -join ',')))
            }

            if ([int]$parsedSurah.surah_number -ne $suraNumber) {
                [void]$jsonContentIssues.Add(('Surah {0}: surah_number round-trip mismatch' -f $suraNumber))
            }
            if ([string]$parsedSurah.basmala_mode -ne $basmalaMode) {
                [void]$jsonContentIssues.Add(('Surah {0}: basmala_mode round-trip mismatch' -f $suraNumber))
            }

            if ($null -eq $basmalaText) {
                if ($null -ne $parsedSurah.basmala_text) {
                    [void]$jsonContentIssues.Add(('Surah {0}: basmala_text should be null' -f $suraNumber))
                }
            }
            elseif (-not (Test-OrdinalEqual -Left ([string]$parsedSurah.basmala_text) -Right $basmalaText)) {
                [void]$jsonContentIssues.Add(('Surah {0}: basmala_text round-trip mismatch' -f $suraNumber))
            }

            $parsedAyahs = @($parsedSurah.ayahs)
            if ($parsedAyahs.Count -ne $ayahObjects.Count) {
                [void]$jsonContentIssues.Add(('Surah {0}: ayah count round-trip mismatch' -f $suraNumber))
            }

            foreach ($parsedAyah in $parsedAyahs) {
                $parsedKey = '{0}:{1}' -f $suraNumber, $parsedAyah.number
                if (-not $expectedAyahByKey.ContainsKey($parsedKey)) {
                    [void]$jsonContentIssues.Add(('{0}: unexpected round-trip ayah' -f $parsedKey))
                    continue
                }

                $expectedAyah = $expectedAyahByKey[$parsedKey]
                if (-not (Test-OrdinalEqual -Left ([string]$parsedAyah.arabic) -Right $expectedAyah.Arabic)) {
                    [void]$jsonContentIssues.Add(('{0}: Arabic round-trip mismatch' -f $parsedKey))
                }
                if (-not (Test-OrdinalEqual -Left ([string]$parsedAyah.translation) -Right $expectedAyah.Translation)) {
                    [void]$jsonContentIssues.Add(('{0}: translation round-trip mismatch' -f $parsedKey))
                }
                if (-not (Test-OrdinalEqual -Left ([string]$parsedAyah.footnotes) -Right $expectedAyah.Footnotes)) {
                    [void]$jsonContentIssues.Add(('{0}: footnotes round-trip mismatch' -f $parsedKey))
                }
                if ([bool]$parsedAyah.sajdah -ne [bool]$expectedAyah.Sajdah) {
                    [void]$jsonContentIssues.Add(('{0}: sajdah round-trip mismatch' -f $parsedKey))
                }
            }
        }

        $record = [pscustomobject]@{
            Number = $suraNumber
            AyahCount = $ayahObjects.Count
            BasmalaMode = $basmalaMode
            BasmalaText = $basmalaText
            Ayahs = $ayahObjects.ToArray()
            Json = $surahJson
            Hash = Get-Sha256Text -Text $surahJson
            FileName = ('{0:D3}.json' -f $suraNumber)
        }

        [void]$surahRecords.Add($record)
        $surahRecordByNumber[$suraNumber] = $record
    }

    # ---------------------------------------------------------------
    # In-memory validation
    # ---------------------------------------------------------------

    Add-Check -Id 'content.arabic_nonempty' -Category 'content' -Description 'No generated Arabic record is empty.' -Passed ($emptyArabic.Count -eq 0) -Details (Format-KeyList -Items $emptyArabic)
    Add-Check -Id 'content.translation_nonempty' -Category 'content' -Description 'No generated English translation record is empty.' -Passed ($emptyTranslations.Count -eq 0) -Details (Format-KeyList -Items $emptyTranslations)
    Add-Check -Id 'content.arabic_controls' -Category 'content' -Description 'Arabic records contain no NUL, tab, CR or LF characters.' -Passed ($arabicControlIssues.Count -eq 0) -Details (Format-KeyList -Items $arabicControlIssues)
    Add-Check -Id 'content.translation_controls' -Category 'content' -Description 'Translation and footnote records contain no NUL characters.' -Passed ($translationControlIssues.Count -eq 0) -Details (Format-KeyList -Items $translationControlIssues)

    $arabicExactIssues = New-Object System.Collections.ArrayList
    foreach ($sourceSura in $xml.Suras) {
        foreach ($sourceAyah in $sourceSura.Ayahs) {
            $key = '{0}:{1}' -f $sourceSura.Number, $sourceAyah.Number
            if (-not $expectedAyahByKey.ContainsKey($key) -or -not (Test-OrdinalEqual -Left ([string]$expectedAyahByKey[$key].Arabic) -Right ([string]$sourceAyah.Text))) {
                [void]$arabicExactIssues.Add($key)
            }
        }
    }
    Add-Check -Id 'content.arabic_exact' -Category 'content' -Description 'All 6,236 generated Arabic strings match the Tanzil source exactly (ordinal comparison).' -Passed ($arabicExactIssues.Count -eq 0) -Details (Format-KeyList -Items $arabicExactIssues)

    $translationExactIssues = New-Object System.Collections.ArrayList
    $footnoteExactIssues = New-Object System.Collections.ArrayList
    foreach ($row in $csv.Rows) {
        $key = '{0}:{1}' -f $row.Sura, $row.Aya
        if (-not $expectedAyahByKey.ContainsKey($key)) {
            [void]$translationExactIssues.Add($key)
            [void]$footnoteExactIssues.Add($key)
            continue
        }
        if (-not (Test-OrdinalEqual -Left ([string]$expectedAyahByKey[$key].Translation) -Right ([string]$row.Translation))) {
            [void]$translationExactIssues.Add($key)
        }
        if (-not (Test-OrdinalEqual -Left ([string]$expectedAyahByKey[$key].Footnotes) -Right ([string]$row.Footnotes))) {
            [void]$footnoteExactIssues.Add($key)
        }
    }
    Add-Check -Id 'content.translation_exact' -Category 'content' -Description 'All 6,236 generated translations match the QuranEnc CSV exactly (ordinal comparison).' -Passed ($translationExactIssues.Count -eq 0) -Details (Format-KeyList -Items $translationExactIssues)
    Add-Check -Id 'content.footnotes_exact' -Category 'content' -Description 'All 6,236 raw footnote strings match the QuranEnc CSV exactly (ordinal comparison).' -Passed ($footnoteExactIssues.Count -eq 0) -Details (Format-KeyList -Items $footnoteExactIssues)

    Add-Check -Id 'content.footnote_counts' -Category 'content' -Description 'Raw footnotes are retained, including embedded newlines and quotation marks.' -Passed (
        $totalFootnotes -eq 6236 -and $footnoteNonEmpty -gt 0
    ) -Details (
        'records={0}; non-empty={1}; with newlines={2}; with quotes={3}' -f $totalFootnotes, $footnoteNonEmpty, $footnoteNewlines, $footnoteQuotes
    )

    Add-Check -Id 'content.catalogue_counts' -Category 'catalogue' -Description 'Every Surah Ayah count matches assets/data/surahs.json.' -Passed ($catalogueMismatches.Count -eq 0) -Details (Format-KeyList -Items $catalogueMismatches)

    Add-Check -Id 'json.in_memory_parse' -Category 'json' -Description 'Every in-memory Surah JSON document parses successfully.' -Passed ($jsonParseIssues.Count -eq 0) -Details (Format-KeyList -Items $jsonParseIssues)
    Add-Check -Id 'json.in_memory_content' -Category 'json' -Description 'Every in-memory Surah JSON round-trip preserves the generated values exactly.' -Passed ($jsonContentIssues.Count -eq 0) -Details (Format-KeyList -Items $jsonContentIssues)

    Add-Check -Id 'totals.surahs' -Category 'totals' -Description 'Generated dataset contains exactly 114 Surahs.' -Passed ($surahRecords.Count -eq 114) -Details ("found {0}" -f $surahRecords.Count)
    Add-Check -Id 'totals.ayahs' -Category 'totals' -Description 'Generated dataset contains exactly 6,236 Ayahs.' -Passed ($totalGeneratedAyahs -eq 6236) -Details ("found {0}" -f $totalGeneratedAyahs)
    Add-Check -Id 'totals.arabic_records' -Category 'totals' -Description 'Generated dataset contains exactly 6,236 Arabic records.' -Passed ($totalGeneratedAyahs -eq 6236) -Details ("found {0}" -f $totalGeneratedAyahs)
    Add-Check -Id 'totals.translation_records' -Category 'totals' -Description 'Generated dataset contains exactly 6,236 English translation records.' -Passed ($totalTranslations -eq 6236) -Details ("found {0}" -f $totalTranslations)

    $basmalaAyahCount = 0
    $basmalaPrefatoryCount = 0
    $basmalaNoneCount = 0
    foreach ($number in 1..114) {
        switch ($basmalaModeBySura[$number]) {
            'ayah' { $basmalaAyahCount++ }
            'prefatory' { $basmalaPrefatoryCount++ }
            'none' { $basmalaNoneCount++ }
            default { throw ('Surah {0} has an invalid Basmala mode.' -f $number) }
        }
    }

    $standardBasmala = [string]$basmalaTextBySura[2]
    $special95 = [string]$basmalaTextBySura[95]
    $special97 = [string]$basmalaTextBySura[97]

    Add-Check -Id 'basmala.attribute_count' -Category 'basmala' -Description 'Tanzil source contains exactly 112 prefatory Basmala attributes, all on first Ayahs.' -Passed (
        $basmalaAttributeCount -eq 112 -and $basmalaNonFirst.Count -eq 0
    ) -Details ('attributes={0}; non-first={1}' -f $basmalaAttributeCount, (Format-KeyList -Items $basmalaNonFirst))

    Add-Check -Id 'basmala.mode_counts' -Category 'basmala' -Description 'Basmala modes are ayah=1, prefatory=112, none=1.' -Passed (
        $basmalaAyahCount -eq 1 -and $basmalaPrefatoryCount -eq 112 -and $basmalaNoneCount -eq 1
    ) -Details ('ayah={0}; prefatory={1}; none={2}' -f $basmalaAyahCount, $basmalaPrefatoryCount, $basmalaNoneCount)

    $surah1 = $xmlBySura[1]
    $surah1FirstAyah = [string]$surah1.Ayahs[0].Text
    Add-Check -Id 'basmala.surah_1' -Category 'basmala' -Description 'Surah 1 uses mode ayah; its first Ayah is the source Basmala and is not duplicated.' -Passed (
        $basmalaModeBySura[1] -eq 'ayah' -and
        $null -eq $basmalaTextBySura[1] -and
        $surah1.Ayahs.Count -eq 7 -and
        (Test-OrdinalEqual -Left $surah1FirstAyah -Right $standardBasmala)
    ) -Details 'Surah 1:1 equals the standard prefatory Basmala from Surah 2.'

    $surah9FirstAyah = [string]$xmlBySura[9].Ayahs[0].Text
    Add-Check -Id 'basmala.surah_9' -Category 'basmala' -Description 'Surah 9 uses mode none and has no prefatory Basmala.' -Passed (
        $basmalaModeBySura[9] -eq 'none' -and
        $null -eq $basmalaTextBySura[9] -and
        -not $surah9FirstAyah.StartsWith($standardBasmala, [System.StringComparison]::Ordinal)
    ) -Details 'Surah 9 has no Basmala attribute and its first Ayah does not start with the Basmala.'

    Add-Check -Id 'basmala.not_prepended' -Category 'basmala' -Description 'No prefatory Basmala is prepended to the first Ayah text.' -Passed ($basmalaPrepended.Count -eq 0) -Details (Format-KeyList -Items $basmalaPrepended)

    $specialBasmalaOk = (
        (Test-OrdinalEqual -Left $special95 -Right $special97) -and
        $special95.Length -eq 40 -and
        $special97.Length -eq 40 -and
        [int]$special95[1] -eq 0x0651 -and
        [int]$special97[1] -eq 0x0651 -and
        $standardBasmala.Length -eq 39 -and
        [int]$standardBasmala[1] -eq 0x0650 -and
        -not (Test-OrdinalEqual -Left $special95 -Right $standardBasmala)
    )
    Add-Check -Id 'basmala.special_95_97' -Category 'basmala' -Description 'Surahs 95 and 97 preserve their distinct Basmala spelling (extra shadda).' -Passed $specialBasmalaOk -Details (
        '95_len={0}; 97_len={1}; standard_len={2}; 95_cp1=U+{3:X4}; standard_cp1=U+{4:X4}' -f $special95.Length, $special97.Length, $standardBasmala.Length, [int]$special95[1], [int]$standardBasmala[1]
    )

    $expectedSajdahLocations = @(
        '7:206', '13:15', '16:50', '17:109', '19:58', '22:18', '22:77',
        '25:60', '27:26', '32:15', '38:24', '41:38', '53:62', '84:21', '96:19'
    )
    $actualSajdahLocations = @($sajdahLocations)
    Add-Check -Id 'sajdah.locations' -Category 'sajdah' -Description 'Exactly the 15 known Sajdah locations are marked and no others.' -Passed (
        ($actualSajdahLocations -join ',') -eq ($expectedSajdahLocations -join ',')
    ) -Details ('found: {0}' -f ($actualSajdahLocations -join ', '))
    Add-Check -Id 'sajdah.markers' -Category 'sajdah' -Description 'Each Sajdah Ayah contains exactly one U+06E9 mark and no other Ayah contains one.' -Passed ($sajdahMarkerIssues.Count -eq 0) -Details (Format-KeyList -Items $sajdahMarkerIssues)

    $sourceMarkerTotals = @{
        PauseMarks = 0
        RubElHizb = 0
        Sajdah = 0
        Tatweel = 0
    }
    foreach ($sourceSura in $xml.Suras) {
        foreach ($sourceAyah in $sourceSura.Ayahs) {
            $counts = Get-QuranMarkerCounts -Text ([string]$sourceAyah.Text)
            $sourceMarkerTotals.PauseMarks += $counts.PauseMarks
            $sourceMarkerTotals.RubElHizb += $counts.RubElHizb
            $sourceMarkerTotals.Sajdah += $counts.Sajdah
            $sourceMarkerTotals.Tatweel += $counts.Tatweel
        }
    }

    Add-Check -Id 'marks.source_totals' -Category 'marks' -Description 'Pause, rub-el-hizb, Sajdah and tatweel marker totals match the source.' -Passed (
        $markerTotals.PauseMarks -eq $sourceMarkerTotals.PauseMarks -and
        $markerTotals.RubElHizb -eq $sourceMarkerTotals.RubElHizb -and
        $markerTotals.Sajdah -eq $sourceMarkerTotals.Sajdah -and
        $markerTotals.Tatweel -eq $sourceMarkerTotals.Tatweel
    ) -Details (
        'pause={0}; rub={1}; sajdah={2}; tatweel={3}' -f $markerTotals.PauseMarks, $markerTotals.RubElHizb, $markerTotals.Sajdah, $markerTotals.Tatweel
    )
    Add-Check -Id 'marks.present' -Category 'marks' -Description 'Pause marks, rub-el-hizb signs and tatweel characters are present in the generated Arabic.' -Passed (
        $markerTotals.PauseMarks -gt 0 -and $markerTotals.RubElHizb -gt 0 -and $markerTotals.Tatweel -gt 0
    ) -Details ('pause={0}; rub={1}; tatweel={2}' -f $markerTotals.PauseMarks, $markerTotals.RubElHizb, $markerTotals.Tatweel)

    Assert-NoFailures -Stage 'in-memory'

    # ---------------------------------------------------------------
    # Preflight generated-output paths
    # ---------------------------------------------------------------

    if (-not [System.IO.Directory]::Exists($generatedDir)) {
        [void][System.IO.Directory]::CreateDirectory($generatedDir)
    }
    if (-not [System.IO.Directory]::Exists($surahsOutDir)) {
        [void][System.IO.Directory]::CreateDirectory($surahsOutDir)
    }

    $expectedFileNames = @($surahRecords | ForEach-Object { $_.FileName })

    foreach ($record in $surahRecords) {
        $path = Join-Path $surahsOutDir $record.FileName
        if ([System.IO.File]::Exists($path)) {
            $existing = Read-Utf8TextFile -Path $path
            if (-not (Test-OrdinalEqual -Left $existing -Right $record.Json) -and -not $Force) {
                throw "Refusing to overwrite an existing Surah file with different content: $path. Inspect it first, then re-run with -Force only if intentional."
            }
        }
    }

    $existingSurahFiles = @(Get-ChildItem -LiteralPath $surahsOutDir -File -Filter '*.json' | ForEach-Object { $_.Name })
    $extraSurahFiles = @($existingSurahFiles | Where-Object { $expectedFileNames -notcontains $_ })
    if ($extraSurahFiles.Count -gt 0) {
        throw ("Refusing to proceed: unexpected .json files exist in generated/surahs: {0}" -f ($extraSurahFiles -join ', '))
    }

    # Content checksum excludes the manifest timestamp by construction.
    $contentChecksumBuilder = New-Object System.Text.StringBuilder
    foreach ($record in ($surahRecords | Sort-Object Number)) {
        [void]$contentChecksumBuilder.Append($record.FileName)
        [void]$contentChecksumBuilder.Append("`n")
        [void]$contentChecksumBuilder.Append($record.Hash)
        [void]$contentChecksumBuilder.Append("`n")
    }
    $contentChecksum = Get-Sha256Text -Text $contentChecksumBuilder.ToString()

    # ---------------------------------------------------------------
    # Write Surah files
    # ---------------------------------------------------------------

    $writeStatuses = @{}
    foreach ($record in $surahRecords) {
        $path = Join-Path $surahsOutDir $record.FileName
        $writeResult = Write-GeneratedFile -Path $path -Content $record.Json -Force:$Force
        $writeStatuses[$record.Number] = $writeResult.Status
    }

    # ---------------------------------------------------------------
    # Post-write validation of every Surah file
    # ---------------------------------------------------------------

    $postParseIssues = New-Object System.Collections.ArrayList
    $postSchemaIssues = New-Object System.Collections.ArrayList
    $postHashIssues = New-Object System.Collections.ArrayList
    $postArabicIssues = New-Object System.Collections.ArrayList
    $postTranslationIssues = New-Object System.Collections.ArrayList
    $postFootnoteIssues = New-Object System.Collections.ArrayList
    $postSajdahIssues = New-Object System.Collections.ArrayList
    $postBasmalaIssues = New-Object System.Collections.ArrayList
    $postAyahSequenceIssues = New-Object System.Collections.ArrayList

    $generatedParsedByNumber = @{}
    $actualHashes = @{}

    foreach ($record in $surahRecords) {
        $path = Join-Path $surahsOutDir $record.FileName
        $fileText = Read-Utf8TextFile -Path $path
        $actualHash = Get-Sha256Hex -Path $path
        $actualHashes[$record.Number] = $actualHash

        if (-not (Test-OrdinalEqual -Left $actualHash -Right $record.Hash)) {
            [void]$postHashIssues.Add(('Surah {0}' -f $record.Number))
        }

        $parsedSurah = $null
        try {
            $parsedSurah = $fileText | ConvertFrom-Json
        }
        catch {
            [void]$postParseIssues.Add(('Surah {0}: {1}' -f $record.Number, $_.Exception.Message))
            continue
        }

        $generatedParsedByNumber[$record.Number] = $parsedSurah

        $topLevelKeys = @($parsedSurah.PSObject.Properties.Name)
        $expectedTopLevelKeys = @('surah_number', 'basmala_mode', 'basmala_text', 'ayahs')
        $topLevelKeysOk = ($topLevelKeys.Count -eq 4)
        foreach ($expectedKey in $expectedTopLevelKeys) {
            if ($topLevelKeys -notcontains $expectedKey) {
                $topLevelKeysOk = $false
            }
        }
        if (-not $topLevelKeysOk) {
            [void]$postSchemaIssues.Add(('Surah {0}: top-level keys {1}' -f $record.Number, ($topLevelKeys -join ',')))
        }

        if ([int]$parsedSurah.surah_number -ne $record.Number) {
            [void]$postSchemaIssues.Add(('Surah {0}: surah_number={1}' -f $record.Number, $parsedSurah.surah_number))
        }
        if ([string]$parsedSurah.basmala_mode -ne $record.BasmalaMode) {
            [void]$postSchemaIssues.Add(('Surah {0}: basmala_mode={1}' -f $record.Number, $parsedSurah.basmala_mode))
        }

        if ($null -eq $record.BasmalaText) {
            if ($null -ne $parsedSurah.basmala_text) {
                [void]$postBasmalaIssues.Add(('Surah {0}: basmala_text should be null' -f $record.Number))
            }
        }
        elseif (-not (Test-OrdinalEqual -Left ([string]$parsedSurah.basmala_text) -Right ([string]$record.BasmalaText))) {
            [void]$postBasmalaIssues.Add(('Surah {0}: basmala_text mismatch' -f $record.Number))
        }

        $parsedAyahs = @($parsedSurah.ayahs)
        if ($parsedAyahs.Count -ne $record.AyahCount) {
            [void]$postSchemaIssues.Add(('Surah {0}: ayah count {1}, expected {2}' -f $record.Number, $parsedAyahs.Count, $record.AyahCount))
        }

        $expectedAyahNumbers = @(1..$record.AyahCount)
        $actualAyahNumbers = @($parsedAyahs | ForEach-Object { [int]$_.number })
        if (($actualAyahNumbers -join ',') -ne ($expectedAyahNumbers -join ',')) {
            [void]$postAyahSequenceIssues.Add(('Surah {0}' -f $record.Number))
        }

        foreach ($parsedAyah in $parsedAyahs) {
            $key = '{0}:{1}' -f $record.Number, $parsedAyah.number
            if (-not $expectedAyahByKey.ContainsKey($key)) {
                [void]$postSchemaIssues.Add(('{0}: unexpected Ayah' -f $key))
                continue
            }

            $ayahKeys = @($parsedAyah.PSObject.Properties.Name)
            $expectedAyahKeys = @('number', 'arabic', 'translation', 'footnotes', 'sajdah')
            $ayahKeysOk = ($ayahKeys.Count -eq 5)
            foreach ($expectedKey in $expectedAyahKeys) {
                if ($ayahKeys -notcontains $expectedKey) {
                    $ayahKeysOk = $false
                }
            }
            if (-not $ayahKeysOk) {
                [void]$postSchemaIssues.Add(('{0}: Ayah keys {1}' -f $key, ($ayahKeys -join ',')))
            }

            $expectedAyah = $expectedAyahByKey[$key]
            if (-not (Test-OrdinalEqual -Left ([string]$parsedAyah.arabic) -Right ([string]$expectedAyah.Arabic))) {
                [void]$postArabicIssues.Add($key)
            }
            if (-not (Test-OrdinalEqual -Left ([string]$parsedAyah.translation) -Right ([string]$expectedAyah.Translation))) {
                [void]$postTranslationIssues.Add($key)
            }
            if (-not (Test-OrdinalEqual -Left ([string]$parsedAyah.footnotes) -Right ([string]$expectedAyah.Footnotes))) {
                [void]$postFootnoteIssues.Add($key)
            }
            if ([bool]$parsedAyah.sajdah -ne [bool]$expectedAyah.Sajdah) {
                [void]$postSajdahIssues.Add($key)
            }
        }
    }

    $actualContentChecksumBuilder = New-Object System.Text.StringBuilder
    $surahFilesTotalSize = [long]0
    foreach ($record in ($surahRecords | Sort-Object Number)) {
        $path = Join-Path $surahsOutDir $record.FileName
        [void]$actualContentChecksumBuilder.Append($record.FileName)
        [void]$actualContentChecksumBuilder.Append("`n")
        [void]$actualContentChecksumBuilder.Append($actualHashes[$record.Number])
        [void]$actualContentChecksumBuilder.Append("`n")
        $surahFilesTotalSize += (Get-Item -LiteralPath $path).Length
    }
    $actualContentChecksum = Get-Sha256Text -Text $actualContentChecksumBuilder.ToString()

    Add-Check -Id 'generated.file_count' -Category 'generated' -Description 'Exactly 114 Surah JSON files exist with the expected names.' -Passed (
        $surahRecords.Count -eq 114 -and
        @(Get-ChildItem -LiteralPath $surahsOutDir -File -Filter '*.json').Count -eq 114
    ) -Details ("files={0}" -f @(Get-ChildItem -LiteralPath $surahsOutDir -File -Filter '*.json').Count)

    Add-Check -Id 'generated.file_hashes' -Category 'generated' -Description 'Every written Surah file has the recorded SHA-256 checksum.' -Passed ($postHashIssues.Count -eq 0) -Details (Format-KeyList -Items $postHashIssues)
    Add-Check -Id 'generated.json_parse' -Category 'generated' -Description 'Every written Surah JSON file parses successfully.' -Passed ($postParseIssues.Count -eq 0) -Details (Format-KeyList -Items $postParseIssues)
    Add-Check -Id 'generated.schema' -Category 'generated' -Description 'Every written Surah file has the required schema, types and Ayah shape.' -Passed ($postSchemaIssues.Count -eq 0) -Details (Format-KeyList -Items $postSchemaIssues)
    Add-Check -Id 'generated.ayah_sequence' -Category 'generated' -Description 'Every written Surah has sequential Ayah numbering.' -Passed ($postAyahSequenceIssues.Count -eq 0) -Details (Format-KeyList -Items $postAyahSequenceIssues)
    Add-Check -Id 'generated.arabic_exact' -Category 'generated' -Description 'Every written Arabic string matches the Tanzil source exactly.' -Passed ($postArabicIssues.Count -eq 0) -Details (Format-KeyList -Items $postArabicIssues)
    Add-Check -Id 'generated.translation_exact' -Category 'generated' -Description 'Every written translation matches the QuranEnc CSV exactly.' -Passed ($postTranslationIssues.Count -eq 0) -Details (Format-KeyList -Items $postTranslationIssues)
    Add-Check -Id 'generated.footnotes_exact' -Category 'generated' -Description 'Every written raw footnote string matches the QuranEnc CSV exactly.' -Passed ($postFootnoteIssues.Count -eq 0) -Details (Format-KeyList -Items $postFootnoteIssues)
    Add-Check -Id 'generated.sajdah_exact' -Category 'generated' -Description 'Every written sajdah flag matches the presence of the U+06E9 source mark.' -Passed ($postSajdahIssues.Count -eq 0) -Details (Format-KeyList -Items $postSajdahIssues)
    Add-Check -Id 'generated.basmala_exact' -Category 'generated' -Description 'Every written Basmala mode and text matches the source-derived values.' -Passed ($postBasmalaIssues.Count -eq 0) -Details (Format-KeyList -Items $postBasmalaIssues)
    Add-Check -Id 'generated.content_checksum' -Category 'generated' -Description 'Per-Surah checksums reproduce the pre-write content checksum.' -Passed (Test-OrdinalEqual -Left $actualContentChecksum -Right $contentChecksum) -Details ('actual={0}; expected={1}' -f $actualContentChecksum, $contentChecksum)

    # ---------------------------------------------------------------
    # Spot checks against the original sources
    # ---------------------------------------------------------------

    $spotCheckKeys = @('1:1', '1:2', '2:1', '9:1', '114:6')
    $spotChecks = New-Object System.Collections.ArrayList
    $spotCheckIssues = New-Object System.Collections.ArrayList

    foreach ($key in $spotCheckKeys) {
        $parts = $key.Split(':')
        $suraNumber = [int]$parts[0]
        $ayahNumber = [int]$parts[1]

        if (-not $generatedParsedByNumber.ContainsKey($suraNumber)) {
            [void]$spotCheckIssues.Add(('{0}: missing Surah' -f $key))
            continue
        }

        $generatedAyah = @($generatedParsedByNumber[$suraNumber].ayahs) |
            Where-Object { [int]$_.number -eq $ayahNumber } |
            Select-Object -First 1

        if ($null -eq $generatedAyah -or -not $expectedAyahByKey.ContainsKey($key)) {
            [void]$spotCheckIssues.Add(('{0}: missing generated or expected record' -f $key))
            continue
        }

        $expectedAyah = $expectedAyahByKey[$key]
        $arabicOk = Test-OrdinalEqual -Left ([string]$generatedAyah.arabic) -Right ([string]$expectedAyah.Arabic)
        $translationOk = Test-OrdinalEqual -Left ([string]$generatedAyah.translation) -Right ([string]$expectedAyah.Translation)
        $footnotesOk = Test-OrdinalEqual -Left ([string]$generatedAyah.footnotes) -Right ([string]$expectedAyah.Footnotes)
        $sajdahOk = ([bool]$generatedAyah.sajdah -eq [bool]$expectedAyah.Sajdah)
        $startsWithBasmala = ([string]$generatedAyah.arabic).StartsWith($standardBasmala, [System.StringComparison]::Ordinal)
        # Surah 1:1 is the Basmala itself, not a Basmala prepended to another Ayah.
        $basmalaPrepended = ($key -ne '1:1') -and $startsWithBasmala

        $spotCheck = [ordered]@{
            key = $key
            arabic_matches_source = $arabicOk
            translation_matches_source = $translationOk
            footnotes_matches_source = $footnotesOk
            sajdah_matches_source = $sajdahOk
            starts_with_standard_basmala = $startsWithBasmala
            basmala_prepended_to_ayah = $basmalaPrepended
            arabic_sha256 = Get-Sha256Text -Text ([string]$generatedAyah.arabic)
            translation_sha256 = Get-Sha256Text -Text ([string]$generatedAyah.translation)
            footnotes_sha256 = Get-Sha256Text -Text ([string]$generatedAyah.footnotes)
            arabic = [string]$generatedAyah.arabic
            translation = [string]$generatedAyah.translation
            footnotes = [string]$generatedAyah.footnotes
            sajdah = [bool]$generatedAyah.sajdah
        }

        [void]$spotChecks.Add($spotCheck)

        $spotPassed = $arabicOk -and $translationOk -and $footnotesOk -and $sajdahOk
        if ($key -eq '2:1' -or $key -eq '9:1') {
            $spotPassed = $spotPassed -and (-not $basmalaPrepended)
        }

        Add-Check -Id ('spot.{0}' -f $key.Replace(':', '_')) -Category 'spot-checks' -Description ('Spot check {0} matches the original Arabic and English sources.' -f $key) -Passed $spotPassed -Details (
            'arabic={0}; translation={1}; footnotes={2}; sajdah={3}; starts_with_basmala={4}; basmala_prepended={5}' -f $arabicOk, $translationOk, $footnotesOk, $sajdahOk, $startsWithBasmala, $basmalaPrepended
        )

        if (-not $spotPassed) {
            [void]$spotCheckIssues.Add($key)
        }
    }

    Add-Check -Id 'spot_checks.all_match' -Category 'spot-checks' -Description 'All required spot checks pass against the original sources.' -Passed ($spotCheckIssues.Count -eq 0) -Details (Format-KeyList -Items $spotCheckIssues)

    # ---------------------------------------------------------------
    # Read-only guard
    # ---------------------------------------------------------------

    $catalogueHashAfter = Get-Sha256Hex -Path $cataloguePath
    $pubspecHashAfter = ''
    if ([System.IO.File]::Exists($pubspecPath)) {
        $pubspecHashAfter = Get-Sha256Hex -Path $pubspecPath
    }
    $appQuranDirExistedAfter = [System.IO.Directory]::Exists($appQuranDir)

    Add-Check -Id 'guard.catalogue_unchanged' -Category 'guard' -Description 'assets/data/surahs.json was not modified.' -Passed (Test-OrdinalEqual -Left $catalogueHashAfter -Right $catalogueHashBefore) -Details ('sha256={0}' -f $catalogueHashAfter)
    Add-Check -Id 'guard.pubspec_unchanged' -Category 'guard' -Description 'pubspec.yaml was not modified.' -Passed (Test-OrdinalEqual -Left $pubspecHashAfter -Right $pubspecHashBefore) -Details ('sha256={0}' -f $pubspecHashAfter)
    Add-Check -Id 'guard.no_app_quran_assets' -Category 'guard' -Description 'No files were added under assets/data/quran/.' -Passed ($appQuranDirExistedAfter -eq $appQuranDirExistedBefore) -Details ('exists={0}' -f $appQuranDirExistedAfter)

    Assert-NoFailures -Stage 'post-write'

    # ---------------------------------------------------------------
    # Manifest
    # ---------------------------------------------------------------

    $arabicSource = [ordered]@{
        name = [string]$acquisition.arabic.name
        provider = [string]$acquisition.arabic.provider
        url = [string]$acquisition.arabic.url
        updates_url = [string]$acquisition.arabic.updates_url
        version = [string]$acquisition.arabic.version
        release_date = [string]$acquisition.arabic.release_date
        file = [string]$acquisition.arabic.file
        size_bytes = [long]$acquisition.arabic.size_bytes
        sha256 = [string]$acquisition.arabic.sha256
        copyright = [string]$acquisition.arabic.copyright
        license = [string]$acquisition.arabic.license
        notice = [string]$acquisition.arabic.notice
    }

    $englishSource = [ordered]@{
        name = [string]$acquisition.english.name
        provider = [string]$acquisition.english.provider
        publisher = [string]$acquisition.english.publisher
        attribution = [string]$acquisition.english.attribution
        url = [string]$acquisition.english.url
        browse_url = [string]$acquisition.english.browse_url
        version = [string]$acquisition.english.version
        revision = [string]$acquisition.english.revision
        last_update_unix = [long]$acquisition.english.last_update_unix
        last_update_utc = [string]$acquisition.english.last_update_utc
        last_update_source_text = [string]$acquisition.english.last_update_source_text
        file = [string]$acquisition.english.file
        size_bytes = [long]$acquisition.english.size_bytes
        sha256 = [string]$acquisition.english.sha256
        license = [string]$acquisition.english.license
        license_url = [string]$acquisition.english.license_url
        license_terms = [string]$acquisition.english.license_terms
        source_info_block = [string]$acquisition.english.source_info_block
    }

    $catalogueSource = [ordered]@{
        name = [string]$catalogue.source.name
        url = [string]$catalogue.source.url
        license = [string]$catalogue.source.license
        copyright = [string]$catalogue.source.copyright
        cross_checked_with = [string]$catalogue.source.cross_checked_with
        path = 'assets/data/surahs.json'
        sha256 = $catalogueHashBefore
        note = 'Existing app catalogue; read-only. It is not part of the Qur''an text source.'
    }

    $surahEntries = New-Object System.Collections.ArrayList
    foreach ($record in ($surahRecords | Sort-Object Number)) {
        [void]$surahEntries.Add([ordered]@{
            number = [int]$record.Number
            ayah_count = [int]$record.AyahCount
            basmala_mode = [string]$record.BasmalaMode
            file = ('surahs/{0}' -f $record.FileName)
            sha256 = [string]$record.Hash
        })
    }

    $totals = [ordered]@{
        surahs = [int]$surahRecords.Count
        ayahs = [int]$totalGeneratedAyahs
        arabic_records = [int]$totalGeneratedAyahs
        translation_records = [int]$totalTranslations
        footnote_records = [int]$totalFootnotes
        footnotes_nonempty = [int]$footnoteNonEmpty
        footnotes_with_embedded_newlines = [int]$footnoteNewlines
        footnotes_with_quotes = [int]$footnoteQuotes
        sajdah_ayahs = [int]$sajdahLocations.Count
        pause_marks = [int]$markerTotals.PauseMarks
        rub_el_hizb_marks = [int]$markerTotals.RubElHizb
        tatweel_characters = [int]$markerTotals.Tatweel
    }

    $basmalaSummary = [ordered]@{
        ayah = @(1)
        prefatory = 112
        none = @(9)
        special_spellings = @(95, 97)
    }

    $checksTotalBeforeManifest = $script:checks.Count
    $checksPassedBeforeManifest = @($script:checks | Where-Object { $_.passed }).Count

    $manifestValidation = [ordered]@{
        status = if ($script:failures.Count -eq 0) { 'passed' } else { 'failed' }
        checks_total = [int]$checksTotalBeforeManifest
        checks_passed = [int]$checksPassedBeforeManifest
        checks_failed = [int]$script:failures.Count
        full_report = 'validation/validation-report.json'
        independent_report = 'validation/independent-validation.json'
        note = 'Counts cover generation and generated-Surah-file checks. The full report additionally includes manifest read-back and checksum checks.'
        source_hashes_verified = $true
        catalogue_counts_verified = ($catalogueMismatches.Count -eq 0)
        generated_surah_files_parsed = 114
        sajdah_locations = @($sajdahLocations)
        spot_checks = @($spotChecks | ForEach-Object { $_.key })
    }

    $manifest = [ordered]@{
        schema_version = '1.0.0'
        dataset_version = '1.0.0'
        generated_at_utc = $GeneratedAtUtc
        generator = [ordered]@{
            name = 'tafseer_audio Qur''an data generator'
            version = '1.0.0'
            entry_point = 'tool/quran_data/generator/generate.ps1'
            library = 'tool/quran_data/generator/quran_data_lib.psm1'
            acquisition_record = 'validation/source-acquisition.json'
        }
        sources = [ordered]@{
            arabic = $arabicSource
            english = $englishSource
            catalogue = $catalogueSource
        }
        totals = $totals
        basmala = $basmalaSummary
        surahs = $surahEntries.ToArray()
        content_checksum = [ordered]@{
            algorithm = 'SHA-256'
            scope = 'SHA-256 over sorted per-Surah file names and digests, each followed by a newline; generation timestamps are excluded.'
            value = $contentChecksum
            file_count = 114
        }
        validation = $manifestValidation
    }

    $manifestJson = (ConvertTo-JsonText -Value $manifest) + "`n"

    # Validate the manifest before writing it.
    $manifestParsed = $null
    try {
        $manifestParsed = $manifestJson | ConvertFrom-Json
    }
    catch {
        Add-Check -Id 'generated.manifest_parse' -Category 'manifest' -Description 'Generated manifest parses as JSON.' -Passed $false -Details $_.Exception.Message
        Assert-NoFailures -Stage 'manifest-in-memory'
    }

    Add-Check -Id 'generated.manifest_parse' -Category 'manifest' -Description 'Generated manifest parses as JSON.' -Passed ($null -ne $manifestParsed) -Details ('length={0}' -f $manifestJson.Length)

    $manifestStructureOk = (
        $null -ne $manifestParsed -and
        [string]$manifestParsed.schema_version -eq '1.0.0' -and
        [string]$manifestParsed.dataset_version -eq '1.0.0' -and
        (Test-OrdinalEqual -Left ([string]$manifestParsed.generated_at_utc) -Right $GeneratedAtUtc) -and
        $null -ne $manifestParsed.sources.arabic -and
        $null -ne $manifestParsed.sources.english -and
        $null -ne $manifestParsed.totals -and
        $null -ne $manifestParsed.basmala -and
        @($manifestParsed.surahs).Count -eq 114 -and
        $null -ne $manifestParsed.content_checksum -and
        $null -ne $manifestParsed.validation
    )
    Add-Check -Id 'generated.manifest_structure' -Category 'manifest' -Description 'Manifest contains schema, timestamp, sources, totals, Basmala summary, Surah entries, checksums and validation.' -Passed $manifestStructureOk -Details 'required top-level fields present'

    $manifestTotalsOk = (
        $null -ne $manifestParsed -and
        [int]$manifestParsed.totals.surahs -eq 114 -and
        [int]$manifestParsed.totals.ayahs -eq 6236 -and
        [int]$manifestParsed.totals.arabic_records -eq 6236 -and
        [int]$manifestParsed.totals.translation_records -eq 6236 -and
        [int]$manifestParsed.totals.sajdah_ayahs -eq 15
    )
    Add-Check -Id 'generated.manifest_totals' -Category 'manifest' -Description 'Manifest totals are 114 Surahs, 6,236 Ayahs, 6,236 Arabic records, 6,236 translations and 15 Sajdah Ayahs.' -Passed $manifestTotalsOk -Details ''

    $manifestSurahIssues = New-Object System.Collections.ArrayList
    if ($null -ne $manifestParsed) {
        $manifestSurahEntries = @($manifestParsed.surahs)
        if ($manifestSurahEntries.Count -ne 114) {
            [void]$manifestSurahIssues.Add(('count={0}' -f $manifestSurahEntries.Count))
        }
        foreach ($entry in $manifestSurahEntries) {
            $number = [int]$entry.number
            if (-not $surahRecordByNumber.ContainsKey($number)) {
                [void]$manifestSurahIssues.Add(('unexpected Surah {0}' -f $number))
                continue
            }
            $record = $surahRecordByNumber[$number]
            if ([int]$entry.ayah_count -ne [int]$record.AyahCount) {
                [void]$manifestSurahIssues.Add(('Surah {0} count' -f $number))
            }
            if (-not (Test-OrdinalEqual -Left ([string]$entry.sha256) -Right ([string]$record.Hash))) {
                [void]$manifestSurahIssues.Add(('Surah {0} sha256' -f $number))
            }
            if (-not (Test-OrdinalEqual -Left ([string]$entry.file) -Right ('surahs/{0}' -f $record.FileName))) {
                [void]$manifestSurahIssues.Add(('Surah {0} file' -f $number))
            }
        }
    }
    Add-Check -Id 'generated.manifest_surahs' -Category 'manifest' -Description 'Manifest per-Surah counts, file names and SHA-256 checksums match the generated files.' -Passed ($manifestSurahIssues.Count -eq 0) -Details (Format-KeyList -Items $manifestSurahIssues)

    $manifestChecksumOk = (
        $null -ne $manifestParsed -and
        [string]$manifestParsed.content_checksum.algorithm -eq 'SHA-256' -and
        (Test-OrdinalEqual -Left ([string]$manifestParsed.content_checksum.value) -Right $actualContentChecksum) -and
        [int]$manifestParsed.content_checksum.file_count -eq 114
    )
    Add-Check -Id 'generated.manifest_checksums' -Category 'manifest' -Description 'Manifest content checksum matches the post-write per-Surah checksums.' -Passed $manifestChecksumOk -Details ('value={0}' -f $actualContentChecksum)

    $manifestNoticesOk = (
        $null -ne $manifestParsed -and
        (Test-OrdinalEqual -Left ([string]$manifestParsed.sources.arabic.notice) -Right $xml.CopyrightBlock) -and
        (Test-OrdinalEqual -Left ([string]$manifestParsed.sources.english.source_info_block) -Right $csv.InfoBlock) -and
        (Test-OrdinalEqual -Left ([string]$manifestParsed.sources.english.attribution) -Right 'Noor International Center, through QuranEnc.') -and
        (Test-OrdinalEqual -Left ([string]$manifestParsed.sources.english.license_terms) -Right ([string]$acquisition.english.license_terms)) -and
        (Test-OrdinalEqual -Left ([string]$manifestParsed.sources.arabic.copyright) -Right ([string]$acquisition.arabic.copyright)) -and
        (Test-OrdinalEqual -Left ([string]$manifestParsed.sources.arabic.license) -Right 'Creative Commons Attribution 3.0')
    )
    Add-Check -Id 'generated.manifest_notices' -Category 'manifest' -Description 'Manifest preserves the exact Tanzil copyright block, QuranEnc preamble, attribution and Terms and Policies.' -Passed $manifestNoticesOk -Details 'notices compared with exact ordinal equality'

    Assert-NoFailures -Stage 'manifest-in-memory'

    # Now that all manifest checks have run, record the final check counts.
    $manifest.validation.checks_total = [int]$script:checks.Count
    $manifest.validation.checks_passed = [int]@($script:checks | Where-Object { $_.passed }).Count
    $manifest.validation.checks_failed = [int]$script:failures.Count
    $manifestJson = (ConvertTo-JsonText -Value $manifest) + "`n"

    $manifestReparsed = $null
    try {
        $manifestReparsed = $manifestJson | ConvertFrom-Json
    }
    catch {
        throw ("Generated manifest is not valid JSON after updating validation counts: {0}" -f $_.Exception.Message)
    }
    if ([int]$manifestReparsed.validation.checks_total -ne $script:checks.Count) {
        throw 'Manifest validation count update did not round-trip.'
    }

    if ([System.IO.File]::Exists($manifestPath)) {
        $existingManifest = Read-Utf8TextFile -Path $manifestPath
        if (-not (Test-OrdinalEqual -Left $existingManifest -Right $manifestJson) -and -not $Force) {
            throw "Refusing to overwrite an existing manifest with different content: $manifestPath. Inspect it first, then re-run with -Force only if intentional."
        }
    }

    $manifestWriteResult = Write-GeneratedFile -Path $manifestPath -Content $manifestJson -Force:$Force
    $manifestHash = Get-Sha256Hex -Path $manifestPath
    $manifestSize = (Get-Item -LiteralPath $manifestPath).Length

    $manifestReadback = $null
    try {
        $manifestReadback = (Read-Utf8TextFile -Path $manifestPath) | ConvertFrom-Json
    }
    catch {
        Add-Check -Id 'generated.manifest_readback' -Category 'manifest' -Description 'Written manifest re-parses and preserves its required metadata.' -Passed $false -Details $_.Exception.Message
        Assert-NoFailures -Stage 'manifest-readback'
    }

    $manifestReadbackOk = (
        $null -ne $manifestReadback -and
        [string]$manifestReadback.schema_version -eq '1.0.0' -and
        [int]$manifestReadback.totals.surahs -eq 114 -and
        [int]$manifestReadback.totals.ayahs -eq 6236 -and
        @($manifestReadback.surahs).Count -eq 114 -and
        (Test-OrdinalEqual -Left ([string]$manifestReadback.content_checksum.value) -Right $actualContentChecksum) -and
        [string]$manifestReadback.validation.status -eq 'passed'
    )
    Add-Check -Id 'generated.manifest_readback' -Category 'manifest' -Description 'Written manifest re-parses and preserves its required metadata.' -Passed $manifestReadbackOk -Details ('sha256={0}; size={1}' -f $manifestHash, $manifestSize)

    $allJsonFilesParse = (
        $postParseIssues.Count -eq 0 -and
        $null -ne $manifestReadback
    )
    Add-Check -Id 'generated.json_files_parse' -Category 'generated' -Description 'All 115 generated JSON files (114 Surahs plus the manifest) parse successfully.' -Passed $allJsonFilesParse -Details '114 Surah files + manifest'

    # ---------------------------------------------------------------
    # Reports
    # ---------------------------------------------------------------

    function Format-MarkdownCell {
        param(
            [AllowNull()]
            [string]$Text
        )

        if ($null -eq $Text) {
            return ''
        }

        $value = $Text.Replace("`r", ' ').Replace("`n", ' ').Replace('|', '\|')
        if ($value.Length -gt 300) {
            $value = $value.Substring(0, 297) + '...'
        }
        return $value
    }

    $checksArray = $script:checks.ToArray()
    $checksPassed = @($script:checks | Where-Object { $_.passed }).Count
    $checksFailed = $script:failures.Count
    $reportStatus = if ($checksFailed -eq 0) { 'passed' } else { 'failed' }

    $generatedFileEntries = New-Object System.Collections.ArrayList
    foreach ($record in ($surahRecords | Sort-Object Number)) {
        $path = Join-Path $surahsOutDir $record.FileName
        [void]$generatedFileEntries.Add([ordered]@{
            file = ('surahs/{0}' -f $record.FileName)
            ayah_count = [int]$record.AyahCount
            size_bytes = [long](Get-Item -LiteralPath $path).Length
            sha256 = [string]$actualHashes[$record.Number]
        })
    }

    $totalGeneratedSize = [long]$surahFilesTotalSize + [long]$manifestSize
    $createdCount = @($writeStatuses.Values | Where-Object { $_ -eq 'created' }).Count
    $unchangedCount = @($writeStatuses.Values | Where-Object { $_ -eq 'unchanged' }).Count
    $replacedCount = @($writeStatuses.Values | Where-Object { $_ -eq 'replaced' }).Count

    $readOnlyGuard = [ordered]@{
        catalogue_path = 'assets/data/surahs.json'
        catalogue_sha256 = $catalogueHashAfter
        catalogue_unchanged = (Test-OrdinalEqual -Left $catalogueHashAfter -Right $catalogueHashBefore)
        pubspec_sha256 = $pubspecHashAfter
        pubspec_unchanged = (Test-OrdinalEqual -Left $pubspecHashAfter -Right $pubspecHashBefore)
        app_quran_dir_exists = $appQuranDirExistedAfter
        app_quran_dir_created = ($appQuranDirExistedAfter -and -not $appQuranDirExistedBefore)
    }

    $report = [ordered]@{
        status = $reportStatus
        generated_at_utc = $GeneratedAtUtc
        schema_version = '1.0.0'
        dataset_version = '1.0.0'
        source_acquisition_record = 'validation/source-acquisition.json'
        acquired_at_utc = [string]$acquisition.acquired_at_utc
        sources = [ordered]@{
            arabic = $arabicSource
            english = $englishSource
            catalogue = $catalogueSource
        }
        totals = $totals
        basmala = $basmalaSummary
        marker_counts = [ordered]@{
            pause_marks = [int]$markerTotals.PauseMarks
            rub_el_hizb_marks = [int]$markerTotals.RubElHizb
            sajdah_marks = [int]$markerTotals.Sajdah
            tatweel_characters = [int]$markerTotals.Tatweel
        }
        sajdah_locations = @($sajdahLocations)
        spot_checks = $spotChecks.ToArray()
        checks_total = [int]$script:checks.Count
        checks_passed = [int]$checksPassed
        checks_failed = [int]$checksFailed
        checks = $checksArray
        generated_files = [ordered]@{
            surah_file_count = 114
            surah_files_total_size_bytes = [long]$surahFilesTotalSize
            manifest_file = 'manifest.json'
            manifest_size_bytes = [long]$manifestSize
            total_size_bytes = [long]$totalGeneratedSize
            surah_files = $generatedFileEntries.ToArray()
        }
        manifest_sha256 = $manifestHash
        content_checksum = [ordered]@{
            algorithm = 'SHA-256'
            scope = 'SHA-256 over sorted per-Surah file names and digests, each followed by a newline; generation timestamps are excluded.'
            value = $actualContentChecksum
        }
        write_statuses = [ordered]@{
            surah_files_created = [int]$createdCount
            surah_files_unchanged = [int]$unchangedCount
            surah_files_replaced = [int]$replacedCount
            manifest_status = [string]$manifestWriteResult.Status
        }
        read_only_guard = $readOnlyGuard
    }

    $reportJson = (ConvertTo-JsonText -Value $report) + "`n"
    $reportPath = Join-Path $validationDir 'validation-report.json'
    [void](Write-GeneratedFile -Path $reportPath -Content $reportJson -Force:$true)

    $spotCheckReport = [ordered]@{
        generated_at_utc = $GeneratedAtUtc
        source_hashes = [ordered]@{
            arabic = [string]$acquisition.arabic.sha256
            english = [string]$acquisition.english.sha256
        }
        checks = $spotChecks.ToArray()
    }
    $spotCheckPath = Join-Path $validationDir 'spot-checks.json'
    [void](Write-GeneratedFile -Path $spotCheckPath -Content ((ConvertTo-JsonText -Value $spotCheckReport) + "`n") -Force:$true)

    # Human-readable report.
    $lines = New-Object System.Collections.ArrayList
    [void]$lines.Add('# Qur''an Data Generation and Validation Report')
    [void]$lines.Add('')
    [void]$lines.Add(('- Status: **{0}**' -f $reportStatus.ToUpperInvariant()))
    [void]$lines.Add(('- Generated at (UTC): `{0}`' -f $GeneratedAtUtc))
    [void]$lines.Add(('- Schema version: `1.0.0`; dataset version: `1.0.0`'))
    [void]$lines.Add(('- Acquisition record: `validation/source-acquisition.json`'))
    [void]$lines.Add('')
    [void]$lines.Add('## Source provenance')
    [void]$lines.Add('')
    [void]$lines.Add('| Source | Version | File | Size (bytes) | SHA-256 |')
    [void]$lines.Add('| --- | --- | --- | ---: | --- |')
    [void]$lines.Add(('| Tanzil Uthmani | {0} | `{1}` | {2} | `{3}` |' -f $arabicSource.version, $arabicSource.file, $arabicSource.size_bytes, $arabicSource.sha256))
    [void]$lines.Add(('| QuranEnc english_saheeh | {0} ({1}) | `{2}` | {3} | `{4}` |' -f $englishSource.version, $englishSource.revision, $englishSource.file, $englishSource.size_bytes, $englishSource.sha256))
    [void]$lines.Add('')
    [void]$lines.Add(('Tanzil: {0}. Licence: {1}.' -f $arabicSource.copyright, $arabicSource.license))
    [void]$lines.Add(('QuranEnc attribution: {0} Licence: {1} ({2}).' -f $englishSource.attribution, $englishSource.license, $englishSource.license_url))
    [void]$lines.Add('')
    [void]$lines.Add('## Totals')
    [void]$lines.Add('')
    [void]$lines.Add(('- Surahs: {0}' -f $totals.surahs))
    [void]$lines.Add(('- Ayahs: {0}' -f $totals.ayahs))
    [void]$lines.Add(('- Arabic records: {0}' -f $totals.arabic_records))
    [void]$lines.Add(('- Translation records: {0}' -f $totals.translation_records))
    [void]$lines.Add(('- Footnote records: {0} (non-empty: {1}; embedded newlines: {2}; quotes: {3})' -f $totals.footnote_records, $totals.footnotes_nonempty, $totals.footnotes_with_embedded_newlines, $totals.footnotes_with_quotes))
    [void]$lines.Add(('- Sajdah Ayahs: {0}' -f $totals.sajdah_ayahs))
    [void]$lines.Add(('- Pause marks: {0}; rub-el-hizb marks: {1}; tatweel characters: {2}' -f $totals.pause_marks, $totals.rub_el_hizb_marks, $totals.tatweel_characters))
    [void]$lines.Add('')
    [void]$lines.Add('## Sajdah locations')
    [void]$lines.Add('')
    [void]$lines.Add((@($sajdahLocations | ForEach-Object { '`' + $_ + '`' }) -join ', '))
    [void]$lines.Add('')
    [void]$lines.Add('## Validation checks')
    [void]$lines.Add('')
    [void]$lines.Add('| ID | Result | Description | Details |')
    [void]$lines.Add('| --- | --- | --- | --- |')
    foreach ($check in $checksArray) {
        $result = if ($check.passed) { 'PASS' } else { 'FAIL' }
        [void]$lines.Add(('| `{0}` | {1} | {2} | {3} |' -f $check.id, $result, (Format-MarkdownCell -Text $check.description), (Format-MarkdownCell -Text $check.details)))
    }
    [void]$lines.Add('')
    [void]$lines.Add('## Spot checks')
    [void]$lines.Add('')
    [void]$lines.Add('| Key | Arabic | Translation | Footnotes | Sajdah | Starts with Basmala | Basmala prepended |')
    [void]$lines.Add('| --- | --- | --- | --- | --- | --- | --- |')
    foreach ($spot in $spotChecks) {
        [void]$lines.Add(('| `{0}` | {1} | {2} | {3} | {4} | {5} | {6} |' -f $spot.key, $spot.arabic_matches_source, $spot.translation_matches_source, $spot.footnotes_matches_source, $spot.sajdah_matches_source, $spot.starts_with_standard_basmala, $spot.basmala_prepended_to_ayah))
    }
    [void]$lines.Add('')
    [void]$lines.Add('## Generated output')
    [void]$lines.Add('')
    [void]$lines.Add(('- Surah JSON files: 114'))
    [void]$lines.Add(('- Surah files total size: {0} bytes' -f $surahFilesTotalSize))
    [void]$lines.Add(('- Manifest: `generated/manifest.json` ({0} bytes, SHA-256 `{1}`)' -f $manifestSize, $manifestHash))
    [void]$lines.Add(('- Total generated size: {0} bytes' -f $totalGeneratedSize))
    [void]$lines.Add(('- Content checksum (timestamps excluded): `{0}`' -f $actualContentChecksum))
    [void]$lines.Add('')
    [void]$lines.Add('## Read-only guard')
    [void]$lines.Add('')
    [void]$lines.Add(('- `assets/data/surahs.json` unchanged: {0} (SHA-256 `{1}`)' -f $readOnlyGuard.catalogue_unchanged, $readOnlyGuard.catalogue_sha256))
    [void]$lines.Add(('- `pubspec.yaml` unchanged: {0} (SHA-256 `{1}`)' -f $readOnlyGuard.pubspec_unchanged, $readOnlyGuard.pubspec_sha256))
    [void]$lines.Add(('- `assets/data/quran/` created by this run: {0}' -f $readOnlyGuard.app_quran_dir_created))
    [void]$lines.Add('')
    [void]$lines.Add('## Notes')
    [void]$lines.Add('')
    [void]$lines.Add('- The original XML and CSV remain unmodified under `sources/`; they are not bundled as Flutter assets.')
    [void]$lines.Add('- The English attribution is the official QuranEnc attribution; no unconfirmed translator identity is asserted.')
    [void]$lines.Add('- Surah JSON files contain no generation timestamp. The manifest timestamp is excluded from the content checksum.')
    [void]$lines.Add('- An independent verification pass is provided by `generator/validate.ps1` and writes `validation/independent-validation.json`.')
    [void]$lines.Add('- This run does not implement or modify reader UI, audio, Tafseer catalogue, navigation, theme, settings or `pubspec.yaml`.')

    $markdownPath = Join-Path $validationDir 'validation-report.md'
    [void](Write-GeneratedFile -Path $markdownPath -Content (($lines -join "`n") + "`n") -Force:$true)

    $checksumLines = New-Object System.Collections.ArrayList
    [void]$checksumLines.Add(('{0}  generated/manifest.json' -f $manifestHash))
    foreach ($record in ($surahRecords | Sort-Object Number)) {
        [void]$checksumLines.Add(('{0}  generated/surahs/{1}' -f $actualHashes[$record.Number], $record.FileName))
    }
    [void]$checksumLines.Add(('{0}  {1}' -f $arabicSource.sha256, $arabicSource.file))
    [void]$checksumLines.Add(('{0}  {1}' -f $englishSource.sha256, $englishSource.file))
    $checksumsPath = Join-Path $validationDir 'checksums.sha256'
    [void](Write-GeneratedFile -Path $checksumsPath -Content (($checksumLines -join "`n") + "`n") -Force:$true)

    if ($checksFailed -gt 0) {
        Write-FailureReport -Stage 'final' -Message ("{0} validation check(s) failed." -f $checksFailed)
        throw ("Validation failed with {0} failed check(s). See {1}" -f $checksFailed, $reportPath)
    }

    Write-Output ''
    Write-Output 'Generation and validation completed successfully.'
    Write-Output ("Surahs: {0}; Ayahs: {1}; Arabic records: {2}; translations: {3}" -f $totals.surahs, $totals.ayahs, $totals.arabic_records, $totals.translation_records)
    Write-Output ("Surah files: {0} (created {1}, unchanged {2}, replaced {3}); total {4} bytes" -f $surahRecords.Count, $createdCount, $unchangedCount, $replacedCount, $surahFilesTotalSize)
    Write-Output ("Manifest: {0} ({1} bytes, SHA-256 {2}, status {3})" -f $manifestPath, $manifestSize, $manifestHash, $manifestWriteResult.Status)
    Write-Output ("Content checksum: {0}" -f $actualContentChecksum)
    Write-Output ("Validation: {0}/{1} checks passed; report: {2}" -f $checksPassed, $script:checks.Count, $reportPath)
    Write-Output ("Checksums: {0}" -f $checksumsPath)
}
catch {
    try {
        Write-FailureReport -Stage 'exception' -Message $_.Exception.Message
    }
    catch {
        # Preserve the original exception even if writing the failure report fails.
    }
    throw
}
