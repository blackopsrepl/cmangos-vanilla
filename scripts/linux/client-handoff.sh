#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"

address=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --address)
      address="${2:-}"
      shift 2
      ;;
    -h|--help)
      printf 'Usage: %s [--address ADDRESS]\n' "$0"
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

ensure_env_file >/dev/null
if [ -z "$address" ]; then
  legacy_address="$(env_value REALM_ADDRESS '')"
  hermes_address="$(env_value HERMES_EXTERNAL_ADDRESS '')"
  detected_address="$(detect_lan_address)"
  if [ -z "$legacy_address" ]; then
    legacy_address="$detected_address"
  fi
  if [ -z "$hermes_address" ]; then
    hermes_address="$legacy_address"
  fi
else
  legacy_address="$address"
  hermes_address="$address"
fi
if [ -z "$legacy_address" ] || [ -z "$hermes_address" ]; then
  printf 'Could not determine LAN address. Re-run with --address ADDRESS.\n' >&2
  exit 1
fi

auth_port="$(env_value LEGACY_AUTH_PORT 3724)"
world_port="$(env_value LEGACY_WORLD_PORT 8085)"
bnet_port="$(env_value HERMES_BNET_PORT 1119)"
realm_port="$(env_value HERMES_REALM_PORT 8084)"
instance_port="$(env_value HERMES_INSTANCE_PORT 8086)"
instant_quest_text="$(env_value CLIENT_INSTANT_QUEST_TEXT 1)"
case "$instant_quest_text" in
  0|false|False|FALSE|no|No|NO|off|Off|OFF)
    instant_quest_text=0
    ;;
  *)
    instant_quest_text=1
    ;;
esac

cat <<EOF
Windows laptop checks:

Test-NetConnection ${legacy_address} -Port ${auth_port}
Test-NetConnection ${hermes_address} -Port ${bnet_port}
Test-NetConnection ${hermes_address} -Port ${realm_port}
Test-NetConnection ${hermes_address} -Port ${instance_port}

After extracted data is imported and mangosd is running:

Test-NetConnection ${legacy_address} -Port ${world_port}

Primary play path, original Vanilla 1.12.x client:

.\scripts\patch-legacy-client-config.ps1 -LegacyClientPath "C:\Games\WoW-1.12.1" -Address "${legacy_address}"

Optional archived modern path, Classic Era 1.14.2 build 42597 only:

.\scripts\patch-modern-client-config.ps1 -ModernClientPath "C:\Games\World of Warcraft\_classic_era_1.14.2.42597" -Portal "${hermes_address}:${bnet_port}"
.\scripts\start-modern-client.ps1 -ModernClientPath "C:\Games\World of Warcraft\_classic_era_1.14.2.42597" -Portal "${hermes_address}:${bnet_port}" -NoProxyRestart

Do not use the current Battle.net Classic Era client with this CMaNGOS/HermesProxy stack.

Manual settings:

realmlist.wtf: set realmlist ${legacy_address}
WTF\Config.wtf: SET instantQuestText "${instant_quest_text}"
WTF\Config.wtf: SET portal "${hermes_address}:${bnet_port}"
EOF
