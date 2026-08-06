#!/usr/bin/env bash
# Step 50: reconcile the GitHub Environment ($ENV_NAME) itself — the
# `production` required-reviewer protection rule, and the 8 non-secret
# Environment variables `deploy-vps.yml`/`ship-deployment.sh` require
# (RUNBOOK.md §1.5). Environment CREATION is handled order-independently by
# lib.sh's `ensure_gh_environment` (called from here AND from every
# `gh_secret_set`/`gh_var_set`), so this step's own job is narrower than its
# name suggests: the reviewer rule + the 8 vars.
#
# This step deliberately does NOT set the 3 Environment SECRETS
# (`BWS_TOKEN`, `SSH_DEPLOY_KEY`, `SSH_HOST_KEY`) — those are set by step 20
# (bws) and step 60 (droplet) respectively, each via `gh_secret_set`, which
# already ensures the Environment exists on its own. Duplicating a
# secret-presence check here would need `gh secret list --env` parsing for
# no benefit (secret values aren't readable back to compare anyway).
#
# Docs consulted:
#   - PUT /repos/{owner}/{repo}/environments/{environment_name} — "Create or
#     update an environment" (also used, WITH a `reviewers` body, for the
#     production required-reviewer rule):
#     https://docs.github.com/en/rest/deployments/environments?apiVersion=2022-11-28#create-or-update-an-environment
#     Reviewer objects are `{"type": "User"|"Team", "id": <integer>}`.
#   - GET /repos/{owner}/{repo}/environments/{environment_name}/variables —
#     "List environment variables" (used to check which of the 8 already
#     exist before setting only the absent ones):
#     https://docs.github.com/en/rest/actions/variables?apiVersion=2022-11-28#list-environment-variables
#   - gh CLI manual (`gh api`) — `{owner}`/`{repo}` placeholder substitution,
#     and `--input -` to read a JSON request body from stdin (used by lib.sh's
#     ensure_gh_environment for the `reviewers` body):
#     https://cli.github.com/manual/gh_api
set -euo pipefail

# --- Provider wrapper — overridden by bats tests, never called directly. ---
# Own copy of step 10's age-keygen wrapper: steps are sourced independently
# under --only/--from, so step 50 cannot assume step 10 was sourced this run.
age_keygen() { command age-keygen "$@"; }

# gh_env_var_exists NAME — true iff NAME is already registered as a GitHub
# Environment variable on $ENV_NAME. Parsed with external jq, matching
# bws_secret_exists's exact idiom in lib.sh, and kept behind this one
# function so bats (which runs in a jq-less Alpine image, see
# infra-setup.bats's step-30 note on acl_satisfied) always stubs it wholesale
# — the same convention steps 10/20/40 use for
# bws_secret_exists/bws_project_exists rather than exercising real jq.
gh_env_var_exists() {
  local name="$1"
  gh_api "repos/{owner}/{repo}/environments/${ENV_NAME}/variables" |
    jq -e --arg n "$name" 'any(.variables[]; .name == $n)' >/dev/null
}

# ensure_gh_var NAME VALUE — set only if absent, so a re-run never clobbers a
# value an operator may have rotated directly in the Environment afterward.
ensure_gh_var() {
  local name="$1" value="$2"
  if gh_env_var_exists "$name"; then
    log_info "GitHub Environment variable already present, skipping: ${name}"
    return 0
  fi
  run_mutation "set var ${name}" gh_var_set "$name" "$value"
}

reconcile_github_env() {
  # production-only required-reviewer gate. The reviewer rule itself is
  # applied by lib.sh's ensure_gh_environment (which re-asserts it on EVERY
  # environment PUT so no later step can wipe the manual-approval gate — see
  # its PRODUCTION REVIEWER SAFETY note); this step's job is only the
  # friendly upfront gate that stops with a clear instruction when the
  # operator has not yet supplied the reviewer id. Checked BEFORE the first
  # ensure_gh_environment so a production run without the id stops here
  # rather than creating a reviewer-less Environment and pressing on.
  if [ "${ENV_NAME:-}" = "production" ] && ! require_cfg GH_PRODUCTION_REVIEWER_ID >/dev/null; then
    need_manual GH_PRODUCTION_REVIEWER_ID \
      "Set the GitHub user id (numeric) to require as a production deploy reviewer (Settings → People, or GET /users/{username} for the id)"
    return $?
  fi

  run_mutation "ensure GitHub Environment ${ENV_NAME:-}" ensure_gh_environment

  # The 7 plain config-driven vars + the gate for AGE_RECIPIENT's derivation
  # input (BWS_RESTORE_PROJECT_ID), collected into one missing[] so a single
  # need_manual call names everything absent at once (same pattern as
  # reconcile_secrets/reconcile_bws/reconcile_b2).
  local missing=() api_port="" firebase_project_id="" s3_endpoint="" \
    b2_bucket="" b2_region="" ts_client_id="" ts_audience="" \
    age_recipient="" restore_project_id="" bws_write_token=""
  api_port="$(require_cfg API_PORT)" || missing+=(API_PORT)
  firebase_project_id="$(require_cfg FIREBASE_PROJECT_ID)" || missing+=(FIREBASE_PROJECT_ID)
  s3_endpoint="$(require_cfg PGBACKREST_REPO1_S3_ENDPOINT)" || missing+=(PGBACKREST_REPO1_S3_ENDPOINT)
  b2_bucket="$(require_cfg B2_BUCKET)" || missing+=(B2_BUCKET)
  b2_region="$(require_cfg B2_REGION)" || missing+=(B2_REGION)
  ts_client_id="$(require_cfg TS_CLIENT_ID)" || missing+=(TS_CLIENT_ID)
  ts_audience="$(require_cfg TS_AUDIENCE)" || missing+=(TS_AUDIENCE)

  # AGE_RECIPIENT: order-independent so `--only github-env` (no step 10 this
  # session) still works. Prefer the exported var (step 10 ran this session);
  # otherwise it must be re-derived from the restore project's
  # age_private_key, which needs both BWS_RESTORE_PROJECT_ID (which project)
  # and BWS_WRITE_TOKEN (read access to it -- steps 10/20/40 each export
  # BWS_ACCESS_TOKEN themselves before reading BWS, and standing alone via
  # --only this step must do the same, not assume an earlier step already did).
  age_recipient="$(cfg AGE_RECIPIENT)"
  if [ -z "$age_recipient" ]; then
    restore_project_id="$(require_cfg BWS_RESTORE_PROJECT_ID)" || missing+=(BWS_RESTORE_PROJECT_ID)
    bws_write_token="$(require_cfg BWS_WRITE_TOKEN)" || missing+=(BWS_WRITE_TOKEN)
  fi

  if [ "${#missing[@]}" -gt 0 ]; then
    need_manual "${missing[*]}" \
      "Set the missing non-secret config value(s) in config/${ENV_NAME:-target}.env (see RUNBOOK.md §1.5)." \
      || return $?
  fi

  if [ -z "$age_recipient" ]; then
    export BWS_ACCESS_TOKEN="$bws_write_token"
    local private_key=""
    private_key="$(bws_get_secret_value age_private_key "$restore_project_id")"
    if [ -z "$private_key" ]; then
      log_err "age_private_key not found in restore-scoped BWS project ${restore_project_id} — run step 10 (secrets) first"
      return 1
    fi
    age_recipient="$(printf '%s\n' "$private_key" | age_keygen -y)"
    # Guard the derivation OUTPUT too (not just the private-key-empty case
    # above): a failed/empty `age-keygen -y` must not silently set an empty
    # GitHub var. A valid age recipient is a bech32 public key prefixed
    # `age1`. Never log the private key itself.
    if [[ "$age_recipient" != age1* ]]; then
      log_err "derived AGE_RECIPIENT is empty/invalid (age-keygen -y produced no age1 recipient)"
      return 1
    fi
  fi

  ensure_gh_var API_PORT "$api_port"
  ensure_gh_var FIREBASE_PROJECT_ID "$firebase_project_id"
  ensure_gh_var PGBACKREST_REPO1_S3_ENDPOINT "$s3_endpoint"
  ensure_gh_var PGBACKREST_REPO1_S3_BUCKET "$b2_bucket"
  ensure_gh_var PGBACKREST_REPO1_S3_REGION "$b2_region"
  ensure_gh_var AGE_RECIPIENT "$age_recipient"
  ensure_gh_var TS_CLIENT_ID "$ts_client_id"
  ensure_gh_var TS_AUDIENCE "$ts_audience"
}
