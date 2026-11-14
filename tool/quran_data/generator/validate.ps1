# Independent validation pass over the acquired sources, manifest and generated Surah files.
# Run from anywhere:
#   powershell -ExecutionPolicy Bypass -File tool/quran_data/generator/validate.ps1
#
# This script only reads the sources and generated dataset. Its sole output is
# tool/quran_data/validation/independent-validation.json.
#
# It does not reuse the generator's control flow or validation results: it
# re-parses both original sources and re-derives every result from them.

[CmdletBinding()]
param(
    [string]$ValidatedAtUtc = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'quran_data_lib.psm1') -Force

$quranDataRoot = Split-Path -Parent $PSScriptRoot
$toolRoot = Split-Path -Parent $quranDataRoot
$projectRoot = Split-Path -Parent $toolRoot

$sourcesDir = Join-Path $quranDataRoot 'sources'
$generatedDir = Join-Path $quranDataRoot 'generated'
$surahsDir = Join-Path $generatedDir 'surahs'
$validationDir = Join-Path $quranDataRoot 'validation'
$acquisitionPath = Join-Path $validationDir 'source-acquisition.json'
$manifestPath = Join-Path $generatedDir 'manifest.json'
$generationReportPath = Join-Path $validationDir 'validation-report.json'
$checksumsPath = Join-Path $validationDir 'checksums.sha256'
$independentPath = Join-Path $validationDir 'independent-validation.json'
$cataloguePath = Join-Path $projectRoot 'assets\data\surahs.json'
$pubspecPath = Join-Path $projectRoot 'pubspec.yaml'
$appQuranDir = Join-Path $projectRoot 'assets\data\quran'

if ([string]::IsNullOrEmpty($ValidatedAtUtc)) {
    $ValidatedAtUtc = Get-UtcTimestamp
}

if ($ValidatedAtUtc -notmatch '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$') {
    throw 'ValidatedAtUtc must look like 2026-11-13T12:34:56Z.'
}

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

function Get-JsonProperty {
    param(
        [AllowNull()]
        $Object,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $Object) {
        return $null
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Test-JsonProperty {
    param(
        [AllowNull()]
        $Object,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $Object) {
        return $false
    }

    return ($null -ne $Object.PSObject.Properties[$Name])
}

function Test-KeySet {
    param(
        [AllowNull()]
        $Object,
        [Parameter(Mandatory = $true)]
        [string[]]$Expected
    )

    if ($null -eq $Object) {
        return $false
    }

    $actual = @($Object.PSObject.Properties.Name)
    if ($actual.Count -ne $Expected.Count) {
        return $false
    }

    foreach ($key in $Expected) {
        if ($actual -notcontains $key) {
            return $false
        }
    }

    return $true
}

function Format-IssueList {
    param(
        [System.Collections.ArrayList]$Items,
        [int]$Maximum = 6
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

function Get-MarkerCounts {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text
    )

    return [pscustomobject]@{
        Pause = [regex]::Matches($Text, '[\u06D6-\u06DC]').Count
        Rub = [regex]::Matches($Text, [regex]::Escape([string][char]0x06DE)).Count
        Sajdah = [regex]::Matches($Text, [regex]::Escape([string][char]0x06E9)).Count
        Tatweel = [regex]::Matches($Text, [regex]::Escape([string][char]0x0640)).Count
    }
}

function Add-TextSetCheck {
    param(
        [string]$Id,
        [string]$Category,
        [string]$Description,
        [System.Collections.ArrayList]$Issues,
        [string]$SuccessDetails = ''
    )

    $details = if ($Issues.Count -eq 0) { $SuccessDetails } else { Format-IssueList -Items $Issues }
    Add-Check -Id $Id -Category $Category -Description $Description -Passed ($Issues.Count -eq 0) -Details $details
}

$expectedTanzilUrl = 'https://tanzil.net/pub/download/index.php?agree=true&marks=true&outType=xml&quranType=uthmani&sajdah=true&rub=true&tatweel=true'
$expectedTanzilUpdatesUrl = 'https://tanzil.net/docs/text_updates'
$expectedQuranEncUrl = 'https://quranenc.com/en/home/d/csv/english_saheeh'
$expectedQuranEncBrowseUrl = 'https://quranenc.com/en/browse/english_saheeh'
$expectedQuranEncLicenseUrl = 'https://quranenc.com/en/home/about'
$expectedQuranEncTermsPrefix = 'Contents of the translations can be downloaded and re-published'
$expectedAttribution = 'Noor International Center, through QuranEnc.'
$expectedPublisher = 'Noor International Center'
$expectedSajdahKeys = @(
    '7:206', '13:15', '16:50', '17:109', '19:58', '22:18', '22:77',
    '25:60', '27:26', '32:15', '38:24', '41:38', '53:62', '84:21', '96:19'
)
$expectedSpotKeys = @('1:1', '1:2', '2:1', '9:1', '114:6')
$requiredManifestTopLevel = @(
    'schema_version', 'dataset_version', 'generated_at_utc', 'generator',
    'sources', 'totals', 'basmala', 'surahs', 'content_checksum', 'validation'
)

$acquisition = $null
$manifest = $null
$catalogue = $null
$xml = $null
$csv = $null
$generationReport = $null

$manifestInfo = [ordered]@{}
$sourceInfo = [ordered]@{}
$catalogueInfo = [ordered]@{}
$generatedInfo = [ordered]@{}
$recomputedTotals = [ordered]@{}
$contentChecksumInfo = [ordered]@{}
$generationCrossCheck = [ordered]@{}
$readOnlyGuard = [ordered]@{}
$spotCheckRecords = New-Object System.Collections.ArrayList
$sajdahKeys = New-Object System.Collections.ArrayList
$actualSajdahKeys = @()
$fatalMessage = ''

try {
    # ---------------------------------------------------------------
    # Acquisition record and original source integrity
    # ---------------------------------------------------------------

    if (-not [System.IO.File]::Exists($acquisitionPath)) {
        throw "Missing acquisition record: $acquisitionPath"
    }

    $acquisitionText = Read-Utf8TextFile -Path $acquisitionPath
    $acquisition = $acquisitionText | ConvertFrom-Json

    Add-Check -Id 'acquisition.record' -Category 'sources' -Description 'Acquisition record parses and records both sources.' -Passed (
        $null -ne $acquisition.arabic -and $null -ne $acquisition.english
    ) -Details ('path={0}; size={1} bytes; sha256={2}' -f $acquisitionPath, (Get-Item -LiteralPath $acquisitionPath).Length, (Get-Sha256Hex -Path $acquisitionPath))

    $acquiredAt = [string]$acquisition.acquired_at_utc
    Add-Check -Id 'acquisition.timestamp' -Category 'sources' -Description 'Acquisition timestamp is a valid UTC timestamp.' -Passed (
        $acquiredAt -match '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'
    ) -Details $acquiredAt

    $arabicRelative = ([string]$acquisition.arabic.file).Replace('/', '\')
    $englishRelative = ([string]$acquisition.english.file).Replace('/', '\')
    $arabicPath = Join-Path $quranDataRoot $arabicRelative
    $englishPath = Join-Path $quranDataRoot $englishRelative

    Add-Check -Id 'sources.paths' -Category 'sources' -Description 'Source file names and approved acquisition URLs are recorded exactly.' -Passed (
        [string]$acquisition.arabic.file -eq 'sources/tanzil-uthmani-v1.1.xml' -and
        [string]$acquisition.english.file -eq 'sources/quranenc-english_saheeh-v1.1.2.csv' -and
        [string]$acquisition.arabic.url -eq $expectedTanzilUrl -and
        [string]$acquisition.arabic.updates_url -eq $expectedTanzilUpdatesUrl -and
        [string]$acquisition.english.url -eq $expectedQuranEncUrl -and
        [string]$acquisition.english.browse_url -eq $expectedQuranEncBrowseUrl
    ) -Details ('arabic={0}; english={1}' -f $acquisition.arabic.file, $acquisition.english.file)

    $sourceActual = @{}
    foreach ($source in @(
        @{ Key = 'arabic'; Path = $arabicPath; Meta = $acquisition.arabic },
        @{ Key = 'english'; Path = $englishPath; Meta = $acquisition.english }
    )) {
        if (-not [System.IO.File]::Exists($source.Path)) {
            throw "Missing source file: $($source.Path)"
        }

        $actualSize = [long](Get-Item -LiteralPath $source.Path).Length
        $actualHash = Get-Sha256Hex -Path $source.Path
        $sourceActual[$source.Key] = [pscustomobject]@{
            Path = $source.Path
            Size = $actualSize
            Hash = $actualHash
        }

        Add-Check -Id ('sources.{0}.integrity' -f $source.Key) -Category 'sources' -Description 'Source file size and SHA-256 match the acquisition record.' -Passed (
            $actualSize -eq [long]$source.Meta.size_bytes -and
            (Test-OrdinalEqual -Left $actualHash -Right ([string]$source.Meta.sha256))
        ) -Details ('size={0} (record {1}); sha256={2} (record {3})' -f $actualSize, [long]$source.Meta.size_bytes, $actualHash, [string]$source.Meta.sha256)

        Add-Check -Id ('sources.{0}.encoding' -f $source.Key) -Category 'sources' -Description 'Source file is valid UTF-8 without a BOM.' -Passed (-not (Test-Utf8Bom -Path $source.Path)) -Details $source.Path
    }

    $sourceInfo = [ordered]@{
        arabic = [ordered]@{
            path = $arabicPath
            size_bytes = [long]$sourceActual['arabic'].Size
            sha256 = [string]$sourceActual['arabic'].Hash
            version = [string]$acquisition.arabic.version
            release_date = [string]$acquisition.arabic.release_date
            copyright = [string]$acquisition.arabic.copyright
            license = [string]$acquisition.arabic.license
        }
        english = [ordered]@{
            path = $englishPath
            size_bytes = [long]$sourceActual['english'].Size
            sha256 = [string]$sourceActual['english'].Hash
            version = [string]$acquisition.english.version
            revision = [string]$acquisition.english.revision
            last_update_unix = [long]$acquisition.english.last_update_unix
            last_update_utc = [string]$acquisition.english.last_update_utc
            publisher = [string]$acquisition.english.publisher
            attribution = [string]$acquisition.english.attribution
        }
    }

    Add-Check -Id 'sources.versions' -Category 'sources' -Description 'Reviewed Tanzil and QuranEnc versions and update metadata are recorded exactly.' -Passed (
        [string]$acquisition.arabic.version -eq '1.1' -and
        [string]$acquisition.arabic.release_date -eq '2021-02-12' -and
        [string]$acquisition.english.version -eq '1.1.2' -and
        [string]$acquisition.english.revision -eq 'v1.1.2-csv.1' -and
        [long]$acquisition.english.last_update_unix -eq 1750772247 -and
        [string]$acquisition.english.last_update_utc -eq '2025-06-24T13:37:27Z' -and
        [string]$acquisition.english.last_update_source_text -eq '2025-06-24 16:37:27'
    ) -Details ('Tanzil {0} ({1}); QuranEnc {2} ({3}); last update {4}' -f $acquisition.arabic.version, $acquisition.arabic.release_date, $acquisition.english.version, $acquisition.english.revision, $acquisition.english.last_update_utc)

    Add-Check -Id 'sources.attribution' -Category 'sources' -Description 'Official Noor International Center attribution is recorded without an unconfirmed translator claim.' -Passed (
        (Test-OrdinalEqual -Left ([string]$acquisition.english.publisher) -Right $expectedPublisher) -and
        (Test-OrdinalEqual -Left ([string]$acquisition.english.attribution) -Right $expectedAttribution)
    ) -Details ([string]$acquisition.english.attribution)

    Add-Check -Id 'sources.license' -Category 'sources' -Description 'QuranEnc Terms and Policies are recorded with the official URL and full wording.' -Passed (
        [string]$acquisition.english.license -eq 'QuranEnc Terms and Policies' -and
        [string]$acquisition.english.license_url -eq $expectedQuranEncLicenseUrl -and
        ([string]$acquisition.english.license_terms).StartsWith($expectedQuranEncTermsPrefix, [System.StringComparison]::Ordinal)
    ) -Details ([string]$acquisition.english.license_url)

    # ---------------------------------------------------------------
    # Re-parse the original sources independently
    # ---------------------------------------------------------------

    $xml = Read-TanzilXml -Path $arabicPath
    $csv = Read-QuranEncCsv -Path $englishPath

    $xmlHeader = Read-Utf8TextFile -Path $arabicPath
    $xmlHeader = $xmlHeader.Substring(0, [System.Math]::Min(200, $xmlHeader.Length))

    $sourceAyahTotal = 0
    foreach ($sura in $xml.Suras) {
        $sourceAyahTotal += @($sura.Ayahs).Count
    }

    Add-Check -Id 'sources.arabic.structure' -Category 'sources' -Description 'Tanzil XML contains 114 Surahs and 6,236 Ayahs.' -Passed (
        @($xml.Suras).Count -eq 114 -and $sourceAyahTotal -eq 6236
    ) -Details ('surahs={0}; ayahs={1}' -f @($xml.Suras).Count, $sourceAyahTotal)

    Add-Check -Id 'sources.english.structure' -Category 'sources' -Description 'QuranEnc CSV contains 6,236 records from 1:1 through 114:6.' -Passed (
        @($csv.Rows).Count -eq 6236 -and
        [int]$csv.Rows[0].Id -eq 1 -and [int]$csv.Rows[0].Sura -eq 1 -and [int]$csv.Rows[0].Aya -eq 1 -and
        [int]$csv.Rows[$csv.Rows.Count - 1].Id -eq 6236 -and
        [int]$csv.Rows[$csv.Rows.Count - 1].Sura -eq 114 -and
        [int]$csv.Rows[$csv.Rows.Count - 1].Aya -eq 6
    ) -Details ('records={0}' -f @($csv.Rows).Count)

    Add-Check -Id 'sources.arabic.notice' -Category 'sources' -Description 'Tanzil copyright block retains its version, licence and preservation notices.' -Passed (
        -not [string]::IsNullOrEmpty([string]$xml.CopyrightBlock) -and
        ([string]$xml.CopyrightBlock) -match 'PLEASE DO NOT REMOVE OR CHANGE THIS COPYRIGHT BLOCK' -and
        ([string]$xml.CopyrightBlock) -match 'Version 1\.1' -and
        ([string]$xml.CopyrightBlock) -match 'Copyright \(C\) 2007-2026 Tanzil Project' -and
        ([string]$xml.CopyrightBlock) -match 'License:\s+Creative Commons Attribution 3\.0' -and
        ([string]$xml.CopyrightBlock) -match 'CHANGING IT IS NOT ALLOWED'
    ) -Details ([string]$acquisition.arabic.copyright)

    Add-Check -Id 'sources.english.notice' -Category 'sources' -Description 'QuranEnc preamble retains its ID, version, update URL and preservation notice.' -Passed (
        -not [string]::IsNullOrEmpty([string]$csv.InfoBlock) -and
        ([string]$csv.InfoBlock) -match 'Translation ID:\s+english_saheeh' -and
        ([string]$csv.InfoBlock) -match [regex]::Escape('v1.1.2-csv.1') -and
        ([string]$csv.InfoBlock) -match [regex]::Escape('2025-06-24 16:37:27') -and
        ([string]$csv.InfoBlock) -match [regex]::Escape('https://quranenc.com/check/english_saheeh/v1.1.2-csv.1') -and
        ([string]$csv.InfoBlock) -match 'PLEASE DON''T REMOVE THIS IMPORTANT INFORMATION!'
    ) -Details 'QuranEnc InfoBlock present'

    Add-Check -Id 'sources.arabic.encoding' -Category 'sources' -Description 'Tanzil XML declares UTF-8 encoding.' -Passed (
        $xmlHeader -match 'encoding="utf-8"'
    ) -Details 'encoding="utf-8"'

    $surahSequenceIssues = New-Object System.Collections.ArrayList
    $actualSuraNumbers = @($xml.Suras | ForEach-Object { [int]$_.Number })
    if (($actualSuraNumbers -join ',') -ne ((1..114) -join ',')) {
        [void]$surahSequenceIssues.Add('Surah numbers are not 1..114 in order')
    }

    $ayahSequenceIssues = New-Object System.Collections.ArrayList
    foreach ($sura in $xml.Suras) {
        $actualNumbers = @($sura.Ayahs | ForEach-Object { [int]$_.Number })
        $expectedNumbers = @(1..@($sura.Ayahs).Count)
        if (($actualNumbers -join ',') -ne ($expectedNumbers -join ',')) {
            [void]$ayahSequenceIssues.Add(('Surah {0}' -f $sura.Number))
        }
    }

    Add-TextSetCheck -Id 'sources.arabic.sequences' -Category 'sources' -Description 'Surah and Ayah numbering are sequential in the original source.' -Issues $surahSequenceIssues -SuccessDetails '1..114; every Surah starts at Ayah 1'
    Add-TextSetCheck -Id 'sources.arabic.ayah_sequences' -Category 'sources' -Description 'Every Surah has contiguous Ayah numbering from 1.' -Issues $ayahSequenceIssues -SuccessDetails 'all 114 Surahs sequential'

    # Build source maps.
    $xmlBySura = @{}
    $xmlKeys = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($sura in $xml.Suras) {
        $number = [int]$sura.Number
        if ($xmlBySura.ContainsKey($number)) {
            throw ('Duplicate Surah {0} in Tanzil XML.' -f $number)
        }
        $xmlBySura[$number] = $sura
        foreach ($ayah in $sura.Ayahs) {
            [void]$xmlKeys.Add(('{0}:{1}' -f $number, [int]$ayah.Number))
        }
    }

    $csvByKey = @{}
    foreach ($row in $csv.Rows) {
        $key = '{0}:{1}' -f [int]$row.Sura, [int]$row.Aya
        if ($csvByKey.ContainsKey($key)) {
            throw ('Duplicate English record for {0}.' -f $key)
        }
        $csvByKey[$key] = $row
    }

    $missingEnglish = New-Object System.Collections.ArrayList
    foreach ($key in $xmlKeys) {
        if (-not $csvByKey.ContainsKey($key)) {
            [void]$missingEnglish.Add($key)
        }
    }

    $extraEnglish = New-Object System.Collections.ArrayList
    foreach ($key in $csvByKey.Keys) {
        if (-not $xmlKeys.Contains($key)) {
            [void]$extraEnglish.Add($key)
        }
    }

    $mappingDetails = if ($missingEnglish.Count -eq 0 -and $extraEnglish.Count -eq 0) {
        '6,236 one-to-one mappings'
    }
    else {
        'missing=[{0}]; extra=[{1}]' -f (Format-IssueList -Items $missingEnglish), (Format-IssueList -Items $extraEnglish)
    }
    Add-Check -Id 'sources.mapping' -Category 'sources' -Description 'Every Arabic Ayah has exactly one English record and vice versa.' -Passed (
        $missingEnglish.Count -eq 0 -and $extraEnglish.Count -eq 0 -and $csvByKey.Count -eq 6236
    ) -Details $mappingDetails

    # ---------------------------------------------------------------
    # Manifest
    # ---------------------------------------------------------------

    if (-not [System.IO.File]::Exists($manifestPath)) {
        throw "Missing manifest: $manifestPath"
    }

    $manifestSize = [long](Get-Item -LiteralPath $manifestPath).Length
    $manifestHash = Get-Sha256Hex -Path $manifestPath
    $manifestText = Read-Utf8TextFile -Path $manifestPath

    try {
        $manifest = $manifestText | ConvertFrom-Json
    }
    catch {
        throw ("Manifest is not valid JSON: {0}" -f $_.Exception.Message)
    }

    Add-Check -Id 'manifest.parse' -Category 'manifest' -Description 'Manifest parses as JSON and has the required top-level schema.' -Passed (
        (Test-KeySet -Object $manifest -Expected $requiredManifestTopLevel)
    ) -Details ('size={0}; sha256={1}' -f $manifestSize, $manifestHash)

    Add-Check -Id 'manifest.encoding' -Category 'manifest' -Description 'Manifest is UTF-8 without a BOM.' -Passed (-not (Test-Utf8Bom -Path $manifestPath)) -Details $manifestPath

    if (-not (Test-KeySet -Object $manifest -Expected $requiredManifestTopLevel)) {
        $actualKeys = @($manifest.PSObject.Properties.Name) -join ','
        throw ('Manifest top-level keys are invalid: {0}' -f $actualKeys)
    }

    $manifestInfo = [ordered]@{
        path = $manifestPath
        size_bytes = [long]$manifestSize
        sha256 = $manifestHash
        generated_at_utc = [string]$manifest.generated_at_utc
        schema_version = [string]$manifest.schema_version
        dataset_version = [string]$manifest.dataset_version
    }

    Add-Check -Id 'manifest.versions' -Category 'manifest' -Description 'Schema and dataset versions are 1.0.0 and the generation timestamp is UTC.' -Passed (
        [string]$manifest.schema_version -eq '1.0.0' -and
        [string]$manifest.dataset_version -eq '1.0.0' -and
        [string]$manifest.generated_at_utc -match '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'
    ) -Details ('schema={0}; dataset={1}; generated_at={2}' -f $manifest.schema_version, $manifest.dataset_version, $manifest.generated_at_utc)

    Add-Check -Id 'manifest.generator' -Category 'manifest' -Description 'Manifest identifies the generator entry point, library and acquisition record.' -Passed (
        [string]$manifest.generator.entry_point -eq 'tool/quran_data/generator/generate.ps1' -and
        [string]$manifest.generator.library -eq 'tool/quran_data/generator/quran_data_lib.psm1' -and
        [string]$manifest.generator.acquisition_record -eq 'validation/source-acquisition.json'
    ) -Details ([string]$manifest.generator.name)

    $manifestArabic = $manifest.sources.arabic
    $manifestEnglish = $manifest.sources.english
    $manifestCatalogue = $manifest.sources.catalogue

    Add-Check -Id 'manifest.sources' -Category 'manifest' -Description 'Manifest source metadata matches the acquisition record and actual source files.' -Passed (
        (Test-OrdinalEqual -Left ([string]$manifestArabic.sha256) -Right ([string]$sourceActual['arabic'].Hash)) -and
        [long]$manifestArabic.size_bytes -eq [long]$sourceActual['arabic'].Size -and
        [string]$manifestArabic.version -eq [string]$acquisition.arabic.version -and
        [string]$manifestArabic.release_date -eq [string]$acquisition.arabic.release_date -and
        (Test-OrdinalEqual -Left ([string]$manifestArabic.file) -Right ([string]$acquisition.arabic.file)) -and
        (Test-OrdinalEqual -Left ([string]$manifestEnglish.sha256) -Right ([string]$sourceActual['english'].Hash)) -and
        [long]$manifestEnglish.size_bytes -eq [long]$sourceActual['english'].Size -and
        [string]$manifestEnglish.version -eq [string]$acquisition.english.version -and
        [string]$manifestEnglish.revision -eq [string]$acquisition.english.revision -and
        [long]$manifestEnglish.last_update_unix -eq [long]$acquisition.english.last_update_unix -and
        (Test-OrdinalEqual -Left ([string]$manifestEnglish.file) -Right ([string]$acquisition.english.file))
    ) -Details ('arabic={0}; english={1}' -f $manifestArabic.sha256, $manifestEnglish.sha256)

    Add-Check -Id 'manifest.source_provenance' -Category 'manifest' -Description 'Manifest records the exact approved URLs, versions, copyright, licence and update metadata.' -Passed (
        [string]$manifestArabic.url -eq $expectedTanzilUrl -and
        [string]$manifestArabic.updates_url -eq $expectedTanzilUpdatesUrl -and
        [string]$manifestArabic.copyright -eq 'Copyright (C) 2007-2026 Tanzil Project' -and
        [string]$manifestArabic.license -eq 'Creative Commons Attribution 3.0' -and
        [string]$manifestEnglish.url -eq $expectedQuranEncUrl -and
        [string]$manifestEnglish.browse_url -eq $expectedQuranEncBrowseUrl -and
        [string]$manifestEnglish.version -eq '1.1.2' -and
        [string]$manifestEnglish.revision -eq 'v1.1.2-csv.1' -and
        [long]$manifestEnglish.last_update_unix -eq 1750772247 -and
        [string]$manifestEnglish.last_update_utc -eq '2025-06-24T13:37:27Z' -and
        [string]$manifestEnglish.last_update_source_text -eq '2025-06-24 16:37:27' -and
        [string]$manifestEnglish.publisher -eq $expectedPublisher -and
        [string]$manifestEnglish.attribution -eq $expectedAttribution -and
        [string]$manifestEnglish.license -eq 'QuranEnc Terms and Policies' -and
        [string]$manifestEnglish.license_url -eq $expectedQuranEncLicenseUrl
    ) -Details ('Tanzil {0}; QuranEnc {1} ({2})' -f $manifestArabic.version, $manifestEnglish.version, $manifestEnglish.revision)

    Add-Check -Id 'manifest.notices' -Category 'manifest' -Description 'Manifest preserves the exact Tanzil copyright block, QuranEnc preamble, attribution and Terms and Policies.' -Passed (
        (Test-OrdinalEqual -Left ([string]$manifestArabic.notice) -Right ([string]$xml.CopyrightBlock)) -and
        (Test-OrdinalEqual -Left ([string]$manifestEnglish.source_info_block) -Right ([string]$csv.InfoBlock)) -and
        (Test-OrdinalEqual -Left ([string]$manifestEnglish.attribution) -Right $expectedAttribution) -and
        [string]$manifestEnglish.publisher -eq $expectedPublisher -and
        [string]$manifestEnglish.license -eq 'QuranEnc Terms and Policies' -and
        [string]$manifestEnglish.license_url -eq $expectedQuranEncLicenseUrl -and
        ([string]$manifestEnglish.license_terms).StartsWith($expectedQuranEncTermsPrefix, [System.StringComparison]::Ordinal)
    ) -Details 'exact ordinal comparison'

    Add-Check -Id 'manifest.catalogue' -Category 'manifest' -Description 'Manifest records the existing Surah catalogue path and its current SHA-256.' -Passed (
        [string]$manifestCatalogue.path -eq 'assets/data/surahs.json' -and
        (Test-OrdinalEqual -Left ([string]$manifestCatalogue.sha256) -Right (Get-Sha256Hex -Path $cataloguePath))
    ) -Details ('sha256={0}' -f $manifestCatalogue.sha256)

    $manifestSurahEntries = @($manifest.surahs)
    $manifestEntryByNumber = @{}
    $manifestEntryIssues = New-Object System.Collections.ArrayList
    foreach ($entry in $manifestSurahEntries) {
        $number = [int](Get-JsonProperty -Object $entry -Name 'number')
        if ($number -lt 1 -or $number -gt 114) {
            [void]$manifestEntryIssues.Add(('invalid Surah {0}' -f $number))
            continue
        }
        if ($manifestEntryByNumber.ContainsKey($number)) {
            [void]$manifestEntryIssues.Add(('duplicate {0}' -f $number))
            continue
        }
        $manifestEntryByNumber[$number] = $entry

        $expectedFileName = 'surahs/{0:D3}.json' -f $number
        if (-not (Test-OrdinalEqual -Left ([string]$entry.file) -Right $expectedFileName)) {
            [void]$manifestEntryIssues.Add(('Surah {0} file={1}' -f $number, $entry.file))
        }
    }

    for ($n = 1; $n -le 114; $n++) {
        if (-not $manifestEntryByNumber.ContainsKey($n)) {
            [void]$manifestEntryIssues.Add(('missing {0}' -f $n))
        }
    }

    $manifestEntryDetails = if ($manifestEntryIssues.Count -eq 0) { '114 entries' } else { Format-IssueList -Items $manifestEntryIssues }
    Add-Check -Id 'manifest.surah_entries' -Category 'manifest' -Description 'Manifest has one unique entry for every Surah with the expected file name.' -Passed (
        $manifestSurahEntries.Count -eq 114 -and $manifestEntryIssues.Count -eq 0
    ) -Details $manifestEntryDetails

    Add-Check -Id 'manifest.validation_summary' -Category 'manifest' -Description 'Manifest records a passed generation-stage validation summary and the 15 Sajdah locations.' -Passed (
        [string]$manifest.validation.status -eq 'passed' -and
        [int]$manifest.validation.checks_failed -eq 0 -and
        [int]$manifest.validation.checks_total -eq [int]$manifest.validation.checks_passed -and
        [int]$manifest.validation.generated_surah_files_parsed -eq 114 -and
        [bool]$manifest.validation.source_hashes_verified -and
        [bool]$manifest.validation.catalogue_counts_verified -and
        ((@($manifest.validation.sajdah_locations) -join ',') -eq ($expectedSajdahKeys -join ',')) -and
        ((@($manifest.validation.spot_checks) -join ',') -eq ($expectedSpotKeys -join ','))
    ) -Details ('status={0}; checks={1}/{2}' -f $manifest.validation.status, $manifest.validation.checks_passed, $manifest.validation.checks_total)

    # ---------------------------------------------------------------
    # Existing application catalogue (read-only)
    # ---------------------------------------------------------------

    $catalogueText = Read-Utf8TextFile -Path $cataloguePath
    $catalogue = $catalogueText | ConvertFrom-Json
    $catalogueSurahs = @($catalogue.surahs)
    $catalogueByNumber = @{}
    $catalogueIssues = New-Object System.Collections.ArrayList
    $catalogueTotal = 0

    foreach ($entry in $catalogueSurahs) {
        $number = [int]$entry.number
        if ($number -lt 1 -or $number -gt 114) {
            [void]$catalogueIssues.Add(('invalid Surah {0}' -f $number))
            continue
        }
        if ($catalogueByNumber.ContainsKey($number)) {
            [void]$catalogueIssues.Add(('duplicate {0}' -f $number))
            continue
        }
        $catalogueByNumber[$number] = $entry
        $catalogueTotal += [int]$entry.ayah_count
    }

    for ($n = 1; $n -le 114; $n++) {
        if (-not $catalogueByNumber.ContainsKey($n)) {
            [void]$catalogueIssues.Add(('missing {0}' -f $n))
        }
    }

    $catalogueInfo = [ordered]@{
        path = $cataloguePath
        sha256 = Get-Sha256Hex -Path $cataloguePath
        surah_count = [int]$catalogueSurahs.Count
        total_ayahs = [int]$catalogueTotal
    }

    $catalogueDetails = if ($catalogueIssues.Count -eq 0) { 'surahs=114; ayahs=6236' } else { Format-IssueList -Items $catalogueIssues }
    Add-Check -Id 'catalogue.structure' -Category 'catalogue' -Description 'Existing assets/data/surahs.json contains 114 unique Surahs and totals 6,236 Ayahs.' -Passed (
        $catalogueSurahs.Count -eq 114 -and $catalogueIssues.Count -eq 0 -and $catalogueTotal -eq 6236
    ) -Details $catalogueDetails

    # ---------------------------------------------------------------
    # Source-specific Basmala, marker and footnote baselines
    # ---------------------------------------------------------------

    $standardBasmala = [string]$xmlBySura[2].Ayahs[0].Bismillah
    $special95 = [string]$xmlBySura[95].Ayahs[0].Bismillah
    $special97 = [string]$xmlBySura[97].Ayahs[0].Bismillah

    $sourceBasmalaIssues = New-Object System.Collections.ArrayList
    $bismillahAttributeCount = 0
    foreach ($sura in $xml.Suras) {
        $number = [int]$sura.Number
        $attributes = @($sura.Ayahs | Where-Object { $null -ne $_.Bismillah })
        $bismillahAttributeCount += $attributes.Count

        if ($number -eq 1 -or $number -eq 9) {
            if ($attributes.Count -ne 0) {
                [void]$sourceBasmalaIssues.Add(('Surah {0} has {1} attributes' -f $number, $attributes.Count))
            }
        }
        else {
            if ($attributes.Count -ne 1) {
                [void]$sourceBasmalaIssues.Add(('Surah {0} has {1} attributes' -f $number, $attributes.Count))
            }
            elseif ([int]$attributes[0].Number -ne 1) {
                [void]$sourceBasmalaIssues.Add(('Surah {0} attribute on Ayah {1}' -f $number, $attributes[0].Number))
            }
            elseif ([string]::IsNullOrEmpty([string]$attributes[0].Bismillah)) {
                [void]$sourceBasmalaIssues.Add(('Surah {0} has empty Basmala' -f $number))
            }
        }
    }

    $sourceBasmalaDetails = if ($sourceBasmalaIssues.Count -eq 0) { '112 attributes' } else { Format-IssueList -Items $sourceBasmalaIssues }
    Add-Check -Id 'sources.basmala_structure' -Category 'basmala' -Description 'Tanzil source has 112 prefatory Basmalas, all on first Ayahs, with none in Surahs 1 and 9.' -Passed (
        $bismillahAttributeCount -eq 112 -and $sourceBasmalaIssues.Count -eq 0
    ) -Details $sourceBasmalaDetails

    Add-Check -Id 'sources.basmala_spelling' -Category 'basmala' -Description 'Source Basmala spellings are preserved exactly, including the distinct 95/97 spelling.' -Passed (
        -not [string]::IsNullOrEmpty($standardBasmala) -and
        (Test-OrdinalEqual -Left ([string]$xmlBySura[1].Ayahs[0].Text) -Right $standardBasmala) -and
        (Test-OrdinalEqual -Left $special95 -Right $special97) -and
        $standardBasmala.Length -eq 39 -and
        $special95.Length -eq 40 -and
        $special97.Length -eq 40 -and
        [int]$standardBasmala[1] -eq 0x0650 -and
        [int]$special95[1] -eq 0x0651 -and
        [int]$special97[1] -eq 0x0651 -and
        -not (Test-OrdinalEqual -Left $special95 -Right $standardBasmala)
    ) -Details ('standard_len={0}; 95_len={1}; 97_len={2}; 1:1_equals_standard={3}' -f $standardBasmala.Length, $special95.Length, $special97.Length, (Test-OrdinalEqual -Left ([string]$xmlBySura[1].Ayahs[0].Text) -Right $standardBasmala))

    $sourceMarkerTotals = @{
        Pause = 0
        Rub = 0
        Sajdah = 0
        Tatweel = 0
    }
    $sourceFootnoteNonEmpty = 0
    $sourceFootnoteNewlines = 0
    $sourceFootnoteQuotes = 0
    $sourceEmptyArabic = New-Object System.Collections.ArrayList
    $sourceEmptyTranslations = New-Object System.Collections.ArrayList

    foreach ($sura in $xml.Suras) {
        foreach ($ayah in $sura.Ayahs) {
            $text = [string]$ayah.Text
            if ([string]::IsNullOrEmpty($text)) {
                [void]$sourceEmptyArabic.Add(('{0}:{1}' -f $sura.Number, $ayah.Number))
            }
            $counts = Get-MarkerCounts -Text $text
            $sourceMarkerTotals.Pause += $counts.Pause
            $sourceMarkerTotals.Rub += $counts.Rub
            $sourceMarkerTotals.Sajdah += $counts.Sajdah
            $sourceMarkerTotals.Tatweel += $counts.Tatweel
        }
    }

    foreach ($row in $csv.Rows) {
        $footnotes = [string]$row.Footnotes
        if ([string]::IsNullOrEmpty([string]$row.Translation)) {
            [void]$sourceEmptyTranslations.Add(('{0}:{1}' -f $row.Sura, $row.Aya))
        }
        if ($footnotes.Length -gt 0) {
            $sourceFootnoteNonEmpty++
        }
        if ($footnotes.IndexOf([char]0x000A) -ge 0 -or $footnotes.IndexOf([char]0x000D) -ge 0) {
            $sourceFootnoteNewlines++
        }
        if ($footnotes.IndexOf([char]0x0022) -ge 0) {
            $sourceFootnoteQuotes++
        }
    }

    Add-TextSetCheck -Id 'sources.nonempty' -Category 'sources' -Description 'No source Arabic Ayah or English translation is empty.' -Issues $sourceEmptyArabic -SuccessDetails 'all Arabic records non-empty'
    Add-TextSetCheck -Id 'sources.english_nonempty' -Category 'sources' -Description 'No English translation record is empty.' -Issues $sourceEmptyTranslations -SuccessDetails 'all 6,236 translations non-empty'

    Add-Check -Id 'sources.marker_baseline' -Category 'marks' -Description 'Source marker totals match the reviewed baseline.' -Passed (
        $sourceMarkerTotals.Pause -eq 4366 -and
        $sourceMarkerTotals.Rub -eq 199 -and
        $sourceMarkerTotals.Sajdah -eq 15 -and
        $sourceMarkerTotals.Tatweel -eq 6736
    ) -Details ('pause={0}; rub={1}; sajdah={2}; tatweel={3}' -f $sourceMarkerTotals.Pause, $sourceMarkerTotals.Rub, $sourceMarkerTotals.Sajdah, $sourceMarkerTotals.Tatweel)

    Add-Check -Id 'sources.footnote_baseline' -Category 'footnotes' -Description 'Source raw footnotes match the reviewed baseline, including embedded newlines and quotes.' -Passed (
        $sourceFootnoteNonEmpty -eq 1613 -and
        $sourceFootnoteNewlines -eq 225 -and
        $sourceFootnoteQuotes -eq 294
    ) -Details ('non-empty={0}; with_newlines={1}; with_quotes={2}' -f $sourceFootnoteNonEmpty, $sourceFootnoteNewlines, $sourceFootnoteQuotes)

    # ---------------------------------------------------------------
    # Generated files
    # ---------------------------------------------------------------

    if (-not [System.IO.Directory]::Exists($surahsDir)) {
        throw "Missing generated Surah directory: $surahsDir"
    }

    $expectedSajdahSet = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($key in $expectedSajdahKeys) {
        [void]$expectedSajdahSet.Add($key)
    }

    $expectedFileNames = @(1..114 | ForEach-Object { '{0:D3}.json' -f $_ })
    $actualFiles = @(Get-ChildItem -LiteralPath $surahsDir -File -Filter '*.json')
    $actualFileNames = @($actualFiles | ForEach-Object { $_.Name })
    $missingFiles = @($expectedFileNames | Where-Object { $actualFileNames -notcontains $_ })
    $extraFiles = @($actualFileNames | Where-Object { $expectedFileNames -notcontains $_ })

    Add-Check -Id 'generated.file_set' -Category 'generated' -Description 'Exactly 114 Surah JSON files exist with names 001.json through 114.json.' -Passed (
        $actualFiles.Count -eq 114 -and $missingFiles.Count -eq 0 -and $extraFiles.Count -eq 0
    ) -Details ('files={0}; missing=[{1}]; extra=[{2}]' -f $actualFiles.Count, ($missingFiles -join ','), ($extraFiles -join ','))

    $totalGeneratedAyahs = 0
    $totalTranslations = 0
    $totalFootnotes = 0
    $generatedFootnoteNonEmpty = 0
    $generatedFootnoteNewlines = 0
    $generatedFootnoteQuotes = 0
    $generatedMarkerTotals = @{
        Pause = 0
        Rub = 0
        Sajdah = 0
        Tatweel = 0
    }
    $generatedBasmalaModes = @{
        ayah = 0
        prefatory = 0
        none = 0
    }

    $parseIssues = New-Object System.Collections.ArrayList
    $schemaIssues = New-Object System.Collections.ArrayList
    $fileHashIssues = New-Object System.Collections.ArrayList
    $manifestFileIssues = New-Object System.Collections.ArrayList
    $manifestHashIssues = New-Object System.Collections.ArrayList
    $ayahCountIssues = New-Object System.Collections.ArrayList
    $catalogueCountIssues = New-Object System.Collections.ArrayList
    $ayahSequenceIssues = New-Object System.Collections.ArrayList
    $arabicIssues = New-Object System.Collections.ArrayList
    $translationIssues = New-Object System.Collections.ArrayList
    $footnoteIssues = New-Object System.Collections.ArrayList
    $sajdahFlagIssues = New-Object System.Collections.ArrayList
    $sajdahMarkerIssues = New-Object System.Collections.ArrayList
    $basmalaIssues = New-Object System.Collections.ArrayList
    $emptyArabicIssues = New-Object System.Collections.ArrayList
    $emptyTranslationIssues = New-Object System.Collections.ArrayList
    $typeIssues = New-Object System.Collections.ArrayList
    $bomIssues = New-Object System.Collections.ArrayList

    $actualHashByNumber = @{}
    $generatedByNumber = @{}
    $contentHashBuilder = New-Object System.Text.StringBuilder
    $totalGeneratedSize = [long]0

    for ($suraNumber = 1; $suraNumber -le 114; $suraNumber++) {
        $fileName = '{0:D3}.json' -f $suraNumber
        $path = Join-Path $surahsDir $fileName

        if (-not [System.IO.File]::Exists($path)) {
            [void]$parseIssues.Add(('Surah {0}: missing file' -f $suraNumber))
            continue
        }

        $fileSize = [long](Get-Item -LiteralPath $path).Length
        $actualHash = Get-Sha256Hex -Path $path
        $actualHashByNumber[$suraNumber] = $actualHash
        $totalGeneratedSize += $fileSize

        [void]$contentHashBuilder.Append($fileName)
        [void]$contentHashBuilder.Append("`n")
        [void]$contentHashBuilder.Append($actualHash)
        [void]$contentHashBuilder.Append("`n")

        if (Test-Utf8Bom -Path $path) {
            [void]$bomIssues.Add(('Surah {0}' -f $suraNumber))
        }

        if (-not $manifestEntryByNumber.ContainsKey($suraNumber)) {
            [void]$manifestFileIssues.Add(('Surah {0}: no manifest entry' -f $suraNumber))
        }
        else {
            $manifestEntry = $manifestEntryByNumber[$suraNumber]
            if (-not (Test-OrdinalEqual -Left ([string]$manifestEntry.sha256) -Right $actualHash)) {
                [void]$manifestHashIssues.Add(('Surah {0}' -f $suraNumber))
            }
        }

        $fileText = Read-Utf8TextFile -Path $path
        $parsedSurah = $null
        try {
            $parsedSurah = $fileText | ConvertFrom-Json
        }
        catch {
            [void]$parseIssues.Add(('Surah {0}: {1}' -f $suraNumber, $_.Exception.Message))
            continue
        }

        $generatedByNumber[$suraNumber] = $parsedSurah

        if (-not (Test-KeySet -Object $parsedSurah -Expected @('surah_number', 'basmala_mode', 'basmala_text', 'ayahs'))) {
            [void]$schemaIssues.Add(('Surah {0}: top-level keys' -f $suraNumber))
        }

        $generatedNumberRaw = Get-JsonProperty -Object $parsedSurah -Name 'surah_number'
        $generatedNumber = [int]$generatedNumberRaw
        if (-not ($generatedNumberRaw -is [int] -or $generatedNumberRaw -is [long])) {
            [void]$typeIssues.Add(('Surah {0}: surah_number type' -f $suraNumber))
        }
        if ($generatedNumber -ne $suraNumber) {
            [void]$schemaIssues.Add(('Surah {0}: surah_number={1}' -f $suraNumber, $generatedNumber))
        }

        $basmalaMode = [string](Get-JsonProperty -Object $parsedSurah -Name 'basmala_mode')
        $expectedBasmalaMode = if ($suraNumber -eq 1) { 'ayah' } elseif ($suraNumber -eq 9) { 'none' } else { 'prefatory' }
        if ($basmalaMode -ne $expectedBasmalaMode) {
            [void]$basmalaIssues.Add(('Surah {0}: mode={1}, expected {2}' -f $suraNumber, $basmalaMode, $expectedBasmalaMode))
        }
        else {
            $generatedBasmalaModes[$basmalaMode]++
        }

        if (-not $manifestEntryByNumber.ContainsKey($suraNumber)) {
            # Already recorded above.
        }
        elseif ([string]$manifestEntryByNumber[$suraNumber].basmala_mode -ne $basmalaMode) {
            [void]$basmalaIssues.Add(('Surah {0}: manifest mode mismatch' -f $suraNumber))
        }

        $hasBasmalaTextProperty = Test-JsonProperty -Object $parsedSurah -Name 'basmala_text'
        $basmalaTextRaw = Get-JsonProperty -Object $parsedSurah -Name 'basmala_text'
        $basmalaText = [string]$basmalaTextRaw

        if ($suraNumber -eq 1) {
            if (-not $hasBasmalaTextProperty -or $null -ne $basmalaTextRaw) {
                [void]$basmalaIssues.Add('Surah 1: basmala_text must be null')
            }
        }
        elseif ($suraNumber -eq 9) {
            if (-not $hasBasmalaTextProperty -or $null -ne $basmalaTextRaw) {
                [void]$basmalaIssues.Add('Surah 9: basmala_text must be null')
            }
            $sourceNinthFirstText = [string]$xmlBySura[9].Ayahs[0].Text
            if ($sourceNinthFirstText.StartsWith($standardBasmala, [System.StringComparison]::Ordinal)) {
                [void]$basmalaIssues.Add('Surah 9: first Ayah starts with the Basmala')
            }
        }
        else {
            if (-not $hasBasmalaTextProperty -or [string]::IsNullOrEmpty($basmalaText)) {
                [void]$basmalaIssues.Add(('Surah {0}: basmala_text is empty or missing' -f $suraNumber))
            }
            else {
                $sourceBasmala = [string]$xmlBySura[$suraNumber].Ayahs[0].Bismillah
                if (-not (Test-OrdinalEqual -Left $basmalaText -Right $sourceBasmala)) {
                    [void]$basmalaIssues.Add(('Surah {0}: basmala_text differs from source' -f $suraNumber))
                }
                $sourceFirstText = [string]$xmlBySura[$suraNumber].Ayahs[0].Text
                if ($sourceFirstText.StartsWith($basmalaText, [System.StringComparison]::Ordinal)) {
                    [void]$basmalaIssues.Add(('Surah {0}: Basmala is prepended to the first Ayah' -f $suraNumber))
                }
            }
        }

        $sourceSura = $xmlBySura[$suraNumber]
        $sourceAyahs = @($sourceSura.Ayahs)
        $sourceAyahCount = $sourceAyahs.Count
        $sourceAyahByNumber = @{}
        foreach ($sourceAyah in $sourceAyahs) {
            $sourceAyahByNumber[[int]$sourceAyah.Number] = $sourceAyah
        }

        if ($sourceAyahCount -ne [int]$catalogueByNumber[$suraNumber].ayah_count) {
            [void]$catalogueCountIssues.Add(('Surah {0}: source={1}, catalogue={2}' -f $suraNumber, $sourceAyahCount, [int]$catalogueByNumber[$suraNumber].ayah_count))
        }

        $parsedAyahs = @(Get-JsonProperty -Object $parsedSurah -Name 'ayahs')
        $parsedAyahCount = $parsedAyahs.Count

        if ($manifestEntryByNumber.ContainsKey($suraNumber)) {
            $manifestEntry = $manifestEntryByNumber[$suraNumber]
            if ([int]$manifestEntry.ayah_count -ne $sourceAyahCount) {
                [void]$ayahCountIssues.Add(('Surah {0}: manifest={1}, source={2}' -f $suraNumber, [int]$manifestEntry.ayah_count, $sourceAyahCount))
            }
        }

        if ($parsedAyahCount -ne $sourceAyahCount) {
            [void]$ayahCountIssues.Add(('Surah {0}: generated={1}, source={2}' -f $suraNumber, $parsedAyahCount, $sourceAyahCount))
        }

        $actualAyahNumbers = @()
        foreach ($parsedAyah in $parsedAyahs) {
            $actualAyahNumbers += [int](Get-JsonProperty -Object $parsedAyah -Name 'number')
        }
        $expectedAyahNumbers = @(1..$sourceAyahCount)
        if (($actualAyahNumbers -join ',') -ne ($expectedAyahNumbers -join ',')) {
            [void]$ayahSequenceIssues.Add(('Surah {0}' -f $suraNumber))
        }

        foreach ($parsedAyah in $parsedAyahs) {
            $numberRaw = Get-JsonProperty -Object $parsedAyah -Name 'number'
            $number = [int]$numberRaw
            $key = '{0}:{1}' -f $suraNumber, $number

            if (-not (Test-KeySet -Object $parsedAyah -Expected @('number', 'arabic', 'translation', 'footnotes', 'sajdah'))) {
                [void]$schemaIssues.Add(('{0}: Ayah keys' -f $key))
            }

            if (-not ($numberRaw -is [int] -or $numberRaw -is [long])) {
                [void]$typeIssues.Add(('{0}: number type' -f $key))
            }

            $arabicRaw = Get-JsonProperty -Object $parsedAyah -Name 'arabic'
            $translationRaw = Get-JsonProperty -Object $parsedAyah -Name 'translation'
            $footnotesRaw = Get-JsonProperty -Object $parsedAyah -Name 'footnotes'
            $sajdahRaw = Get-JsonProperty -Object $parsedAyah -Name 'sajdah'

            if (-not ($arabicRaw -is [string])) {
                [void]$typeIssues.Add(('{0}: arabic type' -f $key))
            }
            if (-not ($translationRaw -is [string])) {
                [void]$typeIssues.Add(('{0}: translation type' -f $key))
            }
            if (-not ($footnotesRaw -is [string])) {
                [void]$typeIssues.Add(('{0}: footnotes type' -f $key))
            }
            if (-not ($sajdahRaw -is [bool])) {
                [void]$typeIssues.Add(('{0}: sajdah type' -f $key))
            }

            $arabic = [string]$arabicRaw
            $translation = [string]$translationRaw
            $footnotes = [string]$footnotesRaw
            $sajdah = [bool]$sajdahRaw

            if ([string]::IsNullOrEmpty($arabic)) {
                [void]$emptyArabicIssues.Add($key)
            }
            if ([string]::IsNullOrEmpty($translation)) {
                [void]$emptyTranslationIssues.Add($key)
            }

            if (-not $sourceAyahByNumber.ContainsKey($number)) {
                [void]$schemaIssues.Add(('{0}: unexpected Ayah number' -f $key))
                continue
            }

            $sourceAyah = $sourceAyahByNumber[$number]
            if (-not (Test-OrdinalEqual -Left $arabic -Right ([string]$sourceAyah.Text))) {
                [void]$arabicIssues.Add($key)
            }

            if (-not $csvByKey.ContainsKey($key)) {
                [void]$translationIssues.Add(('{0}: missing English record' -f $key))
                [void]$footnoteIssues.Add(('{0}: missing English record' -f $key))
            }
            else {
                $englishRow = $csvByKey[$key]
                if (-not (Test-OrdinalEqual -Left $translation -Right ([string]$englishRow.Translation))) {
                    [void]$translationIssues.Add($key)
                }
                if (-not (Test-OrdinalEqual -Left $footnotes -Right ([string]$englishRow.Footnotes))) {
                    [void]$footnoteIssues.Add($key)
                }
            }

            $expectedSajdah = $expectedSajdahSet.Contains($key)
            if ($sajdah -ne $expectedSajdah) {
                [void]$sajdahFlagIssues.Add(('{0}: flag={1}, expected={2}' -f $key, $sajdah, $expectedSajdah))
            }
            if ($sajdah) {
                [void]$sajdahKeys.Add($key)
            }

            $markerCounts = Get-MarkerCounts -Text $arabic
            if ($expectedSajdah) {
                if ($markerCounts.Sajdah -ne 1) {
                    [void]$sajdahMarkerIssues.Add(('{0}: {1} Sajdah marks' -f $key, $markerCounts.Sajdah))
                }
            }
            elseif ($markerCounts.Sajdah -ne 0) {
                [void]$sajdahMarkerIssues.Add(('{0}: unclassified Sajdah mark' -f $key))
            }

            $generatedMarkerTotals.Pause += $markerCounts.Pause
            $generatedMarkerTotals.Rub += $markerCounts.Rub
            $generatedMarkerTotals.Sajdah += $markerCounts.Sajdah
            $generatedMarkerTotals.Tatweel += $markerCounts.Tatweel

            $totalFootnotes++
            if ($footnotes.Length -gt 0) {
                $generatedFootnoteNonEmpty++
            }
            if ($footnotes.IndexOf([char]0x000A) -ge 0 -or $footnotes.IndexOf([char]0x000D) -ge 0) {
                $generatedFootnoteNewlines++
            }
            if ($footnotes.IndexOf([char]0x0022) -ge 0) {
                $generatedFootnoteQuotes++
            }
        }

        $totalGeneratedAyahs += $parsedAyahCount
        $totalTranslations += $parsedAyahCount
    }

    $recomputedTotals = [ordered]@{
        surahs = [int]$actualFiles.Count
        ayahs = [int]$totalGeneratedAyahs
        arabic_records = [int]$totalGeneratedAyahs
        translation_records = [int]$totalTranslations
        footnote_records = [int]$totalFootnotes
        footnotes_nonempty = [int]$generatedFootnoteNonEmpty
        footnotes_with_embedded_newlines = [int]$generatedFootnoteNewlines
        footnotes_with_quotes = [int]$generatedFootnoteQuotes
        sajdah_ayahs = [int]$sajdahKeys.Count
        pause_marks = [int]$generatedMarkerTotals.Pause
        rub_el_hizb_marks = [int]$generatedMarkerTotals.Rub
        tatweel_characters = [int]$generatedMarkerTotals.Tatweel
    }

    $generatedInfo = [ordered]@{
        surah_file_count = [int]$actualFiles.Count
        surah_files_total_size_bytes = [long]$totalGeneratedSize
        manifest_size_bytes = [long]$manifestSize
        total_size_bytes = [long]($totalGeneratedSize + $manifestSize)
    }

    Add-TextSetCheck -Id 'generated.json_parse' -Category 'generated' -Description 'All 114 generated Surah files parse as JSON.' -Issues $parseIssues -SuccessDetails '114 files parsed'
    Add-TextSetCheck -Id 'generated.schema' -Category 'generated' -Description 'Every generated Surah and Ayah has exactly the required keys and types.' -Issues $schemaIssues -SuccessDetails 'schema exact'
    Add-TextSetCheck -Id 'generated.types' -Category 'generated' -Description 'Every generated field has the required JSON type.' -Issues $typeIssues -SuccessDetails 'types exact'
    Add-TextSetCheck -Id 'generated.file_hashes' -Category 'generated' -Description 'Every generated file SHA-256 matches the manifest entry.' -Issues $manifestHashIssues -SuccessDetails '114 hashes matched'
    Add-TextSetCheck -Id 'generated.manifest_entries' -Category 'generated' -Description 'Every generated Surah is represented in the manifest.' -Issues $manifestFileIssues -SuccessDetails '114 entries matched'
    Add-TextSetCheck -Id 'generated.ayah_counts' -Category 'generated' -Description 'Generated, source and manifest Ayah counts agree for every Surah.' -Issues $ayahCountIssues -SuccessDetails 'all counts agree'
    Add-TextSetCheck -Id 'generated.catalogue_counts' -Category 'generated' -Description 'Every generated Surah count agrees with assets/data/surahs.json.' -Issues $catalogueCountIssues -SuccessDetails 'all 114 counts agree'
    Add-TextSetCheck -Id 'generated.ayah_sequence' -Category 'generated' -Description 'Ayah numbers are sequential from 1 in every generated Surah.' -Issues $ayahSequenceIssues -SuccessDetails 'all 114 Surahs sequential'
    Add-TextSetCheck -Id 'generated.arabic_exact' -Category 'generated' -Description 'Every generated Arabic Ayah matches the Tanzil source exactly.' -Issues $arabicIssues -SuccessDetails '6,236 exact Arabic records'
    Add-TextSetCheck -Id 'generated.translation_exact' -Category 'generated' -Description 'Every generated English translation matches the QuranEnc CSV exactly.' -Issues $translationIssues -SuccessDetails '6,236 exact translations'
    Add-TextSetCheck -Id 'generated.footnotes_exact' -Category 'generated' -Description 'Every generated raw footnote string matches the QuranEnc CSV exactly.' -Issues $footnoteIssues -SuccessDetails '6,236 exact footnote strings'
    Add-TextSetCheck -Id 'generated.sajdah_flags' -Category 'sajdah' -Description 'The sajdah flag is true at exactly the 15 known Sajdah Ayahs and false elsewhere.' -Issues $sajdahFlagIssues -SuccessDetails '15 true; 6,221 false'
    Add-TextSetCheck -Id 'generated.sajdah_marks' -Category 'sajdah' -Description 'Each Sajdah Ayah retains exactly one U+06E9 mark and no other Ayah has one.' -Issues $sajdahMarkerIssues -SuccessDetails '15 marks preserved'
    Add-TextSetCheck -Id 'generated.basmala' -Category 'basmala' -Description 'Every generated Basmala mode and text matches the source and required rules.' -Issues $basmalaIssues -SuccessDetails 'Surah 1 ayah; 112 prefatory; Surah 9 none'
    Add-TextSetCheck -Id 'generated.nonempty_arabic' -Category 'generated' -Description 'No generated Arabic record is empty.' -Issues $emptyArabicIssues -SuccessDetails 'all non-empty'
    Add-TextSetCheck -Id 'generated.nonempty_translations' -Category 'generated' -Description 'No generated English translation is empty.' -Issues $emptyTranslationIssues -SuccessDetails 'all non-empty'
    Add-TextSetCheck -Id 'generated.no_bom' -Category 'generated' -Description 'Every generated Surah file is UTF-8 without a BOM.' -Issues $bomIssues -SuccessDetails 'no BOM in 114 files'

    $actualSajdahKeys = @($sajdahKeys)
    Add-Check -Id 'generated.sajdah_locations' -Category 'sajdah' -Description 'The generated Sajdah locations match the 15 expected locations exactly.' -Passed (
        ($actualSajdahKeys -join ',') -eq ($expectedSajdahKeys -join ',')
    ) -Details ('found={0}' -f ($actualSajdahKeys -join ','))

    Add-Check -Id 'generated.basmala_mode_counts' -Category 'basmala' -Description 'Generated Basmala modes are ayah=1, prefatory=112, none=1.' -Passed (
        $generatedBasmalaModes['ayah'] -eq 1 -and
        $generatedBasmalaModes['prefatory'] -eq 112 -and
        $generatedBasmalaModes['none'] -eq 1
    ) -Details ('ayah={0}; prefatory={1}; none={2}' -f $generatedBasmalaModes['ayah'], $generatedBasmalaModes['prefatory'], $generatedBasmalaModes['none'])

    $generated95 = [string](Get-JsonProperty -Object $generatedByNumber[95] -Name 'basmala_text')
    $generated97 = [string](Get-JsonProperty -Object $generatedByNumber[97] -Name 'basmala_text')
    Add-Check -Id 'generated.basmala_95_97' -Category 'basmala' -Description 'Surahs 95 and 97 preserve their distinct 40-character Basmala with the extra shadda.' -Passed (
        (Test-OrdinalEqual -Left $generated95 -Right $special95) -and
        (Test-OrdinalEqual -Left $generated97 -Right $special97) -and
        (Test-OrdinalEqual -Left $generated95 -Right $generated97) -and
        $generated95.Length -eq 40 -and
        [int]$generated95[1] -eq 0x0651 -and
        [int]$generated97[1] -eq 0x0651
    ) -Details ('95_len={0}; 97_len={1}' -f $generated95.Length, $generated97.Length)

    Add-Check -Id 'generated.totals' -Category 'totals' -Description 'Generated totals are 114 Surahs, 6,236 Ayahs, 6,236 Arabic records and 6,236 translations.' -Passed (
        $totalGeneratedAyahs -eq 6236 -and
        $totalTranslations -eq 6236 -and
        $actualFiles.Count -eq 114
    ) -Details ('surahs={0}; ayahs={1}; translations={2}' -f $actualFiles.Count, $totalGeneratedAyahs, $totalTranslations)

    Add-Check -Id 'generated.marker_totals' -Category 'marks' -Description 'Generated pause, rub-el-hizb, Sajdah and tatweel totals match the source and manifest.' -Passed (
        $generatedMarkerTotals.Pause -eq $sourceMarkerTotals.Pause -and
        $generatedMarkerTotals.Rub -eq $sourceMarkerTotals.Rub -and
        $generatedMarkerTotals.Sajdah -eq $sourceMarkerTotals.Sajdah -and
        $generatedMarkerTotals.Tatweel -eq $sourceMarkerTotals.Tatweel -and
        [int]$manifest.totals.pause_marks -eq $generatedMarkerTotals.Pause -and
        [int]$manifest.totals.rub_el_hizb_marks -eq $generatedMarkerTotals.Rub -and
        [int]$manifest.totals.sajdah_ayahs -eq $generatedMarkerTotals.Sajdah -and
        [int]$manifest.totals.tatweel_characters -eq $generatedMarkerTotals.Tatweel
    ) -Details ('generated pause={0}, rub={1}, sajdah={2}, tatweel={3}; source pause={4}, rub={5}, sajdah={6}, tatweel={7}' -f $generatedMarkerTotals.Pause, $generatedMarkerTotals.Rub, $generatedMarkerTotals.Sajdah, $generatedMarkerTotals.Tatweel, $sourceMarkerTotals.Pause, $sourceMarkerTotals.Rub, $sourceMarkerTotals.Sajdah, $sourceMarkerTotals.Tatweel)

    Add-Check -Id 'generated.footnote_totals' -Category 'footnotes' -Description 'Generated raw footnote counts match the source and manifest, including newlines and quotes.' -Passed (
        $totalFootnotes -eq 6236 -and
        $generatedFootnoteNonEmpty -eq $sourceFootnoteNonEmpty -and
        $generatedFootnoteNewlines -eq $sourceFootnoteNewlines -and
        $generatedFootnoteQuotes -eq $sourceFootnoteQuotes -and
        [int]$manifest.totals.footnote_records -eq $totalFootnotes -and
        [int]$manifest.totals.footnotes_nonempty -eq $generatedFootnoteNonEmpty -and
        [int]$manifest.totals.footnotes_with_embedded_newlines -eq $generatedFootnoteNewlines -and
        [int]$manifest.totals.footnotes_with_quotes -eq $generatedFootnoteQuotes
    ) -Details ('records={0}; non-empty={1}; newlines={2}; quotes={3}' -f $totalFootnotes, $generatedFootnoteNonEmpty, $generatedFootnoteNewlines, $generatedFootnoteQuotes)

    $manifestTotalsOk = (
        [int]$manifest.totals.surahs -eq 114 -and
        [int]$manifest.totals.ayahs -eq 6236 -and
        [int]$manifest.totals.arabic_records -eq 6236 -and
        [int]$manifest.totals.translation_records -eq 6236 -and
        [int]$manifest.totals.footnote_records -eq 6236 -and
        [int]$manifest.totals.footnotes_nonempty -eq $sourceFootnoteNonEmpty -and
        [int]$manifest.totals.footnotes_with_embedded_newlines -eq $sourceFootnoteNewlines -and
        [int]$manifest.totals.footnotes_with_quotes -eq $sourceFootnoteQuotes -and
        [int]$manifest.totals.sajdah_ayahs -eq 15 -and
        [int]$manifest.totals.pause_marks -eq $sourceMarkerTotals.Pause -and
        [int]$manifest.totals.rub_el_hizb_marks -eq $sourceMarkerTotals.Rub -and
        [int]$manifest.totals.tatweel_characters -eq $sourceMarkerTotals.Tatweel
    )
    Add-Check -Id 'manifest.totals' -Category 'manifest' -Description 'Manifest totals match all independently recomputed source and generated totals.' -Passed $manifestTotalsOk -Details ('ayahs={0}; footnotes_nonempty={1}; sajdah={2}; pause={3}; rub={4}; tatweel={5}' -f $manifest.totals.ayahs, $manifest.totals.footnotes_nonempty, $manifest.totals.sajdah_ayahs, $manifest.totals.pause_marks, $manifest.totals.rub_el_hizb_marks, $manifest.totals.tatweel_characters)

    $manifestBasmalaOk = (
        ((@($manifest.basmala.ayah) -join ',') -eq '1') -and
        [int]$manifest.basmala.prefatory -eq 112 -and
        ((@($manifest.basmala.none) -join ',') -eq '9') -and
        ((@($manifest.basmala.special_spellings) -join ',') -eq '95,97')
    )
    Add-Check -Id 'manifest.basmala_summary' -Category 'basmala' -Description 'Manifest Basmala summary records Surah 1, Surah 9, 112 prefatory cases and the special 95/97 spellings.' -Passed $manifestBasmalaOk -Details 'ayah=[1]; prefatory=112; none=[9]; special=[95,97]'

    # ---------------------------------------------------------------
    # Content checksum and checksum file
    # ---------------------------------------------------------------

    $recomputedContentChecksum = Get-Sha256Text -Text $contentHashBuilder.ToString()
    $contentChecksumInfo = [ordered]@{
        algorithm = 'SHA-256'
        scope = 'SHA-256 over per-Surah file names 001.json..114.json and their actual SHA-256 digests, each followed by a newline; timestamps excluded.'
        value = $recomputedContentChecksum
        file_count = 114
        manifest_value = [string]$manifest.content_checksum.value
        matches_manifest = (Test-OrdinalEqual -Left $recomputedContentChecksum -Right ([string]$manifest.content_checksum.value))
    }

    Add-Check -Id 'checksum.content' -Category 'checksums' -Description 'Recomputed per-Surah content checksum matches the manifest value.' -Passed (
        $contentChecksumInfo.matches_manifest -and
        [string]$manifest.content_checksum.algorithm -eq 'SHA-256' -and
        [int]$manifest.content_checksum.file_count -eq 114
    ) -Details ('recomputed={0}; manifest={1}' -f $recomputedContentChecksum, $manifest.content_checksum.value)

    $expectedChecksums = @{}
    $expectedChecksums['generated/manifest.json'] = $manifestHash
    foreach ($n in 1..114) {
        $expectedChecksums[('generated/surahs/{0:D3}.json' -f $n)] = [string]$actualHashByNumber[$n]
    }
    $expectedChecksums[[string]$manifestArabic.file] = [string]$sourceActual['arabic'].Hash
    $expectedChecksums[[string]$manifestEnglish.file] = [string]$sourceActual['english'].Hash

    $checksumFileIssues = New-Object System.Collections.ArrayList
    $checksumSeen = New-Object 'System.Collections.Generic.HashSet[string]'
    if (-not [System.IO.File]::Exists($checksumsPath)) {
        [void]$checksumFileIssues.Add('checksums.sha256 is missing')
    }
    else {
        $checksumText = Read-Utf8TextFile -Path $checksumsPath
        $checksumLines = @($checksumText -split "`r?`n" | Where-Object { $_.Length -gt 0 })
        if ($checksumLines.Count -ne $expectedChecksums.Count) {
            [void]$checksumFileIssues.Add(('line count={0}, expected={1}' -f $checksumLines.Count, $expectedChecksums.Count))
        }

        foreach ($line in $checksumLines) {
            if ($line -notmatch '^([0-9a-f]{64})  (.+)$') {
                [void]$checksumFileIssues.Add(('invalid line: {0}' -f $line))
                continue
            }

            $lineHash = $Matches[1]
            $linePath = $Matches[2]
            if (-not $expectedChecksums.ContainsKey($linePath)) {
                [void]$checksumFileIssues.Add(('unexpected path: {0}' -f $linePath))
                continue
            }
            if (-not $checksumSeen.Add($linePath)) {
                [void]$checksumFileIssues.Add(('duplicate path: {0}' -f $linePath))
                continue
            }
            if (-not (Test-OrdinalEqual -Left $lineHash -Right ([string]$expectedChecksums[$linePath]))) {
                [void]$checksumFileIssues.Add(('hash mismatch: {0}' -f $linePath))
            }
        }

        foreach ($expectedPath in $expectedChecksums.Keys) {
            if (-not $checksumSeen.Contains($expectedPath)) {
                [void]$checksumFileIssues.Add(('missing path: {0}' -f $expectedPath))
            }
        }
    }

    Add-TextSetCheck -Id 'checksum.file' -Category 'checksums' -Description 'checksums.sha256 contains exactly the 117 expected source, manifest and Surah file checksums.' -Issues $checksumFileIssues -SuccessDetails '117 checksums matched'

    # ---------------------------------------------------------------
    # Required spot checks against the original sources
    # ---------------------------------------------------------------

    $spotCheckIssues = New-Object System.Collections.ArrayList

    foreach ($key in $expectedSpotKeys) {
        $parts = $key.Split(':')
        $suraNumber = [int]$parts[0]
        $ayahNumber = [int]$parts[1]

        if (-not $generatedByNumber.ContainsKey($suraNumber)) {
            [void]$spotCheckIssues.Add(('{0}: generated Surah missing' -f $key))
            continue
        }

        $generatedSurah = $generatedByNumber[$suraNumber]
        $generatedAyah = @($generatedSurah.ayahs) | Where-Object { [int]$_.number -eq $ayahNumber } | Select-Object -First 1
        if ($null -eq $generatedAyah) {
            [void]$spotCheckIssues.Add(('{0}: generated Ayah missing' -f $key))
            continue
        }

        $sourceAyah = @($xmlBySura[$suraNumber].Ayahs) | Where-Object { [int]$_.Number -eq $ayahNumber } | Select-Object -First 1
        if ($null -eq $sourceAyah -or -not $csvByKey.ContainsKey($key)) {
            [void]$spotCheckIssues.Add(('{0}: source record missing' -f $key))
            continue
        }

        $englishRow = $csvByKey[$key]
        $generatedArabic = [string]$generatedAyah.arabic
        $generatedTranslation = [string]$generatedAyah.translation
        $generatedFootnotes = [string]$generatedAyah.footnotes
        $generatedSajdah = [bool]$generatedAyah.sajdah

        $arabicOk = Test-OrdinalEqual -Left $generatedArabic -Right ([string]$sourceAyah.Text)
        $translationOk = Test-OrdinalEqual -Left $generatedTranslation -Right ([string]$englishRow.Translation)
        $footnotesOk = Test-OrdinalEqual -Left $generatedFootnotes -Right ([string]$englishRow.Footnotes)
        $sajdahOk = ($generatedSajdah -eq $expectedSajdahSet.Contains($key))
        $startsWithBasmala = $generatedArabic.StartsWith($standardBasmala, [System.StringComparison]::Ordinal)
        $isBasmalaItself = ($key -eq '1:1') -and (Test-OrdinalEqual -Left $generatedArabic -Right $standardBasmala)
        $basmalaPrepended = ($key -ne '1:1') -and $startsWithBasmala

        $spotPassed = $arabicOk -and $translationOk -and $footnotesOk -and $sajdahOk -and (-not $basmalaPrepended)
        if ($key -eq '1:1' -and -not $isBasmalaItself) {
            $spotPassed = $false
        }
        if (($key -eq '2:1' -or $key -eq '9:1') -and $startsWithBasmala) {
            $spotPassed = $false
        }

        $spotCheckRecords.Add([ordered]@{
            key = $key
            arabic_matches_source = [bool]$arabicOk
            translation_matches_source = [bool]$translationOk
            footnotes_matches_source = [bool]$footnotesOk
            sajdah_matches_source = [bool]$sajdahOk
            is_basmala_itself = [bool]$isBasmalaItself
            starts_with_standard_basmala = [bool]$startsWithBasmala
            basmala_prepended_to_ayah = [bool]$basmalaPrepended
            arabic_sha256 = Get-Sha256Text -Text $generatedArabic
            translation_sha256 = Get-Sha256Text -Text $generatedTranslation
            footnotes_sha256 = Get-Sha256Text -Text $generatedFootnotes
            arabic = $generatedArabic
            translation = $generatedTranslation
            footnotes = $generatedFootnotes
            sajdah = [bool]$generatedSajdah
        }) | Out-Null

        Add-Check -Id ('spot.{0}' -f $key.Replace(':', '_')) -Category 'spot-checks' -Description ('Spot check {0} matches the original Arabic and English sources exactly.' -f $key) -Passed $spotPassed -Details (
            'arabic={0}; translation={1}; footnotes={2}; sajdah={3}; is_basmala_itself={4}; starts_with_basmala={5}; basmala_prepended={6}' -f $arabicOk, $translationOk, $footnotesOk, $sajdahOk, $isBasmalaItself, $startsWithBasmala, $basmalaPrepended
        )

        if (-not $spotPassed) {
            [void]$spotCheckIssues.Add($key)
        }
    }

    Add-TextSetCheck -Id 'spot.all' -Category 'spot-checks' -Description 'All five required spot checks pass against the original sources.' -Issues $spotCheckIssues -SuccessDetails '1:1, 1:2, 2:1, 9:1, 114:6 exact'

    # ---------------------------------------------------------------
    # Cross-check generated reports
    # ---------------------------------------------------------------

    $generationReportIssues = New-Object System.Collections.ArrayList
    $generationReportSize = [long]0
    $generationReportHash = ''
    if (-not [System.IO.File]::Exists($generationReportPath)) {
        [void]$generationReportIssues.Add('generation validation report is missing')
    }
    elseif (-not [System.IO.File]::Exists((Join-Path $validationDir 'spot-checks.json'))) {
        [void]$generationReportIssues.Add('spot-checks.json is missing')
    }
    else {
        $generationReportSize = [long](Get-Item -LiteralPath $generationReportPath).Length
        $generationReportHash = Get-Sha256Hex -Path $generationReportPath
        try {
            $generationReport = (Read-Utf8TextFile -Path $generationReportPath) | ConvertFrom-Json
        }
        catch {
            [void]$generationReportIssues.Add(('validation-report.json parse error: {0}' -f $_.Exception.Message))
        }

        if ($null -ne $generationReport) {
            if ([string]$generationReport.status -ne 'passed' -or [int]$generationReport.checks_failed -ne 0) {
                [void]$generationReportIssues.Add('generation report status is not passed')
            }
            if ([string]$generationReport.generated_at_utc -ne [string]$manifest.generated_at_utc) {
                [void]$generationReportIssues.Add('generation timestamp mismatch')
            }
            if ([string]$generationReport.acquired_at_utc -ne [string]$acquisition.acquired_at_utc) {
                [void]$generationReportIssues.Add('acquisition timestamp mismatch')
            }
            if (-not (Test-OrdinalEqual -Left ([string]$generationReport.sources.arabic.sha256) -Right ([string]$sourceActual['arabic'].Hash))) {
                [void]$generationReportIssues.Add('Arabic source hash mismatch')
            }
            if (-not (Test-OrdinalEqual -Left ([string]$generationReport.sources.english.sha256) -Right ([string]$sourceActual['english'].Hash))) {
                [void]$generationReportIssues.Add('English source hash mismatch')
            }
            if (-not (Test-OrdinalEqual -Left ([string]$generationReport.manifest_sha256) -Right $manifestHash)) {
                [void]$generationReportIssues.Add('manifest hash mismatch')
            }
            if (-not (Test-OrdinalEqual -Left ([string]$generationReport.content_checksum.value) -Right $recomputedContentChecksum)) {
                [void]$generationReportIssues.Add('content checksum mismatch')
            }
            if ([int]$generationReport.generated_files.surah_file_count -ne 114) {
                [void]$generationReportIssues.Add('generated file count mismatch')
            }
            if ([long]$generationReport.generated_files.surah_files_total_size_bytes -ne [long]$totalGeneratedSize) {
                [void]$generationReportIssues.Add('generated total size mismatch')
            }
            if ([long]$generationReport.generated_files.manifest_size_bytes -ne [long]$manifestSize) {
                [void]$generationReportIssues.Add('manifest size mismatch')
            }
            if ((@($generationReport.sajdah_locations) -join ',') -ne ($expectedSajdahKeys -join ',')) {
                [void]$generationReportIssues.Add('Sajdah locations mismatch')
            }
            if ((@($generationReport.spot_checks | ForEach-Object { $_.key }) -join ',') -ne ($expectedSpotKeys -join ',')) {
                [void]$generationReportIssues.Add('spot-check keys mismatch')
            }
            if ([int]$generationReport.totals.ayahs -ne 6236 -or [int]$generationReport.totals.surahs -ne 114) {
                [void]$generationReportIssues.Add('report totals mismatch')
            }
            if (-not (Test-OrdinalEqual -Left ([string]$generationReport.read_only_guard.catalogue_sha256) -Right (Get-Sha256Hex -Path $cataloguePath))) {
                [void]$generationReportIssues.Add('catalogue guard hash mismatch')
            }
            if (-not (Test-OrdinalEqual -Left ([string]$generationReport.read_only_guard.pubspec_sha256) -Right (Get-Sha256Hex -Path $pubspecPath))) {
                [void]$generationReportIssues.Add('pubspec guard hash mismatch')
            }
            if ([bool]$generationReport.read_only_guard.app_quran_dir_exists) {
                [void]$generationReportIssues.Add('app Qur''an asset directory exists')
            }
        }

        $spotCheckFile = $null
        try {
            $spotCheckFile = (Read-Utf8TextFile -Path (Join-Path $validationDir 'spot-checks.json')) | ConvertFrom-Json
        }
        catch {
            [void]$generationReportIssues.Add(('spot-checks.json parse error: {0}' -f $_.Exception.Message))
        }

        if ($null -ne $spotCheckFile) {
            $spotFileKeys = @($spotCheckFile.checks | ForEach-Object { $_.key })
            if (($spotFileKeys -join ',') -ne ($expectedSpotKeys -join ',')) {
                [void]$generationReportIssues.Add('spot-checks.json keys mismatch')
            }
            foreach ($record in @($spotCheckFile.checks)) {
                if (-not [bool]$record.arabic_matches_source -or -not [bool]$record.translation_matches_source -or -not [bool]$record.footnotes_matches_source -or -not [bool]$record.sajdah_matches_source) {
                    [void]$generationReportIssues.Add(('spot-checks.json {0} mismatch' -f $record.key))
                }
                if ([bool]$record.basmala_prepended_to_ayah) {
                    [void]$generationReportIssues.Add(('spot-checks.json {0} reports prepended Basmala' -f $record.key))
                }
            }
        }
    }

    $generationCrossCheck = [ordered]@{
        report_path = $generationReportPath
        report_size_bytes = [long]$generationReportSize
        report_sha256 = $generationReportHash
        status = if ($null -ne $generationReport) { [string]$generationReport.status } else { '' }
        checks_total = if ($null -ne $generationReport) { [int]$generationReport.checks_total } else { 0 }
        checks_passed = if ($null -ne $generationReport) { [int]$generationReport.checks_passed } else { 0 }
        checks_failed = if ($null -ne $generationReport) { [int]$generationReport.checks_failed } else { 0 }
        matches_current_dataset = ($generationReportIssues.Count -eq 0)
    }

    Add-TextSetCheck -Id 'report.generation_cross_check' -Category 'report' -Description 'validation-report.json and spot-checks.json agree with the independently recomputed dataset.' -Issues $generationReportIssues -SuccessDetails 'generation reports cross-checked'

    # ---------------------------------------------------------------
    # Read-only guards
    # ---------------------------------------------------------------

    $catalogueHashNow = Get-Sha256Hex -Path $cataloguePath
    $pubspecHashNow = Get-Sha256Hex -Path $pubspecPath
    $appQuranDirExistsNow = [System.IO.Directory]::Exists($appQuranDir)

    $catalogueMatchesManifest = (Test-OrdinalEqual -Left $catalogueHashNow -Right ([string]$manifest.sources.catalogue.sha256))
    $catalogueMatchesReport = ($null -ne $generationReport) -and (Test-OrdinalEqual -Left $catalogueHashNow -Right ([string]$generationReport.read_only_guard.catalogue_sha256))
    $pubspecMatchesReport = ($null -ne $generationReport) -and (Test-OrdinalEqual -Left $pubspecHashNow -Right ([string]$generationReport.read_only_guard.pubspec_sha256))

    $readOnlyGuard = [ordered]@{
        catalogue_path = 'assets/data/surahs.json'
        catalogue_sha256 = $catalogueHashNow
        catalogue_matches_manifest = [bool]$catalogueMatchesManifest
        catalogue_matches_generation_report = [bool]$catalogueMatchesReport
        pubspec_sha256 = $pubspecHashNow
        pubspec_matches_generation_report = [bool]$pubspecMatchesReport
        app_quran_dir_exists = [bool]$appQuranDirExistsNow
        app_quran_dir_created = $false
    }

    Add-Check -Id 'guard.catalogue' -Category 'guard' -Description 'assets/data/surahs.json is unchanged and still matches the manifest and generation report.' -Passed (
        $catalogueMatchesManifest -and $catalogueMatchesReport
    ) -Details ('sha256={0}' -f $catalogueHashNow)

    Add-Check -Id 'guard.pubspec' -Category 'guard' -Description 'pubspec.yaml is unchanged and still matches the generation report.' -Passed $pubspecMatchesReport -Details ('sha256={0}' -f $pubspecHashNow)

    Add-Check -Id 'guard.no_app_quran_assets' -Category 'guard' -Description 'No generated data has been copied into assets/data/quran/.' -Passed (-not $appQuranDirExistsNow) -Details ('exists={0}' -f $appQuranDirExistsNow)

}
catch {
    $fatalMessage = $_.Exception.Message
    Add-Check -Id 'validator.fatal' -Category 'fatal' -Description 'Validation completed without an unexpected fatal error.' -Passed $false -Details $fatalMessage
}

$checksArray = $script:checks.ToArray()
$checksPassed = @($script:checks | Where-Object { $_.passed }).Count
$checksFailed = $script:failures.Count
$reportStatus = if ($checksFailed -eq 0 -and [string]::IsNullOrEmpty($fatalMessage)) { 'passed' } else { 'failed' }

$report = [ordered]@{
    status = $reportStatus
    validated_at_utc = $ValidatedAtUtc
    fatal_error = $fatalMessage
    validator = [ordered]@{
        name = 'tafseer_audio independent Qur''an data validator'
        version = '1.0.0'
        entry_point = 'tool/quran_data/generator/validate.ps1'
        library = 'tool/quran_data/generator/quran_data_lib.psm1'
        independence_note = 'Re-parses the original XML and CSV and re-derives all counts, mappings, Basmala rules, markers, footnotes, spot checks and checksums.'
    }
    manifest = $manifestInfo
    sources = $sourceInfo
    catalogue = $catalogueInfo
    generated = $generatedInfo
    totals = $recomputedTotals
    content_checksum = $contentChecksumInfo
    sajdah_locations = @($actualSajdahKeys)
    spot_checks = $spotCheckRecords.ToArray()
    generation_report_cross_check = $generationCrossCheck
    read_only_guard = $readOnlyGuard
    checks_total = [int]$script:checks.Count
    checks_passed = [int]$checksPassed
    checks_failed = [int]$checksFailed
    checks = $checksArray
}

$reportJson = (ConvertTo-JsonText -Value $report) + "`n"
Write-Utf8TextFile -Path $independentPath -Text $reportJson

Write-Output ''
Write-Output ('Independent validation: {0}' -f $reportStatus.ToUpperInvariant())
Write-Output ('Checks: {0}/{1} passed; {2} failed' -f $checksPassed, $script:checks.Count, $checksFailed)
Write-Output ('Surahs: {0}; Ayahs: {1}; Arabic records: {2}; translations: {3}' -f $recomputedTotals.surahs, $recomputedTotals.ayahs, $recomputedTotals.arabic_records, $recomputedTotals.translation_records)
Write-Output ('Content checksum: {0}' -f $contentChecksumInfo.value)
Write-Output ('Report: {0}' -f $independentPath)

if ($reportStatus -ne 'passed') {
    $failureSummary = (@($script:failures | Select-Object -First 8 | ForEach-Object {
        '{0}: {1}' -f $_.id, $_.details
    }) -join ' | ')
    if ([string]::IsNullOrEmpty($failureSummary)) {
        $failureSummary = $fatalMessage
    }
    throw ('Independent validation failed ({0} failed check(s)). {1} See {2}' -f $checksFailed, $failureSummary, $independentPath)
}
