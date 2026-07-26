#!/usr/bin/env bash
# Step 60: create the DigitalOcean Droplet that runs bootstrap.sh via
# cloud-init, mint the deploy pipeline's SSH keypair, and capture the
# Droplet's SSH host key.
#
# --- Idempotency -------------------------------------------------------------
# Droplet EXISTENCE is the source of truth: a `pc-${ENV_NAME}` line in
# `doctl compute droplet list` present/absent, nothing else. If the Droplet
# already exists, the deploy keypair and host key were already provisioned by
# whichever run created it (see below for why both are tied to the Droplet's
# own lifecycle), so this step is a pure no-op past that check — it never
# re-mints a keypair or re-scans a host key for an existing Droplet. Crucially,
# this check is FAIL-CLOSED: a failed list query (expired token, network blip)
# is treated as UNKNOWN and aborts, never as "absent" — else a transient
# failure would create a duplicate same-named Droplet (see droplet_status).
#
# --- Why bootstrap.sh is delivered via cloud-init write_files, not git clone -
# The Droplet has no way to `git clone` this private repo (no deploy
# credential belongs there, and putting one there would defeat the point of
# keeping the repo private). Instead, this step reads bootstrap.sh AND the 3
# on-Droplet helper scripts it installs (backend/scripts/{switch-deployment,
# write-secret,rollback}.sh — see bootstrap.sh's own "helper_src" lookup)
# straight off the machine running this setup script, and embeds their exact
# bytes into the generated cloud-init user-data as base64-encoded
# `write_files` entries. They land at /opt/pc-bootstrap/... on the Droplet,
# preserving the SAME relative layout bootstrap.sh expects at runtime
# (`$script_dir/../../scripts`) so its own helper-file lookup needs no
# change:
#   /opt/pc-bootstrap/backend/deploy/provision/bootstrap.sh
#   /opt/pc-bootstrap/backend/scripts/{switch-deployment,write-secret,rollback}.sh
# A `runcmd` entry then runs bootstrap.sh once, as root, passing
# TAILSCALE_TAG/TAILSCALE_AUTH_KEY/DEPLOY_SSH_PUBLIC_KEY as env (list-form
# runcmd entry — no shell involved, so the public key's embedded spaces need
# no shell quoting). Docs: cloud-init `write_files` module supports
# `encoding: b64` for arbitrary file content, and `runcmd` entries may be
# either a shell command string or a list of literal argv elements executed
# directly — https://docs.cloud-init.io/en/latest/reference/modules.html
# (write_files / runcmd sections).
#
# --- Secret hygiene ----------------------------------------------------------
# TAILSCALE_AUTH_KEY ends up in this user-data document in PLAINTEXT. Accepted:
# it is the EPHEMERAL, single-use, 600-second-TTL key step 30 mints fresh for
# this run (never reusable once consumed or expired), and DigitalOcean's
# user-data is only reachable via the Droplet's own metadata service or a
# caller who already holds write access to the DO account — not a wider
# exposure than DO_TOKEN itself already implies. The deploy keypair's PUBLIC
# half is not a secret either way. The PRIVATE half is generated to a 0600
# temp file, stored as the SSH_DEPLOY_KEY GitHub Environment secret, and the
# temp file is removed immediately after — it is never logged or echoed to
# stdout/stderr. The Droplet's SSH host key is public and safe to log.
set -euo pipefail

# --- Provider wrappers — overridden by bats tests, never called directly. ---
doctl_cli() { command doctl "$@"; }
ssh_keygen() { command ssh-keygen "$@"; }
ssh_keyscan() { command ssh-keyscan "$@"; }

# A current Ubuntu LTS image slug (DigitalOcean docs: "Choosing an operating
# system image" lists ubuntu-24-04-x64 as the current default Ubuntu LTS
# slug for Droplet creation) — https://docs.digitalocean.com/products/droplets/details/images/
DROPLET_IMAGE="ubuntu-24-04-x64"

# --- Paths for embedding bootstrap.sh + its 3 helper scripts -----------------
# bootstrap.sh always sits next to this steps/ directory in the real repo
# layout, so PROVISION_DIR/BOOTSTRAP_SRC need no override — the bats Docker
# image mounts the whole backend/deploy/provision/ folder, so bootstrap.sh is
# reachable there too. BACKEND_SCRIPTS_DIR defaults to the real repo layout
# (`../../scripts` from provision/, matching bootstrap.sh's own
# `$script_dir/../../scripts` helper_src lookup at runtime) but IS
# override-able via env var: the bats Docker image mounts ONLY
# backend/deploy/provision/, not the wider repo, so backend/scripts/ does not
# exist inside that container — tests point this at fixture helper scripts
# under $BATS_TEST_TMPDIR instead.
PROVISION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP_SRC="${PROVISION_DIR}/bootstrap.sh"
: "${BACKEND_SCRIPTS_DIR:=${PROVISION_DIR}/../../scripts}"

# droplet_status NAME — echoes "present"/"absent" and returns 0 when the
# answer is UNAMBIGUOUS; returns non-zero (nothing echoed) when the query
# itself failed so the answer is UNKNOWN. This distinction is load-bearing
# for the idempotency invariant: `doctl compute droplet get "$1"` returning
# non-zero conflates "no such Droplet" with "the API call failed" (expired/
# rate-limited token, network blip), and treating a transient failure as
# "absent" would proceed to `droplet create` and spin up a SECOND Droplet
# with the same name (DO Droplet names are NOT unique) plus a fresh
# keypair/host-key overwrite. So instead we list all Droplet names and
# check the list command's OWN exit status separately: a failed `list`
# aborts (UNKNOWN), never silently reads as "absent".
#
# `doctl compute droplet list --format Name --no-header` prints one Droplet
# name per line —
# https://docs.digitalocean.com/reference/doctl/reference/compute/droplet/list/
# (this also removes any dependency on `droplet get`'s undocumented
# name-vs-ID resolution).
droplet_status() {
  local name="$1" names
  names="$(doctl_cli compute droplet list --format Name --no-header)" || return 1
  if grep -qx "$name" <<<"$names"; then
    printf 'present'
  else
    printf 'absent'
  fi
}

# _yaml_dq STRING — double-quote a string for embedding as a YAML flow
# scalar (used in the runcmd list-of-args entry), escaping backslash and
# embedded double quotes so odd values (unlikely here, but never assume)
# can't break the document.
_yaml_dq() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '"%s"' "$s"
}

# _write_file_entry PATH SRC_FILE — emits one cloud-init `write_files` list
# item embedding SRC_FILE's exact bytes as base64 (encoding: b64 — arbitrary
# script content survives YAML untouched this way, unlike inlining raw text
# under a `|` block scalar). Fails closed if SRC_FILE is missing so a
# misconfigured BACKEND_SCRIPTS_DIR/PROVISION_DIR never silently ships a
# Droplet with a partial bootstrap payload.
_write_file_entry() {
  local path="$1" src="$2"
  if [ ! -f "$src" ]; then
    log_err "cloud-init source file not found: ${src}"
    return 1
  fi
  echo "  - path: ${path}"
  echo "    owner: root:root"
  echo "    permissions: '0755'"
  echo "    encoding: b64"
  echo "    content: |"
  # Piped via stdin (not a positional file argument): GNU/BusyBox base64
  # accept either form, but macOS/BSD base64 only accepts a file via `-i`
  # and errors on a bare positional path — stdin redirection is the one form
  # every base64 implementation this script might run under accepts.
  base64 <"$src" | sed 's/^/      /'
}

# render_cloud_init OUTFILE DEPLOY_PUBLIC_KEY TS_TAG TS_AUTH_KEY — writes a
# #cloud-config user-data document to OUTFILE. See the file header for why
# write_files (not git clone) and for the accepted TAILSCALE_AUTH_KEY
# plaintext exposure.
render_cloud_init() {
  local outfile="$1" deploy_pub_key="$2" ts_tag="$3" ts_auth_key="$4"
  {
    echo "#cloud-config"
    echo "write_files:"
    _write_file_entry /opt/pc-bootstrap/backend/deploy/provision/bootstrap.sh "$BOOTSTRAP_SRC"
    _write_file_entry /opt/pc-bootstrap/backend/scripts/switch-deployment.sh "${BACKEND_SCRIPTS_DIR}/switch-deployment.sh"
    _write_file_entry /opt/pc-bootstrap/backend/scripts/write-secret.sh "${BACKEND_SCRIPTS_DIR}/write-secret.sh"
    _write_file_entry /opt/pc-bootstrap/backend/scripts/rollback.sh "${BACKEND_SCRIPTS_DIR}/rollback.sh"
    echo "runcmd:"
    printf '  - [ "env", %s, %s, %s, "bash", "/opt/pc-bootstrap/backend/deploy/provision/bootstrap.sh" ]\n' \
      "$(_yaml_dq "TAILSCALE_TAG=${ts_tag}")" \
      "$(_yaml_dq "TAILSCALE_AUTH_KEY=${ts_auth_key}")" \
      "$(_yaml_dq "DEPLOY_SSH_PUBLIC_KEY=${deploy_pub_key}")"
  } >"$outfile"
}

# ensure_deploy_keypair — generates a FRESH ed25519 deploy keypair (a fresh
# Droplet always gets a fresh key; see the file header on why tying the key
# to the Droplet's own lifecycle is correct and simplest here), stores the
# PRIVATE half as the SSH_DEPLOY_KEY GitHub Environment secret, and echoes
# the PUBLIC half on stdout for the caller to embed in cloud-init. The temp
# key directory is removed as soon as the material is read AND on the
# ssh-keygen failure path (an explicit `if ! …; then rm; return` guard,
# rather than a `trap … RETURN` — under bats' functrace a RETURN trap fires
# on every nested function return, which is both wrong-scoped and premature)
# so the private key can never be left on the operator's disk. Nothing logged.
ensure_deploy_keypair() {
  local key_dir key_path priv_key pub_key
  key_dir="$(mktemp -d)"
  key_path="${key_dir}/deploy_key"
  if ! ssh_keygen -t ed25519 -N "" -C "deploy@peppercheck-ci" -f "$key_path" >/dev/null; then
    rm -rf "$key_dir"
    log_err "ssh-keygen failed to generate the deploy keypair"
    return 1
  fi
  priv_key="$(cat "$key_path")"
  pub_key="$(cat "${key_path}.pub")"
  rm -rf "$key_dir"

  run_mutation "store deploy private key as GitHub Environment secret SSH_DEPLOY_KEY" \
    gh_secret_set SSH_DEPLOY_KEY "$priv_key" 1>&2
  log_ok "generated deploy SSH keypair; stored the private half as SSH_DEPLOY_KEY (value not logged)"
  printf '%s' "$pub_key"
}

# poll_ssh_host_key HOST — polls `ssh-keyscan` against HOST (the tailnet
# MagicDNS name) until it returns a non-empty known_hosts-format line, or
# gives up after SSH_HOST_KEY_POLL_TIMEOUT seconds (default 300; both the
# timeout and the poll interval are overridable via env for fast bats
# coverage of the give-up path). Bounded so a machine that is NOT itself on
# the tailnet fails clearly instead of hanging: `doctl ... --wait` only
# confirms the Droplet's own boot-complete action, not that cloud-init's
# runcmd (which brings Tailscale up as one of bootstrap.sh's own idempotent
# steps) has finished running inside it yet.
poll_ssh_host_key() {
  local host="$1"
  local timeout="${SSH_HOST_KEY_POLL_TIMEOUT:-300}"
  local interval="${SSH_HOST_KEY_POLL_INTERVAL:-10}"
  local elapsed=0 result=""
  while [ "$elapsed" -lt "$timeout" ]; do
    if result="$(ssh_keyscan "$host" 2>/dev/null)" && [ -n "$result" ]; then
      printf '%s' "$result"
      return 0
    fi
    sleep "$interval"
    elapsed=$((elapsed + interval))
  done
  return 1
}

reconcile_droplet() {
  local do_token=""
  do_token="$(require_cfg DO_TOKEN)" || {
    need_manual DO_TOKEN "Create a DigitalOcean API token (write scope) in the DO control panel"
    return $?
  }
  # doctl reads its access token from DIGITALOCEAN_ACCESS_TOKEN when not
  # already authenticated via `doctl auth init` — confirmed against doctl's
  # own README, "Authenticating with DigitalOcean" section
  # ("DIGITALOCEAN_ACCESS_TOKEN=my-do-token doctl ...", noting Docker/
  # non-interactive users must use this env var instead of `auth init`):
  # https://github.com/digitalocean/doctl#readme
  export DIGITALOCEAN_ACCESS_TOKEN="$do_token"

  local droplet_name="pc-${ENV_NAME:-}" status=""
  status="$(droplet_status "$droplet_name")" || {
    log_err "could not list Droplets to determine whether ${droplet_name} exists (expired/rate-limited DO token or network error) — aborting rather than risk creating a duplicate Droplet"
    return 1
  }
  if [ "$status" = "present" ]; then
    log_ok "Droplet ${droplet_name} already exists — Droplet, deploy keypair, and host key are already provisioned, skipping"
    return 0
  fi

  # Only reached when the Droplet is ABSENT — see the file header.
  local ts_auth_key=""
  ts_auth_key="$(require_cfg TS_AUTH_KEY)" || {
    need_manual TS_AUTH_KEY \
      "Run the full sequence (not --only droplet) so step 30 mints the Tailscale auth key first — the Droplet needs it to join the tailnet during bootstrap (it's a short-TTL ephemeral key, so it can't just be looked up after the fact)"
    return $?
  }

  local missing=() do_region="" do_size="" ssh_host="" ts_tag=""
  do_region="$(require_cfg DO_REGION)" || missing+=(DO_REGION)
  do_size="$(require_cfg DO_SIZE)" || missing+=(DO_SIZE)
  ssh_host="$(require_cfg SSH_HOST)" || missing+=(SSH_HOST)
  ts_tag="$(require_cfg TS_TAG)" || missing+=(TS_TAG)
  if [ "${#missing[@]}" -gt 0 ]; then
    need_manual "${missing[*]}" \
      "Set the missing non-secret config value(s) in config/${ENV_NAME:-target}.env (see RUNBOOK.md §1.6)." \
      || return $?
  fi

  # Explicit `|| return 1`: the orchestrator runs each step under `set +e`
  # (infra-foundation-setup.sh: `set +e; "$fn"; rc=$?; set -e`), so `set -e`
  # is OFF inside reconcile_droplet and a bare `return 1` from
  # ensure_deploy_keypair (its ssh-keygen-failure path) would be silently
  # swallowed here — leaving deploy_pub_key="" and going on to create a real
  # Droplet with an empty DEPLOY_SSH_PUBLIC_KEY. (ensure_deploy_keypair
  # already cleans its own key dir on failure, and the cloud-init dir isn't
  # created yet, so no cleanup is needed at this point.)
  local deploy_pub_key=""
  deploy_pub_key="$(ensure_deploy_keypair)" || {
    log_err "deploy keypair generation failed; aborting before creating a Droplet"
    return 1
  }

  # The rendered cloud-init file contains the plaintext ephemeral
  # TAILSCALE_AUTH_KEY, so it must never survive an abnormal exit. Explicit
  # `if ! …; then rm; return` guards clean it up on the render- and
  # create-failure paths, plus the explicit removal right after a successful
  # create — chosen over a `trap … RETURN` because bats runs with functrace,
  # under which a RETURN trap fires on every nested-function return (deleting
  # the dir before `doctl create` reads it, and firing before the local is
  # even in scope). These guards are correct regardless of functrace or the
  # orchestrator's `set +e` wrapping around the reconcile call.
  local cloud_init_dir cloud_init_file
  cloud_init_dir="$(mktemp -d)"
  cloud_init_file="${cloud_init_dir}/user-data.yaml"
  if ! render_cloud_init "$cloud_init_file" "$deploy_pub_key" "$ts_tag" "$ts_auth_key"; then
    rm -rf "$cloud_init_dir"
    log_err "failed to render the cloud-init user-data document"
    return 1
  fi

  if ! run_mutation "create Droplet ${droplet_name} (${do_region}, ${do_size}, ${DROPLET_IMAGE})" \
    doctl_cli compute droplet create "$droplet_name" \
      --region "$do_region" --size "$do_size" --image "$DROPLET_IMAGE" \
      --user-data-file "$cloud_init_file" --wait; then
    rm -rf "$cloud_init_dir"
    log_err "doctl compute droplet create failed for ${droplet_name}"
    return 1
  fi

  rm -rf "$cloud_init_dir"

  if is_dry_run; then
    log_info "[dry-run] skipping host-key capture (the Droplet was not actually created)"
    return 0
  fi

  log_info "polling for the Droplet's SSH host key over tailnet host ${ssh_host} — this machine must itself be on the tailnet (MagicDNS must resolve '${ssh_host}')"
  local host_key=""
  if ! host_key="$(poll_ssh_host_key "$ssh_host")"; then
    log_err "could not ssh-keyscan ${ssh_host} within the poll window — re-run this step from a machine connected to the tailnet, or capture the host key manually per RUNBOOK.md §1.6 and store it as the SSH_HOST_KEY GitHub Environment secret"
    return 1
  fi
  log_ok "captured SSH host key for ${ssh_host} (public value, safe to log): ${host_key}"

  run_mutation "store Droplet host key as GitHub Environment secret SSH_HOST_KEY" \
    gh_secret_set SSH_HOST_KEY "$host_key"
}
