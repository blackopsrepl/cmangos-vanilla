param(
    [string[]]$Service = @(),
    [switch]$Follow,
    [switch]$NoColor
)

. "$PSScriptRoot\common.ps1"

Ensure-EnvFile | Out-Null

$composeArgs = @('logs')
if ($Follow) {
    $composeArgs += '-f'
}
if ($NoColor) {
    $composeArgs += '--no-color'
}
$composeArgs += $Service

Invoke-DockerCompose -Arguments $composeArgs
