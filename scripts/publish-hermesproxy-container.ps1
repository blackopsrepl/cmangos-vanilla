param(
    [string]$DockerImage = 'mcr.microsoft.com/dotnet/sdk:6.0',
    [switch]$SkipPublish
)

. "$PSScriptRoot\common.ps1"

Ensure-EnvFile | Out-Null
Require-Docker

$root = Get-RepoRoot
$values = Get-CmangosEnv
$lock = Read-DotEnv -Path (Join-Path $root 'versions.lock')
$repo = Get-EnvValue -Values $lock -Name 'hermesproxy_repo' -Default 'https://github.com/Novivy/HermesProxy.git'
$sha = Get-EnvValue -Values $lock -Name 'hermesproxy_sha' -Default '2c4813b4bb77309d94ac40d4702fdffa6dcbf40e'

$sourceDir = Resolve-RepoPath -Path (Get-EnvValue -Values $values -Name 'HERMES_PROXY_SOURCE_DIR' -Default 'data/hermesproxy-src')
$publishDir = Resolve-RepoPath -Path (Get-EnvValue -Values $values -Name 'HERMES_PROXY_LINUX_PUBLISH_DIR' -Default 'data/hermesproxy-linux')
$publishedBinary = Join-Path $publishDir 'HermesProxy'

Assert-PathInsideRepo -Path $sourceDir
Assert-PathInsideRepo -Path $publishDir

if (-not (Test-Path -LiteralPath (Join-Path $sourceDir '.git'))) {
    if ((Test-Path -LiteralPath $sourceDir) -and (Get-ChildItem -LiteralPath $sourceDir -Force -ErrorAction SilentlyContinue | Select-Object -First 1)) {
        throw "HermesProxy source directory exists but is not a git checkout: $sourceDir"
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $sourceDir) | Out-Null
    & git clone $repo $sourceDir
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to clone HermesProxy."
    }
}

& git -C $sourceDir fetch --tags --prune origin
if ($LASTEXITCODE -ne 0) {
    throw "Failed to fetch HermesProxy."
}

$isShallow = (& git -C $sourceDir rev-parse --is-shallow-repository) -join ''
if ($isShallow.Trim() -eq 'true') {
    & git -C $sourceDir fetch --unshallow --tags origin
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to unshallow HermesProxy checkout."
    }
}

& git -C $sourceDir checkout --force $sha
if ($LASTEXITCODE -ne 0) {
    throw "Failed to checkout HermesProxy SHA $sha."
}

New-Item -ItemType Directory -Force -Path $publishDir | Out-Null

if (-not $SkipPublish) {
    Get-ChildItem -LiteralPath $publishDir -Force -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force

    $sourceMount = "${sourceDir}:/src"
    $publishMount = "${publishDir}:/out"
    $dockerArgs = @(
        'run', '--rm',
        '-v', $sourceMount,
        '-v', $publishMount,
        '-w', '/src/HermesProxy',
        $DockerImage,
        'dotnet', 'publish', 'HermesProxy.csproj',
        '--configuration', 'Release',
        '--runtime', 'linux-x64',
        '--self-contained', 'true',
        '-p:UsePublishBuildSettings=true',
        '-p:PublishSingleFile=true',
        '-o', '/out'
    )
    & docker @dockerArgs
    if ($LASTEXITCODE -ne 0) {
        throw "HermesProxy Linux container publish failed."
    }
}

if (-not (Test-Path -LiteralPath $publishedBinary)) {
    throw "HermesProxy Linux container binary not found: $publishedBinary"
}

Write-Host "HermesProxy Linux container publish ready: $publishDir"
