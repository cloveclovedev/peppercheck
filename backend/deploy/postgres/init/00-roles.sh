#!/bin/bash
# Creates the migration and runtime roles on first database initialization.
# Passwords come from environment variables set on the postgres service.
# This runs only when the data directory is empty (docker-entrypoint-initdb.d).
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  -- Migration role: owns schema objects and may run DDL.
  CREATE ROLE peppercheck_migrator LOGIN PASSWORD '${POSTGRES_MIGRATOR_PASSWORD}';
  GRANT CREATE, USAGE ON SCHEMA public TO peppercheck_migrator;

  -- Runtime role: least-privilege DML only, never DDL.
  CREATE ROLE peppercheck_app LOGIN PASSWORD '${POSTGRES_APP_PASSWORD}';
  GRANT USAGE ON SCHEMA public TO peppercheck_app;

  -- Tables the migrator creates later automatically grant DML to the app role.
  ALTER DEFAULT PRIVILEGES FOR ROLE peppercheck_migrator IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO peppercheck_app;
  ALTER DEFAULT PRIVILEGES FOR ROLE peppercheck_migrator IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO peppercheck_app;
EOSQL
