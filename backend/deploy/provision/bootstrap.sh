#!/usr/bin/env bash
# bootstrap.sh -- idempotent provisioning for a fresh DigitalOcean Ubuntu
# Droplet into a PepperCheck deploy target.
#
# Run ONCE as root, from a checked-out copy of this repo on the Droplet
# (e.g. `git clone` over the console, or `scp`'d up), then safe to re-run any
# number of times -- every step below is guarded so a second run only fixes
# drift, it never re-does work or fails on "already exists".
#
#   sudo TAILSCALE_TAG=tag:pc-staging TAILSCALE_AUTH_KEY=tskey-... \
#     DEPLOY_SSH_PUBLIC_KEY="ssh-ed25519 AAAA... deploy@ci" \
#     ./backend/deploy/provision/bootstrap.sh
#
# *** WARNING -- read before running over a plain public-IP SSH session ***
# The ufw step below makes port 22 reachable ONLY on the `tailscale0`
# interface (design doc §6.5/§10: "SSH only via the tailnet"). The moment
# `ufw --force enable` runs, a session connected over the Droplet's public
# IP is cut immediately, mid-script. Run this either:
#   - from the DigitalOcean web console (never touches the network), or
#   - over an SSH session that is ALREADY on the tailnet (i.e. Tailscale is
#     already up on this Droplet from a prior run of this same script).
# There is no way to make this step safe for a first-time plain-IP SSH
# session and still land on the design's SSH-only-via-tailnet posture --
# that is the intended trade-off, not a bug.
#
# Configuration (env vars; secrets are never written to disk by this script):
#   TAILSCALE_TAG           Required the first time Tailscale is brought up
#                            (i.e. whenever `tailscale status` isn't already
#                            Running). One of the tags the tailnet ACL grants
#                            tag:ci-deploy -> SSH (22), e.g. tag:pc-staging or
#                            tag:pc-prod (design doc §10/§6.5) -- staging vs
#                            prod use different tags, so this is parameterized
#                            rather than hardcoded.
#   TAILSCALE_AUTH_KEY      Required alongside TAILSCALE_TAG (same condition).
#                            A Tailscale auth key scoped to TAILSCALE_TAG.
#   DEPLOY_SSH_PUBLIC_KEY   Optional but expected before first deploy. Public
#                            half of the deploy pipeline's SSH_DEPLOY_KEY
#                            (deploy-vps.yml writes the private half to the
#                            runner's ~/.ssh/id and connects as
#                            deploy@<tailnet host>). If unset, this step is
#                            skipped and the operator must append it to
#                            /home/deploy/.ssh/authorized_keys by hand before
#                            SSH hardening (below) is safe to enable.
#   SSH_PERMIT_ROOT_LOGIN   Optional, default "prohibit-password" (root login
#                            still possible via SSH key, password login
#                            disabled). Set to "no" for a stricter posture.
#
# Every step is guarded (command -v / getent / id -u / ufw show added / [ -f
# ] / dpkg -s, etc.) so re-running is a no-op past the first successful run,
# and a partially-failed run can simply be re-invoked.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "bootstrap: must run as root (e.g. sudo $0)" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

log() { echo "bootstrap: $*"; }

# --- 0. Package index -------------------------------------------------------
# Refreshed unconditionally on every run (cheap, and every apt-get install
# below is itself guarded against re-installing) so newly-added apt repos
# (Docker's, Tailscale's) are always picked up in the same run they're added.
apt-get update -y

# --- 1. Docker Engine + compose plugin --------------------------------------
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  log "docker + compose plugin already present, skipping install"
else
  log "installing docker + compose plugin"
  apt-get install -y ca-certificates curl
  install -m 0755 -d /etc/apt/keyrings
  if [ ! -f /etc/apt/keyrings/docker.asc ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
  fi
  # shellcheck source=/dev/null
  . /etc/os-release
  arch="$(dpkg --print-architecture)"
  cat >/etc/apt/sources.list.d/docker.list <<EOF
deb [arch=$arch signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $VERSION_CODENAME stable
EOF
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

# --- 2. Non-root `deploy` user, in the `docker` group -----------------------
# Root-equivalent via `docker run` -- the accepted trust model (design doc
# §6.5): the real trust boundary is SSH/tailnet access, not this group
# membership, so no attempt is made to sandbox `deploy` further.
if id -u deploy >/dev/null 2>&1; then
  log "user 'deploy' already exists, skipping useradd"
else
  log "creating user 'deploy'"
  useradd --create-home --shell /bin/bash deploy
fi

getent group docker >/dev/null || groupadd docker

if id -nG deploy | tr ' ' '\n' | grep -qx docker; then
  log "'deploy' already in docker group"
else
  usermod -aG docker deploy
fi

# --- 3. Tailscale install + tagged `up` -------------------------------------
if command -v tailscale >/dev/null 2>&1; then
  log "tailscale already installed, skipping install"
else
  log "installing tailscale"
  # shellcheck source=/dev/null
  . /etc/os-release
  install -m 0755 -d /usr/share/keyrings
  curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${VERSION_CODENAME}.noarmor.gpg" \
    -o /usr/share/keyrings/tailscale-archive-keyring.gpg
  curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${VERSION_CODENAME}.tailscale-keyring.list" \
    -o /etc/apt/sources.list.d/tailscale.list
  apt-get update -y
  apt-get install -y tailscale
  systemctl enable --now tailscaled
fi

if tailscale status --json 2>/dev/null | grep -q '"BackendState": *"Running"'; then
  log "tailscale already up, skipping tailscale up"
else
  : "${TAILSCALE_TAG:?TAILSCALE_TAG is required (e.g. tag:pc-staging) -- tailscale is not up yet on this Droplet}"
  : "${TAILSCALE_AUTH_KEY:?TAILSCALE_AUTH_KEY is required -- tailscale is not up yet on this Droplet}"
  case "$TAILSCALE_TAG" in
    tag:*) ;;
    *)
      echo "bootstrap: TAILSCALE_TAG must start with 'tag:' (got '$TAILSCALE_TAG')" >&2
      exit 1
      ;;
  esac
  log "bringing tailscale up with tag $TAILSCALE_TAG"
  tailscale up --authkey="$TAILSCALE_AUTH_KEY" --advertise-tags="$TAILSCALE_TAG" --accept-dns=true
fi

# --- 4. ufw: deny by default, SSH only on the tailnet, Caddy public --------
# See the WARNING at the top of this file -- this is the step that cuts any
# plain public-IP SSH session the moment it enables.
if command -v ufw >/dev/null 2>&1; then
  log "ufw already installed, skipping install"
else
  apt-get install -y ufw
fi

ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null

added_rules="$(ufw show added)"

if echo "$added_rules" | grep -qF "allow in on tailscale0 to any port 22"; then
  log "ufw tailscale0 SSH rule already present"
else
  # Deliberately NOT `ufw allow 22` -- that would open SSH on every
  # interface, including the public one. Bound to tailscale0 only.
  ufw allow in on tailscale0 to any port 22
fi

if echo "$added_rules" | grep -qF "allow 80,443/tcp"; then
  log "ufw Caddy public rule already present"
else
  ufw allow 80,443/tcp
fi

if ufw status | grep -q "^Status: active"; then
  log "ufw already enabled"
else
  ufw --force enable
fi

# --- 5. fail2ban -------------------------------------------------------------
if dpkg -s fail2ban >/dev/null 2>&1; then
  log "fail2ban already installed"
else
  apt-get install -y fail2ban
fi
systemctl enable --now fail2ban

# --- 6. unattended-upgrades --------------------------------------------------
if dpkg -s unattended-upgrades >/dev/null 2>&1; then
  log "unattended-upgrades already installed"
else
  apt-get install -y unattended-upgrades
fi
# Idempotent by construction: writing the same two lines every run leaves the
# file's content (and therefore its effect) unchanged.
cat >/etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
systemctl enable --now unattended-upgrades

# --- 7. /opt/peppercheck layout, owned by deploy ----------------------------
mkdir -p /opt/peppercheck/deployments /opt/peppercheck/scripts
chown -R deploy:deploy /opt/peppercheck

# --- 8. On-Droplet helper scripts ------------------------------------------
# switch-deployment.sh and rollback.sh are invoked as
# /opt/peppercheck/scripts/<name>.sh by remote-deploy.sh, rollback.sh itself,
# and smoke-or-rollback.sh (over SSH from the CI runner) -- installed here,
# ONCE per Droplet, independent of any single release's deployments/<id>/
# copy that ship-deployment.sh rsyncs in alongside compose.prod.yaml.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
helper_src="$script_dir/../../scripts"

for helper in switch-deployment.sh write-secret.sh rollback.sh; do
  if [ ! -f "$helper_src/$helper" ]; then
    echo "bootstrap: $helper_src/$helper not found -- run bootstrap.sh from a checked-out copy of the repo (backend/deploy/provision/bootstrap.sh alongside backend/scripts/)" >&2
    exit 1
  fi
  install -m 0755 -o deploy -g deploy "$helper_src/$helper" "/opt/peppercheck/scripts/$helper"
  log "installed $helper -> /opt/peppercheck/scripts/$helper"
done

# --- 9. deploy user's authorized_keys ---------------------------------------
deploy_home="$(getent passwd deploy | cut -d: -f6)"
install -d -m 0700 -o deploy -g deploy "$deploy_home/.ssh"
touch "$deploy_home/.ssh/authorized_keys"
chmod 0600 "$deploy_home/.ssh/authorized_keys"
chown deploy:deploy "$deploy_home/.ssh/authorized_keys"

if [ -n "${DEPLOY_SSH_PUBLIC_KEY:-}" ]; then
  if grep -qxF "$DEPLOY_SSH_PUBLIC_KEY" "$deploy_home/.ssh/authorized_keys"; then
    log "deploy authorized_keys already contains DEPLOY_SSH_PUBLIC_KEY"
  else
    echo "$DEPLOY_SSH_PUBLIC_KEY" >>"$deploy_home/.ssh/authorized_keys"
    log "appended DEPLOY_SSH_PUBLIC_KEY to deploy authorized_keys"
  fi
else
  log "DEPLOY_SSH_PUBLIC_KEY not set -- skipping; operator must append the deploy pipeline's public key to $deploy_home/.ssh/authorized_keys by hand before relying on SSH access as 'deploy'"
fi

# --- 10. SSH hardening -------------------------------------------------------
# Only disable password auth once `deploy` actually has a key installed --
# otherwise this would lock out the very account the deploy pipeline (and any
# operator) needs, with no password fallback left either.
if [ -s "$deploy_home/.ssh/authorized_keys" ]; then
  ssh_permit_root_login="${SSH_PERMIT_ROOT_LOGIN:-prohibit-password}"
  install -d -m 0755 /etc/ssh/sshd_config.d
  cat >/etc/ssh/sshd_config.d/99-peppercheck-hardening.conf <<EOF
PasswordAuthentication no
PermitRootLogin $ssh_permit_root_login
EOF
  if sshd -t; then
    systemctl reload ssh 2>/dev/null || systemctl reload sshd
    log "SSH hardening applied (PasswordAuthentication no, PermitRootLogin $ssh_permit_root_login)"
  else
    echo "bootstrap: sshd -t failed against the new hardening config -- left /etc/ssh/sshd_config.d/99-peppercheck-hardening.conf in place for inspection, did NOT reload sshd" >&2
    exit 1
  fi
else
  log "deploy authorized_keys is empty -- skipping SSH hardening to avoid locking out access; re-run bootstrap after DEPLOY_SSH_PUBLIC_KEY (or a manually-added key) is in place"
fi

log "done"
