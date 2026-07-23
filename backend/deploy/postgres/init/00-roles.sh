#!/bin/bash
# Creates the migration, runtime, and backup roles on first database
# initialization. Passwords come from environment variables and are passed to
# psql as variables so :'name' quotes them safely even if they contain quotes.
# This runs only when the data directory is empty (docker-entrypoint-initdb.d).
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  -v migrator_pw="$POSTGRES_MIGRATOR_PASSWORD" \
  -v app_pw="$POSTGRES_APP_PASSWORD" \
  -v backup_pw="$POSTGRES_BACKUP_PASSWORD" <<-'EOSQL'
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
