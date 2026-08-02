#!/usr/bin/env bash
# r2-to-b2-copy.sh
#
# Disabled skeleton for the Phase 4 daily R2 -> B2 off-site copy of delivery
# objects (docs/designs/2026-07-25-phase7a-infra-ops-foundation-design.md).
# Phase 7-A ships only the guard: R2 doesn't hold any delivery objects yet
# (that lands in Phase 4), so there's nothing to copy today. A cron/systemd
# timer can already be wired to invoke this script in 7-A without effect --
# it must be a true no-op (exit 0), never a failure, so an early/misconfigured
# invocation never pages.
#
# Once Phase 4 lands, flip R2_BACKUP_ENABLED=true and supply the R2/B2
# variables the enabled body reads below.
set -euo pipefail

if [ "${R2_BACKUP_ENABLED:-false}" != "true" ]; then
  echo '{"level":"info","msg":"R2->B2 copy disabled (R2_BACKUP_ENABLED not true); enabled in Phase 4"}'
  exit 0
fi

# Phase 4: R2 (source) and B2 (destination) connection details. Left
# unimplemented on purpose -- the actual bucket/prefix names and credential
# wiring depend on how Phase 4 issues R2 delivery objects. Fail closed rather
# than silently skipping if someone flips R2_BACKUP_ENABLED=true before these
# are wired up.
: "${R2_BUCKET:?Phase 4: R2_BUCKET (source R2 bucket holding delivery objects) is required when R2_BACKUP_ENABLED=true}"
: "${B2_BUCKET:?Phase 4: B2_BUCKET (destination B2 bucket for the off-site copy) is required when R2_BACKUP_ENABLED=true}"
B2_PREFIX="${B2_PREFIX:-r2-mirror}"

# Phase 4: rclone remotes for R2 (source) and B2 (destination) are expected to
# already be configured via RCLONE_CONFIG_* env vars, mirroring the pattern
# deploy/backup/backup.sh uses for its own B2 upload -- see that script's
# RCLONE_CONFIG_AGEDUMP_* block for why env-var remotes are used instead of an
# inline `:s3,...:` connection string (colon-containing values misparse).
# `rclone copy` mirrors additively (skips objects already present at the
# destination) rather than `sync`, so this never deletes anything from B2.
echo '{"level":"info","msg":"R2->B2 copy start"}'
rclone copy "R2:${R2_BUCKET}" "B2:${B2_BUCKET}/${B2_PREFIX}"
echo '{"level":"info","msg":"R2->B2 copy done"}'
