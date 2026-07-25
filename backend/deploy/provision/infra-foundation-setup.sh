#!/usr/bin/env bash
# Idempotent, state-reconciling stand-up orchestrator. See the design doc.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/lib.sh"

STEPS=(secrets bws tailscale b2 github-env droplet dns verify monitoring)

usage() { echo "usage: infra-foundation-setup.sh <staging|production> [--dry-run] [--from <step>] [--only <step>]" >&2; exit 2; }

ENV_NAME=""; ONLY=""; FROM=""
[ "$#" -ge 1 ] || usage
ENV_NAME="$1"; shift
case "$ENV_NAME" in staging|production) ;; *) usage;; esac
while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1;;
    --from) shift; FROM="${1:-}";;
    --only) shift; ONLY="${1:-}";;
    *) usage;;
  esac; shift
done
export ENV_NAME DRY_RUN

# Load config (sourced, so keys become env vars). Missing file is OK — a step
# that needs an absent key stops with need_manual.
CONFIG_FILE="$HERE/config/${ENV_NAME}.env"
# shellcheck disable=SC1090
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

require_tools gh doctl bws b2 jq age openssl ssh-keygen ssh-keyscan curl

started=0
for step in "${STEPS[@]}"; do
  [ -n "$ONLY" ] && [ "$ONLY" != "$step" ] && continue
  [ -z "$ONLY" ] && [ -n "$FROM" ] && [ "$started" = "0" ] && [ "$FROM" != "$step" ] && continue
  started=1
  # shellcheck disable=SC1090
  source "$HERE/steps/"[0-9]*-"$step".sh
  fn="reconcile_${step//-/_}"
  log_info "== step: $step =="
  set +e; "$fn"; rc=$?; set -e
  if [ "$rc" = "$NEEDS_MANUAL" ]; then
    log_warn "stopped at '$step' — complete the action above, then re-run."
    exit "$NEEDS_MANUAL"
  elif [ "$rc" != "0" ]; then
    log_err "step '$step' failed (rc=$rc)"; exit "$rc"
  fi
done
log_ok "all steps satisfied for '$ENV_NAME'"
