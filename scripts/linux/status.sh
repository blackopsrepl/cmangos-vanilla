#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"

include_proxy=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --proxy)
      include_proxy=1
      shift
      ;;
    -h|--help)
      printf 'Usage: %s [--proxy]\n' "$0"
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
project="${CMANGOS_COMPOSE_PROJECT:-$(env_value PROJECT_NAME cmangos-classic)}"
lan_address="$(detect_lan_address)"
realm_address="$(env_value REALM_ADDRESS 127.0.0.1)"
hermes_address="$(env_value HERMES_EXTERNAL_ADDRESS 127.0.0.1)"
auth_port="$(env_value LEGACY_AUTH_PORT 3724)"
world_port="$(env_value LEGACY_WORLD_PORT 8085)"
bnet_port="$(env_value HERMES_BNET_PORT 1119)"
realm_port="$(env_value HERMES_REALM_PORT 8084)"
instance_port="$(env_value HERMES_INSTANCE_PORT 8086)"

failures=()
warnings=()

check_container() {
  local service name status
  service="$1"
  name="${project}_${service}_1"
  status="$(podman ps --filter "name=^${name}$" --format '{{.Status}}' | head -n 1)"
  if [ -z "$status" ]; then
    failures+=("${service} container is not running (${name}).")
    printf 'container %-12s missing\n' "$service"
  else
    printf 'container %-12s %s\n' "$service" "$status"
  fi
}

check_port() {
  local label host port mode
  label="$1"
  host="$2"
  port="$3"
  mode="${4:-connect}"
  if { [ "$mode" = "listen" ] && port_listening "$host" "$port"; } || { [ "$mode" != "listen" ] && port_open "$host" "$port"; }; then
    printf 'port      %-12s %s:%s open\n' "$label" "$host" "$port"
  else
    failures+=("${label} port is not reachable on ${host}:${port}.")
    printf 'port      %-12s %s:%s closed\n' "$label" "$host" "$port"
  fi
}

check_firewall() {
  local ports=("$auth_port")
  if [ "${#missing_data[@]}" -eq 0 ]; then
    ports+=("$world_port")
  fi
  if [ "$include_proxy" = "1" ]; then
    ports+=("$bnet_port" "$realm_port" "$instance_port")
  fi

  if command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
    printf 'firewall  firewalld    running\n'
    for port in "${ports[@]}"; do
      if firewall-cmd --query-port="${port}/tcp" >/dev/null 2>&1; then
        printf 'firewall  %-12s open\n' "${port}/tcp"
      else
        warnings+=("firewalld is running and ${port}/tcp is not explicitly open.")
        printf 'firewall  %-12s not-open\n' "${port}/tcp"
      fi
    done
  elif command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -qi '^Status: active'; then
    printf 'firewall  ufw          active\n'
    for port in "${ports[@]}"; do
      if ufw status 2>/dev/null | grep -Eq "(^|[[:space:]])${port}/tcp([[:space:]]|$).*ALLOW"; then
        printf 'firewall  %-12s allow\n' "${port}/tcp"
      else
        warnings+=("ufw is active and ${port}/tcp is not shown as allowed.")
        printf 'firewall  %-12s not-allowed\n' "${port}/tcp"
      fi
    done
  else
    printf 'firewall  host         no active firewalld/ufw detected\n'
  fi
}

printf 'Project: %s\n' "$project"
printf 'Detected LAN address: %s\n' "${lan_address:-unknown}"
printf 'REALM_ADDRESS: %s\n' "$realm_address"
printf 'HERMES_EXTERNAL_ADDRESS: %s\n' "$hermes_address"

if [ -n "$lan_address" ] && [ "$realm_address" != "$lan_address" ]; then
  warnings+=("REALM_ADDRESS does not match detected LAN address ${lan_address}.")
fi
if [ "$include_proxy" = "1" ] && [ -n "$lan_address" ] && [ "$hermes_address" != "$lan_address" ]; then
  warnings+=("HERMES_EXTERNAL_ADDRESS does not match detected LAN address ${lan_address}.")
fi

printf '\nRequired extracted data:\n'
missing_data=()
while IFS= read -r dir; do
  data_path="$root/data/extracted/$dir"
  if data_dir_has_extracted_files "$data_path" "$dir"; then
    printf 'data      %-12s present\n' "$dir"
  elif [ -d "$data_path" ]; then
    missing_data+=("data/extracted/$dir")
    printf 'data      %-12s invalid\n' "$dir"
  else
    missing_data+=("data/extracted/$dir")
    printf 'data      %-12s missing\n' "$dir"
  fi
done < <(required_data_dirs)
if [ "${#missing_data[@]}" -gt 0 ]; then
  warnings+=("Full mangosd startup is pending missing/invalid extracted data: ${missing_data[*]}.")
fi

printf '\nContainers:\n'
check_container db
check_container realmd
if [ "${#missing_data[@]}" -eq 0 ]; then
  check_container mangosd
fi
if [ "$include_proxy" = "1" ]; then
  check_container hermesproxy
fi

printf '\nPorts:\n'
check_port auth 127.0.0.1 "$auth_port"
if [ -n "$lan_address" ]; then
  check_port auth-lan "$lan_address" "$auth_port"
fi
if [ "${#missing_data[@]}" -eq 0 ]; then
  check_port world 127.0.0.1 "$world_port"
  if [ -n "$lan_address" ]; then
    check_port world-lan "$lan_address" "$world_port"
  fi
fi
if [ "$include_proxy" = "1" ]; then
  check_port bnet 127.0.0.1 "$bnet_port" listen
  check_port realm 127.0.0.1 "$realm_port" listen
  check_port instance 127.0.0.1 "$instance_port" listen
  if [ -n "$lan_address" ]; then
    check_port bnet-lan "$lan_address" "$bnet_port" listen
    check_port realm-lan "$lan_address" "$realm_port" listen
    check_port instance-lan "$lan_address" "$instance_port" listen
  fi
fi

printf '\nFirewall:\n'
check_firewall

if [ "${#warnings[@]}" -gt 0 ]; then
  printf '\nWarnings:\n'
  printf ' - %s\n' "${warnings[@]}"
fi

if [ "${#failures[@]}" -gt 0 ]; then
  printf '\nFailures:\n'
  printf ' - %s\n' "${failures[@]}"
  exit 1
fi

printf '\nStatus check passed.\n'
