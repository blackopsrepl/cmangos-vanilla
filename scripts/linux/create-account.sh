#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"

username=""
password=""
gm_level=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --username)
      username="${2:-}"
      shift 2
      ;;
    --password)
      password="${2:-}"
      shift 2
      ;;
    --gm-level)
      gm_level="${2:-}"
      shift 2
      ;;
    -h|--help)
      printf 'Usage: %s --username NAME --password PASSWORD [--gm-level 0-3]\n' "$0"
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$username" ] || [ -z "$password" ]; then
  printf '%s\n' '--username and --password are required.' >&2
  exit 1
fi
if ! [[ "$username" =~ ^[A-Za-z0-9_.@-]{1,32}$ ]]; then
  printf 'Username must be 1-32 ASCII letters, numbers, underscore, dot, at-sign, or hyphen.\n' >&2
  exit 1
fi
if [ "${#password}" -lt 1 ] || [ "${#password}" -gt 32 ]; then
  printf 'Password must be 1-32 characters for this legacy account table.\n' >&2
  exit 1
fi
if ! [[ "$gm_level" =~ ^[0-3]$ ]]; then
  printf '%s\n' '--gm-level must be 0, 1, 2, or 3.' >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  printf 'python3 is required to generate the SRP6 verifier.\n' >&2
  exit 1
fi

normalized_username="$(printf '%s' "$username" | tr '[:lower:]' '[:upper:]')"
normalized_password="$(printf '%s' "$password" | tr '[:lower:]' '[:upper:]')"
read -r salt verifier < <(python3 - "$normalized_username" "$normalized_password" <<'PY'
import hashlib
import os
import sys

username = sys.argv[1]
password = sys.argv[2]
identity = hashlib.sha1(f"{username}:{password}".encode("utf-8")).digest()
salt_be = bytearray(os.urandom(32))
salt_be[0] |= 0x80
salt_be[31] |= 0x01
salt_le = bytes(reversed(salt_be))
x = int.from_bytes(hashlib.sha1(salt_le + identity).digest(), "little")
n = int("894B645E89E1535BBDAD5B8B290650530801B18EBFBF5E8FAB3C82872A3E9BB7", 16)
v = pow(7, x, n)
print(salt_be.hex().upper(), format(v, "X"))
PY
)

realm_db="$(env_value MANGOS_DB_REALM classicrealmd)"
u="$(sql_string "$normalized_username")"
sql="
INSERT INTO account(username, gmlevel, sessionkey, v, s, email, joindate, lockedIp, failed_logins, locked, last_module, module_day, active_realm_id, expansion, mutetime, locale, os, platform, token, flags)
VALUES(${u}, ${gm_level}, '', $(sql_string "$verifier"), $(sql_string "$salt"), '', NOW(), '127.0.0.1', 0, 0, '', 0, 0, 0, 0, '', '0', '0', NULL, 0)
ON DUPLICATE KEY UPDATE
  gmlevel=VALUES(gmlevel),
  sessionkey='',
  v=VALUES(v),
  s=VALUES(s);

INSERT INTO realmcharacters (realmid, acctid, numchars)
SELECT r.id, a.id, 0
FROM realmlist r
CROSS JOIN account a
LEFT JOIN realmcharacters rc ON rc.acctid = a.id AND rc.realmid = r.id
WHERE a.username=${u} AND rc.acctid IS NULL;
"

db_exec "$realm_db" "$sql"
db_query "$realm_db" "SELECT id, username, gmlevel FROM account WHERE username=${u};"
