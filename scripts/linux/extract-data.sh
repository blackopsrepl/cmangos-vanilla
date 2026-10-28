#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"

legacy_client_path=""
skip_build=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --legacy-client-path)
      legacy_client_path="${2:-}"
      shift 2
      ;;
    --skip-build)
      skip_build=1
      shift
      ;;
    -h|--help)
      printf 'Usage: %s --legacy-client-path PATH [--skip-build]\n' "$0"
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$legacy_client_path" ]; then
  printf '%s\n' '--legacy-client-path is required.' >&2
  exit 1
fi

require_podman
ensure_env_file >/dev/null
if [ ! -d "$legacy_client_path" ]; then
  printf 'Legacy client path does not exist or is not a directory: %s\n' "$legacy_client_path" >&2
  exit 1
fi
client_path="$(realpath "$legacy_client_path")"
if [ ! -d "$client_path/Data" ]; then
  printf 'Legacy client path must contain a Data directory: %s\n' "$client_path" >&2
  exit 1
fi
if ! find "$client_path/Data" -type f -iname '*.mpq' -print -quit | grep -q .; then
  printf 'No MPQ files found under %s/Data. Use an original 1.12.x MPQ-layout client.\n' "$client_path" >&2
  exit 1
fi
if [ -f "$client_path/.build.info" ]; then
  printf 'Warning: this path has .build.info and may be a modern CASC client.\n' >&2
fi

mkdir -p "$(repo_root)/data/extracted"
if [ "$skip_build" = "0" ]; then
  cmangos_compose --profile tools build tools
fi

log_path="$(artifact_log_path extract-data)"
set +e
cmangos_compose --profile tools run --rm --no-deps -v "$client_path:/client:ro" tools extract-data > "$log_path" 2>&1
exit_code=$?
set -e

tail -n 80 "$log_path"
if [ "$exit_code" -ne 0 ]; then
  printf 'Extraction failed. See %s\n' "$log_path" >&2
  exit "$exit_code"
fi

mapfile -t missing < <(missing_extracted_data "$(repo_root)/data/extracted")
if [ "${#missing[@]}" -gt 0 ]; then
  printf 'Extraction completed but required data is missing or invalid: %s\n' "${missing[*]}" >&2
  printf 'See %s\n' "$log_path" >&2
  exit 1
fi

printf 'Extraction log: %s\n' "$log_path"
