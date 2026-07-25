#!/bin/sh
# host-checks.sh -- host-level checks that DigitalOcean Monitoring does NOT
# cover (Phase 7-A infra/ops foundation, Task 17, design doc §9): inode
# exhaustion and Docker container crash-loop detection. Runs on the HOST
# (Droplet) via a systemd timer every 5 minutes (host-checks.timer).
#
# - inode usage: `df -i` -- DO Monitoring tracks disk BYTES, not inode
#   count, so a directory tree with very many small files (e.g. runaway log
#   rotation, a stuck temp-file loop) can exhaust inodes and take the host
#   down while byte-based disk alerts stay quiet.
# - container restarts: summed `docker inspect -f '{{.RestartCount}}'`
#   across every container in this compose project. RestartCount is
#   cumulative since each container was last (re)created -- since every
#   deploy recreates every service's container (`docker compose up -d`
#   after a digest-pinned image change, see scripts/remote-deploy.sh), a
#   nonzero sum reliably means a crash-loop restart (`restart: unless-
#   stopped`) SINCE the last successful deploy, not stale history from
#   weeks ago.
set -u

log_err() { echo "host-checks: $*" >&2; }

# --- Configuration (env vars; delivered via the systemd unit's
# EnvironmentFile -- see backend/deploy/provision/MONITORING.md) -----------
PC_ENV="${PC_ENV:?PC_ENV is required (staging|production)}"
COMPOSE_PROJECT="${COMPOSE_PROJECT:-peppercheck-${PC_ENV}}"

# The filesystem to check inode usage on. Everything (postgres data, WAL,
# Docker's own storage) lives on the single root volume on this deploy
# ladder rung (design doc §7, "app and DB may share one host initially") --
# override if a separate data volume is ever mounted.
INODE_CHECK_PATH="${INODE_CHECK_PATH:-/}"
INODE_ALERT_THRESHOLD_PERCENT="${INODE_ALERT_THRESHOLD_PERCENT:-85}"

# A crash-loop is any nonzero restart count since the last deploy; a small
# nonzero allowance avoids paging on a single incidental restart (e.g. an
# OOM kill during a brief memory spike that then ran fine).
RESTART_COUNT_ALERT_THRESHOLD="${RESTART_COUNT_ALERT_THRESHOLD:-3}"

# Better Stack heartbeat: pinged ONLY when every signal below is healthy
# (same ping-on-success pattern as the other Phase 7-A monitors). Optional,
# and never logged verbatim (it carries an auth token in the URL).
HOST_CHECKS_HEARTBEAT_URL="${HOST_CHECKS_HEARTBEAT_URL:-}"

command -v docker >/dev/null 2>&1 || { log_err "required command not found: docker"; exit 1; }
command -v curl >/dev/null 2>&1 || { log_err "required command not found: curl"; exit 1; }

reasons=""
add_reason() { reasons="${reasons:+$reasons,}$1"; }

# --- Inode usage -------------------------------------------------------
# `df -iP` gives POSIX-portable single-line-per-filesystem output with fixed
# columns `Filesystem Inodes IUsed IFree IUse% Mounted-on` -- IUse% is field
# 5 (verified against real Linux/coreutils df; NOT field 6, which is
# "Mounted"/the start of the mount point). The value ends in a literal "%",
# stripped before the numeric compare.
inode_line="$(df -iP "$INODE_CHECK_PATH" 2>/dev/null | tail -n1)"
if [ -z "$inode_line" ]; then
  log_err "df -iP $INODE_CHECK_PATH produced no output"
  inode_used_percent=""
  add_reason "df -iP $INODE_CHECK_PATH failed"
else
  inode_used_percent="$(echo "$inode_line" | awk '{ print $5 }' | tr -d '%')"
  if [ -z "$inode_used_percent" ]; then
    add_reason "could not parse inode usage from: $inode_line"
  elif [ "$inode_used_percent" -ge "$INODE_ALERT_THRESHOLD_PERCENT" ]; then
    add_reason "inode usage ${inode_used_percent}% at/above threshold ${INODE_ALERT_THRESHOLD_PERCENT}% on ${INODE_CHECK_PATH}"
  fi
fi

# --- Container restart counts -------------------------------------------
container_ids="$(docker ps -a -q -f "label=com.docker.compose.project=${COMPOSE_PROJECT}")"
if [ -z "$container_ids" ]; then
  add_reason "no containers found for compose project ${COMPOSE_PROJECT}"
  total_restarts=0
  container_detail=""
else
  total_restarts=0
  container_detail=""
  for cid in $container_ids; do
    name="$(docker inspect -f '{{.Name}}' "$cid" 2>/dev/null | sed 's#^/##')"
    count="$(docker inspect -f '{{.RestartCount}}' "$cid" 2>/dev/null)"
    case "$count" in
      '' | *[!0-9]*)
        log_err "could not read RestartCount for container $cid ($name)"
        continue
        ;;
    esac
    total_restarts=$((total_restarts + count))
    container_detail="${container_detail:+$container_detail,}${name:-$cid}=${count}"
  done
  if [ "$total_restarts" -ge "$RESTART_COUNT_ALERT_THRESHOLD" ]; then
    add_reason "summed container RestartCount=${total_restarts} at/above threshold=${RESTART_COUNT_ALERT_THRESHOLD} (${container_detail})"
  fi
fi

if [ -n "$reasons" ]; then
  status="alert"
  level="error"
else
  status="ok"
  level="info"
fi

printf '{"level":"%s","msg":"host checks","status":"%s","pc_env":"%s","inode_used_percent":"%s","container_restart_total":%s,"container_restart_detail":"%s","reasons":"%s"}\n' \
  "$level" "$status" "$PC_ENV" "${inode_used_percent:-}" "$total_restarts" "$container_detail" "$reasons"

if [ "$status" = "ok" ]; then
  if [ -n "$HOST_CHECKS_HEARTBEAT_URL" ]; then
    curl -fsS "$HOST_CHECKS_HEARTBEAT_URL" -o /dev/null || log_err "heartbeat POST failed (non-fatal)"
  fi
  exit 0
fi

exit 1
