param(
    [string]$LegacyClientPath = '',
    [string]$ModernClientPath = ''
)

. "$PSScriptRoot\common.ps1"
. "$PSScriptRoot\client-versions.ps1"

function Resolve-ModernClientPath {
    param([string]$Path)

    $resolved = (Resolve-Path -LiteralPath $Path).Path
    $candidate = Join-Path $resolved '_classic_era_'
    if (Test-Path -LiteralPath $candidate) {
        return $candidate
    }
    return $resolved
}

$checked = $false

if (-not [string]::IsNullOrWhiteSpace($LegacyClientPath)) {
    $checked = $true
    $legacy = (Resolve-Path -LiteralPath $LegacyClientPath).Path
    $legacyData = Join-Path $legacy 'Data'
    Write-Host "Legacy client: $legacy"
    if (-not (Test-Path -LiteralPath $legacyData)) {
        Write-Warning "Missing Data directory."
    } else {
        $mpq = Get-ChildItem -LiteralPath $legacyData -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -ieq '.mpq' } |
            Select-Object -First 1
        if ($mpq) {
            Write-Host "MPQ layout: found"
        } else {
            Write-Warning "No MPQ files found; this does not look like original 1.12.x client data."
        }
    }

    $legacyExe = Join-Path $legacy 'WoW.exe'
    $version = Get-FileVersionText -Path $legacyExe
    if ($version) {
        Write-Host "WoW.exe version: $version"
        if (-not (Test-LegacyClientVersion -Version $version)) {
            Write-Warning "Expected an original Vanilla 1.12.x executable for direct legacy testing and extraction."
        }
    } else {
        Write-Warning "WoW.exe not found at the legacy client root."
    }
}

if (-not [string]::IsNullOrWhiteSpace($ModernClientPath)) {
    $checked = $true
    $modern = Resolve-ModernClientPath -Path $ModernClientPath
    Write-Host "Modern Classic Era client: $modern"

    $modernExe = @(
        (Join-Path $modern 'WowClassic.exe'),
        (Join-Path $modern 'Wow.exe')
    ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

    if ($modernExe) {
        $version = Get-FileVersionText -Path $modernExe
        Write-Host "Executable version: $version"
        if (-not (Test-ModernHermesClientVersion -Version $version)) {
            Write-Warning "Unsupported for this stack. HermesProxy is pinned to Classic Era 1.14.2 build 42597; current Battle.net Classic Era clients are too new for this route."
        }
    } else {
        Write-Warning "Could not find WowClassic.exe or Wow.exe in the modern client path."
    }

    $config = Join-Path $modern 'WTF\Config.wtf'
    if (Test-Path -LiteralPath $config) {
        $portal = Select-String -LiteralPath $config -Pattern '^\s*SET\s+portal\s+' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($portal) {
            Write-Host "Portal line: $($portal.Line)"
        } else {
            Write-Warning "No SET portal line found. Run .\scripts\patch-modern-client-config.ps1."
        }
    } else {
        Write-Warning "Missing WTF\Config.wtf. Run the modern client once or use the patch script to create it."
    }
}

if (-not $checked) {
    Write-Host "Provide -LegacyClientPath, -ModernClientPath, or both."
}
