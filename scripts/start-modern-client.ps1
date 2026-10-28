param(
    [string]$ModernClientPath = '',
    [string]$Portal = '',
    [switch]$KeepBattleNet,
    [switch]$SkipProxyPublish,
    [switch]$NoProxyRestart,
    [switch]$NoLaunch
)

. "$PSScriptRoot\common.ps1"
. "$PSScriptRoot\client-versions.ps1"

function Resolve-ModernClientDirectory {
    param(
        [string]$Path,
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Values
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        $Path = Get-EnvValue -Values $Values -Name 'MODERN_CLIENT_PATH' -Default ''
    }

    if ([string]::IsNullOrWhiteSpace($Path)) {
        $candidates = @(
            'D:\Games\World of Warcraft',
            'C:\Program Files (x86)\World of Warcraft',
            'C:\Program Files\World of Warcraft'
        )

        foreach ($candidate in $candidates) {
            $classicEra = Join-Path $candidate '_classic_era_'
            if (Test-Path -LiteralPath $classicEra) {
                $Path = $classicEra
                break
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        throw "Modern Classic Era client path not found. Set MODERN_CLIENT_PATH in .env or pass -ModernClientPath."
    }

    $resolved = (Resolve-Path -LiteralPath $Path).Path
    $nested = Join-Path $resolved '_classic_era_'
    if (Test-Path -LiteralPath $nested) {
        return (Resolve-Path -LiteralPath $nested).Path
    }

    return $resolved
}

function Get-WowRootDirectory {
    param([Parameter(Mandatory = $true)][string]$ClientDir)

    if ((Split-Path -Leaf $ClientDir) -ieq '_classic_era_') {
        return (Split-Path -Parent $ClientDir)
    }

    return $ClientDir
}

function Get-ModernClientBinary {
    param([Parameter(Mandatory = $true)][string]$ClientDir)

    $candidates = @(
        (Join-Path $ClientDir 'WowClassic.exe'),
        (Join-Path $ClientDir 'Wow.exe')
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw "Could not find WowClassic.exe or Wow.exe in $ClientDir."
}

function Ensure-ArctiumLauncher {
    param(
        [Parameter(Mandatory = $true)][string]$WowRoot,
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Values
    )

    $launcherName = 'Arctium Game Launcher.exe'
    $launcherPath = Join-Path $WowRoot $launcherName
    $expectedHash = Get-EnvValue -Values $Values -Name 'ARCTIUM_LAUNCHER_SHA256' -Default 'CB7A04114F6125BBDF3F1AE55B9C81B77A02233710D8295CE38176B01BB5A839'

    if (Test-Path -LiteralPath $launcherPath) {
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $launcherPath).Hash
        if ($hash -ne $expectedHash) {
            throw "Existing Arctium launcher hash did not match the expected official build: $launcherPath"
        }

        return $launcherPath
    }

    $url = Get-EnvValue -Values $Values -Name 'ARCTIUM_LAUNCHER_URL' -Default 'https://arctium.app/launcher/Arctium%20Game%20Launcher%201.5.0.188%2B48ff21fc8c0cc2b5aee1d1aa81af87d999c92ba3.zip'
    $downloadDir = Join-Path (Get-RepoRoot) 'data\downloads\arctium'
    $zipPath = Join-Path $downloadDir 'Arctium Game Launcher.zip'
    $extractDir = Join-Path $downloadDir 'extracted'

    New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null
    if (-not (Test-Path -LiteralPath $zipPath)) {
        Invoke-WebRequest -Uri $url -OutFile $zipPath
    }

    if (Test-Path -LiteralPath $extractDir) {
        Assert-PathInsideRepo -Path $extractDir
        Remove-Item -LiteralPath $extractDir -Recurse -Force
    }

    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractDir -Force
    $sourceLauncher = Join-Path $extractDir $launcherName
    if (-not (Test-Path -LiteralPath $sourceLauncher)) {
        throw "Arctium launcher archive did not contain $launcherName."
    }

    $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourceLauncher).Hash
    if ($sourceHash -ne $expectedHash) {
        throw "Downloaded Arctium launcher hash did not match the expected official build."
    }

    Copy-Item -LiteralPath $sourceLauncher -Destination $launcherPath -Force
    return $launcherPath
}

Ensure-EnvFile | Out-Null
$values = Get-CmangosEnv
$clientDir = Resolve-ModernClientDirectory -Path $ModernClientPath -Values $values
$wowRoot = Get-WowRootDirectory -ClientDir $clientDir
$clientBinary = Get-ModernClientBinary -ClientDir $clientDir
$clientVersion = Get-FileVersionText -Path $clientBinary
if (-not (Test-ModernHermesClientVersion -Version $clientVersion)) {
    throw "Unsupported modern client version '$clientVersion'. HermesProxy in this stack is pinned to Classic Era 1.14.2 build 42597; use original Vanilla 1.12.x directly or provide that exact archived Classic Era client for HermesProxy."
}

$bnetPort = Get-EnvValue -Values $values -Name 'HERMES_BNET_PORT' -Default '1119'
if ([string]::IsNullOrWhiteSpace($Portal)) {
    $portalAddress = Get-EnvValue -Values $values -Name 'HERMES_EXTERNAL_ADDRESS' -Default '127.0.0.1'
    $Portal = "${portalAddress}:$bnetPort"
}

if (-not $KeepBattleNet) {
    $battleNetProcesses = Get-Process -Name 'Battle.net','Agent' -ErrorAction SilentlyContinue
    if ($battleNetProcesses) {
        $battleNetProcesses | Stop-Process -Force
        Start-Sleep -Seconds 1
    }
}

& (Join-Path $PSScriptRoot 'patch-modern-client-config.ps1') -ModernClientPath $clientDir -Portal $Portal

if (-not $NoProxyRestart) {
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $docker) {
        throw "Docker is required to start HermesProxy for this compose stack."
    }

    $containerPublishDir = Resolve-RepoPath -Path (Get-EnvValue -Values $values -Name 'HERMES_PROXY_LINUX_PUBLISH_DIR' -Default 'data/hermesproxy-linux')
    $containerProxy = Join-Path $containerPublishDir 'HermesProxy'
    if (-not $SkipProxyPublish) {
        & (Join-Path $PSScriptRoot 'publish-hermesproxy-container.ps1')
    } elseif (-not (Test-Path -LiteralPath $containerProxy)) {
        throw "HermesProxy container binary is missing: $containerProxy"
    }

    $envPath = Join-Path (Get-RepoRoot) '.env'
    & docker compose --env-file $envPath build hermesproxy
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to build Docker HermesProxy service image."
    }

    & docker compose --env-file $envPath up -d --no-deps --force-recreate hermesproxy
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to start Docker HermesProxy service."
    }
}

$launcherPath = Ensure-ArctiumLauncher -WowRoot $wowRoot -Values $values

Write-Host "Modern client: $clientDir"
Write-Host "Client binary: $clientBinary"
Write-Host "Portal: $Portal"
Write-Host "Launcher: $launcherPath"

if ($NoLaunch) {
    Write-Host "Launch skipped."
    return
}

$arguments = @(
    '--version', 'ClassicEra',
    '--staticseed',
    '--path', "`"$clientDir`"",
    '--binary', "`"$(Split-Path -Leaf $clientBinary)`"",
    '--portal', $Portal
)

$process = Start-Process -FilePath $launcherPath -WorkingDirectory $wowRoot -ArgumentList $arguments -PassThru
Write-Host "Started modern client via Arctium as PID $($process.Id)"
