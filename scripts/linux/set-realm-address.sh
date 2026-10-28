#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"

mode="lan"
address=""
port=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --mode)
      mode="${2:-}"
      shift 2
      ;;
    --address)
      address="${2:-}"
      shift 2
      ;;
    --port)
      port="${2:-}"
      shift 2
      ;;
    -h|--help)
      printf 'Usage: %s [--mode lan|legacy-direct|host-proxy|docker-proxy|custom] [--address ADDRESS] [--port PORT]\n' "$0"
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

case "$mode" in
  lan)
    if [ -z "$address" ]; then
      address="$(detect_lan_address)"
    fi
    ;;
  legacy-direct|host-proxy)
    if [ -z "$address" ]; then
      address="127.0.0.1"
    fi
    ;;
  docker-proxy)
    if [ -z "$address" ]; then
      address="mangosd"
    fi
    ;;
  custom)
    if [ -z "$address" ]; then
      printf '%s\n' '--mode custom requires --address.' >&2
      exit 1
    fi
    ;;
  *)
    printf 'Unknown mode: %s\n' "$mode" >&2
    exit 1
    ;;
esac

if [ -z "$address" ]; then
  printf 'Could not determine an address.\n' >&2
  exit 1
fi
if [ -z "$port" ]; then
  port="$(env_value LEGACY_WORLD_PORT 8085)"
fi

realm_db="$(env_value MANGOS_DB_REALM classicrealmd)"
realm_name="$(env_value REALM_NAME 'Vanilla at Home')"
sql="
INSERT INTO realmlist (id, name, address, port, icon, realmflags, timezone, allowedSecurityLevel, population, realmbuilds)
VALUES (1, $(sql_string "$realm_name"), $(sql_string "$address"), ${port}, 1, 0, 1, 0, 0, '')
ON DUPLICATE KEY UPDATE
  name=VALUES(name),
  address=VALUES(address),
  port=VALUES(port),
  realmflags=0,
  realmbuilds='';
"

db_exec "$realm_db" "$sql"
set_env_value REALM_ADDRESS "$address"
if [ "$mode" = "lan" ]; then
  set_env_value HERMES_EXTERNAL_ADDRESS "$address"
fi
printf 'Realm 1 now advertises %s:%s (%s).\n' "$address" "$port" "$mode"
