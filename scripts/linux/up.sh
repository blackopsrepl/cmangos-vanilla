#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"

auth_only=0
allow_missing_data=0
proxy=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --auth-only)
      auth_only=1
      shift
      ;;
    --allow-missing-data)
      allow_missing_data=1
      shift
      ;;
    --proxy)
      proxy=1
      shift
      ;;
    -h|--help)
      printf 'Usage: %s [--auth-only] [--allow-missing-data] [--proxy]\n' "$0"
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
root="$(repo_root)"
mkdir -p "$root/data/extracted" "$root/artifacts/logs"

services=(db realmd)
if [ "$auth_only" = "0" ]; then
  mapfile -t missing < <(missing_extracted_data "$root/data/extracted")
  if [ "${#missing[@]}" -gt 0 ] && [ "$allow_missing_data" = "0" ]; then
    printf 'Missing or invalid extracted client data: %s\n' "${missing[*]}" >&2
    printf 'Run ./scripts/linux/import-extracted-data.sh --source PATH or ./scripts/linux/extract-data.sh --legacy-client-path PATH.\n' >&2
    exit 1
  fi
  services+=(mangosd)
fi

if [ "$proxy" = "1" ]; then
  proxy_publish_dir="$(resolve_repo_path "$(env_value HERMES_PROXY_LINUX_PUBLISH_DIR data/hermesproxy-linux)")"
  if [ ! -x "$proxy_publish_dir/HermesProxy" ]; then
    printf 'Missing Linux HermesProxy publish. Run ./scripts/linux/publish-hermesproxy.sh first.\n' >&2
    exit 1
  fi
  cmangos_compose build hermesproxy
fi

cmangos_compose up -d "${services[@]}"
if [ "$proxy" = "1" ]; then
  cmangos_compose up -d --no-deps --force-recreate hermesproxy
  services+=(hermesproxy)
fi
printf 'Requested services: %s\n' "${services[*]}"
printf 'Use ./scripts/linux/logs.sh --follow to watch startup.\n'
