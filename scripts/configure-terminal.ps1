[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string[]]$SettingsPath,
    [string]$ProfileDefaultsPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false, $true)
$manualInstructions = 'Open Windows Terminal Settings > Open JSON file, then merge terminal/profile-defaults.json into profiles.defaults. Keep your existing profiles and other settings.'
if (-not $ProfileDefaultsPath) {
    $ProfileDefaultsPath = Join-Path $PSScriptRoot '..\terminal\profile-defaults.json'
}

function Read-TerminalJson {
    param([string]$Text, [string]$Label)

    $withoutComments = [System.Text.StringBuilder]::new()
    $inString = $false
    $escaped = $false
    $hasJsonComments = $false
    for ($index = 0; $index -lt $Text.Length; $index++) {
        $character = $Text[$index]
        if ($inString) {
            [void]$withoutComments.Append($character)
            if ($escaped) {
                $escaped = $false
            }
            elseif ($character -eq '\') {
                $escaped = $true
            }
            elseif ($character -eq '"') {
                $inString = $false
            }
            continue
        }
        if ($character -eq '"') {
            $inString = $true
        }
        elseif ($character -eq '/' -and $index + 1 -lt $Text.Length) {
            if ($Text[$index + 1] -eq '/') {
                $hasJsonComments = $true
                [void]$withoutComments.Append(' ')
                while ($index + 1 -lt $Text.Length -and $Text[$index + 1] -ne "`n") {
                    $index++
                }
                continue
            }
            if ($Text[$index + 1] -eq '*') {
                $hasJsonComments = $true
                $end = $Text.IndexOf('*/', $index + 2, [System.StringComparison]::Ordinal)
                if ($end -lt 0) {
                    throw "Unterminated JSONC comment in $Label. No settings changed. $manualInstructions"
                }
                [void]$withoutComments.Append(' ')
                $index = $end + 1
                continue
            }
        }
        [void]$withoutComments.Append($character)
    }
    if ($inString) {
        throw "Unterminated JSON string in $Label. No settings changed. $manualInstructions"
    }

    $jsonc = $withoutComments.ToString()
    $json = [System.Text.StringBuilder]::new()
    $inString = $false
    $escaped = $false
    $previousToken = ''
    for ($index = 0; $index -lt $jsonc.Length; $index++) {
        $character = $jsonc[$index]
        if ($inString) {
            [void]$json.Append($character)
            if ($escaped) {
                $escaped = $false
            }
            elseif ($character -eq '\') {
                $escaped = $true
            }
            elseif ($character -eq '"') {
                $inString = $false
                $previousToken = 'string'
            }
            continue
        }
        if ($character -eq '"') {
            $inString = $true
        }
        elseif ($character -eq ',') {
            if ($previousToken -eq '' -or $previousToken -in @(',', ':', '[', '{')) {
                throw "Invalid JSON comma in $Label. No settings changed. $manualInstructions"
            }
            $nextIndex = $index + 1
            while ($nextIndex -lt $jsonc.Length -and [char]::IsWhiteSpace($jsonc[$nextIndex])) {
                $nextIndex++
            }
            if ($nextIndex -lt $jsonc.Length -and $jsonc[$nextIndex] -in @('}', ']')) {
                $hasJsonComments = $true
                continue
            }
        }
        if (-not [char]::IsWhiteSpace($character)) {
            $previousToken = [string]$character
        }
        [void]$json.Append($character)
    }
    $jsonText = $json.ToString()
    if (-not $jsonText.TrimStart().StartsWith('{')) {
        throw "Expected a JSON object in $Label. No settings changed. $manualInstructions"
    }
    try {
        $parseParameters = @{ InputObject = $jsonText; ErrorAction = 'Stop' }
        if ((Get-Command ConvertFrom-Json -CommandType Cmdlet).Parameters.ContainsKey('DateKind')) {
            $parseParameters.DateKind = 'String'
        }
        $document = ConvertFrom-Json @parseParameters
    }
    catch {
        throw "Cannot safely parse $Label. No settings changed. $manualInstructions Parser error: $($_.Exception.Message)"
    }
    if ($document -isnot [System.Management.Automation.PSCustomObject]) {
        throw "Expected a JSON object in $Label. No settings changed. $manualInstructions"
    }
    Assert-TerminalJsonValues -Value $document
    return [pscustomobject]@{ Document = $document; HadJsonc = $hasJsonComments }
}

function Assert-TerminalJsonValues {
    param([object]$Value)

    if ($Value -is [datetime] -or $Value -is [datetimeoffset]) {
        throw "This PowerShell version converts JSON date strings automatically. No settings changed. Use Windows PowerShell 5.1 or PowerShell 7.5+, or edit manually. $manualInstructions"
    }
    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        foreach ($property in $Value.PSObject.Properties) {
            Assert-TerminalJsonValues -Value $property.Value
        }
    }
    elseif ($Value -is [array]) {
        foreach ($element in $Value) {
            Assert-TerminalJsonValues -Value $element
        }
    }
}

function Get-TerminalSettingsPaths {
    $candidates = [System.Collections.Generic.List[string]]::new()
    if ($env:LOCALAPPDATA) {
        foreach ($relativePath in @(
            'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json',
            'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json',
            'Packages\Microsoft.WindowsTerminalCanary_8wekyb3d8bbwe\LocalState\settings.json',
            'Microsoft\Windows Terminal\settings.json'
        )) {
            $candidates.Add((Join-Path $env:LOCALAPPDATA $relativePath))
        }
    }
    if ($env:WT_SETTINGS_DIR) {
        $candidates.Add((Join-Path $env:WT_SETTINGS_DIR 'settings.json'))
    }
    foreach ($command in @(Get-Command 'WindowsTerminal.exe', 'wt.exe' -All -ErrorAction SilentlyContinue)) {
        if ($command.Source) {
            $terminalDirectory = Split-Path -Parent $command.Source
            if (Test-Path -LiteralPath (Join-Path $terminalDirectory '.portable') -PathType Leaf) {
                $candidates.Add((Join-Path $terminalDirectory 'settings\settings.json'))
            }
        }
    }
    return @($candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -Unique)
}

function Test-TerminalFont {
    param([string]$Family)

    foreach ($registryPath in @(
        'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
        'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
    )) {
        $fontRegistry = Get-Item -LiteralPath $registryPath -ErrorAction SilentlyContinue
        if ($fontRegistry) {
            foreach ($fontName in $fontRegistry.GetValueNames()) {
                if ($fontName -eq $Family -or $fontName.StartsWith($Family + ' ', [System.StringComparison]::OrdinalIgnoreCase)) {
                    return $true
                }
            }
        }
    }
    return $false
}

function Set-TerminalValue {
    param([object]$Object, [string]$Name, [object]$Value)

    $property = $Object.PSObject.Properties[$Name]
    if ($property) {
        $previous = ConvertTo-Json -InputObject $property.Value -Compress -Depth 100
        $next = ConvertTo-Json -InputObject $Value -Compress -Depth 100
        if ($previous -ceq $next) {
            return $false
        }
    }
    Add-Member -InputObject $Object -MemberType NoteProperty -Name $Name -Value $Value -Force
    return $true
}

function Get-TerminalObject {
    param([object]$Object, [string]$Name)

    $property = $Object.PSObject.Properties[$Name]
    if (-not $property) {
        $value = [pscustomobject]@{}
        Add-Member -InputObject $Object -MemberType NoteProperty -Name $Name -Value $value
        return $value
    }
    if ($property.Value -isnot [System.Management.Automation.PSCustomObject]) {
        throw "profiles/defaults/font must be JSON objects. No settings changed. $manualInstructions"
    }
    return $property.Value
}

$templateFile = Get-Item -LiteralPath $ProfileDefaultsPath
if ($templateFile -isnot [System.IO.FileInfo]) {
    throw 'ProfileDefaultsPath must point to a JSON file.'
}
$template = (Read-TerminalJson -Text ([System.IO.File]::ReadAllText($templateFile.FullName, $utf8)) -Label $templateFile.FullName).Document
$templateNames = @($template.PSObject.Properties.Name)
if (@($templateNames | Where-Object { $_ -notin @('opacity', 'useAcrylic', 'font') }).Count -gt 0 -or $templateNames.Count -ne 3) {
    throw 'The profile defaults template must contain only opacity, useAcrylic and font.'
}
if ($template.opacity -isnot [ValueType] -or $template.opacity -is [bool] -or $template.opacity -lt 0 -or $template.opacity -gt 100 -or $template.useAcrylic -isnot [bool]) {
    throw 'The profile defaults template requires numeric opacity (0-100) and Boolean useAcrylic.'
}
if ($template.font -isnot [System.Management.Automation.PSCustomObject] -or @($template.font.PSObject.Properties.Name).Count -ne 2 -or -not $template.font.PSObject.Properties['face'] -or -not $template.font.PSObject.Properties['size']) {
    throw 'The profile defaults template font must contain only face and size.'
}
if ($template.font.face -isnot [string] -or [string]::IsNullOrWhiteSpace($template.font.face) -or $template.font.size -isnot [ValueType] -or $template.font.size -is [bool] -or $template.font.size -le 0) {
    throw 'The profile defaults template requires a font face and positive numeric font size.'
}

$fontInstalled = Test-TerminalFont -Family $template.font.face
if (-not $fontInstalled) {
    Write-Warning "Font '$($template.font.face)' is not installed. Existing font settings will be kept. Install the font, then rerun this script to apply its face and size."
}
if (-not $SettingsPath) {
    $SettingsPath = @(Get-TerminalSettingsPaths)
}
if (-not $SettingsPath) {
    throw "No Windows Terminal settings found. Start Terminal once, or pass -SettingsPath with its settings.json location. $manualInstructions"
}

foreach ($candidatePath in @($SettingsPath | Select-Object -Unique)) {
    $settingsFile = Get-Item -LiteralPath $candidatePath
    if ($settingsFile -isnot [System.IO.FileInfo]) {
        throw "SettingsPath must point to an existing settings.json file: $candidatePath"
    }
    $settingsFilePath = $settingsFile.FullName
    $original = [System.IO.File]::ReadAllText($settingsFilePath, $utf8)
    $parsed = Read-TerminalJson -Text $original -Label $settingsFilePath
    $profiles = Get-TerminalObject -Object $parsed.Document -Name 'profiles'
    $defaults = Get-TerminalObject -Object $profiles -Name 'defaults'
    $changed = Set-TerminalValue -Object $defaults -Name 'opacity' -Value $template.opacity
    $changed = (Set-TerminalValue -Object $defaults -Name 'useAcrylic' -Value $template.useAcrylic) -or $changed
    if ($fontInstalled) {
        $font = Get-TerminalObject -Object $defaults -Name 'font'
        $changed = (Set-TerminalValue -Object $font -Name 'face' -Value $template.font.face) -or $changed
        $changed = (Set-TerminalValue -Object $font -Name 'size' -Value $template.font.size) -or $changed
    }
    if (-not $changed) {
        Write-Host "Already configured: $settingsFilePath"
        continue
    }
    $replacement = (ConvertTo-Json -InputObject $parsed.Document -Depth 100 -WarningAction Stop) + [Environment]::NewLine
    $backupPath = $settingsFilePath + '.backup-' + (Get-Date -Format 'yyyyMMdd-HHmmssfff') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
    if ($PSCmdlet.ShouldProcess($settingsFilePath, 'Back up and merge portable Windows Terminal profile defaults')) {
        if ([System.IO.File]::ReadAllText($settingsFilePath, $utf8) -cne $original) {
            throw 'Terminal settings changed while being read. No settings changed; rerun the script.'
        }
        $temporaryPath = $settingsFilePath + '.tmp-' + [guid]::NewGuid().ToString('N')
        try {
            [System.IO.File]::WriteAllText($temporaryPath, $replacement, $utf8)
            [System.IO.File]::Replace($temporaryPath, $settingsFilePath, $backupPath, $true)
        }
        finally {
            if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
                Remove-Item -LiteralPath $temporaryPath -Force
            }
        }
        if ($parsed.HadJsonc) {
            Write-Warning 'JSONC comments and trailing commas were removed during JSON serialization; the original is preserved in the backup.'
        }
        Write-Host "Updated: $settingsFilePath"
        Write-Host "Backup:  $backupPath"
    }
}
