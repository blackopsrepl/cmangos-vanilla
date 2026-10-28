param(
    [switch]$Force
)

. "$PSScriptRoot\common.ps1"

Ensure-EnvFile | Out-Null
Require-Docker

Invoke-DockerCompose -Arguments @('up', '-d', 'db')

$logPath = New-ArtifactLogPath -Name 'init-db'
$oldForce = $env:FORCE_DB_INIT
try {
    if ($Force) {
        $env:FORCE_DB_INIT = '1'
    }

    $envPath = Get-EnvPath
    $dockerArgs = @('compose', '--env-file', $envPath, '--profile', 'init', 'run', '--rm', '--no-deps', 'db-init')
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
        throw "Database initialization failed. See $logPath"
    }
} finally {
    if ($null -eq $oldForce) {
        Remove-Item Env:\FORCE_DB_INIT -ErrorAction SilentlyContinue
    } else {
        $env:FORCE_DB_INIT = $oldForce
    }
}

Write-Host "Database initialization log: $logPath"
