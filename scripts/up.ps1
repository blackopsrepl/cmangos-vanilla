param(
    [switch]$AuthOnly,
    [switch]$AllowMissingData
)

. "$PSScriptRoot\common.ps1"

Ensure-EnvFile | Out-Null
Require-Docker

if ($AuthOnly) {
    Invoke-DockerCompose -Arguments @('up', '-d', 'db', 'realmd')
    Write-Host "Auth stack requested. Use .\scripts\logs.ps1 -Follow to watch startup."
    return
}

$missingData = @(Get-MissingExtractedData)
if ($missingData.Count -gt 0) {
    try {
        Sync-ExtractedDataFromComposeVolume
        $missingData = @(Get-MissingExtractedData)
    } catch {
        # The explicit missing-data error below is clearer for first-time setup.
    }
}

if ($missingData.Count -gt 0 -and -not $AllowMissingData) {
    $list = $missingData -join ', '
    throw "Missing or invalid extracted client data: $list. Run .\scripts\extract-data.ps1 first, or use -AuthOnly to start only MariaDB and realmd."
}

Invoke-DockerCompose -Arguments @('up', '-d', 'db', 'realmd', 'mangosd')
Write-Host "Full stack requested. Use .\scripts\logs.ps1 -Follow to watch startup."
