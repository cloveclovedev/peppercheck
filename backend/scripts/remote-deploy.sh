#!/usr/bin/env bash
# remote-deploy.sh -- runs ON THE DROPLET as the `deploy` user, piped in by
# the deploy-vps.yml reusable workflow:
#
#   ssh -i ~/.ssh/id deploy@<ssh_host> 'bash -s' "<env>" "<sha>-<run_id>" \
#     < backend/scripts/remote-deploy.sh
#
# Args (positional, arrive via `bash -s <arg1> <arg2>`):
#   $1 = env   -- staging|production; also compose.prod.yaml's PC_ENV
#   $2 = id    -- <sha>-<run_id>; deployments/<id> was staged under
#                 /opt/peppercheck by ship-deployment.sh BEFORE
#                 this script runs (release files, images.env, and
#                 deploy-owned secret files are already in place).
#
# Ordering is load-bearing (see the three security notes inline below):
#   scoped GHCR login -> pull -> chown secrets to consumer UIDs (root
#   container, no network) -> migrate (gate) -> switch-deployment -> up -d.
set -euo pipefail

env="${1:?usage: remote-deploy.sh <env> <id>}"
id="${2:?usage: remote-deploy.sh <env> <id>}"

base="/opt/peppercheck"
d="$base/deployments/$id"
project="peppercheck-$env"

# compose.prod.yaml's top-level `name: peppercheck-${PC_ENV:?...}` is
# interpolated unconditionally at parse time, even though the -p flag below
# is what actually fixes every invocation's project name -- so PC_ENV must
# always be exported or `docker compose` fails before doing anything.
export PC_ENV="$env"

# Digest-pinned image refs for this exact release, written by
# ship-deployment.sh from the verified release manifest:
# IMAGE_BACKEND / IMAGE_POSTGRES / IMAGE_BACKUP / IMAGE_ATLAS / IMAGE_CADDY.
# `set -a` marks every var images.env assigns (plain KEY=value lines, no
# `export`) for export -- `docker compose` below is a separate process and
# only sees ${IMAGE_POSTGRES} etc. via its own environment, not via bash's
# in-process variable table, so without this the compose calls below would
# fail their compose.prod.yaml `:?`-required checks.
set -a
# shellcheck source=/dev/null
source "$d/images.env"
set +a

compose() {
  # Fixed Compose project name on every invocation, per the task interface
  # (never let a stray `docker compose` in this script guess a project name
  # from the current directory).
  docker compose -p "$project" -f "$d/compose.prod.yaml" "$@"
}

# --- 1. Scoped GHCR login -------------------------------------------------
# `DOCKER_CONFIG` points at a throwaway tmpdir for the lifetime of this
# script, so the GHCR pull token never lands in the deploy user's real
# ~/.docker/config.json. The trap runs on every exit path (success, a failed
# migrate, etc.) so the token and its temp config dir never linger.
DOCKER_CONFIG=$(mktemp -d)
export DOCKER_CONFIG
trap 'docker logout ghcr.io; rm -rf "$DOCKER_CONFIG"' EXIT

docker login ghcr.io -u cloveclovedev --password-stdin < "$d/secrets/ghcr_token"

# Pull every image this release needs, including the profiled `migrate`
# service's Atlas image, so nothing is fetched lazily later in the sequence.
compose --profile deploy pull

# --- 2. Secret ownership via a throwaway root container -------------------
# Runs AFTER the pull above, using the digest-pinned postgres image that is
# now guaranteed local (`--pull never`) and with `--network none` -- so no
# unpinned, mutable, or networked helper (e.g. a floating `alpine` tag) ever
# touches the plaintext secrets, and there is no network path out while they
# are mounted.
#
# UID mapping (matches compose.prod.yaml's consumers and the secret allowlist):
#   database_url / web_form_signing_key / firebase_service_account -> 65532 (Go `nonroot`, api/worker)
#   postgres_* / pgbackrest_cipher / b2_key_id / b2_key_secret -> 999 (postgres image's `postgres` user)
#   migrator_database_url                                   -> 0 (root -- the Atlas one-shot image runs as root by default)
#   ghcr_token is left alone -- it stays deploy-owned, already consumed by the login above, not read by any container.
docker run --rm --network none --pull never --entrypoint sh \
  -v "$d/secrets":/s \
  "$IMAGE_POSTGRES" -c '
    chown 65532 /s/database_url /s/web_form_signing_key /s/firebase_service_account
    chown 999 /s/postgres_* /s/pgbackrest_cipher /s/b2_*
    chown 0 /s/migrator_database_url
    chmod 0400 /s/*
  '

# --- 3. Migration-gated deploy ---------------------------------------------
# `migrate` must succeed before anything else changes: `current` still
# serves the previous release until switch-deployment.sh below runs, and no
# service is restarted onto a schema it doesn't expect yet.
compose --profile deploy run --rm migrate

# Flip current -> deployments/<id> only after a successful migration.
# switch-deployment.sh operates on paths relative to the base dir
# (deployments/, current, previous all live directly under $base), so it
# must run with that as the working directory -- not $d.
(cd "$base" && "$base/scripts/switch-deployment.sh" "$id")

compose up -d --no-build --wait
