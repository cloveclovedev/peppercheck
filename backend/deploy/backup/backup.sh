#!/bin/sh
# Local backup skeleton: takes an age-encrypted, verified logical dump on startup
# and then every BACKUP_INTERVAL_SECONDS. Continuous WAL archiving (postgres
# archive_mode) provides the PITR/RPO mechanism separately. Off-site upload (B2)
# and physical base backups are added in Phase 7.
set -eu

: "${AGE_RECIPIENT:?AGE_RECIPIENT (age public key) is required}"
INTERVAL="${BACKUP_INTERVAL_SECONDS:-86400}"
mkdir -p /backups

cleanup_temps() {
  rm -f /backups/.dump-*.tmp /backups/.dump-*.age.tmp 2>/dev/null || true
}

# Each step guards with `|| return 1` so a failure aborts the backup regardless
# of `set -e`: POSIX/busybox-ash disable `set -e` inside a function called from a
# tested context (`if ! run_backup`), so relying on it would let a failed pg_dump
# slip past the pg_restore verify and publish a corrupt artifact.
run_backup() {
  ts=$(date -u +%Y%m%dT%H%M%SZ)
  tmp="/backups/.dump-${ts}.dump.tmp"       # dot-prefixed: not a published artifact
  enc="/backups/.dump-${ts}.dump.age.tmp"
  final="/backups/dump-${ts}.dump.age"
  echo "{\"level\":\"info\",\"msg\":\"logical backup start\",\"ts\":\"$ts\"}"
  pg_dump -h "$PGHOST" -U "$PGUSER" -d "$PGDATABASE" -Fc -f "$tmp" || return 1
  pg_restore -l "$tmp" >/dev/null || return 1   # verify it is a valid archive
  age -r "$AGE_RECIPIENT" -o "$enc" "$tmp" || return 1
  mv "$enc" "$final" || return 1                 # atomic publish; only now does dump-*.age exist
  rm -f "$tmp"
  echo "{\"level\":\"info\",\"msg\":\"logical backup done\",\"file\":\"dump-${ts}.dump.age\"}"
}

# Startup run: fail loudly if the very first backup cannot be taken.
if ! run_backup; then
  echo "{\"level\":\"error\",\"msg\":\"initial logical backup failed\"}"
  cleanup_temps
  exit 1
fi

while true; do
  sleep "$INTERVAL"
  if ! run_backup; then
    echo "{\"level\":\"error\",\"msg\":\"logical backup failed\"}"
    cleanup_temps
  fi
done
