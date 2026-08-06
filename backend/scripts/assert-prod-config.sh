#!/usr/bin/env bash
# Asserts that backend/compose.prod.yaml's RESOLVED configuration upholds the
# invariants that make it safe to run in production (see the standalone-file
# rationale at the top of
# compose.prod.yaml and design doc §7):
#
#   1. No service defines `build:` -- production must only ever run
#      pre-built, digest-pinned images, never build on the VPS. Checked both
#      against the default resolution and against `--profile deploy`, since
#      the profiled `migrate` service is otherwise invisible to `config`.
#   2. `api`'s `depends_on` does not include `migrate` -- migrations are an
#      explicit `--profile deploy` step driven by the deploy workflow, never
#      a runtime dependency of `up -d`.
#   3. `postgres` publishes no host ports -- 5432 must never be reachable
#      from outside the Compose project.
#
# This does not deploy anything; it only resolves `docker compose config`
# against the standalone prod file and checks the JSON output with jq. Real
# deploys supply real IMAGE_*/secrets -- this script fills in
# placeholder values only so `config` can resolve at all, and is safe to run
# repeatedly in CI or locally. Wired into CI as a step in the `image` job
# (.github/workflows/ci-backend.yml).
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

# --- Dummy values, only used when not already set --------------------------
# `docker compose config` fails closed on any unset `${VAR:?...}` in
# compose.prod.yaml, so every one of them needs *some* value to resolve. A
# real deploy (or a caller wanting to assert against real image refs) can
# pre-export any of these and this script will not clobber them.
: "${PC_ENV:=ci}"
: "${IMAGE_POSTGRES:=ghcr.io/example/peppercheck-postgres:dummy}"
: "${IMAGE_BACKUP:=ghcr.io/example/peppercheck-backup:dummy}"
: "${IMAGE_BACKEND:=ghcr.io/example/peppercheck-backend:dummy}"
: "${IMAGE_CADDY:=caddy:2}"
: "${IMAGE_ATLAS:=arigaio/atlas:1.2.0}"
: "${CADDY_SITE_ADDRESS:=example.invalid}"
: "${API_PORT:=8765}"
: "${FIREBASE_PROJECT_ID:=peppercheck-dummy}"
: "${PGBACKREST_REPO1_S3_ENDPOINT:=s3.example.invalid}"
: "${PGBACKREST_REPO1_S3_BUCKET:=dummy-bucket}"
: "${PGBACKREST_REPO1_S3_REGION:=us-east-1}"
: "${AGE_RECIPIENT:=age1dummydummydummydummydummydummydummydummydummydummydummydumm}"
export PC_ENV IMAGE_POSTGRES IMAGE_BACKUP IMAGE_BACKEND IMAGE_CADDY IMAGE_ATLAS \
  CADDY_SITE_ADDRESS API_PORT FIREBASE_PROJECT_ID \
  PGBACKREST_REPO1_S3_ENDPOINT PGBACKREST_REPO1_S3_BUCKET PGBACKREST_REPO1_S3_REGION \
  AGE_RECIPIENT

# `docker compose config` resolves every `secrets: - file: ./secrets/<name>`
# path and fails if the file is missing, even though `config` never reads
# its contents. These are placeholder fixtures for local/CI validation only:
# never real secret values, and gitignored (see backend/.gitignore) so they
# can never be committed by accident.
readonly SECRETS_DIR="./secrets"
readonly SECRET_NAMES=(
  postgres_superuser_pw
  postgres_app_pw
  postgres_migrator_pw
  postgres_backup_pw
  pgbackrest_cipher
  b2_key_id
  b2_key_secret
  database_url
  migrator_database_url
  web_form_signing_key
  firebase_service_account
)
mkdir -p "$SECRETS_DIR"
for name in "${SECRET_NAMES[@]}"; do
  [ -f "$SECRETS_DIR/$name" ] || printf 'placeholder-not-a-real-secret' > "$SECRETS_DIR/$name"
done

readonly PROJECT="peppercheck-${PC_ENV}"
config_json="$(docker compose -f compose.prod.yaml -p "$PROJECT" config --format json)"

echo "==> asserting no service defines build:"
echo "$config_json" | jq -e '[.services[] | select(has("build"))] | length == 0' >/dev/null

echo "==> asserting api has no dependency on migrate"
echo "$config_json" | jq -e '(.services.api.depends_on // {}) | has("migrate") | not' >/dev/null

echo "==> asserting postgres publishes no host ports"
echo "$config_json" | jq -e '(.services.postgres.ports // []) | length == 0' >/dev/null

# The worker sends FCM (P4a-D18): it must mount the firebase_service_account
# secret and point GOOGLE_APPLICATION_CREDENTIALS at it, with FIREBASE_PROJECT_ID
# set. The api must NOT mount that secret -- it never sends FCM.
echo "==> asserting worker mounts firebase_service_account + FCM env"
echo "$config_json" | jq -e '
  (.services.worker.secrets | map(if type=="object" then .source else . end) | index("firebase_service_account")) != null
  and (.services.worker.environment.GOOGLE_APPLICATION_CREDENTIALS == "/run/secrets/firebase_service_account")
  and (.services.worker.environment | has("FIREBASE_PROJECT_ID"))' >/dev/null

echo "==> asserting api does NOT mount firebase_service_account"
echo "$config_json" | jq -e '
  (.services.api.secrets // [] | map(if type=="object" then .source else . end) | index("firebase_service_account")) == null' >/dev/null

# `migrate` is `profiles: ["deploy"]`-only, so the default `config` resolution
# above never includes it -- a `build:` added to that service later would
# slip past the check above unnoticed. Re-resolve with the profile active
# (which merges the profiled service into the default set, it does not
# replace it) and re-run the build: check over the full resulting set.
echo "==> asserting no service (including profile=deploy's migrate) defines build:"
profiled_config_json="$(docker compose -f compose.prod.yaml -p "$PROJECT" --profile deploy config --format json)"
echo "$profiled_config_json" | jq -e 'has("services") and (.services | has("migrate"))' >/dev/null
echo "$profiled_config_json" | jq -e '[.services[] | select(has("build"))] | length == 0' >/dev/null

echo "assert-prod-config: OK"
