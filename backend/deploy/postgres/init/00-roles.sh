#!/bin/bash
# Creates the migration, runtime, and backup roles on first database
# initialization. Passwords come from POSTGRES_<ROLE>_PASSWORD, or from
# POSTGRES_<ROLE>_PASSWORD_FILE (a Docker file-based secret mounted at
# /run/secrets/*) when set -- mirroring the stock docker-entrypoint.sh's
# file_env() convention, file wins over the plain env var. Either way the
# password is passed to psql as a variable so :'name' quotes it safely even
# if it contains quotes. This runs only when the data directory is empty
# (docker-entrypoint-initdb.d).
set -euo pipefail

read_password() {
  local file_var="${1}_FILE"
  local file_path="${!file_var:-}"
  if [ -n "$file_path" ]; then
    # A set-but-unreadable _FILE hard-fails here under `set -e` (the redirect
    # fails), which is the desired fail-closed behavior.
    tr -d '\n' < "$file_path"
  else
    printf '%s' "${!1:-}"
  fi
}

# Fail closed: refuse to create a LOGIN role with an empty password. Without
# this, a fully-unset POSTGRES_<ROLE>_PASSWORD[_FILE] would silently produce a
# passwordless role.
require_password() {
  local value="$1" name="$2"
  if [ -z "$value" ]; then
    echo "00-roles.sh: ${name} is empty (set ${name} or ${name}_FILE)" >&2
    exit 1
  fi
}

MIGRATOR_PW="$(read_password POSTGRES_MIGRATOR_PASSWORD)"
require_password "$MIGRATOR_PW" POSTGRES_MIGRATOR_PASSWORD
APP_PW="$(read_password POSTGRES_APP_PASSWORD)"
require_password "$APP_PW" POSTGRES_APP_PASSWORD
BACKUP_PW="$(read_password POSTGRES_BACKUP_PASSWORD)"
require_password "$BACKUP_PW" POSTGRES_BACKUP_PASSWORD

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  -v migrator_pw="$MIGRATOR_PW" \
  -v app_pw="$APP_PW" \
  -v backup_pw="$BACKUP_PW" <<-'EOSQL'
  -- Migration role: owns schema objects and may run DDL.
  CREATE ROLE peppercheck_migrator LOGIN PASSWORD :'migrator_pw';
  GRANT CREATE, USAGE ON SCHEMA public TO peppercheck_migrator;

  -- Atlas migration-history table lives in its own schema, owned by the
  -- migrator, so the least-privilege app role (granted no USAGE here) can never
  -- read or tamper with migration state. The app's blanket default-privilege
  -- grant below is scoped to `public`, so it never reaches this schema.
  CREATE SCHEMA atlas AUTHORIZATION peppercheck_migrator;

  -- Runtime role: least-privilege DML only, never DDL.
  CREATE ROLE peppercheck_app LOGIN PASSWORD :'app_pw';
  GRANT USAGE ON SCHEMA public TO peppercheck_app;

  -- Backup role: read-only across all data (for pg_dump), no writes, no DDL.
  CREATE ROLE peppercheck_backup LOGIN PASSWORD :'backup_pw';
  GRANT USAGE ON SCHEMA public TO peppercheck_backup;
  GRANT pg_read_all_data TO peppercheck_backup;

  -- Tables the migrator creates later automatically grant DML to the app role.
  ALTER DEFAULT PRIVILEGES FOR ROLE peppercheck_migrator IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO peppercheck_app;
  ALTER DEFAULT PRIVILEGES FOR ROLE peppercheck_migrator IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO peppercheck_app;
EOSQL
