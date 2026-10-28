#!/usr/bin/env bash
set -euo pipefail

export HERMES_CLIENT_BUILD="${HERMES_CLIENT_BUILD:-42597}"
export HERMES_CLIENT_SEED="${HERMES_CLIENT_SEED:-179D3DC3235629D07113A9B3867F97A7}"
export HERMES_LEGACY_BUILD="${HERMES_LEGACY_BUILD:-5875}"
export HERMES_LEGACY_ADDRESS="${HERMES_LEGACY_ADDRESS:-realmd}"
export LEGACY_AUTH_PORT="${LEGACY_AUTH_PORT:-3724}"
export HERMES_REPORTED_OS="${HERMES_REPORTED_OS:-Win}"
export HERMES_REPORTED_PLATFORM="${HERMES_REPORTED_PLATFORM:-x86}"
export HERMES_EXTERNAL_ADDRESS="${HERMES_EXTERNAL_ADDRESS:-127.0.0.1}"
export HERMES_REST_PORT="${HERMES_REST_PORT:-8081}"
export HERMES_BNET_PORT="${HERMES_BNET_PORT:-1119}"
export HERMES_REALM_PORT="${HERMES_REALM_PORT:-8084}"
export HERMES_INSTANCE_PORT="${HERMES_INSTANCE_PORT:-8086}"
export HERMES_BIND_ALL="${HERMES_BIND_ALL:-1}"
export HERMES_DEBUG_OUTPUT="${HERMES_DEBUG_OUTPUT:-false}"

envsubst < /opt/hermesproxy/HermesProxy.config.template > /opt/hermesproxy/HermesProxy.config
envsubst < /opt/hermesproxy/appsettings.json.template > /opt/hermesproxy/appsettings.json

exec /opt/hermesproxy/HermesProxy
