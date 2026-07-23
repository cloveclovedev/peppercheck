#!/bin/sh
# Local backup skeleton: takes an age-encrypted, verified logical dump on startup
# and then every BACKUP_INTERVAL_SECONDS. Continuous WAL archiving (postgres
# archive_mode) provides the PITR/RPO mechanism separately. Off-site upload (B2)
# and physical base backups are added in Phase 7.
set -eu

: "${AGE_RECIPIENT:?AGE_RECIPIENT (age public key) is required}"
INTERVAL="${BACKUP_INTERVAL_SECONDS:-86400}"
mkdir -p /backups

run_backup() {
  ts=$(date -u +%Y%m%dT%H%M%SZ)
  tmp="/backups/.dump-${ts}.dump.tmp"       # dot-prefixed: not a published artifact
  enc="/backups/.dump-${ts}.dump.age.tmp"
  final="/backups/dump-${ts}.dump.age"
  echo "{\"level\":\"info\",\"msg\":\"logical backup start\",\"ts\":\"$ts\"}"
  # 1) dump to a temp file (no pipe, so a pg_dump failure aborts here)
  pg_dump -h "$PGHOST" -U "$PGUSER" -d "$PGDATABASE" -Fc -f "$tmp"
  # 2) verify it is a valid custom-format archive before trusting it
  pg_restore -l "$tmp" >/dev/null
  # 3) encrypt, then 4) atomically publish; only now does dump-*.age exist
  age -r "$AGE_RECIPIENT" -o "$enc" "$tmp"
  mv "$enc" "$final"
  rm -f "$tmp"
  echo "{\"level\":\"info\",\"msg\":\"logical backup done\",\"file\":\"dump-${ts}.dump.age\"}"
}

# Startup run: fail loudly (set -e) if the very first backup cannot be taken.
run_backup
while true; do
  sleep "$INTERVAL"
  if ! run_backup; then
    echo "{\"level\":\"error\",\"msg\":\"logical backup failed\"}"
    rm -f /backups/.dump-*.tmp /backups/.dump-*.age.tmp 2>/dev/null || true
  fi
done
