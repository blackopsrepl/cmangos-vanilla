Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

function Get-EnvPath {
    return (Join-Path (Get-RepoRoot) '.env')
}

function Ensure-EnvFile {
    $root = Get-RepoRoot
    $envPath = Join-Path $root '.env'
    $examplePath = Join-Path $root '.env.example'

    if (-not (Test-Path -LiteralPath $envPath)) {
        Copy-Item -LiteralPath $examplePath -Destination $envPath
        Write-Host "Created .env from .env.example"
    }

    return $envPath
}

function Read-DotEnv {
    param([Parameter(Mandatory = $true)][string]$Path)

    $result = [ordered]@{}
    if (-not (Test-Path -LiteralPath $Path)) {
        return $result
    }

    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^\s*$' -or $line -match '^\s*#') {
            continue
        }

        if ($line -match '^\s*([^=\s]+)\s*=\s*(.*)\s*$') {
            $key = $matches[1]
            $value = $matches[2].Trim()
            if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                $value = $value.Substring(1, $value.Length - 2)
            }
            $result[$key] = $value
        }
    }

    return $result
}

function Get-CmangosEnv {
    $envPath = Ensure-EnvFile
    return (Read-DotEnv -Path $envPath)
}

function Get-EnvValue {
    param(
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Values,
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$Default = ''
    )

    if ($Values.Contains($Name) -and -not [string]::IsNullOrWhiteSpace([string]$Values[$Name])) {
        return [string]$Values[$Name]
    }

    return $Default
}

function Set-DotEnvValue {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Value
    )

    $envPath = Ensure-EnvFile
    $lines = New-Object System.Collections.Generic.List[string]
    $found = $false

    foreach ($line in Get-Content -LiteralPath $envPath) {
        if ($line -match "^\s*$([regex]::Escape($Name))\s*=") {
            $lines.Add("$Name=$Value")
            $found = $true
        } else {
            $lines.Add($line)
        }
    }

    if (-not $found) {
        $lines.Add("$Name=$Value")
    }

    Set-Content -LiteralPath $envPath -Value $lines -Encoding ASCII
}

function Invoke-DockerCompose {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $envPath = Ensure-EnvFile
    $dockerArgs = @('compose', '--env-file', $envPath) + $Arguments
    & docker @dockerArgs
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose failed with exit code $LASTEXITCODE"
    }
}

function Assert-ServerSources {
    param([string]$SourceRoot = (Join-Path (Get-RepoRoot) 'server'))

    $pins = Read-DotEnv -Path (Join-Path (Get-RepoRoot) 'versions.lock')
    $components = [ordered]@{
        'mangos-classic' = 'cmangos_core_sha'
        'classic-db' = 'classic_db_sha'
        'playerbots' = 'playerbots_sha'
    }
    foreach ($component in $components.Keys) {
        $marker = Read-DotEnv -Path (Join-Path $SourceRoot "$component/.source-base")
        $expected = Get-EnvValue -Values $pins -Name $components[$component]
        $actual = Get-EnvValue -Values $marker -Name 'upstream_sha'
        $repoKey = $components[$component] -replace '_sha$', '_repo'
        $expectedRepo = Get-EnvValue -Values $pins -Name $repoKey
        $actualRepo = Get-EnvValue -Values $marker -Name 'upstream_repo'
        if ([string]::IsNullOrWhiteSpace($expected) -or [string]::IsNullOrWhiteSpace($expectedRepo) -or $actual -ne $expected -or $actualRepo -ne $expectedRepo) {
            throw "Missing or incompatible local source: $component (expected base $expected). Supply authorized sources with scripts/import-server-sources.ps1 -SourcePath PATH. See docs/source-inputs.md."
        }
    }
    foreach ($path in @('mangos-classic/src', 'mangos-classic/CMakeLists.txt', 'classic-db/InstallFullDB.sh', 'playerbots/playerbot')) {
        if (-not (Test-Path -LiteralPath (Join-Path $SourceRoot $path))) {
            throw "Incomplete local server sources: missing $path"
        }
    }
}

function Require-Docker {
    & docker version *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "Docker Desktop is not available. Start Docker Desktop and retry."
    }

    & docker compose version *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "Docker Compose v2 is not available through Docker Desktop."
    }
}

function New-ArtifactLogPath {
    param([Parameter(Mandatory = $true)][string]$Name)

    $logDir = Join-Path (Get-RepoRoot) 'artifacts/logs'
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    return (Join-Path $logDir "$Name-$stamp.log")
}

function Resolve-RepoPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return (Join-Path (Get-RepoRoot) $Path)
}

function Get-RequiredDataDirs {
    return @('dbc', 'maps', 'vmaps', 'mmaps')
}

function Get-ExpectedDataPattern {
    param([Parameter(Mandatory = $true)][string]$Name)

    switch ($Name) {
        'dbc' { return '*.dbc' }
        'maps' { return '*.map' }
        'vmaps' { return '*.vmtree' }
        'mmaps' { return '*.mmap' }
        default { return '*' }
    }
}

function Test-ExtractedDataDirReady {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return $false
    }

    $root = [System.IO.Path]::GetFullPath($Path).TrimEnd([char[]]@('\', '/'))
    $pattern = Get-ExpectedDataPattern -Name $Name
    $file = Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object {
            $full = [System.IO.Path]::GetFullPath($_.FullName)
            $relative = $full.Substring($root.Length).TrimStart([char[]]@('\', '/'))
            @($relative -split '[\\/]' | Where-Object { $_.StartsWith('.') }).Count -eq 0 -and
                $_.Name -like $pattern
        } |
        Select-Object -First 1
    return ($null -ne $file)
}

function Get-MissingExtractedData {
    param(
        [string]$Root = (Join-Path (Get-RepoRoot) 'data/extracted'),
        [string]$Prefix = 'data/extracted'
    )

    $missing = @()
    foreach ($dir in (Get-RequiredDataDirs)) {
        $path = Join-Path $Root $dir
        if (-not (Test-ExtractedDataDirReady -Path $path -Name $dir)) {
            $missing += "$Prefix/$dir"
        }
    }

    return $missing
}

function Sync-ExtractedDataFromComposeVolume {
    param([string]$DestinationRoot = (Join-Path (Get-RepoRoot) 'data/extracted'))

    Ensure-EnvFile | Out-Null
    $destination = Resolve-RepoPath -Path $DestinationRoot
    Assert-PathInsideRepo -Path $destination
    New-Item -ItemType Directory -Force -Path $destination | Out-Null

    $syncScript = @'
set -euo pipefail
for dir in dbc maps vmaps mmaps; do
  case "$dir" in
    dbc) pattern='*.dbc' ;;
    maps) pattern='*.map' ;;
    vmaps) pattern='*.vmtree' ;;
    mmaps) pattern='*.mmap' ;;
  esac
  if [ ! -d "/data/$dir" ] || ! find "/data/$dir" -type f ! -path '*/.*' -iname "$pattern" -print -quit | grep -q .; then
    echo "Missing or invalid /data/$dir in Docker volume." >&2
    exit 1
  fi
done
rm -rf /host-data/dbc /host-data/maps /host-data/vmaps /host-data/mmaps
for dir in dbc maps vmaps mmaps; do
  cp -a "/data/$dir" "/host-data/$dir"
done
'@
    $syncScript = ($syncScript -replace "`r`n", "`n").Trim()

    $envPath = Get-EnvPath
    $mount = "${destination}:/host-data"
    $dockerArgs = @(
        'compose', '--env-file', $envPath,
        '--profile', 'tools', 'run', '--rm', '--no-deps',
        '-v', $mount,
        'tools', 'bash', '-lc', $syncScript
    )

    & docker @dockerArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to sync extracted data from Docker volume."
    }
}

function Assert-PathInsideRepo {
    param([Parameter(Mandatory = $true)][string]$Path)

    $root = [System.IO.Path]::GetFullPath((Get-RepoRoot))
    $full = [System.IO.Path]::GetFullPath($Path)
    if (-not $full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to operate outside the repository: $full"
    }
}

function ConvertTo-SqlString {
    param([AllowNull()][string]$Value)
    if ($null -eq $Value) {
        return "NULL"
    }

    return "'" + ($Value -replace "'", "''") + "'"
}

function Invoke-DbSql {
    param(
        [Parameter(Mandatory = $true)][string]$Database,
        [Parameter(Mandatory = $true)][string]$Sql,
        [switch]$Root,
        [switch]$RawOutput
    )

    $values = Get-CmangosEnv
    if ($Root) {
        $user = 'root'
        $password = Get-EnvValue -Values $values -Name 'DB_ROOT_PASSWORD' -Default 'cmangos-root-local'
    } else {
        $user = Get-EnvValue -Values $values -Name 'MANGOS_DB_USER' -Default 'mangos'
        $password = Get-EnvValue -Values $values -Name 'MANGOS_DB_PASSWORD' -Default 'mangos'
    }

    $envPath = Get-EnvPath
    $dockerArgs = @(
        'compose', '--env-file', $envPath,
        'exec', '-T', '-e', "MYSQL_PWD=$password",
        'db', 'mariadb', '-h127.0.0.1', "-u$user"
    )

    if (-not [string]::IsNullOrWhiteSpace($Database)) {
        $dockerArgs += $Database
    }

    if ($RawOutput) {
        $output = $Sql | & docker @dockerArgs
        if ($LASTEXITCODE -ne 0) {
            throw "Database command failed with exit code $LASTEXITCODE"
        }
        return $output
    }

    $Sql | & docker @dockerArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Database command failed with exit code $LASTEXITCODE"
    }
}

function Invoke-DbQuery {
    param(
        [Parameter(Mandatory = $true)][string]$Database,
        [Parameter(Mandatory = $true)][string]$Sql,
        [switch]$Root
    )

    $values = Get-CmangosEnv
    if ($Root) {
        $user = 'root'
        $password = Get-EnvValue -Values $values -Name 'DB_ROOT_PASSWORD' -Default 'cmangos-root-local'
    } else {
        $user = Get-EnvValue -Values $values -Name 'MANGOS_DB_USER' -Default 'mangos'
        $password = Get-EnvValue -Values $values -Name 'MANGOS_DB_PASSWORD' -Default 'mangos'
    }

    $envPath = Get-EnvPath
    $dockerArgs = @(
        'compose', '--env-file', $envPath,
        'exec', '-T', '-e', "MYSQL_PWD=$password",
        'db', 'mariadb', '-N', '-B', '-h127.0.0.1', "-u$user", $Database, '-e', $Sql
    )

    $output = & docker @dockerArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Database query failed with exit code $LASTEXITCODE"
    }

    return $output
}

function Expand-TemplateFile {
    param(
        [Parameter(Mandatory = $true)][string]$TemplatePath,
        [Parameter(Mandatory = $true)][string]$DestinationPath,
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Values
    )

    $content = Get-Content -LiteralPath $TemplatePath -Raw
    $matches = [regex]::Matches($content, '\$\{([A-Za-z0-9_]+)\}')
    foreach ($match in $matches) {
        $name = $match.Groups[1].Value
        $value = Get-EnvValue -Values $Values -Name $name -Default ''
        $content = $content.Replace($match.Value, $value)
    }

    $destDir = Split-Path -Parent $DestinationPath
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    Set-Content -LiteralPath $DestinationPath -Value $content -Encoding ASCII
}
