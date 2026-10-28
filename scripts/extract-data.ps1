param(
    [Parameter(Mandatory = $true)][string]$LegacyClientPath,
    [switch]$SkipBuild
)

. "$PSScriptRoot\common.ps1"

Ensure-EnvFile | Out-Null
Require-Docker

$clientPath = (Resolve-Path -LiteralPath $LegacyClientPath).Path
$dataPath = Join-Path $clientPath 'Data'
if (-not (Test-Path -LiteralPath $dataPath)) {
    throw "Legacy client path must contain a Data directory: $clientPath"
}

$mpq = Get-ChildItem -LiteralPath $dataPath -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -ieq '.mpq' } |
    Select-Object -First 1
if (-not $mpq) {
    throw "No MPQ files found under $dataPath. CMaNGOS extractors need an original 1.12.x MPQ-layout client, not a modern CASC client."
}

if (Test-Path -LiteralPath (Join-Path $clientPath '.build.info')) {
    Write-Warning "This path has .build.info and may be a modern CASC client. Extraction requires original 1.12.x MPQ files."
}

if (-not $SkipBuild) {
    Invoke-DockerCompose -Arguments @('--profile', 'tools', 'build', 'tools')
}

$logPath = New-ArtifactLogPath -Name 'extract-data'
$envPath = Get-EnvPath
$mount = "${clientPath}:/client:ro"
$dockerArgs = @('compose', '--env-file', $envPath, '--profile', 'tools', 'run', '--rm', '--no-deps', '-v', $mount, 'tools', 'extract-data')

$oldPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    & docker @dockerArgs *> $logPath
    $exitCode = $LASTEXITCODE
} finally {
    $ErrorActionPreference = $oldPreference
}

Get-Content -LiteralPath $logPath -Tail 80

if ($exitCode -ne 0) {
    throw "Extraction failed. See $logPath"
}

Sync-ExtractedDataFromComposeVolume

$missingData = @(Get-MissingExtractedData)
if ($missingData.Count -gt 0) {
    throw "Extraction completed but required data is missing or empty: $($missingData -join ', '). See $logPath"
}

Write-Host "Extraction log: $logPath"
Write-Host "Extracted data mirrored to $(Join-Path (Get-RepoRoot) 'data/extracted')"
