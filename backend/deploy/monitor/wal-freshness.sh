#!/bin/sh
# wal-freshness.sh -- multi-signal WAL-archiving freshness check (Phase 7-A
# infra/ops foundation, Task 17, design doc
# docs/superpowers/specs/2026-07-25-phase7a-infra-ops-foundation-design.md
# §8.2/§9). Runs on the HOST (Droplet) via a systemd timer every 2 minutes
# (wal-freshness.timer) and drives `docker exec` into the running
# peppercheck-postgres container to read pg_stat_archiver and pgBackRest
# state as the `postgres` user -- it does not run inside any container
# itself.
#
# *** Why `.ready` files, not the spool, are the backlog signal ***
# pgBackRest here is configured `archive-async=y` (deploy/postgres/pgbackrest
# .conf): the async local process transfers WAL straight from `pg_wal/` to
# the S3 (B2) repo -- the spool directory (`spool-path=/var/spool/
# pgbackrest`) only ever holds small coordination/status files, NEVER a copy
# of WAL bytes. Watching spool size (a natural first instinct) would
# therefore always read ~0 and completely MISS a real backlog. The correct
# un-archived-backlog signal is Postgres's own queue of not-yet-archived
# segments: `pg_wal/archive_status/*.ready` -- one file per WAL segment
# Postgres has switched out of and is waiting for `archive_command` to
# confirm (via a matching `.done`). This script sums the real WAL segment
# file sizes behind each `.ready` marker for backlog bytes, and uses the
# oldest `.ready` file's mtime for backlog age -- both read directly off
# `pg_wal`, never the spool.
#
# *** Why "last_failed_wal newer than last_archived_wal", not "is set" ***
# `pg_stat_archiver.last_failed_wal` is sticky: once a segment fails once, it
# stays in that column even after that exact segment (or every later one)
# has since archived successfully -- Postgres never clears it back to empty
# on its own. Alerting on "last_failed_wal is non-empty" would page forever
# after the FIRST transient failure in the archive's entire history, even
# once everything has long since caught up (a stale, superseded failure).
# The correct signal is whether the failure is UNRECOVERED: last_failed_wal
# is newer (lexicographically greater, for a same-timeline WAL filename)
# than last_archived_wal. If a later last_archived_wal has since superseded
# it, that is NOT an active problem and must NOT alert.
#
# *** Why this isn't enough by itself (the WAL-drop hazard) ***
# When pgBackRest's `archive-push-queue-max` is exceeded, pgBackRest drops
# the oldest queued WAL and returns SUCCESS to Postgres anyway (its
# documented async archive-push queue behavior) so Postgres marks the
# segment archived and removes it from `pg_wal` entirely. That silently
# breaks the PITR chain while leaving BOTH `pg_stat_archiver` (which only
# knows what Postgres was told) and the `.ready` backlog (the segment is
# gone from pg_wal once "archived") looking perfectly healthy -- and
# `last_failed_wal` is never touched either, since there was no failure from
# Postgres's point of view. This script therefore also independently
# verifies pgBackRest's own view of the repo (the B2-confirmed archive max
# from `pgbackrest info`, cross-checked against last_archived_wal), the
# latest-backup age, and persistently detects pgBackRest's own
# queue-exceeded log line -- see the STATE_DIR section below.
set -u

log_err() { echo "wal-freshness: $*" >&2; }

# --- Configuration (env vars; delivered via the systemd unit's
# EnvironmentFile -- see backend/deploy/provision/MONITORING.md) -----------
PC_ENV="${PC_ENV:?PC_ENV is required (staging|production)}"
COMPOSE_PROJECT="${COMPOSE_PROJECT:-peppercheck-${PC_ENV}}"
PGBACKREST_STANZA="${PGBACKREST_STANZA:-main}"
PG_DATABASE="${PG_DATABASE:-peppercheck}"

# archive_timeout is set to 120s in production (deploy/postgres/init/10-
# archive.sh) -- it only bounds how often Postgres SWITCHES a segment, not
# how fast B2 receives it, so headroom is added on top before alerting.
ARCHIVE_TIMEOUT_SECONDS="${ARCHIVE_TIMEOUT_SECONDS:-120}"
WAL_FRESHNESS_HEADROOM_SECONDS="${WAL_FRESHNESS_HEADROOM_SECONDS:-180}"

# Matches pgbackrest.conf's archive-push-queue-max=1GiB. This `.ready`-backlog
# pre-alert is the PRIMARY defense against the WAL-drop hazard: it is the ONE
# signal that fires BEFORE any WAL is dropped (see the header's WAL-drop
# section and the B2-continuity note below for why the post-drop signals
# cannot reliably catch a mid-stream drop). It must therefore fire with
# generous headroom -- well before the 1GiB queue-max is reached -- so the
# operator can react while the queue is merely growing, not once it has
# already overflowed and silently discarded a segment. Default 0.5 (=512MiB)
# deliberately conservative for that reason; raise only with a concrete
# reason.
ARCHIVE_PUSH_QUEUE_MAX_BYTES="${ARCHIVE_PUSH_QUEUE_MAX_BYTES:-1073741824}"
WAL_BACKLOG_ALERT_RATIO="${WAL_BACKLOG_ALERT_RATIO:-0.5}"

# Schedule is weekly full + daily differential (pgbackrest.conf / crontab) --
# 33h gives a full day plus buffer before a missed differential pages.
MAX_BACKUP_AGE_SECONDS="${MAX_BACKUP_AGE_SECONDS:-118800}"

# B2-confirmed-archive-max lag detects a STALLED/BEHIND async transfer: with
# archive-async=y, Postgres's last_archived_wal advances as soon as pgBackRest
# accepts a segment into the local async queue, whereas b2_archive_max (read
# from the real repo via `pgbackrest info`) only advances once the segment
# actually lands in B2 -- so a sustained last_archived_wal > b2_archive_max
# means the local->B2 transfer has fallen behind (network, credential, or
# repo problem). A single observation of lag is normal async catch-up; only
# alert once it persists for this many consecutive runs (default 3 * 2min =
# 6min).
#
# *** What this does NOT catch (documented honestly) ***
# This is a MAX-lag signal, not a CONTINUITY signal. When archive-push-queue-
# max overflows, pgBackRest drops the OLDEST queued segment and keeps pushing
# newer ones, so b2_archive_max advances in lockstep with last_archived_wal
# and this check stays quiet while a GAP sits undetected in the middle of the
# archived range. A true per-segment continuity/gap scan would need to
# enumerate the repo archive (`pgbackrest repo-ls` over the repo's archive
# path) -- `info --output=json` exposes only the range's min/max, never a
# per-segment list or count -- which is fragile to do correctly in shell
# (repo path layout, compression suffixes, WAL-name arithmetic across the
# 256-segments-per-logfile boundary, thousands of segments every 2 minutes)
# and cannot be verified against real pgBackRest output in this environment.
# The mid-stream-drop case is therefore covered by (a) the `.ready`-backlog
# PRE-drop pre-alert above (the primary line -- fires before any drop) and
# (b) the sticky queue-exceeded log-pattern detection below (post-drop
# backstop). See MONITORING.md's "B2 continuity residual" note and the
# hard Task-21 drill requirement.
B2_LAG_ALERT_STREAK="${B2_LAG_ALERT_STREAK:-3}"

# `pgbackrest check` performs a real archive-push/archive-get round trip
# (i.e. forces an extra WAL segment switch) -- valuable per the design doc's
# multi-signal list, but expensive to run every 2 minutes forever. Default
# off; enable once staging/production wiring (Task 22) has a view of the
# added WAL volume this causes, or lower the check cadence to compensate.
WAL_FRESHNESS_RUN_PGBACKREST_CHECK="${WAL_FRESHNESS_RUN_PGBACKREST_CHECK:-false}"

# Best-effort pattern for pgBackRest's queue-overflow WARN log line -- the
# exact wording has NOT been confirmed against a live overflow in this
# environment (see the task report's "unverifiable without real B2"
# section); broad enough to match regardless of exact phrasing/version.
WAL_FRESHNESS_QUEUE_LOG_PATTERN="${WAL_FRESHNESS_QUEUE_LOG_PATTERN:-archive-push-queue-max|queue.*(exceed|full)|discard.*queue|drop.*wal.*queue}"

# Persistent state survives across runs (and across container recreation --
# it is a HOST path, not inside any container). QUEUE_EXCEEDED_STATE_FILE is
# a sticky sentinel: once pgBackRest's own queue-exceeded log line is seen,
# it stays "alerting" until an operator deliberately clears it after
# completing the WAL-drop -> new-full-backup PITR-rebuild runbook (see
# MONITORING.md) -- it must NOT self-clear just because archiving looks
# healthy again, since the PITR chain is still broken until a new full
# backup re-establishes it.
STATE_DIR="${STATE_DIR:-/var/lib/peppercheck-monitor}"
QUEUE_EXCEEDED_STATE_FILE="$STATE_DIR/wal-freshness.queue-exceeded"
B2_LAG_STREAK_FILE="$STATE_DIR/wal-freshness.b2-lag-streak"

# Better Stack heartbeat: pinged ONLY when every signal below is healthy
# (the same ping-on-success pattern as the worker/backup heartbeats). Better
# Stack's own missed-heartbeat alerting is what actually pages when this
# script detects a problem (and stops pinging) or stops running entirely.
# Optional -- and never logged verbatim anywhere, since it carries an auth
# token in the URL.
WAL_FRESHNESS_HEARTBEAT_URL="${WAL_FRESHNESS_HEARTBEAT_URL:-}"

mkdir -p "$STATE_DIR" || { log_err "cannot create STATE_DIR $STATE_DIR"; exit 1; }

for bin in docker jq curl; do
  command -v "$bin" >/dev/null 2>&1 || { log_err "required command not found: $bin"; exit 1; }
done

# --- Resolve the running postgres container by compose labels, not a
# hardcoded name/index -- robust to compose's `<project>-<service>-<n>`
# naming, and this compose project never uses `--scale`. -------------------
postgres_container="$(docker ps -q \
  -f "label=com.docker.compose.project=${COMPOSE_PROJECT}" \
  -f "label=com.docker.compose.service=postgres" | head -n1)"
if [ -z "$postgres_container" ]; then
  log_err "no running postgres container for compose project ${COMPOSE_PROJECT}"
  exit 1
fi

# --- Signal 1+2: pg_stat_archiver + the .ready backlog (bytes + oldest age)
# One docker exec, as the postgres OS user, over the shared unix socket
# (matches pgbackrest.conf's pg1-socket-path). PG_DATABASE is passed via
# `-e` (not spliced into the quoted script text) so it never has to survive
# nested shell-quoting. --------------------------------------------------
archiver_raw="$(docker exec -u postgres -e PG_DATABASE="$PG_DATABASE" "$postgres_container" sh -c '
  set -eu
  data_dir=/var/lib/postgresql/data
  ready_dir="$data_dir/pg_wal/archive_status"
  now=$(date -u +%s)
  count=0
  total_bytes=0
  oldest_epoch=""
  for f in "$ready_dir"/*.ready; do
    [ -e "$f" ] || continue
    count=$((count + 1))
    seg=$(basename "$f" .ready)
    segfile="$data_dir/pg_wal/$seg"
    sz=0
    [ -f "$segfile" ] && sz=$(stat -c %s "$segfile" 2>/dev/null || echo 0)
    total_bytes=$((total_bytes + sz))
    mtime=$(stat -c %Y "$f" 2>/dev/null || echo "$now")
    if [ -z "$oldest_epoch" ] || [ "$mtime" -lt "$oldest_epoch" ]; then
      oldest_epoch=$mtime
    fi
  done
  oldest_age=0
  [ -n "$oldest_epoch" ] && oldest_age=$((now - oldest_epoch))
  echo "ready_count=$count"
  echo "ready_bytes=$total_bytes"
  echo "ready_oldest_age_seconds=$oldest_age"
  # -A -t (unaligned, tuples-only) renders SQL NULL as an empty field, so no
  # coalesce() is needed to get plain "key=" lines for an unset column.
  psql -X -A -t -F"|" -h /var/run/postgresql -U postgres -d "$PG_DATABASE" -c \
    "select last_archived_wal, extract(epoch from last_archived_time)::bigint, last_failed_wal, extract(epoch from last_failed_time)::bigint from pg_stat_archiver;" |
  {
    IFS="|" read -r a b c d
    echo "last_archived_wal=$a"
    echo "last_archived_time=$b"
    echo "last_failed_wal=$c"
    echo "last_failed_time=$d"
  }
')"
archiver_status=$?
if [ "$archiver_status" -ne 0 ] || [ -z "$archiver_raw" ]; then
  log_err "docker exec into $postgres_container for pg_stat_archiver/.ready failed (exit $archiver_status)"
  exit 1
fi

ready_count=0; ready_bytes=0; ready_oldest_age_seconds=0
last_archived_wal=""; last_archived_time=""; last_failed_wal=""; last_failed_time=""
# The inner script emits only `key=value` lines with values we fully
# control (integers, WAL segment hex names, or empty) -- safe to eval.
eval "$(printf '%s\n' "$archiver_raw")"

# --- Signal 3: pgBackRest's own repo view (B2-confirmed archive max,
# latest backup age). Re-derives the S3/cipher creds from the SAME mounted
# secret files postgres's own entrypoint.sh reads (/run/secrets/*) --
# `docker exec` does NOT inherit variables the entrypoint only `export`ed
# into its own shell before `exec`-ing into the postgres server process (a
# process replacement, not a child docker exec descends from); it only sees
# the image's baked-in ENV plus whatever compose's `environment:` block set
# at container-create time. PGBACKREST_REPO1_S3_ENDPOINT/BUCKET/REGION are
# declared there and so ARE already visible via plain env; the S3 key/
# secret and cipher pass are not, hence re-reading them here from the same
# 0444-inside-the-container secret files remote-deploy.sh mounts. ----------
info_json="$(docker exec -e PGBACKREST_STANZA="$PGBACKREST_STANZA" "$postgres_container" sh -c '
  set -eu
  read_secret() { [ -f "$1" ] && tr -d "\n" < "$1"; }
  export PGBACKREST_REPO1_CIPHER_PASS="$(read_secret /run/secrets/pgbackrest_cipher)"
  export PGBACKREST_REPO1_S3_KEY="$(read_secret /run/secrets/b2_key_id)"
  export PGBACKREST_REPO1_S3_KEY_SECRET="$(read_secret /run/secrets/b2_key_secret)"
  pgbackrest --stanza="$PGBACKREST_STANZA" info --output=json
')"
info_status=$?
if [ "$info_status" -ne 0 ] || [ -z "$info_json" ]; then
  log_err "pgbackrest info --output=json failed inside $postgres_container (exit $info_status)"
  b2_archive_max=""
  last_backup_stop_epoch=""
else
  b2_archive_max="$(printf '%s' "$info_json" | jq -r '.[0].archive[-1].max // empty' 2>/dev/null)"
  last_backup_stop_epoch="$(printf '%s' "$info_json" | jq -r '[.[0].backup[]?.timestamp.stop] | if length > 0 then max else empty end' 2>/dev/null)"
fi

pgbackrest_check_ok=1
if [ "$WAL_FRESHNESS_RUN_PGBACKREST_CHECK" = "true" ]; then
  if docker exec -e PGBACKREST_STANZA="$PGBACKREST_STANZA" "$postgres_container" sh -c '
    set -eu
    read_secret() { [ -f "$1" ] && tr -d "\n" < "$1"; }
    export PGBACKREST_REPO1_CIPHER_PASS="$(read_secret /run/secrets/pgbackrest_cipher)"
    export PGBACKREST_REPO1_S3_KEY="$(read_secret /run/secrets/b2_key_id)"
    export PGBACKREST_REPO1_S3_KEY_SECRET="$(read_secret /run/secrets/b2_key_secret)"
    pgbackrest --stanza="$PGBACKREST_STANZA" check
  ' >/dev/null 2>&1; then
    pgbackrest_check_ok=1
  else
    pgbackrest_check_ok=0
  fi
fi

# --- Signal 4: persistently detect pgBackRest's own archive-push-queue-max
# exceeded log line. See WAL_FRESHNESS_QUEUE_LOG_PATTERN above for the
# verification caveat. QUEUE_LOG_PATTERN travels via `-e`, not string
# splicing, so it never has to survive nested shell-quoting. ---------------
if [ ! -f "$QUEUE_EXCEEDED_STATE_FILE" ]; then
  if docker exec -e QUEUE_LOG_PATTERN="$WAL_FRESHNESS_QUEUE_LOG_PATTERN" "$postgres_container" sh -c '
    grep -Eqi "$QUEUE_LOG_PATTERN" /var/log/pgbackrest/*archive-push*.log 2>/dev/null ||
      grep -Eqi "$QUEUE_LOG_PATTERN" /var/log/pgbackrest/*.log 2>/dev/null
  '; then
    date -u +%FT%TZ > "$QUEUE_EXCEEDED_STATE_FILE"
    log_err "DETECTED archive-push-queue-max exceeded in pgBackRest log -- WAL-drop hazard; PITR chain likely broken. See MONITORING.md's WAL-drop -> new-full-backup runbook. This alert is STICKY and will not clear on its own."
  fi
fi
queue_exceeded=0
[ -f "$QUEUE_EXCEEDED_STATE_FILE" ] && queue_exceeded=1

# --- Evaluate alert conditions ---------------------------------------------
now="$(date -u +%s)"
reasons=""
add_reason() { reasons="${reasons:+$reasons,}$1"; }

# 1. Oldest un-archived segment is older than archive_timeout + headroom.
freshness_threshold=$((ARCHIVE_TIMEOUT_SECONDS + WAL_FRESHNESS_HEADROOM_SECONDS))
if [ "${ready_count:-0}" -gt 0 ] && [ "${ready_oldest_age_seconds:-0}" -gt "$freshness_threshold" ]; then
  add_reason "ready_oldest_age_seconds=${ready_oldest_age_seconds} exceeds threshold=${freshness_threshold}"
fi

# 1b. last_archived_time itself stale: complements the .ready-backlog check
# above -- it catches archiving having stalled entirely (e.g. the
# archive_command/archiver silently wedged) even in the degenerate case
# where ready_count is 0 because no new segment has even been queued.
# last_archived_time can legitimately be empty on a brand-new cluster before
# its first archive ever succeeds, so an empty value is informational only,
# not an alert.
if [ -n "$last_archived_time" ]; then
  archived_age=$((now - last_archived_time))
  if [ "$archived_age" -gt "$freshness_threshold" ]; then
    add_reason "last_archived_time age=${archived_age}s exceeds threshold=${freshness_threshold} (no successful archive recently)"
  fi
fi

# 2. last_failed_wal newer than last_archived_wal (lexicographic compare via
# `sort`, since POSIX `test`/`[` has no portable string ">" operator).
str_gt() {
  [ "$1" = "$2" ] && return 1
  [ "$(printf '%s\n%s\n' "$1" "$2" | LC_ALL=C sort | tail -n1)" = "$1" ]
}
if [ -n "$last_failed_wal" ]; then
  if [ -z "$last_archived_wal" ] || str_gt "$last_failed_wal" "$last_archived_wal"; then
    add_reason "unrecovered archive failure: last_failed_wal=${last_failed_wal} last_archived_wal=${last_archived_wal:-<none>}"
  fi
fi

# 3. .ready backlog bytes approaching archive-push-queue-max.
queue_bytes_threshold=$(awk -v m="$ARCHIVE_PUSH_QUEUE_MAX_BYTES" -v r="$WAL_BACKLOG_ALERT_RATIO" 'BEGIN{printf "%d", m*r}')
if [ "${ready_bytes:-0}" -ge "$queue_bytes_threshold" ]; then
  add_reason "ready_bytes=${ready_bytes} at/above ${WAL_BACKLOG_ALERT_RATIO} of archive-push-queue-max=${ARCHIVE_PUSH_QUEUE_MAX_BYTES}"
fi

# 4. Sticky queue-exceeded log detection (cleared only by the runbook).
if [ "$queue_exceeded" -eq 1 ]; then
  add_reason "archive-push-queue-max exceeded previously detected (sticky; see MONITORING.md runbook)"
fi

# 5. B2-confirmed archive max lagging behind last_archived_wal, sustained.
b2_lag_streak=0
[ -f "$B2_LAG_STREAK_FILE" ] && b2_lag_streak="$(cat "$B2_LAG_STREAK_FILE" 2>/dev/null || echo 0)"
b2_lagging=0
if [ -n "$last_archived_wal" ] && [ -n "$b2_archive_max" ] && str_gt "$last_archived_wal" "$b2_archive_max"; then
  b2_lagging=1
  b2_lag_streak=$((b2_lag_streak + 1))
else
  b2_lag_streak=0
fi
echo "$b2_lag_streak" > "$B2_LAG_STREAK_FILE"
if [ "$b2_lagging" -eq 1 ] && [ "$b2_lag_streak" -ge "$B2_LAG_ALERT_STREAK" ]; then
  add_reason "B2-confirmed archive max (${b2_archive_max:-<none>}) lags last_archived_wal (${last_archived_wal}) for ${b2_lag_streak} consecutive checks -- async local->B2 transfer stalled/behind (NOTE: this is a max-lag signal and does not catch a mid-stream drop; see the .ready pre-alert + sticky queue-exceeded backstop)"
fi
[ -z "$info_json" ] && add_reason "pgbackrest info --output=json unavailable"

# 6. Latest-backup age within bounds.
backup_age=""
if [ -n "$last_backup_stop_epoch" ]; then
  backup_age=$((now - last_backup_stop_epoch))
  if [ "$backup_age" -gt "$MAX_BACKUP_AGE_SECONDS" ]; then
    add_reason "latest backup age=${backup_age}s exceeds MAX_BACKUP_AGE_SECONDS=${MAX_BACKUP_AGE_SECONDS}"
  fi
else
  add_reason "no backup found in pgbackrest info (or info unavailable)"
fi

# 7. `pgbackrest check` (opt-in; see WAL_FRESHNESS_RUN_PGBACKREST_CHECK).
if [ "$WAL_FRESHNESS_RUN_PGBACKREST_CHECK" = "true" ] && [ "$pgbackrest_check_ok" -ne 1 ]; then
  add_reason "pgbackrest check failed"
fi

if [ -n "$reasons" ]; then
  status="alert"
  level="error"
else
  status="ok"
  level="info"
fi

# --- Emit one structured JSON line per run (always) + ping the Better
# Stack heartbeat only when healthy (see the header comment for why: this
# turns Better Stack's built-in missed-heartbeat alerting into the actual
# paging mechanism for every condition above, without inventing a bespoke
# payloaded-webhook contract this script cannot fully exercise/verify
# without real B2 -- see the task report). --------------------------------
printf '{"level":"%s","msg":"wal-freshness check","status":"%s","pc_env":"%s","ready_count":%s,"ready_bytes":%s,"ready_oldest_age_seconds":%s,"last_archived_wal":"%s","last_archived_time":%s,"last_failed_wal":"%s","last_failed_time":%s,"b2_archive_max":"%s","b2_lag_streak":%s,"queue_exceeded_sticky":%s,"backup_age_seconds":%s,"reasons":"%s"}\n' \
  "$level" "$status" "$PC_ENV" "${ready_count:-0}" "${ready_bytes:-0}" "${ready_oldest_age_seconds:-0}" \
  "$last_archived_wal" "${last_archived_time:-null}" "$last_failed_wal" "${last_failed_time:-null}" \
  "${b2_archive_max:-}" "$b2_lag_streak" "$queue_exceeded" "${backup_age:-null}" "$reasons"

if [ "$status" = "ok" ]; then
  if [ -n "$WAL_FRESHNESS_HEARTBEAT_URL" ]; then
    curl -fsS "$WAL_FRESHNESS_HEARTBEAT_URL" -o /dev/null || log_err "heartbeat POST failed (non-fatal)"
  fi
  exit 0
fi

exit 1
