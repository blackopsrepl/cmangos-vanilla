#!/usr/bin/env bash
set -euo pipefail
export TERM="${TERM:-xterm}"

mysql_root() {
  MYSQL_PWD="${DB_ROOT_PASSWORD:-cmangos-root-local}" mariadb \
    -h "$DB_HOST" -P "$DB_PORT" -uroot "$@"
}

mysql_user() {
  MYSQL_PWD="$MANGOS_DB_PASSWORD" mariadb \
    -h "$DB_HOST" -P "$DB_PORT" -u"$MANGOS_DB_USER" "$@"
}

sql_escape() {
  printf "%s" "$1" | sed "s/'/''/g"
}

echo "Waiting for MariaDB at ${DB_HOST}:${DB_PORT}..."
until mysql_root -e "SELECT 1" >/dev/null 2>&1; do
  sleep 2
done

if [ "${FORCE_DB_INIT:-0}" != "1" ] \
  && mysql_root -N -B -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${MANGOS_DB_REALM}' AND table_name='realmlist';" 2>/dev/null | grep -q '^1$'; then
  echo "CMaNGOS databases already look initialized. Set FORCE_DB_INIT=1 to rebuild them."
else
  ahbot_value="NO"
  if [ "${CMANGOS_BUILD_AHBOT:-OFF}" = "ON" ] && [ "${AHBOT_ENABLED:-0}" = "1" ]; then
    ahbot_value="YES"
  fi
  playerbots_value="NO"
  if [ "${CMANGOS_BUILD_PLAYERBOTS:-OFF}" = "ON" ] && [ "${PLAYERBOTS_ENABLED:-0}" = "1" ]; then
    playerbots_value="YES"
  fi

  cat > /opt/src/classic-db/InstallFullDB.config <<EOF
MYSQL_HOST="${DB_HOST}"
MYSQL_PORT="${DB_PORT}"
MYSQL_USERNAME="${MANGOS_DB_USER}"
MYSQL_PASSWORD="${MANGOS_DB_PASSWORD}"
MYSQL_USERIP="%"
MYSQL_COLSTAT=""
WORLD_DB_NAME="${MANGOS_DB_WORLD}"
REALM_DB_NAME="${MANGOS_DB_REALM}"
CHAR_DB_NAME="${MANGOS_DB_CHARACTERS}"
LOGS_DB_NAME="${MANGOS_DB_LOGS}"
MYSQL_PATH="/usr/bin/mariadb"
CORE_PATH="/opt/src/mangos-classic"
MYSQL_DUMP_PATH="/usr/bin/mariadb-dump"
LOCALES="${DB_IMPORT_LOCALES:-YES}"
DEV_UPDATES="${DB_IMPORT_DEV_UPDATES:-NO}"
AHBOT="${ahbot_value}"
PLAYERBOTS_DB="${playerbots_value}"
FORCE_WAIT="NO"
EOF

  echo "Importing classic-db and ScriptDev2 SQL. PlayerBots=${playerbots_value}, AHBot=${ahbot_value}."
  cd /opt/src/classic-db
  bash ./InstallFullDB.sh -InstallAll root "${DB_ROOT_PASSWORD:-cmangos-root-local}" DeleteAll
fi

mysql_user "${MANGOS_DB_WORLD}" <<SQL
UPDATE script_texts st
LEFT JOIN broadcast_text bt ON bt.Id = st.broadcast_text_id
SET st.broadcast_text_id = 0
WHERE st.broadcast_text_id <> 0
  AND bt.Id IS NULL;
SQL

realm_name=$(sql_escape "${REALM_NAME:-Vanilla at Home}")
realm_address=$(sql_escape "${REALM_ADDRESS:-127.0.0.1}")
realm_port="${LEGACY_WORLD_PORT:-8085}"

mysql_user "${MANGOS_DB_REALM}" <<SQL
INSERT INTO realmlist (id, name, address, port, icon, realmflags, timezone, allowedSecurityLevel, population, realmbuilds)
VALUES (1, '${realm_name}', '${realm_address}', ${realm_port}, 1, 0, 1, 0, 0, '')
ON DUPLICATE KEY UPDATE
  name=VALUES(name),
  address=VALUES(address),
  port=VALUES(port),
  realmflags=0,
  realmbuilds='';

INSERT INTO realmcharacters (realmid, acctid, numchars)
SELECT r.id, a.id, 0
FROM realmlist r
CROSS JOIN account a
LEFT JOIN realmcharacters rc ON rc.acctid = a.id AND rc.realmid = r.id
WHERE rc.acctid IS NULL;
SQL

echo "Database initialization complete."
