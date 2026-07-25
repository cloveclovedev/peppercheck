#!/usr/bin/env bash
set -euo pipefail
read_secret() { [ -f "$1" ] && tr -d '\n' < "$1"; }
export PGBACKREST_REPO1_CIPHER_PASS="$(read_secret /run/secrets/pgbackrest_cipher)"
export PGBACKREST_REPO1_S3_KEY="$(read_secret /run/secrets/b2_key_id)"
export PGBACKREST_REPO1_S3_KEY_SECRET="$(read_secret /run/secrets/b2_key_secret)"
# pg_dump auth: fail-closed .pgpass (0600, owned postgres) from the backup password
: "${POSTGRES_BACKUP_PASSWORD_FILE:?}"; umask 077
printf 'localhost:5432:*:peppercheck_backup:%s\n' "$(cat "$POSTGRES_BACKUP_PASSWORD_FILE")" > /var/lib/postgresql/.pgpass
chown postgres:postgres /var/lib/postgresql/.pgpass; export PGPASSFILE=/var/lib/postgresql/.pgpass
# age-dump S3 upload auth: pass B2 creds explicitly (mc/rclone/aws do not inherit PGBACKREST_*)
export AWS_ACCESS_KEY_ID="$PGBACKREST_REPO1_S3_KEY" AWS_SECRET_ACCESS_KEY="$PGBACKREST_REPO1_S3_KEY_SECRET"
printenv | grep -E '^(PGBACKREST_|AWS_|PGPASSFILE|AGE_)' > /etc/environment   # cron jobs inherit
exec cron -f    # root cron daemon; runs the postgres crontab as user postgres
