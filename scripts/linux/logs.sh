#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"

args=(logs)
services=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    -f|--follow)
      args+=(-f)
      shift
      ;;
    --no-color)
      args=(--no-ansi "${args[@]}")
      shift
      ;;
    -h|--help)
      printf 'Usage: %s [--follow] [--no-color] [SERVICE...]\n' "$0"
      exit 0
      ;;
    *)
      services+=("$1")
      shift
      ;;
  esac
done

ensure_env_file >/dev/null
cmangos_compose "${args[@]}" "${services[@]}"
