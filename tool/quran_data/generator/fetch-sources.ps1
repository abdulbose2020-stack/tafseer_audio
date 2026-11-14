# Acquires the approved Qur'an source files and records their provenance.
# Run from anywhere:
#   powershell -ExecutionPolicy Bypass -File tool/quran_data/generator/fetch-sources.ps1
#
# This script refuses to overwrite existing source files. If the upstream version
# differs from the reviewed version, it fails before writing anything.

[CmdletBinding()]
param(
    [string]$ExpectedTanzilVersion = '1.1',
    [string]$ExpectedTanzilReleaseDate = '2021-02-12',
    [string]$ExpectedQuranEncVersion = '1.1.2',
    [long]$ExpectedQuranEncLastUpdate = 1750772247,
    [string]$ExpectedQuranEncRevision = 'v1.1.2-csv.1',
    [string]$AcquiredAtUtc = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

Import-Module (Join-Path $PSScriptRoot 'quran_data_lib.psm1') -Force

$quranDataRoot = Split-Path -Parent $PSScriptRoot
$sourcesDir = Join-Path $quranDataRoot 'sources'
$validationDir = Join-Path $quranDataRoot 'validation'
$acquisitionPath = Join-Path $validationDir 'source-acquisition.json'

$tanzilUrl = 'https://tanzil.net/pub/download/index.php?agree=true&marks=true&outType=xml&quranType=uthmani&sajdah=true&rub=true&tatweel=true'
$tanzilUpdatesUrl = 'https://tanzil.net/docs/text_updates'
$quranEncCsvUrl = 'https://quranenc.com/en/home/d/csv/english_saheeh'
$quranEncApiUrl = 'https://quranenc.com/api/v1/translations/updates?key=english_saheeh'
$quranEncBrowseUrl = 'https://quranenc.com/en/browse/english_saheeh'
$quranEncTermsUrl = 'https://quranenc.com/en/home/about'

$quranEncTerms = 'Contents of the translations can be downloaded and re-published, with the following terms and conditions: 1. No modification, addition, or deletion of the content. 2. Clearly referring to the publisher and the source (QuranEnc.com). 3. Mentioning the version number when re-publishing the translation. 4. Keeping the transcript information inside the document. 5. Notifying the source (QuranEnc.com) of any note on the translation. 6. Updating the translation according to the latest version issued from the source (QuranEnc.com). 7. Inappropriate advertisements must not be included when displaying translations of the meanings of the Noble Quran.'

if ([string]::IsNullOrEmpty($AcquiredAtUtc)) {
    $AcquiredAtUtc = Get-UtcTimestamp
}

if ($AcquiredAtUtc -notmatch '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$') {
    throw "AcquiredAtUtc must look like 2026-11-13T12:34:56Z."
}

$tanzilFinal = Join-Path $sourcesDir ("tanzil-uthmani-v{0}.xml" -f $ExpectedTanzilVersion)
$quranEncFinal = Join-Path $sourcesDir ("quranenc-english_saheeh-v{0}.csv" -f $ExpectedQuranEncVersion)

foreach ($path in @($tanzilFinal, $quranEncFinal, $acquisitionPath)) {
    if ([System.IO.File]::Exists($path)) {
        throw "Refusing to overwrite existing file: $path. Inspect it and remove/rename it manually before re-running."
    }
}

if (-not [System.IO.Directory]::Exists($sourcesDir)) {
    [void][System.IO.Directory]::CreateDirectory($sourcesDir)
}
if (-not [System.IO.Directory]::Exists($validationDir)) {
    [void][System.IO.Directory]::CreateDirectory($validationDir)
}

# Verify the current upstream versions before downloading.
Write-Output 'Verifying upstream versions...'

$updatesResponse = Invoke-WebRequest -UseBasicParsing -Uri $tanzilUpdatesUrl
$updatesText = [regex]::Replace($updatesResponse.Content, '<[^>]+>', ' ')
$updatesText = [System.Net.WebUtility]::HtmlDecode($updatesText)
$updatesText = [regex]::Replace($updatesText, '\s+', ' ')

if ($updatesText -notmatch ('Version\s+' + [regex]::Escape($ExpectedTanzilVersion))) {
    throw "Tanzil no longer reports version $ExpectedTanzilVersion as current. Review the source before acquiring it."
}

$releaseDate = [System.DateTime]::ParseExact(
    $ExpectedTanzilReleaseDate,
    'yyyy-MM-dd',
    [System.Globalization.CultureInfo]::InvariantCulture
)
$releaseDateText = $releaseDate.ToString('MMMM d, yyyy', [System.Globalization.CultureInfo]::InvariantCulture)
if ($updatesText -notmatch [regex]::Escape($releaseDateText)) {
    throw "Tanzil no longer reports release date $ExpectedTanzilReleaseDate ($releaseDateText). Review the source before acquiring it."
}

$quranEncApi = Invoke-RestMethod -Uri $quranEncApiUrl -Method Get
if ([string]$quranEncApi.version -ne $ExpectedQuranEncVersion) {
    throw "QuranEnc reports version $($quranEncApi.version); the reviewed version is $ExpectedQuranEncVersion. Review the source before acquiring it."
}
if ([long]$quranEncApi.last_update -ne $ExpectedQuranEncLastUpdate) {
    throw "QuranEnc reports last_update $($quranEncApi.last_update); the reviewed value is $ExpectedQuranEncLastUpdate. Review the source before acquiring it."
}

$quranEncLastUpdateUtc = [System.DateTimeOffset]::FromUnixTimeSeconds($ExpectedQuranEncLastUpdate).UtcDateTime.ToString(
    'yyyy-MM-ddTHH:mm:ssZ',
    [System.Globalization.CultureInfo]::InvariantCulture
)

# Download into a private staging directory, validate, then move into sources/.
$workDir = Join-Path $validationDir ('.fetch-' + [guid]::NewGuid().ToString('N'))
[void][System.IO.Directory]::CreateDirectory($workDir)
$tanzilDownload = Join-Path $workDir 'tanzil-uthmani.xml'
$quranEncDownload = Join-Path $workDir 'quranenc-english_saheeh.csv'
$movedFiles = New-Object System.Collections.ArrayList

try {
    Write-Output 'Downloading Tanzil Uthmani XML...'
    Invoke-WebRequest -UseBasicParsing -Uri $tanzilUrl -OutFile $tanzilDownload
    if (-not [System.IO.File]::Exists($tanzilDownload) -or (Get-Item -LiteralPath $tanzilDownload).Length -le 0) {
        throw 'Tanzil download is empty or missing.'
    }

    Write-Output 'Downloading QuranEnc english_saheeh CSV...'
    Invoke-WebRequest -UseBasicParsing -Uri $quranEncCsvUrl -OutFile $quranEncDownload
    if (-not [System.IO.File]::Exists($quranEncDownload) -or (Get-Item -LiteralPath $quranEncDownload).Length -le 0) {
        throw 'QuranEnc download is empty or missing.'
    }

    Write-Output 'Validating downloaded sources...'
    $xml = Read-TanzilXml -Path $tanzilDownload
    $csv = Read-QuranEncCsv -Path $quranEncDownload

    if ($xml.Suras.Count -ne 114) {
        throw "Tanzil XML contains $($xml.Suras.Count) Surahs; expected 114."
    }

    $ayahCount = 0
    foreach ($sura in $xml.Suras) {
        $ayahCount += $sura.Ayahs.Count
    }
    if ($ayahCount -ne 6236) {
        throw "Tanzil XML contains $ayahCount Ayahs; expected 6236."
    }

    if ([string]::IsNullOrEmpty($xml.CopyrightBlock)) {
        throw 'Tanzil XML is missing the copyright block.'
    }
    if ($xml.CopyrightBlock -notmatch 'PLEASE DO NOT REMOVE OR CHANGE THIS COPYRIGHT BLOCK') {
        throw 'Tanzil XML copyright block does not contain the required preservation notice.'
    }
    if ($xml.CopyrightBlock -notmatch ('Version\s+' + [regex]::Escape($ExpectedTanzilVersion))) {
        throw "Tanzil XML copyright block does not identify version $ExpectedTanzilVersion."
    }
    if ($xml.CopyrightBlock -notmatch 'License:\s+Creative Commons Attribution 3\.0') {
        throw 'Tanzil XML copyright block does not contain the expected CC BY 3.0 licence line.'
    }

    $copyrightLineMatch = [regex]::Match($xml.CopyrightBlock, 'Copyright \(C\) [0-9]{4}-[0-9]{4} Tanzil Project')
    if (-not $copyrightLineMatch.Success) {
        throw 'Tanzil XML copyright block does not contain a recognizable copyright line.'
    }
    $copyrightLine = $copyrightLineMatch.Value

    if ($csv.Rows.Count -ne 6236) {
        throw "QuranEnc CSV contains $($csv.Rows.Count) data records; expected 6236."
    }
    if ($csv.InfoBlock -notmatch 'Translation ID:\s+english_saheeh') {
        throw 'QuranEnc CSV preamble does not identify english_saheeh.'
    }
    if ($csv.InfoBlock -notmatch [regex]::Escape($ExpectedQuranEncRevision)) {
        throw "QuranEnc CSV preamble does not identify revision $ExpectedQuranEncRevision."
    }
    if ($csv.InfoBlock -notmatch 'PLEASE DON''T REMOVE THIS IMPORTANT INFORMATION!') {
        throw 'QuranEnc CSV preamble does not contain the required preservation notice.'
    }

    $lastUpdateMatch = [regex]::Match($csv.InfoBlock, '# Last update:\s+([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2})')
    if (-not $lastUpdateMatch.Success) {
        throw 'QuranEnc CSV preamble does not contain a recognizable last-update timestamp.'
    }
    $lastUpdateSourceText = $lastUpdateMatch.Groups[1].Value

    $tanzilSize = (Get-Item -LiteralPath $tanzilDownload).Length
    $quranEncSize = (Get-Item -LiteralPath $quranEncDownload).Length
    $tanzilSha256 = Get-Sha256Hex -Path $tanzilDownload
    $quranEncSha256 = Get-Sha256Hex -Path $quranEncDownload

    [System.IO.File]::Move($tanzilDownload, $tanzilFinal)
    [void]$movedFiles.Add($tanzilFinal)
    [System.IO.File]::Move($quranEncDownload, $quranEncFinal)
    [void]$movedFiles.Add($quranEncFinal)

    # Re-read the final paths so the recorded hashes and sizes are for the files
    # that actually remain in sources/.
    $tanzilSize = (Get-Item -LiteralPath $tanzilFinal).Length
    $quranEncSize = (Get-Item -LiteralPath $quranEncFinal).Length
    $tanzilSha256 = Get-Sha256Hex -Path $tanzilFinal
    $quranEncSha256 = Get-Sha256Hex -Path $quranEncFinal

    $acquisition = [ordered]@{
        acquired_at_utc = $AcquiredAtUtc
        arabic = [ordered]@{
            name = ('Tanzil Quran Text (Uthmani, Version {0})' -f $ExpectedTanzilVersion)
            provider = 'Tanzil Project'
            url = $tanzilUrl
            updates_url = $tanzilUpdatesUrl
            version = $ExpectedTanzilVersion
            release_date = $ExpectedTanzilReleaseDate
            file = ('sources/tanzil-uthmani-v{0}.xml' -f $ExpectedTanzilVersion)
            size_bytes = [long]$tanzilSize
            sha256 = $tanzilSha256
            copyright = $copyrightLine
            license = 'Creative Commons Attribution 3.0'
            notice = $xml.CopyrightBlock
        }
        english = [ordered]@{
            name = 'QuranEnc English translation (english_saheeh)'
            provider = 'QuranEnc'
            publisher = 'Noor International Center'
            attribution = 'Noor International Center, through QuranEnc.'
            url = $quranEncCsvUrl
            browse_url = $quranEncBrowseUrl
            version = $ExpectedQuranEncVersion
            revision = $ExpectedQuranEncRevision
            last_update_unix = [long]$ExpectedQuranEncLastUpdate
            last_update_utc = $quranEncLastUpdateUtc
            last_update_source_text = $lastUpdateSourceText
            file = ('sources/quranenc-english_saheeh-v{0}.csv' -f $ExpectedQuranEncVersion)
            size_bytes = [long]$quranEncSize
            sha256 = $quranEncSha256
            license = 'QuranEnc Terms and Policies'
            license_url = $quranEncTermsUrl
            license_terms = $quranEncTerms
            source_info_block = $csv.InfoBlock
        }
    }

    $acquisitionJson = ConvertTo-JsonText -Value $acquisition
    Write-Utf8TextFile -Path $acquisitionPath -Text $acquisitionJson

    Write-Output ''
    Write-Output 'Acquisition completed.'
    Write-Output ("Arabic:  {0} ({1} bytes, SHA-256 {2})" -f $tanzilFinal, $tanzilSize, $tanzilSha256)
    Write-Output ("English: {0} ({1} bytes, SHA-256 {2})" -f $quranEncFinal, $quranEncSize, $quranEncSha256)
    Write-Output ("Provenance: {0}" -f $acquisitionPath)
}
catch {
    foreach ($path in $movedFiles) {
        if ([System.IO.File]::Exists($path)) {
            [System.IO.File]::Delete($path)
        }
    }
    throw
}
finally {
    if ([System.IO.Directory]::Exists($workDir)) {
        Remove-Item -LiteralPath $workDir -Recurse -Force
    }
}
