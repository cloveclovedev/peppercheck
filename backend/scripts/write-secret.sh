#!/usr/bin/env bash
# Validates a secret name and writes stdin to the deploy-owned staging dir
# (Task 6, Phase 7-A infra/ops foundation -- design doc §6.1/§6.5).
#
# Run as the `deploy` user during a deploy. `deploy` -- already
# root-equivalent via the docker group (§6.5) -- is trusted to write these
# files, but the *name* still comes from the deploy workflow over SSH, so it
# is validated against an exact allowlist (a `case` of literal names only --
# no globs, no `..`, no `/`) before it ever touches a path. The written file
# is owned by `deploy` and left world-unreadable (umask 077); re-owning it to
# the consuming container's UID happens later, in a throwaway root container
# (Task 10) -- this script never runs as root and never chowns.
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: write-secret.sh <name>" >&2
  exit 1
fi

name="$1"

# Exact allowlist -- must stay in sync with compose.prod.yaml's `secrets:`
# block (Task 5) plus `ghcr_token` (used for the GHCR pull login, Task 10).
# Every branch is a literal string; none of these patterns contain glob
# metacharacters, so this only ever matches an exact name.
case "$name" in
  database_url | \
  postgres_superuser_pw | \
  postgres_app_pw | \
  postgres_migrator_pw | \
  postgres_backup_pw | \
  migrator_database_url | \
  pgbackrest_cipher | \
  b2_key_id | \
  b2_key_secret | \
  ghcr_token)
    ;;
  *)
    echo "write-secret: '$name' is not an allowlisted secret name" >&2
    exit 1
    ;;
esac

: "${DEPLOY_SECRET_DIR:?DEPLOY_SECRET_DIR is required}"

umask 077
mkdir -p "$DEPLOY_SECRET_DIR"

# Write to a temp file in the same dir (so the later `mv` is a same-filesystem
# rename, i.e. atomic) and only replace the real path on full success -- a
# reader can never observe a partially-written secret file.
tmp="$(mktemp "$DEPLOY_SECRET_DIR/.${name}.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

cat > "$tmp"
mv -f "$tmp" "$DEPLOY_SECRET_DIR/$name"
