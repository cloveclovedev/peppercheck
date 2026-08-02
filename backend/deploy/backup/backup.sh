#!/bin/sh
# One-shot age-encrypted logical backup: pg_dump -> pg_restore -l verify ->
# upload to B2 -> exit. Cadence is owned by the postgres crontab (../crontab)
# driven by `cron -f` in entrypoint.sh, not this script (the former `while
# true` interval loop is gone). Continuous WAL archiving + scheduled
# pgBackRest full/diff backups (also cron-driven) are the primary PITR
# mechanism; this age-encrypted dump is the independent secondary logical
# fallback, uploaded to a separate B2 prefix.
set -eu

# AGE_RECIPIENT (the age public key) is not inherently secret, but is
# accepted either as a Docker file-based secret (AGE_RECIPIENT_FILE, mirrors
# the *_FILE convention used throughout deploy/postgres/init/00-roles.sh) or
# as a plain env var -- file wins.
read_age_recipient() {
  if [ -n "${AGE_RECIPIENT_FILE:-}" ]; then
    tr -d '\n' < "$AGE_RECIPIENT_FILE"
  else
    printf '%s' "${AGE_RECIPIENT:-}"
  fi
}
AGE_RECIPIENT="$(read_age_recipient)"
: "${AGE_RECIPIENT:?AGE_RECIPIENT (age public key) is required, via AGE_RECIPIENT or AGE_RECIPIENT_FILE}"

# pg_dump connects over the shared Postgres Unix socket (matches
# pgbackrest.conf's pg1-socket-path); libpq/`.pgpass` compare the socket
# dir's host field against the literal "localhost", which is exactly the
# host entrypoint.sh bakes into .pgpass.
PGHOST="${PGHOST:-/var/run/postgresql}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-peppercheck_backup}"
PGDATABASE="${PGDATABASE:-peppercheck}"

: "${PGBACKREST_REPO1_S3_BUCKET:?PGBACKREST_REPO1_S3_BUCKET is required}"
: "${PGBACKREST_REPO1_S3_ENDPOINT:?PGBACKREST_REPO1_S3_ENDPOINT is required}"
# Separate prefix within the same repo bucket, distinct from pgBackRest's own
# repo path, so the logical fallback never collides with (or is prunable by)
# pgBackRest's own retention/expire processing.
AGE_DUMP_S3_PREFIX="${AGE_DUMP_S3_PREFIX:-age-dumps}"

DUMP_DIR="${DUMP_DIR:-/tmp}"

cleanup_temps() {
  rm -f "$DUMP_DIR"/.dump-*.tmp "$DUMP_DIR"/.dump-*.age.tmp 2>/dev/null || true
}

# rclone (not the MinIO "mc" client, which collides with Debian's unrelated
# "mc" / GNU Midnight Commander package) uploads the finished artifact. The
# remote is configured through RCLONE_CONFIG_* env vars rather than an inline
# `:s3,...:` connection string on purpose: in a connection string any value
# containing a colon must be quoted, and an unquoted host:port endpoint (the
# local MinIO `minio:9000`) or a scheme (`https://...`) misparses -- rclone
# then silently builds a wrong URL (e.g. `https://minio/9000%2C...`) and the
# upload never reaches the intended remote. A bare-hostname B2 endpoint
# parses fine either way, so the bug would pass in production and only surface
# against a host:port endpoint. The env-var form passes each value literally,
# so a host:port endpoint is safe. `env_auth=true` reads AWS_ACCESS_KEY_ID/
# AWS_SECRET_ACCESS_KEY, which entrypoint.sh exports from the same B2 key
# pgBackRest itself uses, so no rclone.conf or credential file is needed.
export RCLONE_CONFIG_AGEDUMP_TYPE=s3
export RCLONE_CONFIG_AGEDUMP_PROVIDER=Other
export RCLONE_CONFIG_AGEDUMP_ENV_AUTH=true
export RCLONE_CONFIG_AGEDUMP_ENDPOINT="$PGBACKREST_REPO1_S3_ENDPOINT"
export RCLONE_CONFIG_AGEDUMP_REGION="${PGBACKREST_REPO1_S3_REGION:-us-east-1}"

upload_backup() {
  src="$1" name="$2"
  rclone copyto "$src" "AGEDUMP:${PGBACKREST_REPO1_S3_BUCKET}/${AGE_DUMP_S3_PREFIX}/${name}"
}

# Each step guards with `|| return 1` so a failure aborts the backup regardless
# of `set -e`: POSIX/busybox-ash disable `set -e` inside a function called from a
# tested context (`if ! run_backup`), so relying on it would let a failed pg_dump
# slip past the pg_restore verify and publish/upload a corrupt artifact.
run_backup() {
  ts=$(date -u +%Y%m%dT%H%M%SZ)
  tmp="${DUMP_DIR}/.dump-${ts}.dump.tmp"       # dot-prefixed: not a published artifact
  enc="${DUMP_DIR}/.dump-${ts}.dump.age.tmp"
  name="dump-${ts}.dump.age"
  final="${DUMP_DIR}/${name}"
  echo "{\"level\":\"info\",\"msg\":\"logical backup start\",\"ts\":\"$ts\"}"
  pg_dump -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -Fc -f "$tmp" || return 1
  pg_restore -l "$tmp" >/dev/null || return 1   # verify it is a valid archive
  age -r "$AGE_RECIPIENT" -o "$enc" "$tmp" || return 1
  mv "$enc" "$final" || return 1                # atomic publish; only now does dump-*.age exist
  rm -f "$tmp"
  echo "{\"level\":\"info\",\"msg\":\"logical backup dumped\",\"file\":\"${name}\"}"
  # On upload failure remove the locally-published artifact too: B2 is the
  # real published location, so a failed upload must not leave the local
  # dump-*.age accumulating (cleanup_temps only sweeps .tmp files, not the
  # published name). Removing it here keeps the atomic-publish safety -- the
  # local file only ever exists between mv and a successful upload.
  upload_backup "$final" "$name" || { rm -f "$final"; return 1; }
  rm -f "$final"
  echo "{\"level\":\"info\",\"msg\":\"logical backup done\",\"file\":\"${name}\"}"
}

if ! run_backup; then
  echo "{\"level\":\"error\",\"msg\":\"logical backup failed\"}"
  cleanup_temps
  exit 1
fi

# Optional Better Stack heartbeat: guarded because not every environment
# monitors this cycle (HEARTBEAT_URL_BACKUP may be unset), and non-fatal
# (`|| ...`) because under `set -eu` a failed heartbeat POST must never mark
# an otherwise-successful, already-uploaded backup as failed.
if [ -n "${HEARTBEAT_URL_BACKUP:-}" ]; then
  if curl -fsS "$HEARTBEAT_URL_BACKUP" -o /dev/null; then
    echo "{\"level\":\"info\",\"msg\":\"backup heartbeat sent\"}"
  else
    echo "{\"level\":\"warn\",\"msg\":\"backup heartbeat POST failed\"}"
  fi
fi
