param(
    [string]$OutputPath = ''
)

. "$PSScriptRoot\common.ps1"

$root = Get-RepoRoot
$source = Join-Path $root 'data/extracted'
$required = @(Get-RequiredDataDirs)
$missing = @(Get-MissingExtractedData -Root $source)

if ($missing.Count -gt 0) {
    try {
        Require-Docker
        Sync-ExtractedDataFromComposeVolume -DestinationRoot $source
        $missing = @(Get-MissingExtractedData -Root $source)
    } catch {
        throw "Missing or invalid extracted data: $($missing -join ', '). Run .\scripts\extract-data.ps1 first. Docker volume sync failed: $($_.Exception.Message)"
    }
}

if ($missing.Count -gt 0) {
    throw "Missing or invalid extracted data: $($missing -join ', '). Run .\scripts\extract-data.ps1 first."
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $OutputPath = Join-Path $root "artifacts/cmangos-extracted-data-$stamp.zip"
}

$destination = Resolve-RepoPath -Path $OutputPath
$destinationDir = Split-Path -Parent $destination
New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null

if (Test-Path -LiteralPath $destination) {
    Remove-Item -LiteralPath $destination -Force
}

Compress-Archive -Path ($required | ForEach-Object { Join-Path $source $_ }) -DestinationPath $destination -CompressionLevel Optimal

Write-Host "Extracted data archive: $destination"
