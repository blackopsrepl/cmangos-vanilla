#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"

auth_only=0
proxy=0
lan_address=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --auth-only)
      auth_only=1
      shift
      ;;
    --proxy)
      proxy=1
      shift
      ;;
    --lan-address)
      lan_address="${2:-}"
      shift 2
      ;;
    -h|--help)
      printf 'Usage: %s [--auth-only] [--proxy] [--lan-address ADDRESS]\n' "$0"
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
failures=()
warnings=()

if [ "$auth_only" = "0" ]; then
  mapfile -t missing_data < <(missing_extracted_data "$root/data/extracted")
  for path in "${missing_data[@]}"; do
    failures+=("Missing or invalid extracted data directory: $path")
  done
fi

auth_port="$(env_value LEGACY_AUTH_PORT 3724)"
world_port="$(env_value LEGACY_WORLD_PORT 8085)"
if ! port_open 127.0.0.1 "$auth_port"; then
  failures+=("Legacy auth port is not reachable on 127.0.0.1:$auth_port")
fi
if [ "$auth_only" = "0" ] && ! port_open 127.0.0.1 "$world_port"; then
  failures+=("Legacy world port is not reachable on 127.0.0.1:$world_port")
fi

realm_db="$(env_value MANGOS_DB_REALM classicrealmd)"
if realm="$(db_query "$realm_db" 'SELECT id, name, address, port, realmflags FROM realmlist WHERE id=1;' 2>/dev/null)"; then
  if [ -z "$realm" ]; then
    failures+=("No realm row found in ${realm_db}.realmlist.")
  else
    printf 'Realm row:\n%s\n' "$realm"
  fi
else
  failures+=("Could not query realm DB.")
fi

if [ -n "$lan_address" ]; then
  realm_address="$(env_value REALM_ADDRESS '')"
  hermes_address="$(env_value HERMES_EXTERNAL_ADDRESS '')"
  if [ "$realm_address" != "$lan_address" ]; then
    failures+=("REALM_ADDRESS is $realm_address, expected $lan_address")
  fi
  if ! port_open "$lan_address" "$auth_port"; then
    failures+=("Legacy auth port is not reachable on ${lan_address}:${auth_port}")
  fi
  if [ "$auth_only" = "0" ] && ! port_open "$lan_address" "$world_port"; then
    failures+=("Legacy world port is not reachable on ${lan_address}:${world_port}")
  fi
  if [ "$proxy" = "1" ] && [ "$hermes_address" != "$lan_address" ]; then
    failures+=("HERMES_EXTERNAL_ADDRESS is $hermes_address, expected $lan_address")
  fi
fi

compose_log="$(artifact_log_path smoke-compose)"
log_services=(db realmd)
if [ "$auth_only" = "0" ]; then
  log_services+=(mangosd)
fi
if [ "$proxy" = "1" ]; then
  log_services+=(hermesproxy)
fi
if cmangos_compose --no-ansi logs --tail 300 "${log_services[@]}" > "$compose_log" 2>&1; then
  if grep -Ei 'segmentation fault|fatal|Unable to open|Could not find|ERROR' "$compose_log" \
      | grep -Eiv 'Received an unexpected EOF or 0 bytes from the transport stream|Got an error reading communication packets' >/dev/null; then
    warnings+=("Startup logs contain error-like lines. Review $compose_log")
  else
    printf 'No obvious fatal/error strings found in recent compose logs.\n'
  fi
else
  warnings+=("Could not capture compose logs. Review $compose_log")
fi

if [ "$proxy" = "1" ]; then
  project="${CMANGOS_COMPOSE_PROJECT:-$(env_value PROJECT_NAME cmangos-classic)}"
  if ! podman ps --format '{{.Names}}' | grep -qx "${project}_hermesproxy_1"; then
    failures+=("HermesProxy service is not running.")
  fi
  bnet_port="$(env_value HERMES_BNET_PORT 1119)"
  if ! port_listening 127.0.0.1 "$bnet_port"; then
    failures+=("HermesProxy BNet/portal port is not reachable on 127.0.0.1:$bnet_port")
  fi
  if [ -n "$lan_address" ] && ! port_listening "$lan_address" "$bnet_port"; then
    failures+=("HermesProxy BNet/portal port is not reachable on ${lan_address}:${bnet_port}")
  fi
  if [ -n "$lan_address" ]; then
    realm_port="$(env_value HERMES_REALM_PORT 8084)"
    instance_port="$(env_value HERMES_INSTANCE_PORT 8086)"
    if ! port_listening "$lan_address" "$realm_port"; then
      failures+=("HermesProxy realm port is not reachable on ${lan_address}:${realm_port}")
    fi
    if ! port_listening "$lan_address" "$instance_port"; then
      failures+=("HermesProxy instance port is not reachable on ${lan_address}:${instance_port}")
    fi
  fi
fi

printf 'Compose log snapshot: %s\n' "$compose_log"

if [ "${#warnings[@]}" -gt 0 ]; then
  printf 'Warnings:\n'
  printf ' - %s\n' "${warnings[@]}"
fi

if [ "${#failures[@]}" -gt 0 ]; then
  printf 'Smoke failed:\n'
  printf ' - %s\n' "${failures[@]}"
  exit 1
fi

printf 'Smoke checks passed.\n'
