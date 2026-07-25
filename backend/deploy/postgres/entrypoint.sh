#!/usr/bin/env bash
set -euo pipefail
read_secret() { [ -f "$1" ] && tr -d '\n' < "$1"; }
export PGBACKREST_REPO1_CIPHER_PASS="$(read_secret /run/secrets/pgbackrest_cipher)"
export PGBACKREST_REPO1_S3_KEY="$(read_secret /run/secrets/b2_key_id)"
export PGBACKREST_REPO1_S3_KEY_SECRET="$(read_secret /run/secrets/b2_key_secret)"
exec docker-entrypoint.sh postgres "$@"   # drops to postgres; env inherited by archive_command
