#!/usr/bin/env bash
# smoke-or-rollback.sh <host> <ssh_host> <env>
#
# Run from the CI runner (deploy-vps.yml, Phase 7-A Task 8) immediately after
# remote-deploy.sh has switched traffic to the new release.
#
#   host     = public domain -- curl https://<host>/readyz
#   ssh_host = tailnet MagicDNS name/IP -- SSH only; ufw allows port 22 on
#              the tailscale0 interface alone, so the public host can never
#              be reached over SSH
#   env      = staging|production, forwarded to rollback.sh (Task 10) for
#              its fixed peppercheck-<env> Compose project name
#
# Uses the same SSH identity the calling workflow's "Set up SSH + pinned
# host key" step wrote to ~/.ssh/id (see .github/workflows/deploy-vps.yml).
#
# Exit status: 0 only if /readyz was healthy. Any other path (readyz failed,
# whether or not the rollback itself succeeds) exits non-zero, so the deploy
# workflow always reports the underlying deploy as failed even when the
# Droplet was safely rolled back.
set -euo pipefail

host="${1:?usage: smoke-or-rollback.sh <host> <ssh_host> <env>}"
ssh_host="${2:?usage: smoke-or-rollback.sh <host> <ssh_host> <env>}"
env="${3:?usage: smoke-or-rollback.sh <host> <ssh_host> <env>}"

if curl -fsS "https://$host/readyz"; then
  echo "smoke: https://$host/readyz is healthy"
  exit 0
fi

echo "smoke: https://$host/readyz failed -- rolling back $env on $ssh_host" >&2
ssh -i ~/.ssh/id "deploy@$ssh_host" '/opt/peppercheck/scripts/rollback.sh' "$env"
exit 1
