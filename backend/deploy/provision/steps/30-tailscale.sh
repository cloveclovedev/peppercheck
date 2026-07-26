#!/usr/bin/env bash
# Step 30: reconcile the tailnet ACL (check-and-instruct only, never
# auto-overwritten) and mint the Droplet's ephemeral Tailscale auth key.
#
# Two manual gates, both admin-console-only (Tailscale has no API to create
# either): TS_API_KEY is this script's own bootstrap credential (an API
# access token); TS_CLIENT_ID/TS_AUDIENCE belong to the CI runner's OAuth
# client and are only confirmed present here — step 50 (github-env) is what
# turns them into GitHub Environment variables for deploy-vps.yml.
#
# The tailnet ACL is a single full-replace document (POST /tailnet/-/acl
# replaces the whole policy file), so this step never POSTs a merged ACL on
# the operator's behalf — that would silently clobber whatever other rules
# already live there. Instead it GETs the current ACL, checks (via jq)
# whether the tags and SSH grant this setup needs are already present, and
# if not, prints the exact HuJSON to merge and stops with NEEDS_MANUAL so the
# operator can merge it safely in the admin console.
#
# Minting the ephemeral auth key IS automated: it is additive (a new key each
# run, never a modification of existing state) and self-limiting (a 10-minute
# TTL — a short-TTL key minted but never consumed by step 60 is harmless, it
# just expires). Ephemeral auth keys are single-use bootstrap tokens, so this
# deliberately does NOT try to make minting idempotent/re-run-safe the way
# steps 10/20 make their BWS writes idempotent.
set -euo pipefail

# --- Provider wrapper — overridden by bats tests, never called directly. ---
# ts_api METHOD PATH [JSON_BODY] — curl to the Tailscale API, bearer-token
# auth. Fail-closed: any non-2xx response or transport error aborts with a
# clear message (curl -fsS's own exit status), so a caller composing
# `x="$(ts_api ...)"` never silently proceeds on a stale/empty response.
ts_api() {
  local method="$1" path="$2" body="${3:-}"
  local -a args=(
    -fsS -X "$method"
    -H "Authorization: Bearer ${TS_API_KEY}"
    -H "Accept: application/json"
  )
  [ -n "$body" ] && args+=(-H "Content-Type: application/json" --data "$body")
  local response
  if ! response="$(curl "${args[@]}" "https://api.tailscale.com/api/v2${path}")"; then
    log_err "Tailscale API call failed: ${method} ${path} (non-2xx response or network error)"
    return 1
  fi
  printf '%s' "$response"
}

# tailscale_acl_snippet — the exact tags + grant rule the operator must merge
# into the tailnet policy file (admin console → Access Controls → edit file).
# Printed verbatim by need_manual so the fix is directly copy-pasteable;
# never auto-applied (see the file header for why).
tailscale_acl_snippet() {
  cat <<'HUJSON'
{
  "tagOwners": {
    "tag:ci-deploy":  ["autogroup:admin"],
    "tag:pc-staging": ["autogroup:admin"],
    "tag:pc-prod":    ["autogroup:admin"],
  },
  "grants": [
    {
      "src": ["tag:ci-deploy"],
      "dst": ["tag:pc-staging", "tag:pc-prod"],
      "ip":  ["tcp:22"],
    },
  ],
}
HUJSON
}

# acl_satisfied ACL_JSON
# True iff the parsed tailnet ACL already owns tag:ci-deploy/pc-staging/
# pc-prod AND grants tag:ci-deploy tcp:22 to both tag:pc-staging and
# tag:pc-prod — as one grant listing both dsts, or as separate grants, either
# merges cleanly with an operator's existing policy.
acl_satisfied() {
  local acl_json="$1"
  jq -e '
    (.tagOwners // {}) as $to |
    ($to | has("tag:ci-deploy")) and
    ($to | has("tag:pc-staging")) and
    ($to | has("tag:pc-prod")) and
    ((.grants // []) as $grants |
      ["tag:pc-staging", "tag:pc-prod"] | all(. as $need_dst |
        $grants | any(
          ((.src // []) | index("tag:ci-deploy")) and
          ((.dst // []) | index($need_dst)) and
          ((.ip  // []) | index("tcp:22"))
        )
      )
    )
  ' >/dev/null <<<"$acl_json"
}

# check_tailscale_acl — GET the current ACL and confirm the required tags +
# grant are present. Never POSTs; see the file header.
check_tailscale_acl() {
  local acl_json
  acl_json="$(ts_api GET /tailnet/-/acl)" || return 1
  if acl_satisfied "$acl_json"; then
    log_ok "tailnet ACL already has tag:ci-deploy/pc-staging/pc-prod + the SSH grant"
    return 0
  fi
  need_manual TAILSCALE_ACL "$(printf '%s\n\n%s' \
    "The tailnet policy file is missing the tag owners and/or the SSH grant this setup needs. Open the admin console (Access Controls) and MERGE the following into the EXISTING policy file — do not replace it wholesale:" \
    "$(tailscale_acl_snippet)")"
}

# _extract_json_string_field JSON FIELD
# Pure-bash extraction of a single flat top-level "field":"value" string from
# a JSON object — same no-external-tool-dependency approach as lib.sh's
# _json_escape, applied here so mint_tailscale_auth_key's key extraction
# doesn't need jq (unlike acl_satisfied's grant lookup, this is a single flat
# field so a full JSON query engine buys nothing). Echoes the value and
# returns 0 if the field is present; returns 1 with no output otherwise.
_extract_json_string_field() {
  local json="$1" field="$2" rest
  case "$json" in
    *"\"${field}\""*) ;;
    *) return 1 ;;
  esac
  rest="${json#*\""${field}"\"}"
  rest="${rest#*:}"
  rest="${rest#*\"}"
  rest="${rest%%\"*}"
  printf '%s' "$rest"
}

# mint_tailscale_auth_key TAG — create a tag-scoped, ephemeral, preauthorized,
# single-use auth key (short TTL) and export it as TS_AUTH_KEY for step 60 to
# consume within this same orchestrator run. See
# https://tailscale.com/docs/features/access-control/auth-keys for the
# ephemeral/preauthorized/tagged key semantics this relies on.
mint_tailscale_auth_key() {
  local tag="$1" body response key
  body=$(printf '{"capabilities":{"devices":{"create":{"reusable":false,"ephemeral":true,"preauthorized":true,"tags":["%s"]}}},"expirySeconds":600,"description":"infra-foundation-setup bootstrap key"}' "$tag")
  response="$(run_mutation "mint ephemeral Tailscale auth key for ${tag} (expires in 600s)" \
    ts_api POST /tailnet/-/keys "$body")"
  is_dry_run && return 0

  if ! key="$(_extract_json_string_field "$response" key)" || [ -z "$key" ]; then
    log_err "Tailscale auth key mint returned no key"
    return 1
  fi
  export TS_AUTH_KEY="$key"
  log_ok "minted ephemeral Tailscale auth key for ${tag} (value not logged)"
}

reconcile_tailscale() {
  local ts_api_key=""
  ts_api_key="$(require_cfg TS_API_KEY)" || {
    need_manual TS_API_KEY \
      "Create a Tailscale API access token (admin console → Settings → Keys → API access token) for this provisioning script"
    return $?
  }
  export TS_API_KEY="$ts_api_key"

  # TS_CLIENT_ID/TS_AUDIENCE are only confirmed present here — this step does
  # not use their values (there is no API to create an OAuth client); step 50
  # (github-env) is what turns them into GitHub Environment variables.
  local missing=()
  require_cfg TS_CLIENT_ID >/dev/null || missing+=(TS_CLIENT_ID)
  require_cfg TS_AUDIENCE >/dev/null || missing+=(TS_AUDIENCE)
  if [ "${#missing[@]}" -gt 0 ]; then
    need_manual "${missing[*]}" \
      "Create a GitHub-OIDC OAuth client in the Tailscale admin console (Settings → OAuth clients) that issues nodes tagged tag:ci-deploy, restricted to this repo + the deploy-vps.yml workflow." \
      || return $?
  fi

  local ts_tag=""
  ts_tag="$(require_cfg TS_TAG)" || {
    log_err "TS_TAG is not set (expected in config/<env>.env, e.g. tag:pc-staging)"
    return 1
  }

  check_tailscale_acl || return $?

  mint_tailscale_auth_key "$ts_tag"
}
