[CmdletBinding(SupportsShouldProcess = $true)]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$fontFamily = 'HackGen Console NF'
$version = '2.10.0'
$archiveUri = 'https://github.com/yuru7/HackGen/releases/download/v2.10.0/HackGen_NF_v2.10.0.zip'
$archiveSha256 = 'F8ABD483D5EDFAD88A78ED511978F43C83B43C48E364AA29EBE4A68217474428'
$registryPath = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'

foreach ($fontRegistryPath in @($registryPath, 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts')) {
    $fontRegistry = Get-Item -LiteralPath $fontRegistryPath -ErrorAction SilentlyContinue
    if ($fontRegistry) {
        foreach ($fontName in $fontRegistry.GetValueNames()) {
            if ($fontName -eq $fontFamily -or $fontName.StartsWith($fontFamily + ' ', [System.StringComparison]::OrdinalIgnoreCase)) {
                Write-Host "Already installed: $fontFamily"
                return
            }
        }
    }
}
if (-not $env:LOCALAPPDATA) {
    throw 'This installer requires Windows LOCALAPPDATA and installs fonts for the current user only.'
}
$fontDirectory = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
if (-not $PSCmdlet.ShouldProcess($fontDirectory, "Download verified HackGen NF $version and register $fontFamily for the current user")) {
    return
}

$temporaryBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
$temporaryRoot = [System.IO.Path]::GetFullPath((Join-Path $temporaryBase ('nvim-hackgen-font-' + [guid]::NewGuid().ToString('N'))))
if (-not $temporaryRoot.StartsWith($temporaryBase, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Could not resolve a temporary directory inside the system temporary folder.'
}
$fonts = @(
    @{ File = 'HackGenConsoleNF-Regular.ttf'; DisplayName = 'HackGen Console NF Regular (TrueType)' },
    @{ File = 'HackGenConsoleNF-Bold.ttf'; DisplayName = 'HackGen Console NF Bold (TrueType)' }
)

try {
    [void][System.IO.Directory]::CreateDirectory($temporaryRoot)
    $archivePath = Join-Path $temporaryRoot 'HackGen_NF.zip'
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -UseBasicParsing -Uri $archiveUri -OutFile $archivePath
    if ((Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash -cne $archiveSha256) {
        throw 'HackGen archive SHA256 verification failed. No fonts installed.'
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        foreach ($font in $fonts) {
            $entries = @($archive.Entries | Where-Object { $_.Name -ceq $font.File })
            if ($entries.Count -ne 1) {
                throw "Expected exactly one $($font.File) in the verified archive. No fonts installed."
            }
            $font.StagedPath = Join-Path $temporaryRoot $font.File
            $font.TargetPath = Join-Path $fontDirectory $font.File
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entries[0], $font.StagedPath, $false)
            if (Test-Path -LiteralPath $font.TargetPath) {
                if ((Get-FileHash -LiteralPath $font.TargetPath -Algorithm SHA256).Hash -cne (Get-FileHash -LiteralPath $font.StagedPath -Algorithm SHA256).Hash) {
                    throw "A different $($font.File) already exists. Remove the old font through Windows Settings before reinstalling. Existing files were kept."
                }
            }
        }
    }
    finally {
        $archive.Dispose()
    }

    [void][System.IO.Directory]::CreateDirectory($fontDirectory)
    if (-not (Test-Path -LiteralPath $registryPath)) {
        [void](New-Item -Path $registryPath -Force)
    }
    foreach ($font in $fonts) {
        if (-not (Test-Path -LiteralPath $font.TargetPath)) {
            Copy-Item -LiteralPath $font.StagedPath -Destination $font.TargetPath
        }
        [void](New-ItemProperty -LiteralPath $registryPath -Name $font.DisplayName -Value $font.TargetPath -PropertyType String -Force)
    }

    if (-not ('PortableNvim.FontRegistration' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace PortableNvim {
    public static class FontRegistration {
        [DllImport("gdi32.dll", CharSet = CharSet.Unicode)]
        public static extern int AddFontResourceEx(string filename, uint flags, IntPtr reserved);
        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern IntPtr SendMessageTimeout(IntPtr window, uint message, IntPtr wParam, IntPtr lParam, uint flags, uint timeout, out IntPtr result);
    }
}
'@
    }
    foreach ($font in $fonts) {
        if ([PortableNvim.FontRegistration]::AddFontResourceEx($font.TargetPath, 0, [IntPtr]::Zero) -eq 0) {
            Write-Warning "Font registered, but the current session could not load $($font.File). Sign out and back in if restarting Terminal is insufficient."
        }
    }
    $broadcastResult = [IntPtr]::Zero
    [void][PortableNvim.FontRegistration]::SendMessageTimeout([IntPtr]0xffff, 0x001d, [IntPtr]::Zero, [IntPtr]::Zero, 2, 1000, [ref]$broadcastResult)
    Write-Host "Installed: $fontFamily $version (current user). Restart Windows Terminal, then run scripts/configure-terminal.ps1."
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot -PathType Container) {
        $resolvedCleanupPath = [System.IO.Path]::GetFullPath($temporaryRoot)
        if (-not $resolvedCleanupPath.StartsWith($temporaryBase, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw 'Refusing to clean up a temporary directory outside the system temporary folder.'
        }
        Remove-Item -LiteralPath $resolvedCleanupPath -Recurse -Force
    }
}
