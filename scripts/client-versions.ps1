function Get-FileVersionText {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return ''
    }

    $info = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($Path)
    if (-not [string]::IsNullOrWhiteSpace($info.ProductVersion)) {
        return $info.ProductVersion
    }
    return $info.FileVersion
}

function Test-LegacyClientVersion {
    param([string]$Version)
    return -not [string]::IsNullOrWhiteSpace($Version) -and $Version -match '^1\.12\.'
}

function Test-ModernHermesClientVersion {
    param([string]$Version)
    return -not [string]::IsNullOrWhiteSpace($Version) -and ($Version -match '(^|[^0-9])1\.14\.2([^0-9]|$)' -or $Version -match '(^|[^0-9])42597([^0-9]|$)')
}
