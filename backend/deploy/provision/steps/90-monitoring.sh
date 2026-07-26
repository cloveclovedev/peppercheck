#!/usr/bin/env bash
# Step 90 (LAST step): reconcile Better Stack uptime + heartbeat monitors and
# DigitalOcean host alert policies. PING MODEL ONLY (design doc D2 / §2
# non-goals): this step CREATES monitors/policies against the already-merged
# Phase 7-A monitoring surface — it never edits `deploy/monitor/wal-freshness.sh`,
# `deploy/monitor/host-checks.sh`, `deploy/backup/backup.sh`, or
# `internal/worker/worker.go` (the four things that already ping Better Stack
# heartbeats). See `backend/deploy/provision/MONITORING.md` for what each
# monitor/heartbeat corresponds to at runtime.
#
# --- What this step ensures --------------------------------------------------
#   - TWO uptime monitors: `https://$PUBLIC_DOMAIN/livez` and `/readyz`
#     (HTTP status check), each with TLS-expiry checking enabled.
#   - FOUR heartbeat monitors, named `pc-<env> worker` / `backup` /
#     `wal-freshness` / `host-checks` — these are exactly the heartbeats the
#     already-merged worker/backup/wal-freshness/host-checks scripts ping;
#     this step only creates the Better Stack side, never the scripts.
#   - THREE DigitalOcean host alert policies (CPU/memory/disk > 80%, 5-minute
#     window) on the environment's Droplet.
#
# --- Staging must be non-paging (design doc §5, MONITORING.md §2.3) ---------
# Better Stack's monitor/heartbeat attributes have no single "team/escalation
# policy" id this script can safely invent (creating/discovering the right
# escalation policy is an operator/dashboard concern — see the Better Stack
# API docs cited below, `policy_id` targets an EXISTING policy). Instead,
# for ENV_NAME=staging every created monitor/heartbeat explicitly disables
# every notification channel Better Stack's API exposes
# (`call`/`sms`/`email`/`push`/`critical_alert` all `false`): the check still
# runs and still shows on the dashboard (and in Better Stack's own incident
# history) — nobody is paged. Production omits these fields entirely, so the
# account's own default notification/escalation configuration applies
# unmodified (pages whoever it already pages).
#
# --- Docs consulted (Better Stack Uptime API v2, DigitalOcean doctl) --------
#   - Create monitor — POST /api/v2/monitors. Body fields used here:
#     `monitor_type` ("status" — a plain up/down HTTP status check, one of
#     the documented monitor_type values alongside expected_status_code/
#     keyword/ping/tcp/...), `url`, `pronounceable_name`, `ssl_expiration`
#     (integer days-before-expiry to alert on, one of 1/2/3/7/14/30/60 — an
#     EXPLICIT opt-in field, not something Better Stack checks unless set),
#     and the non-paging channel booleans `call`/`sms`/`email`/`push`/
#     `critical_alert`:
#     https://betterstack.com/docs/uptime/api/create-a-new-monitor/
#   - List monitors — GET /api/v2/monitors: JSON:API-style
#     `{"data":[{"id":...,"attributes":{"url":...,"pronounceable_name":...,
#     "monitor_type":...,...}}]}`:
#     https://betterstack.com/docs/uptime/api/list-all-existing-monitors/
#   - Create heartbeat — POST /api/v2/heartbeats. Body fields used here:
#     `name`, `period` (seconds, minimum 30), `grace` (seconds, minimum 0),
#     and the same non-paging channel booleans as monitors:
#     https://betterstack.com/docs/uptime/api/create-a-hearbeat/
#   - List heartbeats — GET /api/v2/heartbeats: JSON:API-style
#     `{"data":[{"id":...,"attributes":{"url":...(the ping
#     URL),"name":...,"period":...,"grace":...}}]}`:
#     https://betterstack.com/docs/uptime/api/list-all-existing-hearbeats/
#   - `doctl monitoring alert create --type <T> --compare {GreaterThan,
#     LessThan} --value <N> --window {5m,10m,30m,1h} --entities <droplet-id>
#     --emails <addr> --description <text>`:
#     https://docs.digitalocean.com/reference/doctl/reference/monitoring/alert/create/
#   - The `--type` values for CPU/memory/disk are the godo constants
#     `DropletCPUUtilizationPercent = "v1/insights/droplet/cpu"`,
#     `DropletMemoryUtilizationPercent =
#     "v1/insights/droplet/memory_utilization_percent"`,
#     `DropletDiskUtilizationPercent =
#     "v1/insights/droplet/disk_utilization_percent"` (github.com/
#     digitalocean/godo `monitoring.go`), which is what doctl's own
#     `validAlertPolicyTypes` map resolves `--type` against.
#   - `doctl monitoring alert list -o json` prints the godo `AlertPolicy`
#     struct verbatim: `{"uuid":...,"type":...,"description":...,
#     "compare":...,"value":...,"window":...,"entities":[...],"tags":[...],
#     "alerts":{"slack":[...],"email":[...]},"enabled":...}` (a top-level
#     JSON array, doctl's usual `-o json` list shape) — used here purely as
#     an existence probe (type + droplet id already in `entities`).
#
# --- Known gap: heartbeat ping URLs are not auto-delivered to BWS ----------
# A Better Stack heartbeat's ping URL (the thing `wal-freshness.sh`/
# `host-checks.sh`/the worker/backup containers actually ping) is only
# returned in the CREATE response and is a secret in its own right — see
# MONITORING.md §4. This step deliberately does NOT parse that response and
# push it into BWS (out of this task's scope: "creates monitors only"); it
# logs a reminder instead. Copying the 4 heartbeat URLs from the Better
# Stack dashboard into the env's BWS project (`heartbeat_url_worker`/
# `heartbeat_url_backup`/`heartbeat_url_wal_freshness`/
# `heartbeat_url_host_checks`) and wiring them into `compose.prod.yaml`/
# `/etc/peppercheck/monitor.env` remains the manual/future step MONITORING.md
# §4 already documents.
#
# --- set +e note (same pattern as steps 60/70/80) ---------------------------
# The orchestrator runs each step's reconcile_* function under `set +e`
# (infra-foundation-setup.sh: `set +e; "$fn"; rc=$?; set -e`), so `set -e` is
# OFF by the time reconcile_monitoring runs for real. Every command
# substitution below whose failure must abort is guarded with an explicit
# `|| { ...; return 1; }` — a bare `return 1` inside a function invoked as
# `x="$(fn ...)"` only exits that command-substitution subshell; it does NOT
# propagate to the caller without an explicit check of `$?`.
set -euo pipefail

# --- Provider wrapper — overridden by bats tests, never called directly. ---
# bs_api METHOD PATH [JSON_BODY] — curl to the Better Stack Uptime API v2,
# bearer-token auth. Fail-closed: any non-2xx response or transport error
# aborts with a clear message (curl -fsS's own exit status), so a caller
# composing `x="$(bs_api ...)"` never silently proceeds on a stale/empty
# response. The token itself is never logged.
bs_api() {
  local method="$1" path="$2" body="${3:-}"
  local -a args=(
    -fsS -X "$method"
    -H "Authorization: Bearer ${BETTERSTACK_API_TOKEN}"
    -H "Accept: application/json"
  )
  [ -n "$body" ] && args+=(-H "Content-Type: application/json" --data "$body")
  local response
  if ! response="$(curl "${args[@]}" "https://uptime.betterstack.com/api/v2${path}")"; then
    log_err "Better Stack API call failed: ${method} ${path} (non-2xx response or network error)"
    return 1
  fi
  printf '%s' "$response"
}

# --- jq-based list-response parsers, each behind its own stubbable helper --
# (same convention as step 70's _dns_a_record_fields / step 30's
# acl_satisfied): the bats/bats:latest image this suite runs in has no jq, so
# tests stub these directly instead of feeding real API JSON through jq.

# _bs_monitor_url_exists MONITORS_JSON URL — true iff a monitor with this
# exact `attributes.url` is present in a GET /monitors response.
_bs_monitor_url_exists() {
  local json="$1" url="$2"
  jq -e --arg u "$url" 'any(.data[]?; .attributes.url == $u)' >/dev/null 2>&1 <<<"$json"
}

# _bs_heartbeat_name_exists HEARTBEATS_JSON NAME — true iff a heartbeat with
# this exact `attributes.name` is present in a GET /heartbeats response.
_bs_heartbeat_name_exists() {
  local json="$1" name="$2"
  jq -e --arg n "$name" 'any(.data[]?; .attributes.name == $n)' >/dev/null 2>&1 <<<"$json"
}

# _do_alert_exists ALERTS_JSON TYPE ENTITY_ID — true iff a `doctl monitoring
# alert list -o json` array already has a policy of this `type` targeting
# this Droplet id in its `entities`.
_do_alert_exists() {
  local json="$1" type="$2" entity="$3"
  jq -e --arg t "$type" --arg e "$entity" \
    'any(.[]?; .type == $t and ((.entities // []) | index($e) != null))' \
    >/dev/null 2>&1 <<<"$json"
}

# _heartbeat_period_grace SERVICE — echoes "PERIOD GRACE" (seconds), chosen
# generously above each script's actual cadence per MONITORING.md §2 step 2
# (worker: a few minutes; backup: ~36h; wal-freshness: ~6 minutes;
# host-checks: ~15 minutes) so ordinary jitter never pages, but a genuinely
# stopped process does within an acceptable window.
_heartbeat_period_grace() {
  case "$1" in
    worker) printf '300 120' ;;          # 5m + 2m grace = 7m total
    backup) printf '86400 43200' ;;      # 24h + 12h grace = 36h total
    wal-freshness) printf '120 240' ;;   # 2m + 4m grace = 6m total
    host-checks) printf '300 600' ;;     # 5m + 10m grace = 15m total
    *) return 1 ;;
  esac
}

# ensure_uptime_monitors PUBLIC_DOMAIN PAGING_FIELDS
ensure_uptime_monitors() {
  local public_domain="$1" paging_fields="$2"
  local monitors_json=""
  monitors_json="$(bs_api GET /monitors)" || {
    log_err "failed to list existing Better Stack uptime monitors"
    return 1
  }

  local path url name body
  for path in livez readyz; do
    url="https://${public_domain}/${path}"
    if _bs_monitor_url_exists "$monitors_json" "$url"; then
      log_info "Better Stack uptime monitor for ${url} already exists — no change"
      continue
    fi
    name="pc-${ENV_NAME} ${path}"
    body="$(printf '{"monitor_type":"status","url":"%s","pronounceable_name":"%s","ssl_expiration":14%s}' \
      "$url" "$name" "$paging_fields")"
    run_mutation "create Better Stack uptime monitor '${name}' for ${url} (status check + 14-day TLS-expiry alert)" \
      bs_api POST /monitors "$body" || {
      log_err "failed to create Better Stack uptime monitor for ${url}"
      return 1
    }
    log_ok "created Better Stack uptime monitor '${name}' for ${url}"
  done
}

# ensure_heartbeat_monitors ENV PAGING_FIELDS
ensure_heartbeat_monitors() {
  local env="$1" paging_fields="$2"
  local heartbeats_json=""
  heartbeats_json="$(bs_api GET /heartbeats)" || {
    log_err "failed to list existing Better Stack heartbeats"
    return 1
  }

  local service name period_grace period grace body
  for service in worker backup wal-freshness host-checks; do
    name="pc-${env} ${service}"
    if _bs_heartbeat_name_exists "$heartbeats_json" "$name"; then
      log_info "Better Stack heartbeat '${name}' already exists — no change"
      continue
    fi
    period_grace="$(_heartbeat_period_grace "$service")" || {
      log_err "no period/grace configured for heartbeat service '${service}' (bug: not in the loop's known list)"
      return 1
    }
    read -r period grace <<<"$period_grace"
    body="$(printf '{"name":"%s","period":%s,"grace":%s%s}' \
      "$name" "$period" "$grace" "$paging_fields")"
    run_mutation "create Better Stack heartbeat '${name}' (period=${period}s grace=${grace}s)" \
      bs_api POST /heartbeats "$body" || {
      log_err "failed to create Better Stack heartbeat '${name}'"
      return 1
    }
    log_ok "created Better Stack heartbeat '${name}' — copy its ping URL from the Better Stack dashboard into the '${env}' BWS project as heartbeat_url_${service//-/_} (see MONITORING.md §4); this script does not read the URL back out of the create response (never logs it)"
  done
}

# ensure_do_host_alerts ENV ALERT_EMAIL
ensure_do_host_alerts() {
  local env="$1" alert_email="$2"
  local droplet_name="pc-${env}" droplet_id=""
  droplet_id="$(doctl_cli compute droplet get "$droplet_name" --format ID --no-header)" || {
    log_err "could not query the Droplet id of ${droplet_name} via doctl (expired/rate-limited DO token, or a network error) — run step 60 (droplet) first"
    return 1
  }
  if [ -z "$droplet_id" ]; then
    log_err "Droplet ${droplet_name} was found but has no id, or does not exist — run step 60 (droplet) first, then re-run this step"
    return 1
  fi

  local alerts_json=""
  alerts_json="$(doctl_cli monitoring alert list -o json)" || {
    log_err "failed to list existing DigitalOcean alert policies"
    return 1
  }

  local metric type
  for metric in cpu memory disk; do
    case "$metric" in
      cpu) type="v1/insights/droplet/cpu" ;;
      memory) type="v1/insights/droplet/memory_utilization_percent" ;;
      disk) type="v1/insights/droplet/disk_utilization_percent" ;;
    esac
    if _do_alert_exists "$alerts_json" "$type" "$droplet_id"; then
      log_info "DigitalOcean ${metric} alert policy for ${droplet_name} already exists — no change"
      continue
    fi
    run_mutation "create DigitalOcean ${metric} alert policy for ${droplet_name} (>80%, 5m window, notify ${alert_email})" \
      doctl_cli monitoring alert create \
        --type "$type" --compare GreaterThan --value 80 --window 5m \
        --entities "$droplet_id" --emails "$alert_email" \
        --description "pc-${env} ${metric} > 80%" || {
      log_err "failed to create DigitalOcean ${metric} alert policy for ${droplet_name}"
      return 1
    }
    log_ok "created DigitalOcean ${metric} alert policy for ${droplet_name}"
  done
}

reconcile_monitoring() {
  local missing=() bs_token="" do_token="" public_domain="" alert_email=""
  bs_token="$(require_cfg BETTERSTACK_API_TOKEN)" || missing+=(BETTERSTACK_API_TOKEN)
  do_token="$(require_cfg DO_TOKEN)" || missing+=(DO_TOKEN)
  public_domain="$(require_cfg PUBLIC_DOMAIN)" || missing+=(PUBLIC_DOMAIN)
  alert_email="$(require_cfg ALERT_EMAIL)" || missing+=(ALERT_EMAIL)
  if [ "${#missing[@]}" -gt 0 ]; then
    need_manual "${missing[*]}" \
      "Create a Better Stack Uptime API token (team-scoped) in the Better Stack dashboard (Settings -> API tokens). DO_TOKEN/PUBLIC_DOMAIN are ordinary config/${ENV_NAME:-target}.env values (see RUNBOOK.md §1) if those are what's actually missing. ALERT_EMAIL is the address DigitalOcean host alerts notify — use a dashboard-only alias nobody's on-call watches for staging, the real on-call address for production." \
      || return $?
  fi
  export BETTERSTACK_API_TOKEN="$bs_token"
  # doctl reads its access token from DIGITALOCEAN_ACCESS_TOKEN when not
  # already authenticated via `doctl auth init` (see reconcile_droplet in
  # steps/60-droplet.sh for the doctl README citation on this env var).
  export DIGITALOCEAN_ACCESS_TOKEN="$do_token" DO_TOKEN="$do_token"

  # ENV_NAME is part of every monitor/heartbeat/alert NAME below (pc-<env>
  # ...); the orchestrator always exports it, so an empty value here only
  # catches a direct-invocation misuse (matches step 40's ENV_NAME guard).
  local env="${ENV_NAME:-}"
  if [ -z "$env" ]; then
    log_err "ENV_NAME is empty — refusing to create ambiguously-named monitors/heartbeats/alerts"
    return 1
  fi

  # Staging: disable every Better Stack notification channel on every
  # monitor/heartbeat this step creates (see the file header for why this,
  # not a policy_id, is the mechanism). Production: omit the fields entirely
  # so the account's own default notification/escalation config applies.
  local paging_fields=""
  if [ "$env" = staging ]; then
    paging_fields=',"call":false,"sms":false,"email":false,"push":false,"critical_alert":false'
  fi

  ensure_uptime_monitors "$public_domain" "$paging_fields" || return 1
  ensure_heartbeat_monitors "$env" "$paging_fields" || return 1
  ensure_do_host_alerts "$env" "$alert_email" || return 1
}
