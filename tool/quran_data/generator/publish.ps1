# Publishes the validated generated Qur'an dataset into the Flutter runtime assets.
# Run from anywhere:
#   powershell -ExecutionPolicy Bypass -File tool/quran_data/generator/publish.ps1
#
# The script never regenerates source or generated data. It:
#   1. runs validate.ps1 in pre-publish mode;
#   2. reads and re-verifies the generated manifest and Surah files;
#   3. copies the generated output into a staging directory and verifies it;
#   4. backs up assets/data/quran, then swaps in the verified staging copy;
#   5. runs validate.ps1 in post-publish mode;
#   6. restores the backup if any step after the swap fails.
#
# The previous runtime directory is kept under tool/quran_data/backups/ unless
# -RemoveBackupOnSuccess is supplied. Paths are derived from this script's
# location and are reported relative to the project root.

[CmdletBinding()]
param(
    [switch]$RemoveBackupOnSuccess
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'quran_data_lib.psm1') -Force

$quranDataRoot = Split-Path -Parent $PSScriptRoot
$toolRoot = Split-Path -Parent $quranDataRoot
$projectRoot = Split-Path -Parent $toolRoot

$generatedDir = Join-Path $quranDataRoot 'generated'
$generatedManifestPath = Join-Path $generatedDir 'manifest.json'
$generatedSurahsDir = Join-Path $generatedDir 'surahs'
$runtimeDir = Join-Path $projectRoot 'assets\data\quran'
$validateScript = Join-Path $PSScriptRoot 'validate.ps1'
$workRoot = Join-Path $quranDataRoot 'publish-work'
$backupRoot = Join-Path $quranDataRoot 'backups'

function Get-ProjectRelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ($Path.StartsWith($projectRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        $relative = $Path.Substring($projectRoot.Length)
        return $relative.TrimStart('\', '/').Replace('\', '/')
    }

    return $Path.Replace('\', '/')
}

function Get-DatasetContentChecksum {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SurahsDirectory
    )

    $builder = New-Object System.Text.StringBuilder
    for ($number = 1; $number -le 114; $number++) {
        $fileName = '{0:D3}.json' -f $number
        $path = Join-Path $SurahsDirectory $fileName
        if (-not [System.IO.File]::Exists($path)) {
            throw ('Missing Surah file while computing the content checksum: {0}' -f $path)
        }

        [void]$builder.Append($fileName)
        [void]$builder.Append("`n")
        [void]$builder.Append((Get-Sha256Hex -Path $path))
        [void]$builder.Append("`n")
    }

    return (Get-Sha256Text -Text $builder.ToString())
}

function Remove-DirectoryIfExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ([System.IO.Directory]::Exists($Path)) {
        [System.IO.Directory]::Delete($Path, $true)
    }
}

function Invoke-QuranValidation {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('pre-publish', 'post-publish')]
        [string]$ValidationMode
    )

    & $validateScript -Mode $ValidationMode
}

# ---------------------------------------------------------------
# 1. Validate the generated dataset before touching runtime assets
# ---------------------------------------------------------------

Write-Output 'Step 1/6: validating generated data (pre-publish)...'
try {
    Invoke-QuranValidation -ValidationMode 'pre-publish'
}
catch {
    throw ('Pre-publish validation failed: {0}' -f $_.Exception.Message)
}

# ---------------------------------------------------------------
# 2. Re-verify the generated manifest and files independently
# ---------------------------------------------------------------

Write-Output 'Step 2/6: re-verifying generated manifest and files...'

if (-not [System.IO.File]::Exists($generatedManifestPath)) {
    throw ('Missing generated manifest: {0}' -f (Get-ProjectRelativePath -Path $generatedManifestPath))
}
if (-not [System.IO.Directory]::Exists($generatedSurahsDir)) {
    throw ('Missing generated Surah directory: {0}' -f (Get-ProjectRelativePath -Path $generatedSurahsDir))
}

$generatedManifest = (Read-Utf8TextFile -Path $generatedManifestPath) | ConvertFrom-Json
$generatedManifestHash = Get-Sha256Hex -Path $generatedManifestPath
$generatedChecksum = [string]$generatedManifest.content_checksum.value

if ([string]$generatedManifest.content_checksum.algorithm -ne 'SHA-256') {
    throw 'The generated manifest content checksum algorithm is not SHA-256.'
}
if ([int]$generatedManifest.content_checksum.file_count -ne 114) {
    throw ('The generated manifest content checksum file count is {0}; expected 114.' -f $generatedManifest.content_checksum.file_count)
}
if ($generatedChecksum -notmatch '^[0-9a-f]{64}$') {
    throw 'The generated manifest content checksum is not a lowercase SHA-256 digest.'
}

$generatedSurahEntries = @($generatedManifest.surahs)
if ($generatedSurahEntries.Count -ne 114) {
    throw ('The generated manifest has {0} Surah entries; expected 114.' -f $generatedSurahEntries.Count)
}

$manifestEntryByNumber = @{}
foreach ($entry in $generatedSurahEntries) {
    $number = [int]$entry.number
    if ($number -lt 1 -or $number -gt 114) {
        throw ('The generated manifest has an invalid Surah number: {0}.' -f $number)
    }
    if ($manifestEntryByNumber.ContainsKey($number)) {
        throw ('The generated manifest has a duplicate Surah entry: {0}.' -f $number)
    }
    $manifestEntryByNumber[$number] = $entry
}
for ($number = 1; $number -le 114; $number++) {
    if (-not $manifestEntryByNumber.ContainsKey($number)) {
        throw ('The generated manifest is missing Surah {0}.' -f $number)
    }
}

$generatedHashByNumber = @{}
for ($number = 1; $number -le 114; $number++) {
    $fileName = '{0:D3}.json' -f $number
    $path = Join-Path $generatedSurahsDir $fileName
    if (-not [System.IO.File]::Exists($path)) {
        throw ('Missing generated Surah file: {0}' -f (Get-ProjectRelativePath -Path $path))
    }

    $actualHash = Get-Sha256Hex -Path $path
    $generatedHashByNumber[$number] = $actualHash
    $expectedHash = [string]$manifestEntryByNumber[$number].sha256
    if (-not (Test-OrdinalEqual -Left $actualHash -Right $expectedHash)) {
        throw ('Generated Surah {0:D3} does not match its manifest SHA-256.' -f $number)
    }
}

$generatedComputedChecksum = Get-DatasetContentChecksum -SurahsDirectory $generatedSurahsDir
if (-not (Test-OrdinalEqual -Left $generatedComputedChecksum -Right $generatedChecksum)) {
    throw ('Generated content checksum mismatch: computed={0}; manifest={1}.' -f $generatedComputedChecksum, $generatedChecksum)
}

Write-Output ('Generated dataset verified: 114 Surahs; manifest sha256={0}; content checksum={1}' -f $generatedManifestHash, $generatedChecksum)

# ---------------------------------------------------------------
# 3. Stage a copy and verify it before replacing runtime assets
# ---------------------------------------------------------------

Write-Output 'Step 3/6: staging and verifying generated files...'

$runId = ([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ', [System.Globalization.CultureInfo]::InvariantCulture)) + '-' + ([Guid]::NewGuid().ToString('N').Substring(0, 8))
$stagingRoot = Join-Path $workRoot ('staging-' + $runId)
$stagingSurahsDir = Join-Path $stagingRoot 'surahs'
[void][System.IO.Directory]::CreateDirectory($stagingSurahsDir)

try {
    [System.IO.File]::Copy($generatedManifestPath, (Join-Path $stagingRoot 'manifest.json'), $false)
    for ($number = 1; $number -le 114; $number++) {
        $fileName = '{0:D3}.json' -f $number
        [System.IO.File]::Copy(
            (Join-Path $generatedSurahsDir $fileName),
            (Join-Path $stagingSurahsDir $fileName),
            $false
        )
    }

    $stagedFiles = @(Get-ChildItem -LiteralPath $stagingRoot -Recurse -File -Force)
    if ($stagedFiles.Count -ne 115) {
        throw ('Staged file count is {0}; expected 115 (manifest.json plus 114 Surahs).' -f $stagedFiles.Count)
    }

    $stagedManifestHash = Get-Sha256Hex -Path (Join-Path $stagingRoot 'manifest.json')
    if (-not (Test-OrdinalEqual -Left $stagedManifestHash -Right $generatedManifestHash)) {
        throw ('Staged manifest SHA-256 mismatch: staged={0}; generated={1}.' -f $stagedManifestHash, $generatedManifestHash)
    }

    for ($number = 1; $number -le 114; $number++) {
        $fileName = '{0:D3}.json' -f $number
        $stagedHash = Get-Sha256Hex -Path (Join-Path $stagingSurahsDir $fileName)
        $manifestHash = [string]$manifestEntryByNumber[$number].sha256
        if (-not (Test-OrdinalEqual -Left $stagedHash -Right $manifestHash)) {
            throw ('Staged Surah {0:D3} does not match its manifest SHA-256.' -f $number)
        }
        if (-not (Test-OrdinalEqual -Left $stagedHash -Right ([string]$generatedHashByNumber[$number]))) {
            throw ('Staged Surah {0:D3} does not match the generated file.' -f $number)
        }
    }

    $stagedComputedChecksum = Get-DatasetContentChecksum -SurahsDirectory $stagingSurahsDir
    if (-not (Test-OrdinalEqual -Left $stagedComputedChecksum -Right $generatedChecksum)) {
        throw ('Staged content checksum mismatch: staged={0}; generated={1}.' -f $stagedComputedChecksum, $generatedChecksum)
    }

    Write-Output ('Staging verified: 115 files; content checksum={0}' -f $stagedComputedChecksum)
}
catch {
    Remove-DirectoryIfExists -Path $stagingRoot
    if ([System.IO.Directory]::Exists($workRoot) -and @(Get-ChildItem -LiteralPath $workRoot -Force).Count -eq 0) {
        [System.IO.Directory]::Delete($workRoot, $false)
    }
    throw
}

# ---------------------------------------------------------------
# 4-6. Swap, validate, and roll back on failure
# ---------------------------------------------------------------

Write-Output 'Step 4/6: backing up and replacing runtime assets...'

$runtimeExistedBefore = [System.IO.Directory]::Exists($runtimeDir)
$backupPath = ''
$backupCreated = $false
$newRuntimeInstalled = $false
$publishSucceeded = $false

try {
    [void][System.IO.Directory]::CreateDirectory((Split-Path -Parent $runtimeDir))

    if ($runtimeExistedBefore) {
        [void][System.IO.Directory]::CreateDirectory($backupRoot)
        $backupPath = Join-Path $backupRoot ('quran-' + $runId)
        Move-Item -LiteralPath $runtimeDir -Destination $backupPath
        $backupCreated = $true
        Write-Output ('Backed up existing runtime assets to {0}' -f (Get-ProjectRelativePath -Path $backupPath))
    }
    else {
        Write-Output 'No existing runtime assets to back up.'
    }

    Move-Item -LiteralPath $stagingRoot -Destination $runtimeDir
    $newRuntimeInstalled = $true
    Write-Output ('Replaced runtime assets at {0}' -f (Get-ProjectRelativePath -Path $runtimeDir))

    Write-Output 'Step 5/6: validating published runtime assets (post-publish)...'
    try {
        Invoke-QuranValidation -ValidationMode 'post-publish'
    }
    catch {
        throw ('Post-publish validation failed: {0}' -f $_.Exception.Message)
    }

    $publishSucceeded = $true
}
catch {
    $publishError = $_
    Write-Warning ('Publishing failed: {0}' -f $publishError.Exception.Message)

    $rollbackError = ''
    try {
        if ($newRuntimeInstalled -and [System.IO.Directory]::Exists($runtimeDir)) {
            Remove-DirectoryIfExists -Path $runtimeDir
        }
        elseif (-not $runtimeExistedBefore -and [System.IO.Directory]::Exists($runtimeDir)) {
            Remove-DirectoryIfExists -Path $runtimeDir
        }

        if ($backupCreated -and [System.IO.Directory]::Exists($backupPath)) {
            if ([System.IO.Directory]::Exists($runtimeDir)) {
                Remove-DirectoryIfExists -Path $runtimeDir
            }
            Move-Item -LiteralPath $backupPath -Destination $runtimeDir
            $backupCreated = $false
            Write-Output 'Rollback complete: the previous runtime assets were restored.'
        }
        elseif (-not $runtimeExistedBefore) {
            Write-Output 'Rollback complete: the newly published runtime assets were removed.'
        }
    }
    catch {
        $rollbackError = $_.Exception.Message
    }

    if (-not [string]::IsNullOrEmpty($rollbackError)) {
        throw ('Publishing failed and rollback also failed: {0}. Original error: {1}. Backup path: {2}' -f $rollbackError, $publishError.Exception.Message, (Get-ProjectRelativePath -Path $backupPath))
    }

    throw $publishError
}
finally {
    if ([System.IO.Directory]::Exists($stagingRoot)) {
        Remove-DirectoryIfExists -Path $stagingRoot
    }
    if ([System.IO.Directory]::Exists($workRoot) -and @(Get-ChildItem -LiteralPath $workRoot -Force).Count -eq 0) {
        [System.IO.Directory]::Delete($workRoot, $false)
    }
    if ([System.IO.Directory]::Exists($backupRoot) -and @(Get-ChildItem -LiteralPath $backupRoot -Force).Count -eq 0) {
        [System.IO.Directory]::Delete($backupRoot, $false)
    }
}

if (-not $publishSucceeded) {
    throw 'Publishing did not complete.'
}

# ---------------------------------------------------------------
# Summary
# ---------------------------------------------------------------

$publishedManifestPath = Join-Path $runtimeDir 'manifest.json'
$publishedManifest = (Read-Utf8TextFile -Path $publishedManifestPath) | ConvertFrom-Json
$publishedChecksum = [string]$publishedManifest.content_checksum.value
$publishedFiles = @(Get-ChildItem -LiteralPath $runtimeDir -Recurse -File -Force)
$publishedSurahFiles = @(Get-ChildItem -LiteralPath (Join-Path $runtimeDir 'surahs') -File -Force)

if ($RemoveBackupOnSuccess -and $backupCreated) {
    try {
        Remove-DirectoryIfExists -Path $backupPath
        $backupCreated = $false
        if ([System.IO.Directory]::Exists($backupRoot) -and @(Get-ChildItem -LiteralPath $backupRoot -Force).Count -eq 0) {
            [System.IO.Directory]::Delete($backupRoot, $false)
        }
        Write-Output 'Previous runtime backup removed (-RemoveBackupOnSuccess).'
    }
    catch {
        Write-Warning ('Publish succeeded, but the previous runtime backup could not be removed: {0}' -f $_.Exception.Message)
    }
}

Write-Output ''
Write-Output 'Publish complete.'
Write-Output ('Published files: {0} ({1} Surahs + manifest.json)' -f $publishedFiles.Count, $publishedSurahFiles.Count)
Write-Output ('Content checksum: {0}' -f $publishedChecksum)
Write-Output ('Runtime assets: {0}' -f (Get-ProjectRelativePath -Path $runtimeDir))

if ($backupCreated) {
    Write-Output ('Previous runtime backup: {0}' -f (Get-ProjectRelativePath -Path $backupPath))
}
elseif ($runtimeExistedBefore) {
    Write-Output 'Previous runtime backup: removed after successful validation.'
}
else {
    Write-Output 'Previous runtime backup: none (no previous runtime assets).'
}

if (-not (Test-OrdinalEqual -Left $publishedChecksum -Right $generatedChecksum)) {
    throw ('Published content checksum changed after validation: published={0}; generated={1}.' -f $publishedChecksum, $generatedChecksum)
}
