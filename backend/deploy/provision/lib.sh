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
gh_secret_set() { command gh secret set "$1" --env "$ENV_NAME" --body "$2"; }
gh_var_set() { command gh variable set "$1" --env "$ENV_NAME" --body "$2"; }

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
