#!/usr/bin/env bash
# rollback.sh <env>
#
# Installed at /opt/peppercheck/scripts/rollback.sh by bootstrap (Task 11).
# Invoked two ways:
#   - smoke-or-rollback.sh (Task 8), over SSH from the CI runner, immediately
#     after a failed post-deploy smoke test:
#       ssh -i ~/.ssh/id deploy@<ssh_host> '/opt/peppercheck/scripts/rollback.sh' <env>
#   - directly by an operator on the Droplet during an incident.
#
# Repoints `current` back to whatever release it pointed at before the LAST
# switch-deployment.sh call (recorded in `previous`), then brings that
# release's compose project back up. Deliberately does NOT re-run migrations
# or a GHCR login/pull: the previous release's images are already local
# (they were running until the failed deploy's switch-deployment.sh moved
# `current` away from them), so a rollback must not depend on network access
# to GHCR to recover -- see remote-deploy.sh for the full
# login+pull+migrate+switch sequence a normal deploy uses instead.
set -euo pipefail

env="${1:?usage: rollback.sh <env>}"

base="/opt/peppercheck"
project="peppercheck-${env}"

cd "$base"

if [ ! -f previous ]; then
  echo "rollback: no previous deployment recorded in $base/previous -- nothing to roll back to" >&2
  exit 1
fi

prior_id="$(cat previous)"

# Reuses switch-deployment.sh's own atomic-swap + validation logic (Task 6)
# rather than re-implementing it: calling it with the prior id both repoints
# `current` -> deployments/<prior_id> and records the release being rolled
# back AWAY FROM into `previous` -- so a second, mistaken rollback call
# toggles back to the release that just failed rather than doing anything
# unsafe.
"$base/scripts/switch-deployment.sh" "$prior_id"

d="$base/current"

# compose.prod.yaml's top-level `name: peppercheck-${PC_ENV:?...}` and every
# service's IMAGE_* / non-secret vars must resolve exactly as they did for
# the original deploy of this release -- see remote-deploy.sh for the same
# export + `set -a; source images.env; set +a` pattern.
export PC_ENV="$env"
set -a
# shellcheck source=/dev/null
source "$d/images.env"
set +a

docker compose -p "$project" -f "$d/compose.prod.yaml" up -d --no-build --wait

echo "rollback: $project is back on deployments/$prior_id"
