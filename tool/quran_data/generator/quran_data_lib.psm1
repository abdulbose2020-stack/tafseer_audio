# Shared helpers for the Qur'an data acquisition, generation and validation tools.
# PowerShell 5.1 compatible. No external dependencies.
Set-StrictMode -Version Latest

function Read-Utf8TextFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not [System.IO.File]::Exists($Path)) {
        throw "File not found: $Path"
    }

    # throwOnInvalidBytes = true: never silently replace invalid UTF-8.
    $encoding = New-Object System.Text.UTF8Encoding($false, $true)
    try {
        $text = [System.IO.File]::ReadAllText($Path, $encoding)
    }
    catch {
        throw "Unable to read '$Path' as valid UTF-8: $($_.Exception.Message)"
    }

    # File.ReadAllText normally removes a UTF-8 BOM, but guard explicitly.
    if ($text.Length -gt 0 -and [int]$text[0] -eq 0xFEFF) {
        $text = $text.Substring(1)
    }

    return $text
}

function Write-Utf8TextFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text
    )

    $directory = [System.IO.Path]::GetDirectoryName($Path)
    if (-not [string]::IsNullOrEmpty($directory) -and -not [System.IO.Directory]::Exists($directory)) {
        [void][System.IO.Directory]::CreateDirectory($directory)
    }

    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Text, $encoding)
}

function Get-Sha256Hex {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not [System.IO.File]::Exists($Path)) {
        throw "File not found: $Path"
    }

    $sha = [System.Security.Cryptography.SHA256]::Create()
    $stream = $null
    try {
        $stream = [System.IO.File]::Open(
            $Path,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::Read
        )
        $bytes = $sha.ComputeHash($stream)
    }
    finally {
        if ($null -ne $stream) {
            $stream.Dispose()
        }
        $sha.Dispose()
    }

    return (($bytes | ForEach-Object { $_.ToString('x2') }) -join '')
}

function Get-Sha256Text {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text
    )

    $encoding = New-Object System.Text.UTF8Encoding($false)
    $bytes = $encoding.GetBytes($Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash($bytes)
    }
    finally {
        $sha.Dispose()
    }

    return (($hash | ForEach-Object { $_.ToString('x2') }) -join '')
}

function Test-OrdinalEqual {
    param(
        [AllowNull()]
        [string]$Left,
        [AllowNull()]
        [string]$Right
    )

    return [System.String]::Equals($Left, $Right, [System.StringComparison]::Ordinal)
}

function ConvertTo-JsonStringLiteral {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value
    )

    $builder = New-Object System.Text.StringBuilder
    [void]$builder.Append('"')

    for ($i = 0; $i -lt $Value.Length; $i++) {
        $character = $Value[$i]
        $code = [int]$character

        if ($code -eq 0x22) {
            [void]$builder.Append('\"')
        }
        elseif ($code -eq 0x5C) {
            [void]$builder.Append('\\')
        }
        elseif ($code -eq 0x08) {
            [void]$builder.Append('\b')
        }
        elseif ($code -eq 0x09) {
            [void]$builder.Append('\t')
        }
        elseif ($code -eq 0x0A) {
            [void]$builder.Append('\n')
        }
        elseif ($code -eq 0x0C) {
            [void]$builder.Append('\f')
        }
        elseif ($code -eq 0x0D) {
            [void]$builder.Append('\r')
        }
        elseif ($code -lt 0x20) {
            [void]$builder.Append(('\u{0:x4}' -f $code))
        }
        else {
            [void]$builder.Append($character)
        }
    }

    [void]$builder.Append('"')
    return $builder.ToString()
}

function ConvertTo-JsonValue {
    param(
        [AllowNull()]
        $Value,
        [int]$IndentLevel
    )

    if ($null -eq $Value) {
        return 'null'
    }

    if ($Value -is [bool]) {
        if ($Value) {
            return 'true'
        }
        return 'false'
    }

    if ($Value -is [string]) {
        return ConvertTo-JsonStringLiteral -Value $Value
    }

    if ($Value -is [char]) {
        return ConvertTo-JsonStringLiteral -Value ([string]$Value)
    }

    if (
        $Value -is [byte] -or
        $Value -is [sbyte] -or
        $Value -is [int16] -or
        $Value -is [uint16] -or
        $Value -is [int32] -or
        $Value -is [uint32] -or
        $Value -is [int64] -or
        $Value -is [uint64]
    ) {
        return ([System.Convert]::ToInt64($Value)).ToString([System.Globalization.CultureInfo]::InvariantCulture)
    }

    if ($Value -is [single] -or $Value -is [double] -or $Value -is [decimal]) {
        return ([System.Convert]::ToDouble($Value)).ToString('R', [System.Globalization.CultureInfo]::InvariantCulture)
    }

    $indent = ' ' * $IndentLevel
    $childIndent = ' ' * ($IndentLevel + 2)

    if ($Value -is [System.Collections.IDictionary]) {
        if ($Value.Count -eq 0) {
            return '{}'
        }

        $parts = New-Object System.Collections.ArrayList
        foreach ($key in $Value.Keys) {
            $keyJson = ConvertTo-JsonStringLiteral -Value ([string]$key)
            $valueJson = ConvertTo-JsonValue -Value $Value[$key] -IndentLevel ($IndentLevel + 2)
            [void]$parts.Add($childIndent + $keyJson + ': ' + $valueJson)
        }

        return '{' + "`n" + ($parts -join (",`n")) + "`n" + $indent + '}'
    }

    if ($Value -is [System.Collections.IEnumerable]) {
        $items = @($Value)
        if ($items.Count -eq 0) {
            return '[]'
        }

        $parts = New-Object System.Collections.ArrayList
        foreach ($item in $items) {
            [void]$parts.Add($childIndent + (ConvertTo-JsonValue -Value $item -IndentLevel ($IndentLevel + 2)))
        }

        return '[' + "`n" + ($parts -join (",`n")) + "`n" + $indent + ']'
    }

    # Fail loudly rather than emitting a misleading representation.
    throw "Unsupported value type for JSON serialization: $($Value.GetType().FullName)"
}

function ConvertTo-JsonText {
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $Value
    )

    return (ConvertTo-JsonValue -Value $Value -IndentLevel 0)
}

function ConvertFrom-Rfc4180Csv {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text,
        [string]$SourceName = 'CSV'
    )

    $records = New-Object System.Collections.ArrayList
    $fields = New-Object System.Collections.ArrayList
    $field = New-Object System.Text.StringBuilder
    $inQuotes = $false
    $quoteStartLine = 0
    $line = 1
    $index = 0
    $endedWithRecordSeparator = $false

    while ($index -lt $Text.Length) {
        $character = $Text[$index]

        if ($inQuotes) {
            if ($character -eq '"') {
                if (($index + 1) -lt $Text.Length -and $Text[$index + 1] -eq '"') {
                    [void]$field.Append('"')
                    $index += 2
                    continue
                }

                # A closing quote may only be followed by a delimiter, a newline, or EOF.
                if (($index + 1) -lt $Text.Length) {
                    $next = $Text[$index + 1]
                    if ($next -ne ',' -and $next -ne "`r" -and $next -ne "`n") {
                        throw "$SourceName line ${line}: unexpected character after a closing quote."
                    }
                }

                $inQuotes = $false
                $index++
                continue
            }

            [void]$field.Append($character)
            if ($character -eq "`n") {
                $line++
            }
            $index++
            continue
        }

        if ($character -eq '"') {
            if ($field.Length -ne 0) {
                throw "$SourceName line ${line}: quote character inside an unquoted field."
            }
            $inQuotes = $true
            $quoteStartLine = $line
            $index++
            continue
        }

        if ($character -eq ',') {
            [void]$fields.Add($field.ToString())
            [void]$field.Clear()
            $index++
            $endedWithRecordSeparator = $false
            continue
        }

        if ($character -eq "`r" -or $character -eq "`n") {
            [void]$fields.Add($field.ToString())
            [void]$field.Clear()
            [void]$records.Add($fields.ToArray())
            $fields.Clear()

            if ($character -eq "`r" -and ($index + 1) -lt $Text.Length -and $Text[$index + 1] -eq "`n") {
                $index += 2
            }
            else {
                $index++
            }

            $line++
            $endedWithRecordSeparator = $true
            continue
        }

        [void]$field.Append($character)
        $index++
        $endedWithRecordSeparator = $false
    }

    if ($inQuotes) {
        throw "$SourceName line ${quoteStartLine}: unterminated quoted field."
    }

    if (-not $endedWithRecordSeparator) {
        [void]$fields.Add($field.ToString())
        [void]$records.Add($fields.ToArray())
        $fields.Clear()
    }

    return ,$records
}

function Read-QuranEncCsv {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $text = Read-Utf8TextFile -Path $Path
    $records = ConvertFrom-Rfc4180Csv -Text $text -SourceName $Path

    $expectedHeader = @('id', 'sura', 'aya', 'translation', 'footnotes')
    $headerIndex = -1

    for ($i = 0; $i -lt $records.Count; $i++) {
        $record = $records[$i]
        if ($record.Count -ne 5) {
            continue
        }

        $isHeader = $true
        for ($j = 0; $j -lt 5; $j++) {
            if (-not (Test-OrdinalEqual -Left ([string]$record[$j]) -Right ([string]$expectedHeader[$j]))) {
                $isHeader = $false
                break
            }
        }

        if ($isHeader) {
            $headerIndex = $i
            break
        }
    }

    if ($headerIndex -lt 0) {
        throw "QuranEnc CSV '$Path' does not contain the expected header: id,sura,aya,translation,footnotes"
    }

    $preambleRecords = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt $headerIndex; $i++) {
        [void]$preambleRecords.Add($records[$i])
    }

    $infoBlock = ''
    foreach ($record in $preambleRecords) {
        if ($record.Count -gt 0 -and -not [string]::IsNullOrEmpty([string]$record[0])) {
            $infoBlock = [string]$record[0]
            break
        }
    }

    if ([string]::IsNullOrEmpty($infoBlock)) {
        throw "QuranEnc CSV '$Path' has no translation information preamble."
    }

    $rows = New-Object System.Collections.ArrayList
    $expectedId = 1

    for ($i = ($headerIndex + 1); $i -lt $records.Count; $i++) {
        $record = $records[$i]

        # Ignore only genuinely blank records.
        if ($record.Count -eq 1 -and [string]::IsNullOrEmpty([string]$record[0])) {
            continue
        }

        if ($record.Count -ne 5) {
            throw "QuranEnc CSV '$Path' record $i has $($record.Count) fields; expected 5."
        }

        $idText = [string]$record[0]
        $suraText = [string]$record[1]
        $ayaText = [string]$record[2]

        if ($idText -notmatch '^[0-9]+$') {
            throw "QuranEnc CSV '$Path' record $i has a non-integer id: '$idText'."
        }
        if ($suraText -notmatch '^[0-9]+$') {
            throw "QuranEnc CSV '$Path' record $i has a non-integer sura: '$suraText'."
        }
        if ($ayaText -notmatch '^[0-9]+$') {
            throw "QuranEnc CSV '$Path' record $i has a non-integer aya: '$ayaText'."
        }

        $id = [int]$idText
        $sura = [int]$suraText
        $aya = [int]$ayaText

        if ($id -ne $expectedId) {
            throw "QuranEnc CSV '$Path' record $i has id $id; expected $expectedId."
        }
        $expectedId++

        [void]$rows.Add([pscustomobject]@{
            Id = $id
            Sura = $sura
            Aya = $aya
            Translation = [string]$record[3]
            Footnotes = [string]$record[4]
        })
    }

    return [pscustomobject]@{
        Path = $Path
        Text = $text
        ExpectedHeader = $expectedHeader
        PreambleRecords = $preambleRecords
        InfoBlock = $infoBlock
        Rows = $rows
    }
}

function Read-TanzilXml {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not [System.IO.File]::Exists($Path)) {
        throw "File not found: $Path"
    }

    $document = New-Object System.Xml.XmlDocument
    $document.XmlResolver = $null
    try {
        $document.Load($Path)
    }
    catch {
        throw "Unable to parse Tanzil XML '$Path': $($_.Exception.Message)"
    }

    if ($null -eq $document.DocumentElement -or $document.DocumentElement.Name -ne 'quran') {
        throw "Tanzil XML '$Path' does not have a <quran> document element."
    }

    $copyrightBlock = ''
    foreach ($comment in @($document.SelectNodes('//comment()'))) {
        if ($comment.Value -match 'Tanzil Quran Text') {
            $copyrightBlock = $comment.Value
            break
        }
    }

    $suras = New-Object System.Collections.ArrayList

    foreach ($suraNode in @($document.DocumentElement.SelectNodes('sura'))) {
        $suraText = $suraNode.GetAttribute('index')
        if ($suraText -notmatch '^[0-9]+$') {
            throw "Tanzil XML '$Path': sura has a missing or invalid index '$suraText'."
        }
        $suraNumber = [int]$suraText

        $ayahs = New-Object System.Collections.ArrayList

        foreach ($ayaNode in @($suraNode.SelectNodes('aya'))) {
            $ayaText = $ayaNode.GetAttribute('index')
            if ($ayaText -notmatch '^[0-9]+$') {
                throw "Tanzil XML '$Path': sura $suraNumber has an ayah with a missing or invalid index '$ayaText'."
            }
            $ayahNumber = [int]$ayaText

            $textAttribute = $ayaNode.Attributes['text']
            if ($null -eq $textAttribute) {
                throw "Tanzil XML '$Path': sura $suraNumber ayah $ayahNumber is missing its text attribute."
            }

            $bismillah = $null
            $bismillahAttribute = $ayaNode.Attributes['bismillah']
            if ($null -ne $bismillahAttribute) {
                $bismillah = $bismillahAttribute.Value
            }

            [void]$ayahs.Add([pscustomobject]@{
                Number = $ayahNumber
                Text = $textAttribute.Value
                Bismillah = $bismillah
            })
        }

        [void]$suras.Add([pscustomobject]@{
            Number = $suraNumber
            Name = $suraNode.GetAttribute('name')
            Ayahs = $ayahs
        })
    }

    return [pscustomobject]@{
        Path = $Path
        CopyrightBlock = $copyrightBlock
        Suras = $suras
    }
}

function Get-QuranMarkerCounts {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text
    )

    return [pscustomobject]@{
        PauseMarks = [regex]::Matches($Text, '[\u06D6-\u06DC]').Count
        RubElHizb = [regex]::Matches($Text, [regex]::Escape([string][char]0x06DE)).Count
        Sajdah = [regex]::Matches($Text, [regex]::Escape([string][char]0x06E9)).Count
        Tatweel = [regex]::Matches($Text, [regex]::Escape([string][char]0x0640)).Count
    }
}

function Test-HasChar {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text,
        [Parameter(Mandatory = $true)]
        [char]$Character
    )

    return ($Text.IndexOf($Character) -ge 0)
}

function Get-UtcTimestamp {
    return [System.DateTime]::UtcNow.ToString(
        'yyyy-MM-ddTHH:mm:ssZ',
        [System.Globalization.CultureInfo]::InvariantCulture
    )
}

function Write-GeneratedFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content,
        [switch]$Force
    )

    if ([System.IO.File]::Exists($Path)) {
        $existing = Read-Utf8TextFile -Path $Path
        if (Test-OrdinalEqual -Left $existing -Right $Content) {
            return [pscustomobject]@{
                Path = $Path
                Status = 'unchanged'
            }
        }

        if (-not $Force) {
            throw "Refusing to overwrite an existing file with different content: $Path. Inspect it first, then re-run with -Force only if the change is intentional."
        }

        Write-Utf8TextFile -Path $Path -Text $Content
        return [pscustomobject]@{
            Path = $Path
            Status = 'replaced'
        }
    }

    Write-Utf8TextFile -Path $Path -Text $Content
    return [pscustomobject]@{
        Path = $Path
        Status = 'created'
    }
}

Export-ModuleMember -Function @(
    'Read-Utf8TextFile',
    'Write-Utf8TextFile',
    'Get-Sha256Hex',
    'Get-Sha256Text',
    'Test-OrdinalEqual',
    'ConvertTo-JsonStringLiteral',
    'ConvertTo-JsonText',
    'ConvertFrom-Rfc4180Csv',
    'Read-QuranEncCsv',
    'Read-TanzilXml',
    'Get-QuranMarkerCounts',
    'Test-HasChar',
    'Get-UtcTimestamp',
    'Write-GeneratedFile'
)
