param(
    [string]$SourcePath,
    [switch]$Check
)

. "$PSScriptRoot\common.ps1"

$root = Get-RepoRoot
$destination = Join-Path $root 'server'
if ($Check) {
    if (-not [string]::IsNullOrWhiteSpace($SourcePath)) {
        throw '-Check and -SourcePath are mutually exclusive.'
    }
    Assert-ServerSources
    Write-Host 'Local server source inputs match the pinned bases.'
    return
}
if ([string]::IsNullOrWhiteSpace($SourcePath)) {
    throw 'Supply -SourcePath DIRECTORY. See docs/source-inputs.md.'
}
$source = (Resolve-Path -LiteralPath $SourcePath).Path
if (Test-Path -LiteralPath $destination) {
    throw 'server/ already exists; refusing to overwrite local work. Use -Check to validate it.'
}
Assert-ServerSources -SourceRoot $source
$staging = Join-Path $root ('.server-import-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $staging | Out-Null
try {
    foreach ($component in @('mangos-classic', 'classic-db', 'playerbots')) {
        $componentRoot = Join-Path $source $component
        $targetRoot = Join-Path $staging $component
        New-Item -ItemType Directory -Path $targetRoot | Out-Null
        Get-ChildItem -LiteralPath $componentRoot -Recurse -Force | Where-Object {
            $relative = $_.FullName.Substring($componentRoot.Length).TrimStart([char[]]@('\', '/'))
            @($relative -split '[\\/]' | Where-Object { $_ -eq '.git' }).Count -eq 0
        } | ForEach-Object {
            $relative = $_.FullName.Substring($componentRoot.Length).TrimStart([char[]]@('\', '/'))
            $target = Join-Path $targetRoot $relative
            if ($_.PSIsContainer) {
                New-Item -ItemType Directory -Force -Path $target | Out-Null
            } else {
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
                Copy-Item -LiteralPath $_.FullName -Destination $target
            }
        }
    }
    Assert-ServerSources -SourceRoot $staging
    [System.IO.Directory]::Move($staging, $destination)
} finally {
    if (Test-Path -LiteralPath $staging) {
        Remove-Item -LiteralPath $staging -Recurse -Force
    }
}
Write-Host 'Local server sources imported into ignored server/. Keep these inputs and built images private.'
