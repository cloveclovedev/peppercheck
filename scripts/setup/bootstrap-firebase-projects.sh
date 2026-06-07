#!/usr/bin/env bash
# Idempotently create the two non-production Firebase projects used by
# the multi-environment setup roadmap.
#
# Usage: scripts/setup/bootstrap-firebase-projects.sh
# Pre-req: `firebase login` and `jq` on PATH.
#
# Does NOT touch the existing production project `peppercheck`.
# Spark plan is sufficient — no Blaze prompt.

set -euo pipefail

command -v firebase >/dev/null || { echo "ERROR: firebase CLI not installed" >&2; exit 1; }
command -v jq >/dev/null || { echo "ERROR: jq not installed" >&2; exit 1; }

PROJECTS=(
  "peppercheck-dev:peppercheck-dev"
  "peppercheck-staging:peppercheck-staging"
)

existing="$(firebase projects:list --json | jq -r '.result[].projectId')"

for entry in "${PROJECTS[@]}"; do
  project_id="${entry%%:*}"
  display_name="${entry##*:}"

  if grep -qx "$project_id" <<< "$existing"; then
    echo "[skip] $project_id already exists"
  else
    echo "[create] $project_id ($display_name)"
    firebase projects:create "$project_id" --display-name "$display_name"
  fi
done

echo
echo "Done. Spark plan is sufficient for FCM + Crashlytics + Performance + Analytics."
echo "Run scripts/setup/register-firebase-apps.sh {dev|staging|production} next."
