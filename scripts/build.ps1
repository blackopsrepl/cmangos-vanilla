param(
    [switch]$NoCache,
    [switch]$Pull,
    [ValidateSet('auto', 'plain', 'tty', 'quiet')]
    [string]$Progress = 'plain'
)

. "$PSScriptRoot\common.ps1"

Assert-ServerSources
Ensure-EnvFile | Out-Null
Require-Docker

$composeArgs = @('build')
if ($Pull) {
    $composeArgs += '--pull'
}
if ($NoCache) {
    $composeArgs += '--no-cache'
}
$composeArgs += @('realmd', 'mangosd', 'db-init', 'tools')

$envPath = Ensure-EnvFile
$dockerArgs = @('compose', '--progress', $Progress, '--env-file', $envPath) + $composeArgs
& docker @dockerArgs
if ($LASTEXITCODE -ne 0) {
    throw "docker compose build failed with exit code $LASTEXITCODE"
}
