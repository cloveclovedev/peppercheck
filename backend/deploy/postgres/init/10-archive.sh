#!/bin/bash
# Enables WAL archiving via pgBackRest. Runs once during initdb (only on an
# empty data directory, like 00-roles.sh), appending settings to
# postgresql.auto.conf so they take effect on every subsequent start even
# though this script itself never runs again. Baked into the custom
# `peppercheck-postgres` image (deploy/postgres/Dockerfile) that
# compose.prod.yaml runs, so production/staging archive straight to
# pgBackRest/B2.
#
# ../archive-wal.sh is NOT dead: it is still the archive_command wired into
# the local dev stack (compose.yaml's `command:` passes explicit
# `-c archive_mode=on -c archive_command=/usr/local/bin/archive-wal.sh %p %f`
# command-line flags, which take precedence over this script's
# postgresql.auto.conf entries -- see PostgreSQL's parameter-precedence
# rules). Converging dev onto the same pgBackRest-based archiving as prod
# (and then removing archive-wal.sh) is a tracked follow-up, not done here.
#
# `make test`'s throwaway Postgres (Makefile `test` target) has no such
# command-line override, so it inherits this script's archive_mode=on +
# pgbackrest archive-push from postgresql.auto.conf on a stock postgres:17
# image with no pgbackrest binary -- the Makefile passes
# `-c archive_mode=off` on that container's command line to suppress the
# resulting (non-fatal) archive_command failure noise; see the `test` target.
set -euo pipefail

cat >> "$PGDATA/postgresql.auto.conf" <<'EOF'
wal_level = replica
archive_mode = on
archive_command = 'pgbackrest --stanza=main archive-push %p'
archive_timeout = 120s
max_wal_senders = 3
EOF
