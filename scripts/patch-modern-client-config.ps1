param(
    [Parameter(Mandatory = $true)][string]$ModernClientPath,
    [string]$Portal = ''
)

. "$PSScriptRoot\common.ps1"
. "$PSScriptRoot\client-versions.ps1"

Ensure-EnvFile | Out-Null

if ([string]::IsNullOrWhiteSpace($Portal)) {
    $values = Get-CmangosEnv
    $address = Get-EnvValue -Values $values -Name 'HERMES_EXTERNAL_ADDRESS' -Default '127.0.0.1'
    $Portal = "${address}:$(Get-EnvValue -Values $values -Name 'HERMES_BNET_PORT' -Default '1119')"
}

$resolved = (Resolve-Path -LiteralPath $ModernClientPath).Path
$candidate = Join-Path $resolved '_classic_era_'
if (Test-Path -LiteralPath $candidate) {
    $clientDir = $candidate
} else {
    $clientDir = $resolved
}

$clientBinary = @(
    (Join-Path $clientDir 'WowClassic.exe'),
    (Join-Path $clientDir 'Wow.exe')
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

if (-not $clientBinary) {
    throw "Could not find WowClassic.exe or Wow.exe in $clientDir."
}

$clientVersion = Get-FileVersionText -Path $clientBinary
if (-not (Test-ModernHermesClientVersion -Version $clientVersion)) {
    throw "Unsupported modern client version '$clientVersion'. HermesProxy in this stack is pinned to Classic Era 1.14.2 build 42597; use original Vanilla 1.12.x directly or provide that exact archived Classic Era client for HermesProxy."
}

$wtfDir = Join-Path $clientDir 'WTF'
New-Item -ItemType Directory -Force -Path $wtfDir | Out-Null

$configPath = Join-Path $wtfDir 'Config.wtf'
if (Test-Path -LiteralPath $configPath) {
    $backup = "$configPath.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item -LiteralPath $configPath -Destination $backup
    $lines = New-Object System.Collections.Generic.List[string]
    $found = $false
    foreach ($line in Get-Content -LiteralPath $configPath) {
        if ($line -match '^\s*SET\s+portal\s+') {
            $lines.Add("SET portal `"$Portal`"")
            $found = $true
        } else {
            $lines.Add($line)
        }
    }
    if (-not $found) {
        $lines.Add("SET portal `"$Portal`"")
    }
    Set-Content -LiteralPath $configPath -Value $lines -Encoding ASCII
    Write-Host "Updated portal in $configPath"
    Write-Host "Backup: $backup"
} else {
    Set-Content -LiteralPath $configPath -Value @("SET portal `"$Portal`"") -Encoding ASCII
    Write-Host "Created $configPath"
}
