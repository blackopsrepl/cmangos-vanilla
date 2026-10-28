#!/usr/bin/env bash
set -euo pipefail

repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

env_path() {
  printf '%s/.env\n' "$(repo_root)"
}

ensure_env_file() {
  local root env
  root="$(repo_root)"
  env="$root/.env"
  if [ ! -f "$env" ]; then
    cp "$root/.env.example" "$env"
    printf 'Created .env from .env.example\n' >&2
  fi
  printf '%s\n' "$env"
}

read_key_value() {
  local file key default value
  file="$1"
  key="$2"
  default="${3:-}"
  if [ ! -f "$file" ]; then
    printf '%s\n' "$default"
    return
  fi
  value="$(grep -E "^[[:space:]]*${key}=" "$file" | tail -n 1 | sed -E "s/^[[:space:]]*${key}=//; s/^[[:space:]]+//; s/[[:space:]]+$//; s/^['\"]//; s/['\"]$//" || true)"
  if [ -z "$value" ]; then
    printf '%s\n' "$default"
  else
    printf '%s\n' "$value"
  fi
}

env_value() {
  read_key_value "$(ensure_env_file)" "$1" "${2:-}"
}

set_env_value() {
  local key value env tmp
  key="$1"
  value="$2"
  env="$(ensure_env_file)"
  tmp="$(mktemp)"
  awk -v key="$key" -v value="$value" '
    BEGIN { found = 0 }
    $0 ~ "^[[:space:]]*" key "=" { print key "=" value; found = 1; next }
    { print }
    END { if (!found) print key "=" value }
  ' "$env" > "$tmp"
  mv "$tmp" "$env"
}

check_server_sources() {
  local source component key expected actual expected_repo actual_repo
  source="${1:-$(repo_root)/server}"
  for component in mangos-classic classic-db playerbots; do
    case "$component" in
      mangos-classic) key=cmangos_core_sha ;;
      classic-db) key=classic_db_sha ;;
      playerbots) key=playerbots_sha ;;
    esac
    expected="$(read_key_value "$(repo_root)/versions.lock" "$key")"
    actual="$(read_key_value "$source/$component/.source-base" upstream_sha)"
    expected_repo="$(read_key_value "$(repo_root)/versions.lock" "${key%_sha}_repo")"
    actual_repo="$(read_key_value "$source/$component/.source-base" upstream_repo)"
    if [ -z "$expected" ] || [ -z "$expected_repo" ] || [ "$actual" != "$expected" ] || [ "$actual_repo" != "$expected_repo" ]; then
      printf 'Missing or incompatible local source: %s (expected base %s).\n' "$component" "$expected" >&2
      printf 'Supply authorized local sources with scripts/linux/import-server-sources.sh --source PATH. See docs/source-inputs.md.\n' >&2
      return 1
    fi
  done
  for component in mangos-classic/src mangos-classic/CMakeLists.txt classic-db/InstallFullDB.sh playerbots/playerbot; do
    if [ ! -e "$source/$component" ]; then
      printf 'Incomplete local server sources: missing %s\n' "$source/$component" >&2
      return 1
    fi
  done
}

require_podman() {
  if ! command -v podman >/dev/null 2>&1; then
    printf 'podman is required for the Linux deployment path.\n' >&2
    exit 1
  fi
  podman version >/dev/null
  if ! podman compose version >/dev/null 2>&1 && ! command -v podman-compose >/dev/null 2>&1; then
    printf 'podman compose or podman-compose is required.\n' >&2
    exit 1
  fi
}

cmangos_compose() {
  local env project root compose_files
  root="$(repo_root)"
  env="$(ensure_env_file)"
  project="${CMANGOS_COMPOSE_PROJECT:-$(env_value PROJECT_NAME cmangos-classic)}"
  compose_files=(-f "$root/docker-compose.yml" -f "$root/docker-compose.linux.yml")
  if [ -n "${CMANGOS_COMPOSE_COMMAND:-}" ]; then
    # shellcheck disable=SC2086
    $CMANGOS_COMPOSE_COMMAND "${compose_files[@]}" -p "$project" --env-file "$env" "$@"
  elif podman compose version >/dev/null 2>&1; then
    podman compose "${compose_files[@]}" -p "$project" --env-file "$env" "$@"
  else
    podman-compose "${compose_files[@]}" -p "$project" --env-file "$env" "$@"
  fi
}

artifact_log_path() {
  local name log_dir stamp
  name="$1"
  log_dir="$(repo_root)/artifacts/logs"
  mkdir -p "$log_dir"
  stamp="$(date +%Y%m%d-%H%M%S)"
  printf '%s/%s-%s.log\n' "$log_dir" "$name" "$stamp"
}

assert_inside_repo() {
  local root target
  root="$(realpath "$(repo_root)")"
  target="$(realpath -m "$1")"
  case "$target" in
    "$root"|"$root"/*) ;;
    *)
      printf 'Refusing to operate outside the repository: %s\n' "$target" >&2
      exit 1
      ;;
  esac
}

resolve_repo_path() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s/%s\n' "$(repo_root)" "$1" ;;
  esac
}

required_data_dirs() {
  printf '%s\n' dbc maps vmaps mmaps
}

expected_data_pattern() {
  case "$1" in
    dbc) printf '%s\n' '*.dbc' ;;
    maps) printf '%s\n' '*.map' ;;
    vmaps) printf '%s\n' '*.vmtree' ;;
    mmaps) printf '%s\n' '*.mmap' ;;
    *) printf '%s\n' '*' ;;
  esac
}

data_dir_has_extracted_files() {
  local path dir pattern
  path="$1"
  dir="$2"
  pattern="$(expected_data_pattern "$dir")"
  [ -d "$path" ] && (cd -- "$path" && find . -type f ! -path '*/.*' -iname "$pattern" -print -quit | grep -q .)
}

missing_extracted_data() {
  local root prefix dir path
  root="${1:-$(repo_root)/data/extracted}"
  prefix="${2:-data/extracted}"
  while IFS= read -r dir; do
    path="$root/$dir"
    if ! data_dir_has_extracted_files "$path" "$dir"; then
      printf '%s/%s\n' "$prefix" "$dir"
    fi
  done < <(required_data_dirs)
}

detect_lan_address() {
  local ip
  ip="$(ip route get 1.1.1.1 2>/dev/null | awk '{ for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit } }' || true)"
  if [ -z "$ip" ]; then
    ip="$(hostname -I 2>/dev/null | awk '{ print $1 }' || true)"
  fi
  printf '%s\n' "$ip"
}

sql_string() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/''/g")"
}

db_credentials() {
  local root_mode
  root_mode="${1:-0}"
  if [ "$root_mode" = "1" ]; then
    printf 'root\n%s\n' "$(env_value DB_ROOT_PASSWORD cmangos-root-local)"
  else
    printf '%s\n%s\n' "$(env_value MANGOS_DB_USER mangos)" "$(env_value MANGOS_DB_PASSWORD mangos)"
  fi
}

db_exec() {
  local database sql root_mode creds user password
  database="$1"
  sql="$2"
  root_mode="${3:-0}"
  mapfile -t creds < <(db_credentials "$root_mode")
  user="${creds[0]}"
  password="${creds[1]}"
  printf '%s\n' "$sql" | cmangos_compose exec -T -e "MYSQL_PWD=$password" db mariadb -h127.0.0.1 "-u$user" "$database"
}

db_query() {
  local database sql root_mode creds user password
  database="$1"
  sql="$2"
  root_mode="${3:-0}"
  mapfile -t creds < <(db_credentials "$root_mode")
  user="${creds[0]}"
  password="${creds[1]}"
  cmangos_compose exec -T -e "MYSQL_PWD=$password" db mariadb -N -B -h127.0.0.1 "-u$user" "$database" -e "$sql"
}

port_open() {
  local host port
  host="$1"
  port="$2"
  timeout 2 bash -c ":</dev/tcp/${host}/${port}" >/dev/null 2>&1
}

port_listening() {
  local host port state recv send local_addr peer addr
  host="$1"
  port="$2"

  if ! command -v ss >/dev/null 2>&1; then
    port_open "$host" "$port"
    return
  fi

  while read -r state recv send local_addr peer _; do
    [ "$state" = "LISTEN" ] || continue
    case "$local_addr" in
      *:"$port") ;;
      *) continue ;;
    esac
    addr="${local_addr%:"$port"}"
    addr="${addr#[}"
    addr="${addr%]}"
    case "$addr" in
      "*"|"0.0.0.0"|"::"|"$host")
        return 0
        ;;
    esac
  done < <(ss -H -ltn 2>/dev/null)

  return 1
}
