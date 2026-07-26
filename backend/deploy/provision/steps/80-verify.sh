#!/usr/bin/env bash
# Step 80: NON-MUTATING verification of the environment's security posture.
# Automates RUNBOOK.md §1.8 ("Verify before the first deploy") and the
# post-first-deploy manual checklist in RUNBOOK.md §2. This step creates or
# changes nothing — it only asserts. Unlike every other step, it therefore
# has NO NEEDS_MANUAL gate: a failed check is a normal, expected outcome to
# report (an assertion failure), not a "go do this in a dashboard" pause. Its
# contract is strictly return 0 (all checks passed) or a non-zero, non-75
# code (one or more checks failed) — see reconcile_verify below.
#
# --- The 4 checks -----------------------------------------------------------
#   1. check_ssh_off_tailnet_refused — SSH to the Droplet's PUBLIC IP must be
#      refused/time out (ufw only allows :22 on the tailscale0 interface, so
#      the public-IP path is blocked even from a machine that is itself on
#      the tailnet).
#   2. check_ufw_tailnet_only — over the tailnet, `sudo ufw status` on the
#      Droplet shows :22 allowed only on tailscale0, and :80/:443 allowed on
#      all interfaces.
#   3. check_tls_le — `https://${PUBLIC_DOMAIN}/readyz` is healthy AND the
#      served certificate is a real Let's Encrypt cert, not Caddy's internal
#      self-signed fallback.
#   4. check_secret_perms — over the tailnet, every file under
#      /opt/peppercheck/deployments/*/secrets/* is mode 0400.
#
# --- Prerequisites -----------------------------------------------------------
#   - Checks 3 and 4 require the FIRST DEPLOY to have already completed
#     (there is no Caddy-issued cert, and no rendered secrets directory,
#     before that). Running this step before the first deploy is expected to
#     report checks 3/4 as FAIL.
#   - Checks 2 and 4 SSH to the Droplet over the tailnet (`deploy@$SSH_HOST`),
#     so the MACHINE RUNNING THIS SCRIPT must itself be joined to the tailnet
#     with MagicDNS resolving $SSH_HOST. If it is not, those checks fail
#     closed (reported as FAIL, not a hang) rather than blocking forever —
#     every ssh/curl call below is bounded with `-o ConnectTimeout=5` /
#     `--max-time`.
#
# --- Each check is its own stubbable helper ---------------------------------
# Exactly like steps 30/70's ts_api/cf_api provider wrappers, every external
# call a check needs (ssh, curl, the openssl cert-issuer pipeline) is behind
# a small named function so bats can override it directly — check_* functions
# themselves are ALSO directly stubbable (reconcile_verify's own tests do
# this), since they are the unit the task asked to aggregate over.
#
# --- set +e note -------------------------------------------------------------
# The orchestrator runs each step's reconcile_* function under `set +e`
# (infra-foundation-setup.sh: `set +e; "$fn"; rc=$?; set -e`), so `set -e` is
# OFF by the time reconcile_verify runs for real. It is NOT necessarily off
# when a bats test calls a check_* function directly (outside of
# reconcile_verify's own `if "$check"; then` — an `if` condition is always
# exempt from errexit regardless), so every command substitution below that
# needs its own output/exit-code inspected is guarded with `|| { ...; return
# 1; }` or wrapped in an `if`, per the pattern established in steps 60/70.
set -euo pipefail

# --- Provider wrappers — overridden by bats tests, never called directly. ---
ssh_cli() { command ssh "$@"; }
curl_cli() { command curl "$@"; }

# _tls_cert_issuer HOST — the openssl s_client/x509 pipeline that reads the
# issuer of the certificate HOST serves on :443, as one stubbable unit (same
# approach as step 70's _dns_a_record_fields wrapping a jq pipeline): the
# bats/bats:latest image this suite runs in has no real network access to a
# live Droplet, so tests stub this function's output directly rather than
# exercising a real TLS handshake.
_tls_cert_issuer() {
  local host="$1"
  openssl s_client -connect "${host}:443" -servername "$host" </dev/null 2>/dev/null |
    openssl x509 -noout -issuer 2>/dev/null
}

# _ufw_status_ok TEXT — true iff `sudo ufw status` output shows :22 allowed
# ONLY on the tailscale0 interface (never unrestricted) and :80/:443 allowed
# on all interfaces. Matches both the IPv4 and "(v6)" line variants ufw
# prints. Factored out (like step 30's acl_satisfied) so the parsing logic is
# isolated from the ssh call; not independently unit-tested here since the
# aggregate check_ufw_tailnet_only tests stub the whole check, matching how
# _dns_a_record_fields's real jq expression is inspection-only in step 70
# (verified by reading, not exercised against a live `ufw status` here).
_ufw_status_ok() {
  local text="$1"
  grep -qE '^22([[:space:]]*\(v6\))?[[:space:]]+on[[:space:]]+tailscale0[[:space:]]+ALLOW' <<<"$text" || return 1
  grep -qE '^22([[:space:]]*\(v6\))?[[:space:]]+ALLOW' <<<"$text" && return 1  # unrestricted :22 present
  grep -qE '^80([[:space:]]*\(v6\))?[[:space:]]+ALLOW' <<<"$text" || return 1
  grep -qE '^443([[:space:]]*\(v6\))?[[:space:]]+ALLOW' <<<"$text" || return 1
  return 0
}

# check_ssh_off_tailnet_refused — queries the Droplet's own public IP (same
# doctl source-of-truth pattern as step 70's reconcile_dns) and attempts an
# ssh login to it. "FAIL = it connects" is interpreted as "ssh got as far as
# authenticating" (a "Permission denied"/host-key response), not merely "ssh
# exited non-zero" — a reachable-but-unauthenticated host ALSO exits
# non-zero, so a bare exit-code check would wrongly report PASS even when
# ufw is not actually blocking the port. Only a genuine connection-level
# failure (timeout/refused, exit 255 with no auth-stage output) is a PASS.
check_ssh_off_tailnet_refused() {
  local do_token=""
  do_token="$(require_cfg DO_TOKEN)" || {
    log_err "check_ssh_off_tailnet_refused: DO_TOKEN is not configured"
    return 1
  }
  # doctl reads DIGITALOCEAN_ACCESS_TOKEN when not already `doctl auth init`'d
  # — see steps/60-droplet.sh for the doctl README citation on this env var.
  export DIGITALOCEAN_ACCESS_TOKEN="$do_token"

  local droplet_name="pc-${ENV_NAME:-}" ip=""
  ip="$(doctl_cli compute droplet get "$droplet_name" --format PublicIPv4 --no-header)" || {
    log_err "check_ssh_off_tailnet_refused: could not query the public IP of Droplet ${droplet_name} via doctl (expired/rate-limited DO token, or a network error)"
    return 1
  }
  if [ -z "$ip" ]; then
    log_err "check_ssh_off_tailnet_refused: Droplet ${droplet_name} has no public IP yet (or does not exist) — run step 60 (droplet) first, then re-run this step"
    return 1
  fi

  local ssh_output="" ssh_rc=0
  if ssh_output="$(ssh_cli -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "deploy@${ip}" true 2>&1)"; then
    ssh_rc=0
  else
    ssh_rc=$?
  fi

  if [ "$ssh_rc" -eq 0 ]; then
    log_err "check_ssh_off_tailnet_refused: SSH to the Droplet's PUBLIC IP ${ip} SUCCEEDED (logged in) — ufw is not restricting :22 to tailscale0"
    return 1
  fi
  case "$ssh_output" in
    *"Permission denied"* | *"Host key verification failed"*)
      log_err "check_ssh_off_tailnet_refused: SSH to the Droplet's PUBLIC IP ${ip} reached the authentication stage — ufw is not blocking :22 off-tailnet. ssh said: ${ssh_output}"
      return 1
      ;;
  esac
  log_ok "check_ssh_off_tailnet_refused: SSH to the Droplet's public IP ${ip} was refused/timed out at the network level, as expected"
  return 0
}

# check_ufw_tailnet_only — over the tailnet, confirm ufw's actual rule shape.
check_ufw_tailnet_only() {
  local ssh_host=""
  ssh_host="$(require_cfg SSH_HOST)" || {
    log_err "check_ufw_tailnet_only: SSH_HOST is not configured"
    return 1
  }
  local ufw_output=""
  ufw_output="$(ssh_cli -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new "deploy@${ssh_host}" 'sudo ufw status' 2>&1)" || {
    log_err "check_ufw_tailnet_only: could not reach ${ssh_host} over the tailnet to run 'sudo ufw status' (is this machine on the tailnet, with MagicDNS resolving '${ssh_host}'?) — ${ufw_output}"
    return 1
  }
  if _ufw_status_ok "$ufw_output"; then
    log_ok "check_ufw_tailnet_only: ufw on ${ssh_host} allows :22 only on tailscale0, and :80/:443 on all interfaces"
    return 0
  fi
  log_err "check_ufw_tailnet_only: ufw status on ${ssh_host} does not match the expected shape (:22 restricted to tailscale0; :80/:443 open) — got: ${ufw_output}"
  return 1
}

# check_tls_le — /readyz is healthy AND the served cert is real Let's Encrypt.
check_tls_le() {
  local domain=""
  domain="$(require_cfg PUBLIC_DOMAIN)" || {
    log_err "check_tls_le: PUBLIC_DOMAIN is not configured"
    return 1
  }
  if ! curl_cli -fsS --max-time 10 "https://${domain}/readyz" >/dev/null 2>&1; then
    log_err "check_tls_le: https://${domain}/readyz did not respond healthy (needs the first deploy to have completed)"
    return 1
  fi
  local issuer=""
  issuer="$(_tls_cert_issuer "$domain")" || {
    log_err "check_tls_le: could not read the TLS certificate served by ${domain}:443"
    return 1
  }
  case "$issuer" in
    *"Let's Encrypt"*)
      log_ok "check_tls_le: ${domain}/readyz is healthy and serving a Let's Encrypt certificate"
      return 0
      ;;
    *)
      log_err "check_tls_le: ${domain} is NOT serving a Let's Encrypt certificate (issuer: ${issuer:-<empty>}) — possibly Caddy's internal self-signed fallback cert"
      return 1
      ;;
  esac
}

# check_secret_perms — over the tailnet, every rendered secret file is 0400.
check_secret_perms() {
  local ssh_host=""
  ssh_host="$(require_cfg SSH_HOST)" || {
    log_err "check_secret_perms: SSH_HOST is not configured"
    return 1
  }
  local perms=""
  perms="$(ssh_cli -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new "deploy@${ssh_host}" 'stat -c %a /opt/peppercheck/deployments/*/secrets/*' 2>&1)" || {
    log_err "check_secret_perms: could not reach ${ssh_host} over the tailnet, or the stat command failed (needs the first deploy to have completed) — ${perms}"
    return 1
  }
  if [ -z "$perms" ]; then
    log_err "check_secret_perms: stat returned no output for /opt/peppercheck/deployments/*/secrets/* on ${ssh_host}"
    return 1
  fi
  local mode
  while IFS= read -r mode; do
    [ -n "$mode" ] || continue
    if [ "$mode" != "0400" ] && [ "$mode" != "400" ]; then
      log_err "check_secret_perms: found a secret file with mode ${mode} on ${ssh_host} (expected 0400)"
      return 1
    fi
  done <<<"$perms"
  log_ok "check_secret_perms: all secret files under /opt/peppercheck/deployments/*/secrets/* on ${ssh_host} are mode 0400"
  return 0
}

# reconcile_verify — runs all 4 checks (always all 4, never short-circuits,
# so one early failure doesn't hide the state of the others), logs a
# pass/fail line per check, and returns 0 iff every check passed. Returns 1
# (a plain assertion failure) if any check failed — this is intentionally
# NEVER $NEEDS_MANUAL (75): unlike every other step, this one has no manual
# action to prompt for, only a pass/fail report.
reconcile_verify() {
  local -a checks=(check_ssh_off_tailnet_refused check_ufw_tailnet_only check_tls_le check_secret_perms)
  local -a failed=()
  local check
  for check in "${checks[@]}"; do
    if "$check"; then
      log_ok "PASS: ${check}"
    else
      log_err "FAIL: ${check}"
      failed+=("$check")
    fi
  done

  if [ "${#failed[@]}" -gt 0 ]; then
    log_err "verification FAILED (${#failed[@]}/${#checks[@]} checks failed): ${failed[*]}"
    return 1
  fi
  log_ok "verification PASSED: all ${#checks[@]} checks succeeded"
  return 0
}
