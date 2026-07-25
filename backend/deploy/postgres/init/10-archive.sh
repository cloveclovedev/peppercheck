#!/bin/bash
# Enables WAL archiving via pgBackRest. Runs once during initdb (only on an
# empty data directory, like 00-roles.sh), appending settings to
# postgresql.auto.conf so they take effect on every subsequent start even
# though this script itself never runs again. Supersedes the Phase 1
# archive-wal.sh script (../archive-wal.sh, now dead -- not wired into
# anything here; a later cleanup task should remove it).
set -euo pipefail

cat >> "$PGDATA/postgresql.auto.conf" <<'EOF'
wal_level = replica
archive_mode = on
archive_command = 'pgbackrest --stanza=main archive-push %p'
archive_timeout = 120s
max_wal_senders = 3
EOF
