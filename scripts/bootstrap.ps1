[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$SkipTools,
    [switch]$SkipRust,
    [switch]$SkipCodex,
    [switch]$SkipProvider,
    [switch]$SkipNeovimBootstrap,
    [switch]$InstallBuildTools,
    [switch]$InstallFont
)

$ErrorActionPreference = 'Stop'
$script:BootstrapCmdlet = $PSCmdlet
$script:DryRun = [bool]$WhatIfPreference
$configRoot = Split-Path -Parent $PSScriptRoot
$appName = if ($env:NVIM_APPNAME) { $env:NVIM_APPNAME } else { 'nvim' }
$expectedRoot = Join-Path $env:LOCALAPPDATA $appName
if ([IO.Path]::GetFullPath($configRoot).TrimEnd('\') -ine [IO.Path]::GetFullPath($expectedRoot).TrimEnd('\')) {
    throw "Clone this repository into $expectedRoot before running bootstrap.ps1. No configuration is copied automatically."
}
if ([IntPtr]::Size -ne 8 -or ($env:PROCESSOR_ARCHITECTURE -ne 'AMD64' -and $env:PROCESSOR_ARCHITEW6432 -ne 'AMD64')) {
    throw 'This bootstrap targets Windows x64. Use an x64 PowerShell session.'
}

function Invoke-Change {
    param([string]$Target, [string]$Description, [scriptblock]$Action)
    if ($script:BootstrapCmdlet.ShouldProcess($Target, $Description)) { & $Action }
}

function Invoke-Native {
    param([string]$Command, [string[]]$Arguments, [int[]]$AllowedExitCodes = @(0), [switch]$ReturnExitCode)
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) { throw "Command is not available: $Command. Check installed dependencies and PATH." }
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $Command @Arguments | Out-Host
        $commandCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($AllowedExitCodes -notcontains $commandCode) { throw "$Command failed with exit code $commandCode." }
    if ($ReturnExitCode) { return $commandCode }
}

function Refresh-Path {
    $entries = @([Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';')
    $entries += [Environment]::GetEnvironmentVariable('Path', 'User') -split ';'
    $env:Path = (@($entries | Where-Object { $_ } | Select-Object -Unique) -join ';')
}

function Add-UserPath {
    param([string]$Directory, [switch]$First)
    if (-not $Directory) { return }
    $entries = @([Environment]::GetEnvironmentVariable('Path', 'User') -split ';' | Where-Object { $_ })
    if ($entries -notcontains $Directory -or ($First -and $entries[0] -ne $Directory)) {
        Invoke-Change $Directory 'Add directory to user PATH' {
            $entries = @($entries | Where-Object { $_ -ine $Directory })
            if ($First) { $entries = @($Directory) + $entries } else { $entries += $Directory }
            [Environment]::SetEnvironmentVariable('Path', ($entries -join ';'), 'User')
        }
    }
    if (-not $script:DryRun) {
        $env:Path = $Directory + ';' + $env:Path
    }
}

function Install-WingetPackage {
    param([string]$Id, [string[]]$ExtraArguments = @(), [switch]$DefaultScope)
    Invoke-Change $Id 'Install missing dependency with WinGet' {
        $arguments = @('install', '--exact', '--id', $Id, '--source', 'winget', '--silent', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')
        if ($DefaultScope) {
            Invoke-Native 'winget.exe' ($arguments + $ExtraArguments)
        } else {
            $installCode = Invoke-Native 'winget.exe' ($arguments + @('--scope', 'user') + $ExtraArguments) -AllowedExitCodes @(0, -1978335216) -ReturnExitCode
            if ($installCode -eq -1978335216) {
                Write-Output "$Id has no user-scope installer. Its default installer may request administrator access."
                Invoke-Native 'winget.exe' ($arguments + $ExtraArguments)
            } elseif ($installCode -ne 0) {
                throw "WinGet could not install $Id (exit $installCode). Install it manually, then rerun this script."
            }
        }
        Refresh-Path
    }
}

function Find-Python314 {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Python\pythoncore-3.14-64\python.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python314\python.exe'),
        (Join-Path $env:ProgramFiles 'Python314\python.exe')
    )
    $candidates += @(Get-Command python.exe -All -ErrorAction SilentlyContinue | Where-Object { $_.Source -notlike '*\WindowsApps\*' } | Select-Object -ExpandProperty Source)
    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            if ($script:DryRun) { return $candidate }
            $version = & $candidate -c 'import sys; print(str(sys.version_info.major)+chr(46)+str(sys.version_info.minor))'
            if ($LASTEXITCODE -eq 0 -and $version -eq '3.14') { return $candidate }
        }
    }
}

Refresh-Path
if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue) -and -not $SkipTools) {
    throw 'Install Microsoft App Installer (WinGet), then rerun this script.'
}
if (-not $SkipTools) {
    $tools = @(
        @{ Command = 'git.exe'; Id = 'Git.Git' },
        @{ Command = 'nvim.exe'; Id = 'Neovim.Neovim' },
        @{ Command = 'rg.exe'; Id = 'BurntSushi.ripgrep.MSVC' },
        @{ Command = 'fd.exe'; Id = 'sharkdp.fd' },
        @{ Command = 'lazygit.exe'; Id = 'JesseDuffield.lazygit' },
        @{ Command = 'fzf.exe'; Id = 'junegunn.fzf' },
        @{ Command = 'gcc.exe'; Id = 'BrechtSanders.WinLibs.POSIX.UCRT' },
        @{ Command = 'cmake.exe'; Id = 'Kitware.CMake' },
        @{ Command = 'ninja.exe'; Id = 'Ninja-build.Ninja' },
        @{ Command = 'gh.exe'; Id = 'GitHub.cli' },
        @{ Command = 'uv.exe'; Id = 'astral-sh.uv' }
    )
    foreach ($tool in $tools) {
        if (Get-Command $tool.Command -ErrorAction SilentlyContinue) {
            Write-Output "Already available: $($tool.Command)"
        } else {
            Install-WingetPackage $tool.Id
        }
    }
    if (-not (Get-Command node.exe -ErrorAction SilentlyContinue)) {
        Install-WingetPackage 'OpenJS.NodeJS.LTS' @('--installer-type', 'zip')
    }
    $nodeBinary = Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\OpenJS.NodeJS.LTS*\node-v*-win-x64\node.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($nodeBinary) { Add-UserPath $nodeBinary.DirectoryName }
    $python = Find-Python314
    if (-not $python) {
        Install-WingetPackage 'Python.Python.3.14'
        $python = Find-Python314
    }
    if ($python) {
        Add-UserPath (Join-Path (Split-Path $python -Parent) 'Scripts')
        Add-UserPath (Split-Path $python -Parent) -First
    } elseif (-not $script:DryRun) {
        throw 'Python 3.14 was not found. Restart PowerShell after installation and rerun this script.'
    }
    if (-not (Get-Command gitui.exe -ErrorAction SilentlyContinue)) {
        $gitUiDirectory = Join-Path $env:LOCALAPPDATA 'Programs\GitUI'
        Invoke-Change $gitUiDirectory 'Install GitUI 0.28.1 portable from its official release' {
            New-Item -ItemType Directory -Path $gitUiDirectory -Force | Out-Null
            $archive = Join-Path $env:TEMP ('gitui-' + [Guid]::NewGuid().ToString('N') + '.tar.gz')
            try {
                Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/gitui-org/gitui/releases/download/v0.28.1/gitui-win.tar.gz' -OutFile $archive
                $checksum = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
                if ($checksum -ne 'FAB116CCDF9AE4E17378DB912D76CC26E60AEFD2226F44E665120DEA166867E4') { throw 'GitUI archive checksum mismatch.' }
                Invoke-Native 'tar.exe' @('-xzf', $archive, '-C', $gitUiDirectory)
            } finally {
                if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive -Force }
            }
        }
        Add-UserPath $gitUiDirectory
    }
}

if (-not $SkipRust) {
    $cargoDirectory = if ($env:CARGO_HOME) { Join-Path $env:CARGO_HOME 'bin' } else { Join-Path $env:USERPROFILE '.cargo\bin' }
    $rustup = Join-Path $cargoDirectory 'rustup.exe'
    if (-not (Test-Path -LiteralPath $rustup)) { $rustup = (Get-Command rustup.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source) }
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    $hasMsvc = [bool](Get-ChildItem -Path "${env:ProgramFiles(x86)}\Microsoft Visual Studio\*\*\VC\Tools\MSVC\*\bin\Hostx64\x64\cl.exe", "$env:ProgramFiles\Microsoft Visual Studio\*\*\VC\Tools\MSVC\*\bin\Hostx64\x64\cl.exe" -ErrorAction SilentlyContinue | Select-Object -First 1)
    if ((Test-Path -LiteralPath $vswhere) -and -not $script:DryRun) {
        $hasMsvc = [bool](& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath)
    }
    if (-not $hasMsvc) {
        if ($InstallBuildTools) {
            Install-WingetPackage 'Microsoft.VisualStudio.2022.BuildTools' @('--override', '--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended') -DefaultScope
        } else {
            Write-Output 'Rust MSVC builds require Visual Studio C++ Build Tools and Windows SDK. Install the Desktop development with C++ workload, or rerun with -InstallBuildTools.'
        }
    }
    if (-not $rustup) {
        Invoke-Change $cargoDirectory 'Install Rust stable with rustup for Windows x64 MSVC' {
            $installer = Join-Path $env:TEMP ('rustup-' + [Guid]::NewGuid().ToString('N') + '.exe')
            try {
                Invoke-WebRequest -UseBasicParsing -Uri 'https://win.rustup.rs/x86_64' -OutFile $installer
                Invoke-Native $installer @('-y', '--profile', 'minimal', '--default-toolchain', 'stable', '--default-host', 'x86_64-pc-windows-msvc', '--no-modify-path')
            } finally {
                if (Test-Path -LiteralPath $installer) { Remove-Item -LiteralPath $installer -Force }
            }
        }
        $rustup = Join-Path $cargoDirectory 'rustup.exe'
    }
    Add-UserPath $cargoDirectory
    Invoke-Change 'Rust stable toolchain' 'Ensure stable toolchain and rustfmt, clippy, rust-src, rust-analyzer' {
        $installedToolchains = & $rustup toolchain list
        if (-not ($installedToolchains -match '^stable-')) { Invoke-Native $rustup @('toolchain', 'install', 'stable', '--profile', 'minimal') }
        Invoke-Native $rustup @('component', 'add', '--toolchain', 'stable', 'rustfmt', 'clippy', 'rust-src', 'rust-analyzer')
    }
}

if (-not $SkipCodex) {
    Add-UserPath (Join-Path $env:APPDATA 'npm')
    if (Get-Command codex.cmd, codex.exe -ErrorAction SilentlyContinue) {
        Write-Output 'Already available: Codex CLI'
    } else {
        Invoke-Change '@openai/codex' 'Install the official Codex CLI with npm' {
            $nodeVersion = & node.exe --version
            if ($nodeVersion -notmatch '^v(\d+)' -or [int]$Matches[1] -lt 22) { throw 'Use Node.js LTS (22 or newer) before installing Codex CLI.' }
            Invoke-Native 'npm.cmd' @('install', '--global', '@openai/codex')
        }
    }
}

if ($InstallFont) {
    Invoke-Change 'HackGen Console NF' 'Install the terminal font for the current Windows user' {
        & (Join-Path $PSScriptRoot 'install-font.ps1')
    }
}

if (-not $SkipProvider -or -not $SkipNeovimBootstrap) {
    $dataRoot = Join-Path $env:LOCALAPPDATA ($appName + '-data')
    if (-not $script:DryRun) {
        $nvimVersion = & nvim.exe --version | Select-Object -First 1
        if ($nvimVersion -notmatch 'NVIM v(\d+)\.(\d+)' -or [int]$Matches[1] -eq 0 -and [int]$Matches[2] -lt 12) { throw 'Neovim 0.12 or newer is required. Upgrade Neovim and rerun.' }
        $paths = (& nvim.exe --headless -u NONE -i NONE -n -c "lua io.stdout:write(vim.json.encode({config=vim.fn.stdpath('config'),data=vim.fn.stdpath('data')}))" -c 'qa!') | ConvertFrom-Json
        if ([IO.Path]::GetFullPath($paths.config).TrimEnd('\') -ine [IO.Path]::GetFullPath($configRoot).TrimEnd('\')) {
            throw "Neovim resolves another configuration directory: $($paths.config). Check NVIM_APPNAME and XDG_CONFIG_HOME before retrying."
        }
        $dataRoot = $paths.data
    }
    if (-not $SkipProvider) {
        $providerRoot = Join-Path $dataRoot 'python-provider'
        $providerPython = Join-Path $providerRoot 'Scripts\python.exe'
        Invoke-Change $providerRoot 'Ensure a dedicated Python 3.14 provider virtual environment with pynvim' {
            if (-not (Test-Path -LiteralPath $providerPython)) { Invoke-Native 'uv.exe' @('venv', '--python', '3.14', $providerRoot) }
            Invoke-Native 'uv.exe' @('pip', 'install', '--python', $providerPython, 'pynvim')
        }
    }
    if (-not $SkipNeovimBootstrap) {
        Invoke-Change $configRoot 'Install plugins, restore the original lockfile, install Mason tools and Treesitter parsers' {
            $lockPath = Join-Path $configRoot 'lazy-lock.json'
            $lockBytes = [IO.File]::ReadAllBytes($lockPath)
            $previousBootstrapScript = $env:NVIM_BOOTSTRAP_SCRIPT
            try {
                $lock = [Text.Encoding]::UTF8.GetString($lockBytes) | ConvertFrom-Json
                foreach ($seed in @(
                    @{ Name = 'lazy.nvim'; Repository = 'https://github.com/folke/lazy.nvim.git' },
                    @{ Name = 'LazyVim'; Repository = 'https://github.com/LazyVim/LazyVim.git' }
                )) {
                    $pluginDirectory = Join-Path (Join-Path $dataRoot 'lazy') $seed.Name
                    if (-not (Test-Path -LiteralPath (Join-Path $pluginDirectory '.git'))) {
                        if (Test-Path -LiteralPath $pluginDirectory) { throw "Existing plugin directory is not a Git checkout: $pluginDirectory" }
                        New-Item -ItemType Directory -Path (Split-Path $pluginDirectory -Parent) -Force | Out-Null
                        Invoke-Native 'git.exe' @('clone', '--filter=blob:none', $seed.Repository, $pluginDirectory)
                        Invoke-Native 'git.exe' @('-C', $pluginDirectory, 'checkout', '--detach', $lock.PSObject.Properties[$seed.Name].Value.commit)
                    }
                }
                try {
                    Invoke-Native 'nvim.exe' @('--headless', '-i', 'NONE', '-n', '-c', 'Lazy! install', '-c', 'qa!')
                } finally {
                    [IO.File]::WriteAllBytes($lockPath, $lockBytes)
                }
                $env:NVIM_BOOTSTRAP_SCRIPT = Join-Path $PSScriptRoot 'bootstrap-nvim.lua'
                Invoke-Native 'nvim.exe' @('--headless', '-i', 'NONE', '-n', '-c', "lua local ok,err=xpcall(function() dofile(vim.env.NVIM_BOOTSTRAP_SCRIPT) end,debug.traceback); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit') end")
            } finally {
                [IO.File]::WriteAllBytes($lockPath, $lockBytes)
                $env:NVIM_BOOTSTRAP_SCRIPT = $previousBootstrapScript
            }
        }
    }
}
Write-Output 'Bootstrap finished. Restart your terminal; run gh auth login and codex login manually on this PC as needed.'
