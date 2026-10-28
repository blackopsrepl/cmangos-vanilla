#!/usr/bin/env bash
set -euo pipefail

export DB_HOST="${DB_HOST:-db}"
export DB_PORT="${DB_PORT:-3306}"
export MANGOS_DB_USER="${MANGOS_DB_USER:-mangos}"
export MANGOS_DB_PASSWORD="${MANGOS_DB_PASSWORD:-mangos}"
export MANGOS_DB_WORLD="${MANGOS_DB_WORLD:-classicmangos}"
export MANGOS_DB_REALM="${MANGOS_DB_REALM:-classicrealmd}"
export MANGOS_DB_CHARACTERS="${MANGOS_DB_CHARACTERS:-classiccharacters}"
export MANGOS_DB_LOGS="${MANGOS_DB_LOGS:-classiclogs}"
export REALM_NAME="${REALM_NAME:-Vanilla at Home}"
export REALM_ADDRESS="${REALM_ADDRESS:-127.0.0.1}"
export LEGACY_AUTH_PORT="${LEGACY_AUTH_PORT:-3724}"
export LEGACY_WORLD_PORT="${LEGACY_WORLD_PORT:-8085}"
export DATA_DIR="${DATA_DIR:-/data}"
export RATE_XP_KILL="${RATE_XP_KILL:-1}"
export RATE_XP_QUEST="${RATE_XP_QUEST:-1}"
export RATE_XP_EXPLORE="${RATE_XP_EXPLORE:-1}"
export RATE_DROP_ITEMS="${RATE_DROP_ITEMS:-1}"
export RATE_DROP_MONEY="${RATE_DROP_MONEY:-1}"
export PLAYERBOTS_ENABLED="${PLAYERBOTS_ENABLED:-1}"
export PLAYERBOTS_MIN_RANDOM_BOTS="${PLAYERBOTS_MIN_RANDOM_BOTS:-20}"
export PLAYERBOTS_MAX_RANDOM_BOTS="${PLAYERBOTS_MAX_RANDOM_BOTS:-30}"
export PLAYERBOTS_MIN_LEVEL="${PLAYERBOTS_MIN_LEVEL:-1}"
export PLAYERBOTS_MAX_LEVEL="${PLAYERBOTS_MAX_LEVEL:-60}"
export PLAYERBOTS_ACCOUNT_PREFIX="${PLAYERBOTS_ACCOUNT_PREFIX:-RNDBOT}"
export PLAYERBOTS_ACCOUNT_COUNT="${PLAYERBOTS_ACCOUNT_COUNT:-20}"
export PLAYERBOTS_BOT_ACTIVE_ALONE="${PLAYERBOTS_BOT_ACTIVE_ALONE:-10}"
export AHBOT_ENABLED="${AHBOT_ENABLED:-1}"
export AHBOT_SELL_CHANCE="${AHBOT_SELL_CHANCE:-10}"
export AHBOT_BUY_CHANCE="${AHBOT_BUY_CHANCE:-5}"
export AHBOT_MAX_REQUIRED_LEVEL="${AHBOT_MAX_REQUIRED_LEVEL:-60}"

render_configs() {
  mkdir -p /opt/cmangos/etc /opt/cmangos/logs "$DATA_DIR" /opt/etc
  envsubst < /opt/cmangos/templates/mangosd.conf.template > /opt/cmangos/etc/mangosd.conf
  envsubst < /opt/cmangos/templates/realmd.conf.template > /opt/cmangos/etc/realmd.conf
  envsubst < /opt/cmangos/templates/aiplayerbot.conf.template > /opt/cmangos/etc/aiplayerbot.conf
  envsubst < /opt/cmangos/templates/ahbot.conf.template > /opt/cmangos/etc/ahbot.conf
  cp /opt/src/mangos-classic/src/game/Anticheat/module/anticheat.conf.dist.in /opt/cmangos/etc/anticheat.conf
  sed -i 's|^Warden.ModuleDir = .*|Warden.ModuleDir = "/opt/cmangos/bin/warden_modules"|' /opt/cmangos/etc/anticheat.conf
  cp /opt/cmangos/etc/aiplayerbot.conf /opt/cmangos/aiplayerbot.conf
  cp /opt/cmangos/etc/ahbot.conf /opt/cmangos/ahbot.conf
  cp /opt/cmangos/etc/aiplayerbot.conf /opt/etc/aiplayerbot.conf
  cp /opt/cmangos/etc/ahbot.conf /opt/etc/ahbot.conf
  cp /opt/cmangos/etc/anticheat.conf /opt/etc/anticheat.conf
}

extract_data() {
  if [ ! -d /client/Data ]; then
    echo "Expected a legacy 1.12.x client mounted at /client with a Data directory." >&2
    exit 1
  fi

  mkdir -p /data
  rm -rf /tmp/cmangos-extract-client
  mkdir -p /tmp/cmangos-extract-client
  ln -s /client/Data /tmp/cmangos-extract-client/Data

  cd /tmp/cmangos-extract-client
  /opt/cmangos/bin/tools/ad
  /opt/cmangos/bin/tools/vmap_extractor
  mkdir -p vmaps
  /opt/cmangos/bin/tools/vmap_assembler Buildings vmaps
  mkdir -p mmaps
  /opt/cmangos/bin/tools/MoveMapGen --silent

  rm -rf /data/dbc /data/maps /data/vmaps /data/mmaps
  cp -a dbc maps vmaps mmaps /data/
  echo "Extracted dbc, maps, vmaps, and mmaps into /data."
}

case "${1:-}" in
  init-db)
    render_configs
    exec /opt/cmangos/docker/init-db.sh
    ;;
  extract-data)
    extract_data
    ;;
  realmd)
    render_configs
    exec /opt/cmangos/bin/realmd --config /opt/cmangos/etc/realmd.conf
    ;;
  mangosd)
    render_configs
    cmd=(/opt/cmangos/bin/mangosd --config /opt/cmangos/etc/mangosd.conf)
    if [ "${CMANGOS_BUILD_PLAYERBOTS:-OFF}" = "ON" ] && [ "${PLAYERBOTS_ENABLED:-0}" = "1" ]; then
      cmd+=(-p /opt/cmangos/etc/aiplayerbot.conf)
    fi
    if [ "${CMANGOS_BUILD_AHBOT:-OFF}" = "ON" ] && [ "${AHBOT_ENABLED:-0}" = "1" ]; then
      cmd+=(-a /opt/cmangos/etc/ahbot.conf)
    fi
    exec "${cmd[@]}"
    ;;
  "")
    exec bash
    ;;
  *)
    render_configs
    exec "$@"
    ;;
esac
