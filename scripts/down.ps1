param(
    [switch]$Volumes
)

. "$PSScriptRoot\common.ps1"

Ensure-EnvFile | Out-Null

$composeArgs = @('down')
if ($Volumes) {
    $composeArgs += '-v'
}

Invoke-DockerCompose -Arguments $composeArgs
