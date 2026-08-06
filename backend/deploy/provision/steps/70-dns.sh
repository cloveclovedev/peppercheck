#!/usr/bin/env bash
# Step 70: reconcile the public Cloudflare DNS A record for PUBLIC_DOMAIN,
# pointing it at the Droplet's own public IP as DNS-only (never proxied).
#
# --- Source of truth: the Droplet's own public IP -----------------------
# The Droplet (created by step 60) is asked directly for its current
# PublicIPv4 via doctl (shared wrapper, now in lib.sh — see lib.sh's own
# comment on doctl_cli for why it moved out of steps/60-droplet.sh). This
# step never reads/writes a cached IP anywhere else, so it is safe to re-run
# any time the Droplet is recreated or its IP changes.
#
# --- Why proxied MUST be false (DNS-only / "grey cloud") -----------------
# Caddy on the Droplet performs its own ACME HTTP-01 challenge and terminates
# TLS itself. A proxied (orange-cloud) Cloudflare record would intercept that
# traffic at Cloudflare's edge instead of routing it straight to the Droplet,
# breaking both the ACME challenge and Caddy's own TLS termination. This step
# therefore never creates or leaves a record with proxied:true — see
# reconcile_dns below, which actively corrects it back to false if found set.
#
# --- Docs consulted (Cloudflare API v4 — https://developers.cloudflare.com/api/) -
#   - List DNS Records — GET /zones/{zone_id}/dns_records, filterable by
#     `type`/`name` query params:
#     https://developers.cloudflare.com/api/resources/dns/subresources/records/methods/list/
#   - Create DNS Record — POST /zones/{zone_id}/dns_records, body fields
#     type/name/content/ttl/proxied for an A record; `proxied` "whether the
#     record is receiving the performance and security benefits of
#     Cloudflare" (true routes through Cloudflare's edge, false is DNS-only):
#     https://developers.cloudflare.com/api/resources/dns/subresources/records/methods/create/
#   - Edit DNS Record — PATCH /zones/{zone_id}/dns_records/{dns_record_id},
#     a genuine PARTIAL update (only the fields given are changed) — distinct
#     from the sibling PUT .../dns_records/{dns_record_id} "Update DNS
#     Record" endpoint, which overwrites the whole record and is NOT used
#     here:
#     https://developers.cloudflare.com/api/resources/dns/subresources/records/methods/edit/
#   - doctl `compute droplet get` accepts either a Droplet ID or NAME as its
#     argument (`doctl compute droplet get <droplet-id|droplet-name>`):
#     https://docs.digitalocean.com/reference/doctl/reference/compute/droplet/get/
set -euo pipefail

# --- Provider wrapper — overridden by bats tests, never called directly. ---
# cf_api METHOD PATH [JSON_BODY] — curl to the Cloudflare API v4, bearer-token
# auth. Fail-closed: any non-2xx response or transport error aborts with a
# clear message (curl -fsS's own exit status), so a caller composing
# `x="$(cf_api ...)"` never silently proceeds on a stale/empty response.
# The token itself is never logged.
cf_api() {
  local method="$1" path="$2" body="${3:-}"
  local -a args=(
    -fsS -X "$method"
    -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}"
    -H "Accept: application/json"
  )
  [ -n "$body" ] && args+=(-H "Content-Type: application/json" --data "$body")
  local response
  if ! response="$(curl "${args[@]}" "https://api.cloudflare.com/client/v4${path}")"; then
    log_err "Cloudflare API call failed: ${method} ${path} (non-2xx response or network error)"
    return 1
  fi
  printf '%s' "$response"
}

# _dns_a_record_fields JSON — extracts "id<TAB>content<TAB>proxied" for the
# first record in a Cloudflare "list DNS records" response's `.result` array,
# or prints nothing (exit 0) when `.result` is empty (no existing A record).
# Factored into its own stubbable helper — like lib.sh's own _json_escape and
# step 30's acl_satisfied — because jq is absent from the bats/bats:latest
# image the unit tests run in; the real script still uses real jq here, only
# the bats tests stub this function directly instead of feeding it real
# Cloudflare JSON through a jq binary that isn't there.
_dns_a_record_fields() {
  local json="$1"
  jq -r '.result[0] | select(. != null) | "\(.id)\t\(.content)\t\(.proxied)"' <<<"$json"
}

reconcile_dns() {
  local missing=() cf_token="" zone_id="" do_token="" public_domain=""
  cf_token="$(require_cfg CLOUDFLARE_API_TOKEN)" || missing+=(CLOUDFLARE_API_TOKEN)
  zone_id="$(require_cfg CLOUDFLARE_ZONE_ID)" || missing+=(CLOUDFLARE_ZONE_ID)
  do_token="$(require_cfg DO_TOKEN)" || missing+=(DO_TOKEN)
  public_domain="$(require_cfg PUBLIC_DOMAIN)" || missing+=(PUBLIC_DOMAIN)
  if [ "${#missing[@]}" -gt 0 ]; then
    need_manual "${missing[*]}" \
      "Create a Cloudflare API token with DNS:Edit permission on the peppercheck.dev zone, and get the zone id (dashboard → the zone's Overview page → API section in the right sidebar). DO_TOKEN/PUBLIC_DOMAIN are ordinary config/${ENV_NAME:-target}.env values (see RUNBOOK.md §1.6) if those are what's actually missing." \
      || return $?
  fi
  export CLOUDFLARE_API_TOKEN="$cf_token"

  # doctl reads its access token from DIGITALOCEAN_ACCESS_TOKEN when not
  # already authenticated via `doctl auth init` (see reconcile_droplet in
  # steps/60-droplet.sh for the doctl README citation on this env var).
  export DIGITALOCEAN_ACCESS_TOKEN="$do_token"

  # Get the Droplet's public IP — the source of truth for the A record.
  # Explicit `|| { …; return 1; }`: the orchestrator runs each step under
  # `set +e` (infra-foundation-setup.sh: `set +e; "$fn"; rc=$?; set -e`), so
  # `set -e` is OFF inside reconcile_dns and a failing command substitution
  # would otherwise leave `ip=""` and fall through to reconcile_dns's own
  # logic (worst case: patching the live A record to an empty content).
  local droplet_name="pc-${ENV_NAME:-}" ip=""
  ip="$(doctl_cli compute droplet get "$droplet_name" --format PublicIPv4 --no-header)" || {
    log_err "could not query the public IP of Droplet ${droplet_name} via doctl (expired/rate-limited DO token, or a network error) — aborting rather than reconcile DNS against an unknown IP"
    return 1
  }
  if [ -z "$ip" ]; then
    log_err "Droplet ${droplet_name} was found but has no public IP yet (still provisioning), or does not exist — run step 60 (droplet) first, then re-run this step"
    return 1
  fi

  # Look up any existing A record for PUBLIC_DOMAIN.
  local response=""
  response="$(cf_api GET "/zones/${zone_id}/dns_records?type=A&name=${public_domain}")" || {
    log_err "Cloudflare DNS record lookup failed for ${public_domain}"
    return 1
  }
  local fields=""
  fields="$(_dns_a_record_fields "$response")" || {
    log_err "failed to parse the Cloudflare DNS record list response for ${public_domain}"
    return 1
  }

  if [ -z "$fields" ]; then
    local create_body=""
    create_body="$(printf '{"type":"A","name":"%s","content":"%s","proxied":false,"ttl":300}' "$public_domain" "$ip")"
    run_mutation "create Cloudflare A record ${public_domain} -> ${ip} (DNS-only, proxied:false)" \
      cf_api POST "/zones/${zone_id}/dns_records" "$create_body" || {
      log_err "failed to create the Cloudflare A record for ${public_domain}"
      return 1
    }
    log_ok "created Cloudflare A record ${public_domain} -> ${ip} (DNS-only)"
    return 0
  fi

  local record_id="" current_content="" current_proxied=""
  IFS=$'\t' read -r record_id current_content current_proxied <<<"$fields"

  if [ "$current_content" = "$ip" ] && [ "$current_proxied" = "false" ]; then
    log_ok "Cloudflare A record for ${public_domain} already correct (${ip}, DNS-only) — no change"
    return 0
  fi

  # Wrong IP and/or proxied:true — PATCH is a genuine partial update (see the
  # Edit DNS Record doc cited above), so only content+proxied need sending.
  local patch_body=""
  patch_body="$(printf '{"content":"%s","proxied":false}' "$ip")"
  run_mutation "fix Cloudflare A record ${public_domain} (id ${record_id}): content ${current_content} -> ${ip}, proxied ${current_proxied} -> false" \
    cf_api PATCH "/zones/${zone_id}/dns_records/${record_id}" "$patch_body" || {
    log_err "failed to update the Cloudflare A record for ${public_domain}"
    return 1
  }
  log_ok "updated Cloudflare A record for ${public_domain} -> ${ip} (DNS-only, was content=${current_content} proxied=${current_proxied})"
}
