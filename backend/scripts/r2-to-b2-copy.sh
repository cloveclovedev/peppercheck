#!/usr/bin/env bash
# r2-to-b2-copy.sh
#
# Disabled skeleton for the daily R2 -> B2 off-site copy of delivery objects.
# R2 does not hold delivery objects yet, so there is nothing to copy today. A
# cron/systemd timer can already invoke this script without effect --
# it must be a true no-op (exit 0), never a failure, so an early/misconfigured
# invocation never pages.
#
# Once delivery-object storage lands, flip R2_BACKUP_ENABLED=true and supply
# the R2/B2 variables the enabled body reads below.
set -euo pipefail

if [ "${R2_BACKUP_ENABLED:-false}" != "true" ]; then
  echo '{"level":"info","msg":"R2->B2 copy disabled (R2_BACKUP_ENABLED not true)"}'
  exit 0
fi

# R2 (source) and B2 (destination) connection details. Left
# unimplemented on purpose -- the actual bucket/prefix names and credential
# wiring depend on how delivery objects are issued. Fail closed rather
# than silently skipping if someone flips R2_BACKUP_ENABLED=true before these
# are wired up.
: "${R2_BUCKET:?R2_BUCKET (source R2 bucket holding delivery objects) is required when R2_BACKUP_ENABLED=true}"
: "${B2_BUCKET:?B2_BUCKET (destination B2 bucket for the off-site copy) is required when R2_BACKUP_ENABLED=true}"
B2_PREFIX="${B2_PREFIX:-r2-mirror}"

# rclone remotes for R2 (source) and B2 (destination) are expected to
# already be configured via RCLONE_CONFIG_* env vars, mirroring the pattern
# deploy/backup/backup.sh uses for its own B2 upload -- see that script's
# RCLONE_CONFIG_AGEDUMP_* block for why env-var remotes are used instead of an
# inline `:s3,...:` connection string (colon-containing values misparse).
# `rclone copy` mirrors additively (skips objects already present at the
# destination) rather than `sync`, so this never deletes anything from B2.
echo '{"level":"info","msg":"R2->B2 copy start"}'
rclone copy "R2:${R2_BUCKET}" "B2:${B2_BUCKET}/${B2_PREFIX}"
echo '{"level":"info","msg":"R2->B2 copy done"}'
