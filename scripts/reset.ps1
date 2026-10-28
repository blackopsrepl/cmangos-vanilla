param(
    [switch]$Database,
    [switch]$ExtractedData,
    [switch]$HermesProxy,
    [switch]$Force
)

. "$PSScriptRoot\common.ps1"

Ensure-EnvFile | Out-Null

if (-not ($Database -or $ExtractedData -or $HermesProxy)) {
    throw "Choose at least one reset target: -Database, -ExtractedData, or -HermesProxy."
}

if (-not $Force) {
    throw "Reset deletes generated local state. Re-run with -Force after checking the selected targets."
}

if ($Database) {
    Invoke-DockerCompose -Arguments @('down', '-v')
} else {
    Invoke-DockerCompose -Arguments @('down')
}

$root = Get-RepoRoot
if ($ExtractedData) {
    $target = Join-Path $root 'data/extracted'
    Assert-PathInsideRepo -Path $target
    Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $target | Out-Null
}

if ($HermesProxy) {
    foreach ($relative in @('data/hermesproxy', 'data/hermesproxy-linux', 'data/hermesproxy-src')) {
        $target = Join-Path $root $relative
        Assert-PathInsideRepo -Path $target
        Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force -Path $target | Out-Null
    }
}

Write-Host "Reset complete."
