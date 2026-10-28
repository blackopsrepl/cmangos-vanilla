param()

. "$PSScriptRoot\common.ps1"

$envPath = Ensure-EnvFile
Require-Docker

$root = Get-RepoRoot
@(
    'data',
    'data/extracted',
    'data/hermesproxy',
    'data/hermesproxy-linux',
    'data/hermesproxy-src',
    'artifacts/logs'
) | ForEach-Object {
    New-Item -ItemType Directory -Force -Path (Join-Path $root $_) | Out-Null
}

Write-Host "Bootstrap complete."
Write-Host "Env file: $envPath"
Write-Host "Next: .\scripts\build.ps1"
