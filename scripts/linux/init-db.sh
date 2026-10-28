#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"

force=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --force)
      force=1
      shift
      ;;
    -h|--help)
      printf 'Usage: %s [--force]\n' "$0"
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

require_podman
ensure_env_file >/dev/null
cmangos_compose up -d db

log_path="$(artifact_log_path init-db)"
set +e
if [ "$force" = "1" ]; then
  FORCE_DB_INIT=1 cmangos_compose --profile init run --rm --no-deps db-init > "$log_path" 2>&1
else
  cmangos_compose --profile init run --rm --no-deps db-init > "$log_path" 2>&1
fi
exit_code=$?
set -e

tail -n 80 "$log_path"
if [ "$exit_code" -ne 0 ]; then
  printf 'Database initialization failed. See %s\n' "$log_path" >&2
  exit "$exit_code"
fi
printf 'Database initialization log: %s\n' "$log_path"
