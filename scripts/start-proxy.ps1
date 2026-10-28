param(
    [switch]$Foreground,
    [switch]$Restart,
    [switch]$SkipPublish
)

. "$PSScriptRoot\common.ps1"

function Get-HermesBuildNumber {
    param([Parameter(Mandatory = $true)][string]$Build)

    if ($Build -match '(\d+)$') {
        return $matches[1]
    }

    return $Build
}

function Set-FileContentIfChanged {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $current = ''
    if (Test-Path -LiteralPath $Path) {
        $current = Get-Content -LiteralPath $Path -Raw
    }

    if ($current -ne $Content) {
        Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8
    }
}

Ensure-EnvFile | Out-Null

$root = Get-RepoRoot
$envExample = Read-DotEnv -Path (Join-Path $root '.env.example')
$envActual = Get-CmangosEnv
foreach ($key in $envActual.Keys) {
    $envExample[$key] = $envActual[$key]
}
$values = $envExample
$values['HERMES_CLIENT_BUILD'] = Get-HermesBuildNumber -Build (Get-EnvValue -Values $values -Name 'HERMES_CLIENT_BUILD' -Default '42597')
$values['HERMES_LEGACY_BUILD'] = Get-HermesBuildNumber -Build (Get-EnvValue -Values $values -Name 'HERMES_LEGACY_BUILD' -Default '5875')

$lock = Read-DotEnv -Path (Join-Path $root 'versions.lock')
$repo = Get-EnvValue -Values $lock -Name 'hermesproxy_repo' -Default 'https://github.com/Novivy/HermesProxy.git'
$sha = Get-EnvValue -Values $lock -Name 'hermesproxy_sha' -Default '57543d33f63ead2fdadcc77b09f5bf51564c1266'

$sourceDir = Resolve-RepoPath -Path (Get-EnvValue -Values $values -Name 'HERMES_PROXY_SOURCE_DIR' -Default 'data/hermesproxy-src')
$publishDir = Resolve-RepoPath -Path (Get-EnvValue -Values $values -Name 'HERMES_PROXY_PUBLISH_DIR' -Default 'data/hermesproxy')
$pidPath = Join-Path $publishDir 'hermesproxy.pid'
$publishedExe = Join-Path $publishDir 'HermesProxy.exe'

if ($Restart -and (Test-Path -LiteralPath $pidPath)) {
    $oldPid = Get-Content -LiteralPath $pidPath -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($oldPid -and (Get-Process -Id ([int]$oldPid) -ErrorAction SilentlyContinue)) {
        Stop-Process -Id ([int]$oldPid) -Force
    }
    Remove-Item -LiteralPath $pidPath -Force -ErrorAction SilentlyContinue
}

if ((Test-Path -LiteralPath $pidPath) -and -not $Foreground) {
    $pidText = Get-Content -LiteralPath $pidPath -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pidText -and (Get-Process -Id ([int]$pidText) -ErrorAction SilentlyContinue)) {
        throw "HermesProxy already appears to be running as PID $pidText. Use -Restart to replace it."
    }
}

New-Item -ItemType Directory -Force -Path $publishDir | Out-Null
$template = Join-Path $root 'config/hermesproxy.config.xml.template'
$configPath = Join-Path $publishDir 'HermesProxy.config'
Expand-TemplateFile -TemplatePath $template -DestinationPath $configPath -Values $values

$canReusePublishedProxy = $SkipPublish -and (Test-Path -LiteralPath $publishedExe)

if (-not $canReusePublishedProxy) {
    if (-not (Test-Path -LiteralPath (Join-Path $sourceDir '.git'))) {
        if ((Test-Path -LiteralPath $sourceDir) -and ((Get-ChildItem -LiteralPath $sourceDir -Force | Select-Object -First 1))) {
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

}

if (-not $SkipPublish) {
    $dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
    if (-not $dotnet) {
        throw ".NET SDK is required to build HermesProxy. Install a .NET SDK and retry."
    }

    $projectPath = Join-Path $sourceDir 'HermesProxy\HermesProxy.csproj'
    if (-not (Test-Path -LiteralPath $projectPath)) {
        throw "HermesProxy project not found: $projectPath"
    }

    & dotnet publish $projectPath --configuration Release --use-current-runtime -p:UsePublishBuildSettings=true -o $publishDir
    if ($LASTEXITCODE -ne 0) {
        throw "HermesProxy publish failed."
    }
    Expand-TemplateFile -TemplatePath $template -DestinationPath $configPath -Values $values
}

$exe = $publishedExe
if (-not (Test-Path -LiteralPath $exe)) {
    $exe = Join-Path $publishDir 'HermesProxy'
}
if (-not (Test-Path -LiteralPath $exe)) {
    throw "HermesProxy executable not found in $publishDir"
}

if ($Foreground) {
    Push-Location $publishDir
    try {
        & $exe
    } finally {
        Pop-Location
    }
} else {
    $stdout = New-ArtifactLogPath -Name 'hermesproxy-out'
    $stderr = New-ArtifactLogPath -Name 'hermesproxy-err'
    $process = Start-Process -FilePath $exe -WorkingDirectory $publishDir -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
    Start-Sleep -Seconds 2
    if ($process.HasExited) {
        throw "HermesProxy exited immediately. See $stdout and $stderr"
    }
    Set-Content -LiteralPath $pidPath -Value $process.Id -Encoding ASCII
    Write-Host "HermesProxy started as PID $($process.Id)"
    Write-Host "Config: $configPath"
    Write-Host "Logs: $stdout ; $stderr"
}
