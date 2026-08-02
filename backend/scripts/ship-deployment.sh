#!/usr/bin/env bash
# ship-deployment.sh <env> <ssh_host> <sha> <run_id> <manifest>
#
# Run from the CI runner (deploy-vps.yml) via
# `bws run -- ./backend/scripts/ship-deployment.sh ...` -- so every
# `${secret_name}` referenced below already exists in this process's
# environment, rendered by bws immediately before this script starts (and
# masked in the workflow log by `bws run` itself). This script never writes
# a secret value to the runner's own disk: each one is piped straight over
# SSH into write-secret.sh's stdin.
#
#   env      = staging|production -- rendered into images.env as PC_ENV
#              (compose.prod.yaml's `name:` and every service's `APP_ENV`)
#   ssh_host = tailnet MagicDNS name/IP -- SSH only; ufw allows port 22 on
#              the tailscale0 interface alone, so the public `host` input
#              can never be reached over SSH (see deploy-vps.yml)
#   sha      = validated source commit SHA
#   run_id   = ${{ github.run_id }} -- combined with sha, this is the
#              deployment id: /opt/peppercheck/deployments/<sha>-<run_id>/
#   manifest = path to the oras-pulled, digest-verified peppercheck-release
#              manifest.json (deploy-vps.yml's "Pull + verify release
#              manifest by digest" step), e.g. m/manifest.json
#
# Uses the same SSH identity the calling workflow's "Set up SSH + pinned
# host key" step wrote to ~/.ssh/id (see .github/workflows/deploy-vps.yml).
#
# Non-secret compose vars: compose.prod.yaml `${VAR:?...}`-requires several
# vars that are NOT secrets (S3 endpoint/bucket/region, the age public
# recipient key, the public Caddy domain, the API port, the Firebase project
# ID) -- see deploy-vps.yml's "Render secrets + ship deployment" step env
# block, which exports these from `inputs.*`/`vars.*` (GitHub Actions
# Environment non-secret vars) into this script's environment. Rendering
# them into images.env here (which remote-deploy.sh sources with `set -a`
# before every `docker compose` invocation) is what lets
# compose.prod.yaml resolve at all on the Droplet -- without this, the very
# first `compose pull` in remote-deploy.sh would fail closed on an unset
# `${VAR:?...}`.
set -euo pipefail

env="${1:?usage: ship-deployment.sh <env> <ssh_host> <sha> <run_id> <manifest>}"
ssh_host="${2:?usage: ship-deployment.sh <env> <ssh_host> <sha> <run_id> <manifest>}"
sha="${3:?usage: ship-deployment.sh <env> <ssh_host> <sha> <run_id> <manifest>}"
run_id="${4:?usage: ship-deployment.sh <env> <ssh_host> <sha> <run_id> <manifest>}"
man="${5:?usage: ship-deployment.sh <env> <ssh_host> <sha> <run_id> <manifest>}"

id="${sha}-${run_id}"
d="/opt/peppercheck/deployments/${id}"

ssh_cmd=(ssh -i ~/.ssh/id)

"${ssh_cmd[@]}" "deploy@${ssh_host}" "mkdir -p '${d}/secrets'"

# Release files (compose.prod.yaml, migrations/, deploy/caddy/Caddyfile,
# scripts/) matching the validated $sha, staged into the deployment dir
# BEFORE images.env/secrets so remote-deploy.sh finds a complete release the
# moment it starts. images.env and secrets/* are rendered at deploy time and
# are not part of the repo (both gitignored, see backend/.gitignore), so
# rsync without `--delete` never touches them.
rsync -a -e "${ssh_cmd[*]}" backend/ "deploy@${ssh_host}:${d}/"

# Digest-pinned image refs from the verified release manifest (full
# immutable GHCR/Docker Hub references, verbatim) plus the non-secret
# compose vars listed above -- written in one shot so the Droplet never
# observes a partially-written images.env.
{
  for kv in "BACKEND backend" "POSTGRES postgres" "BACKUP backup" "ATLAS atlas" "CADDY caddy"; do
    # shellcheck disable=SC2086 # intentional word-splitting of the "NAME field" pair
    set -- $kv
    echo "IMAGE_$1=$(jq -r ".$2" "$man")"
  done
  echo "PC_ENV=${env}"
  echo "CADDY_SITE_ADDRESS=${CADDY_SITE_ADDRESS:?missing CADDY_SITE_ADDRESS}"
  echo "API_PORT=${API_PORT:?missing API_PORT}"
  echo "FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID:?missing FIREBASE_PROJECT_ID}"
  echo "PGBACKREST_REPO1_S3_ENDPOINT=${PGBACKREST_REPO1_S3_ENDPOINT:?missing PGBACKREST_REPO1_S3_ENDPOINT}"
  echo "PGBACKREST_REPO1_S3_BUCKET=${PGBACKREST_REPO1_S3_BUCKET:?missing PGBACKREST_REPO1_S3_BUCKET}"
  echo "PGBACKREST_REPO1_S3_REGION=${PGBACKREST_REPO1_S3_REGION:?missing PGBACKREST_REPO1_S3_REGION}"
  echo "AGE_RECIPIENT=${AGE_RECIPIENT:?missing AGE_RECIPIENT}"
} | "${ssh_cmd[@]}" "deploy@${ssh_host}" "cat > '${d}/images.env'"

# GHCR login is NOT done here -- ghcr_token ships as a 0400 secret below and
# is consumed inside remote-deploy.sh with a scoped DOCKER_CONFIG (never on a
# command line or in the deploy user's real ~/.docker/config.json).
#
# Every secret value is piped directly into write-secret.sh's stdin over
# SSH -- it never touches a file, an argv, or an intermediate shell variable
# expansion on the Droplet side, and `${!k}` here reads it straight out of
# this process's own environment (populated by `bws run`, never echoed).
# Ownership to the consuming container's UID happens later, in remote-deploy
# .sh's throwaway root container -- this script only ever
# writes deploy-owned, 0600 files via write-secret.sh.
for k in database_url postgres_superuser_pw postgres_app_pw postgres_migrator_pw \
  postgres_backup_pw migrator_database_url pgbackrest_cipher b2_key_id b2_key_secret ghcr_token; do
  printf '%s' "${!k:?missing $k}" |
    "${ssh_cmd[@]}" "deploy@${ssh_host}" "DEPLOY_SECRET_DIR='${d}/secrets' /opt/peppercheck/scripts/write-secret.sh '$k'"
done

echo "ship-deployment: shipped ${id} to ${ssh_host}"
