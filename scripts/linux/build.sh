#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"

args=(build)
while [ "$#" -gt 0 ]; do
  case "$1" in
    --no-cache)
      args+=(--no-cache)
      shift
      ;;
    --pull)
      args+=(--pull)
      shift
      ;;
    -h|--help)
      printf 'Usage: %s [--pull] [--no-cache]\n' "$0"
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

check_server_sources "$(repo_root)/server"
require_podman
ensure_env_file >/dev/null
mkdir -p "$(repo_root)/data/extracted" "$(repo_root)/artifacts/logs"
cmangos_compose "${args[@]}" realmd
