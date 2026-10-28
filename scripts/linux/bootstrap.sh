#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"

lan_address=""
configure_lan=1

while [ "$#" -gt 0 ]; do
  case "$1" in
    --lan-address)
      lan_address="${2:-}"
      shift 2
      ;;
    --skip-lan-config)
      configure_lan=0
      shift
      ;;
    -h|--help)
      printf 'Usage: %s [--lan-address ADDRESS] [--skip-lan-config]\n' "$0"
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

require_podman
env_file="$(ensure_env_file)"
root="$(repo_root)"
mkdir -p "$root/data/extracted" "$root/data/hermesproxy-linux" "$root/data/hermesproxy-src" "$root/artifacts/logs"

if [ "$configure_lan" = "1" ]; then
  if [ -z "$lan_address" ]; then
    lan_address="$(detect_lan_address)"
  fi
  if [ -z "$lan_address" ]; then
    printf 'Could not auto-detect a LAN address. Re-run with --lan-address ADDRESS.\n' >&2
    exit 1
  fi
  set_env_value REALM_ADDRESS "$lan_address"
  set_env_value HERMES_EXTERNAL_ADDRESS "$lan_address"
fi

printf 'Bootstrap complete.\n'
printf 'Env file: %s\n' "$env_file"
if [ "$configure_lan" = "1" ]; then
  printf 'LAN address: %s\n' "$lan_address"
  printf 'Windows client portal for HermesProxy: %s:%s\n' "$lan_address" "$(env_value HERMES_BNET_PORT 1119)"
fi
printf 'Next: ./scripts/linux/build.sh\n'
