param(
    [switch]$AuthOnly,
    [switch]$Proxy
)

. "$PSScriptRoot\common.ps1"

Ensure-EnvFile | Out-Null
Require-Docker

$values = Get-CmangosEnv
$root = Get-RepoRoot
$failures = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

function Add-Failure {
    param([string]$Message)
    $script:failures.Add($Message) | Out-Null
}

function Add-WarningLine {
    param([string]$Message)
    $script:warnings.Add($Message) | Out-Null
}

if (-not $AuthOnly) {
    $missingData = @(Get-MissingExtractedData)
    if ($missingData.Count -gt 0) {
        try {
            Sync-ExtractedDataFromComposeVolume
            $missingData = @(Get-MissingExtractedData)
        } catch {
            # Keep the smoke failure focused on the required data paths.
        }
    }
    foreach ($path in $missingData) {
        Add-Failure "Missing or invalid extracted data directory: $path"
    }
}

$authPort = [int](Get-EnvValue -Values $values -Name 'LEGACY_AUTH_PORT' -Default '3724')
$worldPort = [int](Get-EnvValue -Values $values -Name 'LEGACY_WORLD_PORT' -Default '8085')

if (-not (Test-NetConnection -ComputerName '127.0.0.1' -Port $authPort -InformationLevel Quiet)) {
    Add-Failure "Legacy auth port is not reachable on 127.0.0.1:$authPort"
}
if (-not $AuthOnly -and -not (Test-NetConnection -ComputerName '127.0.0.1' -Port $worldPort -InformationLevel Quiet)) {
    Add-Failure "Legacy world port is not reachable on 127.0.0.1:$worldPort"
}

$realmDb = Get-EnvValue -Values $values -Name 'MANGOS_DB_REALM' -Default 'classicrealmd'
try {
    $realm = Invoke-DbQuery -Database $realmDb -Sql 'SELECT id, name, address, port, realmflags FROM realmlist WHERE id=1;'
    if (-not $realm) {
        Add-Failure "No realm row found in $realmDb.realmlist."
    } else {
        Write-Host "Realm row:"
        Write-Host $realm
    }
} catch {
    Add-Failure "Could not query realm DB: $($_.Exception.Message)"
}

$envPath = Get-EnvPath
$composeLog = New-ArtifactLogPath -Name 'smoke-compose'
$dockerArgs = @('compose', '--env-file', $envPath, 'logs', '--no-color', '--tail', '300')
& docker @dockerArgs | Set-Content -LiteralPath $composeLog -Encoding UTF8

$badLines = Select-String -LiteralPath $composeLog -Pattern 'segmentation fault|fatal|Unable to open|Could not find|ERROR' -CaseSensitive:$false -ErrorAction SilentlyContinue
if ($badLines) {
    Add-WarningLine "Startup logs contain error-like lines. Review $composeLog"
} else {
    Write-Host "No obvious fatal/error strings found in recent compose logs."
}

if ($Proxy) {
    $runningServices = & docker compose --env-file $envPath ps --status running --services
    if ($LASTEXITCODE -ne 0 -or ($runningServices -notcontains 'hermesproxy')) {
        Add-Failure "Docker HermesProxy service is not running."
    }

    $bnetPort = [int](Get-EnvValue -Values $values -Name 'HERMES_BNET_PORT' -Default '1119')
    if (-not (Test-NetConnection -ComputerName '127.0.0.1' -Port $bnetPort -InformationLevel Quiet)) {
        Add-Failure "HermesProxy BNet/portal port is not reachable on 127.0.0.1:$bnetPort"
    }
}

Write-Host "Compose log snapshot: $composeLog"

if ($warnings.Count -gt 0) {
    Write-Host "Warnings:"
    $warnings | ForEach-Object { Write-Host " - $_" }
}

if ($failures.Count -gt 0) {
    Write-Host "Smoke failed:"
    $failures | ForEach-Object { Write-Host " - $_" }
    exit 1
}

Write-Host "Smoke checks passed."
