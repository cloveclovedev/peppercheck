#!/usr/bin/env bash
# restore-drill.sh <env>
#
# Isolated, DB-clock, sentinel-verified PITR restore drill (Task 16, Phase
# 7-A infra/ops foundation -- design doc §8.4). Proves the pgBackRest backup
# chain can actually be restored to a point in time, brings an authenticated
# API up on the restored data, and measures RTO against the 4-hour target.
# Task 21 runs this for real against staging/B2; this task only authors it
# (verified here by shellcheck/bash -n + a careful manual read -- it cannot
# be executed end-to-end without a real B2 bucket and a real staging
# Firebase project).
#
# ---- where this runs ------------------------------------------------------
# Installed on the Droplet at /opt/peppercheck/current/scripts/restore-drill.sh
# by the normal deploy pipeline (ship-deployment.sh rsyncs the whole
# `backend/` tree; switch-deployment.sh points `current` at it) -- no extra
# shipping step is needed. Run it FROM the deployment root it ships with, as
# the `deploy` user, the same way rollback.sh (Task 6) is invoked:
#
#   cd /opt/peppercheck/current
#   bws run --project-id <restore-scoped-project-id> -- ./scripts/restore-drill.sh staging
#
# `bws run` renders every secret in the RESTORE-SCOPED BWS project (NEVER the
# staging/production project -- see deploy/provision/RUNBOOK.md §1.2) into
# this process's own environment before the script starts, exactly like
# ship-deployment.sh already relies on for the primary deploy secrets:
#   b2_key_id, b2_key_secret       -- a READ-ONLY B2 application key, distinct
#                                     from the read-write key `postgres`/
#                                     `backup` use in production
#   pgbackrest_cipher              -- same passphrase as the source stanza
#                                     (decryption only; the repo cipher is
#                                     symmetric, §8.5 of the design doc)
#   age_private_key                -- restore-only; never present on the
#                                     primary Droplet at all (§6.3)
#   firebase_test_api_key,
#   firebase_test_email,
#   firebase_test_password         -- a dedicated low-privilege test account
#                                     in the target environment's real
#                                     Firebase project, consumed by
#                                     firebase-test-token.sh
#
# The non-secret PGBACKREST_REPO1_S3_*/FIREBASE_PROJECT_ID/IMAGE_* values
# come from the SAME `images.env` the live deployment already has on disk
# (sourced below, exactly like rollback.sh) -- they are configuration, not
# credentials, and reusing them means this script never has to be told the
# bucket/region/project id a second time.
#
# ---- isolation / safety measures (see the design doc §8.4 checklist) ------
#   - The restore lands in a BRAND NEW Docker volume (created + chowned
#     below), never the live `pgdata` volume `peppercheck-<env>` is using.
#   - compose.restore.yaml brings up ONLY postgres + api, under an isolated
#     Compose project/network (`peppercheck-restore-drill` / `pcnet_restore`)
#     -- never `pcnet`, never the worker, never `migrate`/`backup`/`caddy`.
#   - The restored postgres runs with `archive_mode=off` on the command line
#     (compose.restore.yaml), which overrides whatever the restored
#     PGDATA's postgresql.auto.conf says -- so even though PITR promote
#     puts it on a fresh timeline, it can NEVER attempt to archive-push WAL
#     back into the shared production B2 stanza.
#   - `--target-action=promote` (not the pgBackRest default `pause`) so the
#     restored server actually leaves recovery and the API's DB connection
#     works -- `pause` would leave it read-only-in-recovery and block /me.
#   - Steps that need B2 network access (pgbackrest restore, the age-dump
#     verification) run in `--rm` throwaway containers scoped to exactly
#     that task; the chown helper runs with `--network none`; the restored
#     stack's api port is published to 127.0.0.1 only, never a public/
#     tailnet-reachable interface.
#   - `trap cleanup EXIT` tears the isolated project + volume + any scratch
#     verification resources down on every exit path, success or failure.
#   - This script NEVER runs `docker compose down`/`rm`/`volume rm` against
#     the live `peppercheck-<env>` project or its `pgdata` volume -- every
#     destructive command below is scoped to names this script itself
#     generated for the drill.
set -euo pipefail
export LC_ALL=C # WAL segment filenames are fixed-width hex; string comparison must not be locale-dependent

env="${1:?usage: restore-drill.sh <env> (staging|production)}"
case "$env" in
  staging | production) ;;
  *)
    echo "restore-drill: env must be staging or production, got '$env'" >&2
    exit 1
    ;;
esac

log() { echo "==> $*"; }

# cd into the deployment root this script ships alongside (current/), the
# same way pgbackrest-local-smoke.sh anchors itself to backend/ -- so every
# relative path below (compose.prod.yaml, compose.restore.yaml, images.env)
# resolves regardless of the caller's own working directory.
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# images.env is written by ship-deployment.sh at deploy time (Task 10) and
# holds IMAGE_POSTGRES/IMAGE_BACKEND/IMAGE_BACKUP plus the non-secret
# PGBACKREST_REPO1_S3_*/FIREBASE_PROJECT_ID/API_PORT values -- the exact same
# ones the live `peppercheck-<env>` project is running with right now, so
# the drill restores and smoke-tests the ACTUAL deployed release.
: "${IMAGES_ENV:=images.env}"
set -a
# shellcheck source=/dev/null
source "$IMAGES_ENV"
set +a

: "${b2_key_id:?b2_key_id is required (restore-scoped BWS secret, READ-ONLY B2 key)}"
: "${b2_key_secret:?b2_key_secret is required (restore-scoped BWS secret)}"
: "${pgbackrest_cipher:?pgbackrest_cipher is required (restore-scoped BWS secret)}"
: "${age_private_key:?age_private_key is required (restore-scoped BWS secret)}"
: "${firebase_test_api_key:?firebase_test_api_key is required (restore-scoped BWS secret)}"
: "${firebase_test_email:?firebase_test_email is required (restore-scoped BWS secret)}"
: "${firebase_test_password:?firebase_test_password is required (restore-scoped BWS secret)}"
: "${PGBACKREST_REPO1_S3_ENDPOINT:?missing PGBACKREST_REPO1_S3_ENDPOINT (expected in $IMAGES_ENV)}"
: "${PGBACKREST_REPO1_S3_BUCKET:?missing PGBACKREST_REPO1_S3_BUCKET (expected in $IMAGES_ENV)}"
: "${PGBACKREST_REPO1_S3_REGION:?missing PGBACKREST_REPO1_S3_REGION (expected in $IMAGES_ENV)}"
: "${FIREBASE_PROJECT_ID:?missing FIREBASE_PROJECT_ID (expected in $IMAGES_ENV)}"
: "${API_PORT:?missing API_PORT (expected in $IMAGES_ENV)}"
: "${IMAGE_POSTGRES:?missing IMAGE_POSTGRES (expected in $IMAGES_ENV)}"
: "${IMAGE_BACKEND:?missing IMAGE_BACKEND (expected in $IMAGES_ENV)}"
: "${IMAGE_BACKUP:?missing IMAGE_BACKUP (expected in $IMAGES_ENV)}"

readonly SOURCE_PROJECT="peppercheck-${env}"
readonly SOURCE_COMPOSE="compose.prod.yaml"
readonly RESTORE_PROJECT="peppercheck-restore-drill"
readonly RESTORE_COMPOSE="compose.restore.yaml"
readonly RESTORE_VOLUME="pgdata-restore-drill-$$"
# Relative to the deployment root (we already cd'd there above, so this is
# e.g. /opt/peppercheck/current/secrets/database_url on a real Droplet) --
# the SAME file write-secret.sh/remote-deploy.sh already placed there for
# the live deployment's own api/worker services.
readonly DATABASE_URL_SECRET_FILE="${DATABASE_URL_SECRET_FILE:-secrets/database_url}"
readonly RESTORE_API_PORT="${RESTORE_API_PORT:-18765}"
readonly WAL_POLL_TIMEOUT_SECONDS="${WAL_POLL_TIMEOUT_SECONDS:-300}"
readonly WAL_POLL_INTERVAL_SECONDS="${WAL_POLL_INTERVAL_SECONDS:-5}"
readonly API_READY_TIMEOUT_SECONDS="${API_READY_TIMEOUT_SECONDS:-120}"
readonly RTO_TARGET_SECONDS=$((4 * 60 * 60))

# Set by verify_age_dump_restore() before it creates each resource, so
# cleanup() can remove them even if that function dies partway through
# (its own happy-path already removes them itself; this is the belt for
# the failure-path suspenders).
VERIFY_NETWORK=""
VERIFY_SCRATCH=""

source_exec() {
  docker compose -p "$SOURCE_PROJECT" -f "$SOURCE_COMPOSE" exec -T postgres "$@"
}

restore_compose() {
  RESTORE_VOLUME="$RESTORE_VOLUME" RESTORE_API_PORT="$RESTORE_API_PORT" \
    IMAGE_POSTGRES="$IMAGE_POSTGRES" IMAGE_BACKEND="$IMAGE_BACKEND" \
    API_PORT="$API_PORT" FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID" \
    DATABASE_URL_SECRET_FILE="$DATABASE_URL_SECRET_FILE" \
    docker compose -p "$RESTORE_PROJECT" -f "$RESTORE_COMPOSE" "$@"
}

cleanup() {
  local status=$?
  log "tearing down ${RESTORE_PROJECT} (status=$status)"
  # `down -v` removes the compose-managed pcnet_restore network, but NEVER
  # the `pgdata_restore` volume -- it is declared `external: true` in
  # compose.restore.yaml precisely so Compose can never delete a volume it
  # didn't create, so it is removed explicitly by name below instead.
  restore_compose down -v --remove-orphans >/dev/null 2>&1 || true
  docker volume rm -f "$RESTORE_VOLUME" >/dev/null 2>&1 || true
  [ -n "$VERIFY_SCRATCH" ] && docker rm -f "$VERIFY_SCRATCH" >/dev/null 2>&1
  [ -n "$VERIFY_NETWORK" ] && docker network rm "$VERIFY_NETWORK" >/dev/null 2>&1
  exit "$status"
}
trap cleanup EXIT

wal_ge() {
  # True if $1 (last_archived_wal) has reached-or-passed $2 (target segment).
  # WAL segment filenames are fixed-width 24-hex-digit strings on a single
  # timeline here, so plain string comparison is exactly numeric comparison
  # (hence the LC_ALL=C above, so this never depends on locale collation).
  [ "$1" = "$2" ] || [[ "$1" > "$2" ]]
}

verify_age_dump_restore() {
  log "verifying the independent age-encrypted logical dump restores for real"
  local net="pc-restore-verify-net-$$"
  local scratch="pc-restore-scratch-$$"
  VERIFY_NETWORK="$net"
  docker network create "$net" >/dev/null
  VERIFY_SCRATCH="$scratch"
  docker run -d --name "$scratch" --network "$net" \
    -e POSTGRES_PASSWORD=restore-drill-scratch-throwaway \
    postgres:17 >/dev/null

  local i
  for i in $(seq 1 30); do
    if docker exec "$scratch" pg_isready -U postgres >/dev/null 2>&1; then
      break
    fi
    if [ "$i" -eq 30 ]; then
      echo "restore-drill: scratch postgres never became ready" >&2
      docker logs "$scratch" >&2 || true
      return 1
    fi
    sleep 2
  done

  # Fetch the LATEST age-dumps/*.dump.age object from B2 (dump-<UTC
  # timestamp>.dump.age names sort lexicographically = chronologically, per
  # deploy/backup/backup.sh), decrypt it with the restore-scoped age
  # PRIVATE key, and run a REAL `pg_restore` (not just `pg_restore -l`) into
  # the scratch DB above. All three tools (rclone, age, pg_restore) already
  # ship in IMAGE_BACKUP (deploy/backup/Dockerfile) -- no new tooling is
  # installed anywhere for this. The private key is piped over the
  # container's stdin and only ever materializes inside this `--rm`
  # container's own removable filesystem, never on the Droplet's host disk.
  # shellcheck disable=SC2016 # single-quoted on purpose: this expands inside
  # the container's exec'd shell (via the -e vars above), not this host shell.
  docker run --rm -i --network "$net" \
    -e AWS_ACCESS_KEY_ID="$b2_key_id" \
    -e AWS_SECRET_ACCESS_KEY="$b2_key_secret" \
    -e RCLONE_CONFIG_AGEDUMP_TYPE=s3 \
    -e RCLONE_CONFIG_AGEDUMP_PROVIDER=Other \
    -e RCLONE_CONFIG_AGEDUMP_ENV_AUTH=true \
    -e RCLONE_CONFIG_AGEDUMP_ENDPOINT="$PGBACKREST_REPO1_S3_ENDPOINT" \
    -e RCLONE_CONFIG_AGEDUMP_REGION="$PGBACKREST_REPO1_S3_REGION" \
    -e B2_BUCKET="$PGBACKREST_REPO1_S3_BUCKET" \
    -e AGE_DUMP_S3_PREFIX="${AGE_DUMP_S3_PREFIX:-age-dumps}" \
    -e PGHOST="$scratch" -e PGPORT=5432 -e PGUSER=postgres \
    -e PGPASSWORD=restore-drill-scratch-throwaway -e PGDATABASE=postgres \
    --entrypoint sh "$IMAGE_BACKUP" -c '
      set -eu
      umask 077
      cat > /tmp/age.key
      latest="$(rclone lsf "AGEDUMP:${B2_BUCKET}/${AGE_DUMP_S3_PREFIX}/" | sort | tail -n1)"
      [ -n "$latest" ] || { echo "no age dump found under ${AGE_DUMP_S3_PREFIX}/" >&2; exit 1; }
      echo "restoring latest age dump: $latest" >&2
      rclone copyto "AGEDUMP:${B2_BUCKET}/${AGE_DUMP_S3_PREFIX}/${latest}" /tmp/dump.age
      age -d -i /tmp/age.key -o /tmp/dump.dump /tmp/dump.age
      pg_restore -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" --no-owner --clean --if-exists /tmp/dump.dump
    ' <<<"$age_private_key"

  docker rm -f "$scratch" >/dev/null
  VERIFY_SCRATCH=""
  docker network rm "$net" >/dev/null
  VERIFY_NETWORK=""
  log "age dump real pg_restore verification OK"
}

# ---- Step 1: pre sentinel --------------------------------------------------
log "inserting pre-target sentinel row on the live ${SOURCE_PROJECT} database"
source_exec psql -v ON_ERROR_STOP=1 -U postgres -d peppercheck \
  -c "insert into restore_sentinel(tag) values ('pre');"

# ---- Step 2: PITR target = the DATABASE's clock, not the host's -----------
# Clock skew between this script's host and the DB server would silently
# shift the restore target if we used `date`/`$(date -u ...)` here instead.
target="$(source_exec psql -U postgres -d peppercheck -tAc 'select now();' | tr -d '\r')"
log "PITR target (DB clock): $target"

# ---- Step 3: sleep, then post sentinel -------------------------------------
source_exec psql -v ON_ERROR_STOP=1 -U postgres -d peppercheck -c 'select pg_sleep(2);' >/dev/null
source_exec psql -v ON_ERROR_STOP=1 -U postgres -d peppercheck \
  -c "insert into restore_sentinel(tag) values ('post');"

# ---- Step 4: force + confirm the target's WAL segment reached B2 ----------
# pg_switch_wal()'s return value is the START of the NEW segment, not the
# name of the segment being closed -- so the segment name we actually need
# archived (the one containing both sentinel inserts and the target time)
# must be captured from pg_current_wal_lsn() BEFORE switching, not from
# pg_switch_wal()'s own result.
target_wal="$(source_exec psql -U postgres -d peppercheck -tAc \
  'select pg_walfile_name(pg_current_wal_lsn());' | tr -d '\r')"
source_exec psql -v ON_ERROR_STOP=1 -U postgres -d peppercheck -c 'select pg_switch_wal();' >/dev/null
log "waiting for pg_stat_archiver.last_archived_wal to reach $target_wal (i.e. B2 has it)"
elapsed=0
while :; do
  # psql -A (unaligned) renders a NULL column as an empty string, which is
  # exactly what last_archived_wal is before the very first WAL is archived
  # -- no explicit coalesce() needed.
  last_archived="$(source_exec psql -U postgres -d peppercheck -tAc \
    'select last_archived_wal from pg_stat_archiver;' | tr -d '\r')"
  if [ -n "$last_archived" ] && wal_ge "$last_archived" "$target_wal"; then
    log "confirmed: last_archived_wal=$last_archived has reached $target_wal"
    break
  fi
  if [ "$elapsed" -ge "$WAL_POLL_TIMEOUT_SECONDS" ]; then
    echo "restore-drill: timed out after ${WAL_POLL_TIMEOUT_SECONDS}s waiting for $target_wal to be archived (last seen: ${last_archived:-none})" >&2
    exit 1
  fi
  sleep "$WAL_POLL_INTERVAL_SECONDS"
  elapsed=$((elapsed + WAL_POLL_INTERVAL_SECONDS))
done

# RTO is measured from here: the source-side sentinel/WAL bookkeeping above
# is drill instrumentation, not part of a real recovery's critical path --
# the clock that matters is "how long from deciding to restore, to a
# verified-healthy API."
restore_start_epoch=$(date +%s)

# ---- Step 5: empty restore volume, chowned for the pgBackRest UID (999) --
log "creating + chowning empty restore volume $RESTORE_VOLUME"
docker volume create "$RESTORE_VOLUME" >/dev/null
docker run --rm --network none --entrypoint sh \
  -v "${RESTORE_VOLUME}:/var/lib/postgresql/data" \
  "$IMAGE_POSTGRES" -c 'chown -R 999:999 /var/lib/postgresql/data'

# ---- Step 6: the actual PITR restore ---------------------------------------
# --target-action=promote (NOT the pgBackRest default `pause`) is REQUIRED:
# `pause` would leave the restored server sitting in recovery indefinitely,
# unable to accept the write-capable connection the api needs even for a
# read-only /api/v1/me. Uses the RESTORE-SCOPED read-only B2 key, never the
# read-write key `postgres`/`backup` use in production.
log "pgbackrest --type=time --target=\"$target\" --target-action=promote restore"
docker run --rm --user 999 --entrypoint pgbackrest \
  -v "${RESTORE_VOLUME}:/var/lib/postgresql/data" \
  -e PGBACKREST_REPO1_S3_ENDPOINT="$PGBACKREST_REPO1_S3_ENDPOINT" \
  -e PGBACKREST_REPO1_S3_BUCKET="$PGBACKREST_REPO1_S3_BUCKET" \
  -e PGBACKREST_REPO1_S3_REGION="$PGBACKREST_REPO1_S3_REGION" \
  -e PGBACKREST_REPO1_S3_KEY="$b2_key_id" \
  -e PGBACKREST_REPO1_S3_KEY_SECRET="$b2_key_secret" \
  -e PGBACKREST_REPO1_CIPHER_PASS="$pgbackrest_cipher" \
  "$IMAGE_POSTGRES" \
  --stanza=main --type=time --target="$target" --target-action=promote --delta restore

# ---- Step 7: bring up the isolated postgres+api-only stack -----------------
log "bringing up isolated ${RESTORE_PROJECT} (postgres + api only, no worker)"
restore_compose up -d --no-build --wait --wait-timeout "$API_READY_TIMEOUT_SECONDS"

# ---- Step 8: assert PITR correctness: pre present, post absent ------------
log "asserting pre-sentinel present and post-sentinel absent on the restored DB"
counts="$(restore_compose exec -T postgres psql -U postgres -d peppercheck -tAc \
  "select count(*) filter (where tag = 'pre'), count(*) filter (where tag = 'post') from restore_sentinel;" | tr -d '\r')"
pre_count="${counts%|*}"
post_count="${counts#*|}"
if [ "${pre_count:-0}" -lt 1 ] || [ "${post_count:-1}" -ne 0 ]; then
  echo "restore-drill: PITR assertion FAILED (pre=${pre_count:-?} post=${post_count:-?}, want pre>=1 post=0)" >&2
  exit 1
fi
log "PITR assertion OK (pre=$pre_count post=$post_count)"

# ---- Step 9: authenticated smoke test against the restored api ------------
log "obtaining a Firebase test ID token"
# firebase_test_api_key/_email/_password are already in this process's own
# environment (rendered there directly by `bws run`, see the header above)
# and are inherited by the child process below like any other env var --
# no need to re-thread them explicitly.
id_token="$(./scripts/firebase-test-token.sh)"

log "calling GET /api/v1/me on the restored api (127.0.0.1:${RESTORE_API_PORT})"
smoke_status="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 \
  -H "Authorization: Bearer ${id_token}" \
  "http://127.0.0.1:${RESTORE_API_PORT}/api/v1/me")"
unset id_token
if [ "$smoke_status" != "200" ]; then
  echo "restore-drill: authenticated /api/v1/me smoke FAILED (status=$smoke_status)" >&2
  exit 1
fi
smoke_success_epoch=$(date +%s)
log "authenticated /api/v1/me smoke OK"

# ---- Step 10: RTO ----------------------------------------------------------
rto_seconds=$((smoke_success_epoch - restore_start_epoch))
log "RTO: ${rto_seconds}s (target: ${RTO_TARGET_SECONDS}s / 4h)"
if [ "$rto_seconds" -gt "$RTO_TARGET_SECONDS" ]; then
  echo "restore-drill: RTO ${rto_seconds}s EXCEEDS the 4-hour target" >&2
fi

# ---- Step 11: independent logical-dump fallback verification --------------
verify_age_dump_restore

log "restore drill PASSED for ${env} (RTO ${rto_seconds}s)"
# `cleanup` (the EXIT trap) tears everything down from here.
