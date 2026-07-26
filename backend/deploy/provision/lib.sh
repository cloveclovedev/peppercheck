#!/usr/bin/env bash
# Shared framework for the infra-foundation-setup orchestrator: config loading,
# tool checks, the reconcile three-valued contract, logging, and the dry-run
# guard. Provider calls live in wrapper functions (gh_api/bws_cli/... added in
# later steps) so tests can override them; no step calls a CLI directly.
set -euo pipefail

NEEDS_MANUAL=75
DRY_RUN="${DRY_RUN:-0}"

# Pure-bash JSON string escaping (no jq dependency) so logging works
# standalone: jq is one of require_tools' checks for the orchestrator's real
# run, but the bats unit tests source lib.sh directly and must not need it.
_json_escape() {
  local s=$1
  s=${s//\\/\\\\}   # backslash first, so later escapes aren't double-escaped
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}  # CR and TAB are the realistic ones in CLI/API error text
  s=${s//$'\t'/\\t}
  printf '%s' "$s"
}
_log() { printf '{"level":"%s","msg":"%s"}\n' "$1" "$(_json_escape "$2")" >&2; }
log_info() { _log info "$1"; }
log_ok()   { _log ok "$1"; }
log_warn() { _log warn "$1"; }
log_err()  { _log error "$1"; }

need_manual() {
  local key="$1"; shift
  {
    echo "=== ACTION REQUIRED ==="
    echo "$*"
    echo "Then put the resulting value in config/<env>.env as: ${key}"
    echo "Re-run the same command to continue."
  } >&2
  return "$NEEDS_MANUAL"
}

require_tools() {
  local missing=() t
  for t in "$@"; do command -v "$t" >/dev/null 2>&1 || missing+=("$t"); done
  if [ "${#missing[@]}" -gt 0 ]; then
    log_err "missing required tools: ${missing[*]} (install them; this script does not)"
    exit 1
  fi
}

cfg() { printf '%s' "${!1:-}"; }
require_cfg() { local v; v="$(cfg "$1")"; [ -n "$v" ] || return 1; printf '%s' "$v"; }

is_dry_run() { [ "$DRY_RUN" = "1" ]; }

# require_known_step KIND VALUE step1 step2 …
# Validates an operator-supplied --only/--from selector against the known step
# list. Exits 2 (usage-style) naming the bad value and the valid steps if it is
# not a member. Factored out of the orchestrator so it is unit-testable without
# running the whole source-and-dispatch loop.
require_known_step() {
  local kind="$1" value="$2"; shift 2
  local s
  for s in "$@"; do [ "$s" = "$value" ] && return 0; done
  echo "error: unknown --${kind} step '${value}'. valid steps: $*" >&2
  exit 2
}

run_mutation() {
  local desc="$1"; shift
  if is_dry_run; then echo "[dry-run] ${desc}"; return 0; fi
  "$@"
}

# --- Shared provider wrappers ------------------------------------------------
# Live here (not in whichever step first needed them) because the
# orchestrator's --only/--from can run a single step without any earlier
# step's file being sourced, but lib.sh is always sourced. Kept thin so bats
# tests can redefine them after `source lib.sh`; no step calls these
# providers' CLIs directly.
bws_cli() { command bws "$@"; }
gh_api() { command gh api "$@"; }
# doctl_cli lives here rather than in the step (60-droplet.sh) that first
# needed it: step 70 (dns) also needs it, to query the Droplet's public IP as
# the source of truth for the DNS A record, and the orchestrator's
# --only/--from can run either step alone without the other step's file ever
# being sourced. lib.sh is always sourced, so this is the one place both can
# rely on it existing (and bats tests still override it after sourcing
# lib.sh, exactly like bws_cli/gh_api above).
doctl_cli() { command doctl "$@"; }

# ensure_gh_environment — idempotent create-or-update of the GitHub
# Environment named $ENV_NAME. A plain `PUT .../environments/{name}` with no
# request body creates the Environment if it is absent, and is a no-op
# update if it already exists (every body field is optional) — GitHub REST
# docs, "Create or update an environment":
# https://docs.github.com/en/rest/deployments/environments?apiVersion=2022-11-28#create-or-update-an-environment
#
# `{owner}`/`{repo}` are gh CLI's own literal placeholders, substituted from
# the repository of the current working directory (or `GH_REPO` if set) —
# gh CLI manual: "Placeholder values `{owner}`, `{repo}`... will get
# replaced with values from the repository of the current directory."
# (https://cli.github.com/manual/gh_api). No separate `gh repo view` lookup
# is needed; this script always runs from inside the repo checkout.
#
# Called from gh_secret_set/gh_var_set below (not only from step 50) so that
# ANY env-scoped secret/var set works regardless of --only/--from step
# order: env secrets are set by step 20 (BWS_TOKEN) and step 60
# (SSH_DEPLOY_KEY/SSH_HOST_KEY), both of which can run before step 50
# (github-env) creates the Environment, or alone via `--only`. Safe to call
# many times per run — every call after the first is a no-op update.
#
# PRODUCTION REVIEWER SAFETY: GitHub's env PUT is NOT documented to preserve
# omitted protection-rule fields, so a no-body PUT that omits `reviewers`
# MAY reset the production manual-approval gate. Because this function fires
# on EVERY gh_var_set/gh_secret_set (step 50's var loop, step 60's SSH-key
# secrets, ...), any such no-body PUT after step 50 set the reviewer could
# silently wipe it. Guard: when $ENV_NAME=production AND a
# GH_PRODUCTION_REVIEWER_ID is configured, EVERY PUT carries the reviewer
# body, so the reviewer is re-asserted (never left wiped) no matter which
# step issues the last PUT. This makes ensure_gh_environment the single
# source of truth for the production reviewer. Staging (no reviewer) and
# production-before-the-id-is-set (caught by step 50's friendly need_manual
# gate) both take the plain no-body PUT.
ensure_gh_environment() {
  local reviewer_id
  if [ "${ENV_NAME:-}" = "production" ] && reviewer_id="$(require_cfg GH_PRODUCTION_REVIEWER_ID)"; then
    printf '{"reviewers":[{"type":"User","id":%s}]}' "$reviewer_id" |
      gh_api --method PUT "repos/{owner}/{repo}/environments/${ENV_NAME}" --input - >/dev/null
  else
    gh_api --method PUT "repos/{owner}/{repo}/environments/${ENV_NAME}" >/dev/null
  fi
}

gh_secret_set() {
  ensure_gh_environment
  command gh secret set "$1" --env "$ENV_NAME" --body "$2"
}
gh_var_set() {
  ensure_gh_environment
  command gh variable set "$1" --env "$ENV_NAME" --body "$2"
}

# bws_secret_exists NAME PROJECT_ID
bws_secret_exists() {
  local name="$1" project_id="$2"
  bws_cli secret list "$project_id" | jq -e --arg n "$name" 'any(.[]; .key == $n)' >/dev/null
}

# bws_put_secret NAME VALUE PROJECT_ID
bws_put_secret() {
  local name="$1" value="$2" project_id="$3"
  bws_cli secret create "$name" "$value" "$project_id" >/dev/null
}

# bws_get_secret_value NAME PROJECT_ID
# Only needed on re-run paths that must recover an already-stored plaintext
# (e.g. step 10's age-key/cipher mirroring); most secrets are write-once so
# their plaintext never needs reading back.
bws_get_secret_value() {
  local name="$1" project_id="$2"
  bws_cli secret list "$project_id" | jq -r --arg n "$name" '.[] | select(.key == $n) | .value'
}

# bws_project_exists PROJECT_ID
# Confirms a BWS project id is visible/reachable with the currently exported
# BWS_ACCESS_TOKEN (used by step 20's write-token gate).
bws_project_exists() {
  local project_id="$1"
  bws_cli project list | jq -e --arg id "$project_id" 'any(.[]; .id == $id)' >/dev/null
}
