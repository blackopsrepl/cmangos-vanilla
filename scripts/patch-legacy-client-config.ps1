param(
    [Parameter(Mandatory = $true)][string]$LegacyClientPath,
    [string]$Address = '',
    [int]$Port = 0
)

. "$PSScriptRoot\common.ps1"

$values = Get-CmangosEnv
if ([string]::IsNullOrWhiteSpace($Address)) {
    $Address = Get-EnvValue -Values $values -Name 'REALM_ADDRESS' -Default '127.0.0.1'
}
if ($Port -eq 0) {
    $Port = [int](Get-EnvValue -Values $values -Name 'LEGACY_AUTH_PORT' -Default '3724')
}

$clientDir = (Resolve-Path -LiteralPath $LegacyClientPath).Path
if (-not (Test-Path -LiteralPath (Join-Path $clientDir 'Data'))) {
    throw "Legacy client path must contain a Data directory: $clientDir"
}

$targetValue = $Address
if ($Port -ne 3724) {
    $targetValue = "${Address}:${Port}"
}

$possibleFiles = @(
    (Join-Path $clientDir 'realmlist.wtf')
)

$localeRealmlists = Get-ChildItem -LiteralPath (Join-Path $clientDir 'Data') -Directory -ErrorAction SilentlyContinue |
    ForEach-Object { Join-Path $_.FullName 'realmlist.wtf' }
$possibleFiles += $localeRealmlists

$existing = $possibleFiles | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $existing) {
    $existing = Join-Path $clientDir 'realmlist.wtf'
}

if (Test-Path -LiteralPath $existing) {
    $backup = "$existing.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item -LiteralPath $existing -Destination $backup
    Write-Host "Backup: $backup"
}

Set-Content -LiteralPath $existing -Value @("set realmlist $targetValue") -Encoding ASCII
Write-Host "Updated legacy realmlist: $existing"

$wtfDir = Join-Path $clientDir 'WTF'
New-Item -ItemType Directory -Force -Path $wtfDir | Out-Null

$configPath = Join-Path $wtfDir 'Config.wtf'
$instantQuestText = Get-EnvValue -Values $values -Name 'CLIENT_INSTANT_QUEST_TEXT' -Default '1'
if (@('0', 'false', 'False', 'FALSE', 'no', 'No', 'NO', 'off', 'Off', 'OFF') -contains $instantQuestText) {
    $instantQuestText = '0'
} else {
    $instantQuestText = '1'
}
$questTextLine = "SET instantQuestText `"$instantQuestText`""
if (Test-Path -LiteralPath $configPath) {
    $backup = "$configPath.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item -LiteralPath $configPath -Destination $backup
    $lines = New-Object System.Collections.Generic.List[string]
    $found = $false
    foreach ($line in Get-Content -LiteralPath $configPath) {
        if ($line -match '^\s*SET\s+instantQuestText\s+') {
            $lines.Add($questTextLine)
            $found = $true
        } else {
            $lines.Add($line)
        }
    }
    if (-not $found) {
        $lines.Add($questTextLine)
    }
    Set-Content -LiteralPath $configPath -Value $lines -Encoding ASCII
    Write-Host "Set instant quest text to $instantQuestText in $configPath"
    Write-Host "Backup: $backup"
} else {
    Set-Content -LiteralPath $configPath -Value @($questTextLine) -Encoding ASCII
    Write-Host "Created $configPath with instant quest text set to $instantQuestText"
}
