param(
    [string[]]$SearchRoots = @()
)

. "$PSScriptRoot\common.ps1"

function Add-Candidate {
    param(
        [System.Collections.Generic.List[string]]$List,
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }
    if ((Test-Path -LiteralPath $Path) -and -not ($List -contains $Path)) {
        $List.Add($Path) | Out-Null
    }
}

$candidates = New-Object System.Collections.Generic.List[string]

foreach ($root in $SearchRoots) {
    if (Test-Path -LiteralPath $root) {
        Add-Candidate -List $candidates -Path (Resolve-Path -LiteralPath $root).Path
    }
}

$commonRoots = @(
    (Join-Path ${env:ProgramFiles} 'World of Warcraft'),
    (Join-Path ${env:ProgramFiles(x86)} 'World of Warcraft'),
    'C:\Games',
    'D:\Games',
    'C:\Program Files\World of Warcraft',
    'C:\Program Files (x86)\World of Warcraft'
)

foreach ($root in $commonRoots) {
    Add-Candidate -List $candidates -Path $root
    Add-Candidate -List $candidates -Path (Join-Path $root '_classic_era_')
    Add-Candidate -List $candidates -Path (Join-Path $root 'World of Warcraft')
    Add-Candidate -List $candidates -Path (Join-Path (Join-Path $root 'World of Warcraft') '_classic_era_')
}

foreach ($drive in Get-PSDrive -PSProvider FileSystem) {
    foreach ($name in @('WoW-1.12.1', 'World of Warcraft 1.12.1', 'Vanilla 1.12.1', 'WoW Vanilla')) {
        Add-Candidate -List $candidates -Path (Join-Path $drive.Root $name)
        Add-Candidate -List $candidates -Path (Join-Path (Join-Path $drive.Root 'Games') $name)
    }
}

$seen = @{}
foreach ($candidate in $candidates) {
    $full = [System.IO.Path]::GetFullPath($candidate)
    if ($seen.ContainsKey($full)) {
        continue
    }
    $seen[$full] = $true

    $data = Join-Path $full 'Data'
    $isLegacy = $false
    $isModern = $false

    if (Test-Path -LiteralPath $data) {
        $mpq = Get-ChildItem -LiteralPath $data -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -ieq '.mpq' } |
            Select-Object -First 1
        if ($mpq) {
            $isLegacy = $true
        }
    }

    if ((Test-Path -LiteralPath (Join-Path $full '.build.info')) -or (Test-Path -LiteralPath (Join-Path $full 'WowClassic.exe'))) {
        $isModern = $true
    }

    if ($isLegacy -or $isModern) {
        Write-Host ""
        Write-Host $full
        if ($isLegacy) {
            Write-Host "  Legacy candidate: yes"
            & "$PSScriptRoot\check-clients.ps1" -LegacyClientPath $full
        }
        if ($isModern) {
            Write-Host "  Modern Classic Era candidate: yes"
            & "$PSScriptRoot\check-clients.ps1" -ModernClientPath $full
        }
    }
}
