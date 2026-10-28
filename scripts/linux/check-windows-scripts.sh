#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"

image="${POWERSHELL_IMAGE:-mcr.microsoft.com/powershell:7.4-ubuntu-22.04}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --image)
      image="${2:-}"
      shift 2
      ;;
    -h|--help)
      printf 'Usage: %s [--image IMAGE]\n' "$0"
      printf 'Parses scripts/*.ps1 with PowerShell inside a Podman container.\n'
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

require_podman
root="$(repo_root)"
checker="$(mktemp)"
cleanup() {
  rm -f "$checker"
}
trap cleanup EXIT

cat > "$checker" <<'PS'
$failed = $false
Get-ChildItem scripts -Filter *.ps1 | Sort-Object Name | ForEach-Object {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors) > $null
    if ($errors.Count -gt 0) {
        $failed = $true
        Write-Host "ERROR $($_.FullName)"
        $errors | ForEach-Object {
            Write-Host "  $($_.Message) at $($_.Extent.StartLineNumber):$($_.Extent.StartColumnNumber)"
        }
    } else {
        Write-Host "OK $($_.Name)"
    }
}
if ($failed) {
    exit 1
}
PS

podman run --rm \
  -v "$root:/repo:ro,Z" \
  -v "$checker:/check-windows-scripts.ps1:ro,Z" \
  -w /repo \
  "$image" \
  pwsh -NoLogo -NoProfile -NonInteractive -File /check-windows-scripts.ps1
