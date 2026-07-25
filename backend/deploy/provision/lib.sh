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
