# PepperCheck VPS Provisioning Runbook

Operator runbook for standing up a PepperCheck deploy environment (Phase 7-A
infrastructure/operations foundation,
`docs/designs/2026-07-25-phase7a-infra-ops-foundation-design.md`
§10). Staging is stood up first; production follows the same steps at
cutover, substituting the `production` values called out inline.

This runbook only documents what the already-implemented pipeline actually
reads — every secret name, GitHub Actions Environment variable, script, and
path below is cross-referenced against the real files:

- `.github/workflows/ci-backend.yml` (`image`, `guard`, `deploy-staging`, `tag-validated` jobs)
- `.github/workflows/deploy-vps.yml` (reusable deploy)
- `.github/workflows/deploy-vps-production.yml` (production promotion)
- `backend/scripts/ship-deployment.sh`, `backend/scripts/install-cli.sh`
- `backend/deploy/provision/bootstrap.sh`
- `backend/compose.prod.yaml`

If a step here does not match one of those files, the file is the source of
truth, not this runbook.

> **Two ways to stand up an environment.** §1 (prerequisites) and §3's
> monitoring setup can be driven **automatically** by the idempotent
> `infra-foundation-setup.sh` orchestrator — see **§4**. The orchestrator does
> only what is missing and **stops with instructions at each browser-only
> manual gate**, so §1–§3 below double as the detailed reference behind each
> gate. §2 (first deploy) is the same either way. Complete §1 (by hand) or §4
> (automated) before the first push.

## 1. Prerequisites (before any deploy)

Complete all of these before the first push that triggers `deploy-staging`.
For production, repeat the environment-scoped items (BWS, GHCR token,
GitHub Environment, Droplet, DNS) against the `production` Environment,
`tag:pc-prod`, and `peppercheck.dev`.

### 1.1 Tailscale — tags, ACL, OIDC client, Droplet auth key

The deploy runner joins the tailnet as an ephemeral, tagged node (no
long-lived Tailscale secret) via `tailscale/github-action` in
`deploy-vps.yml`:

```yaml
- uses: tailscale/github-action@v4
  with:
    oauth-client-id: ${{ vars.TS_CLIENT_ID }}
    audience: ${{ vars.TS_AUDIENCE }}
    tags: tag:ci-deploy
```

There are **two distinct Tailscale credentials** in play, and they must not
be confused:

- an **OIDC federated-identity client** (`TS_CLIENT_ID` / `TS_AUDIENCE`),
  used by the CI runner to join the tailnet with no long-lived secret — set
  up in steps 3-4 below; and
- a tag-scoped, **ephemeral Tailscale auth key** (`TAILSCALE_AUTH_KEY`),
  used once by the Droplet's `bootstrap.sh` to bring the Droplet onto the
  tailnet — set up in step 5 below, needed in hand before you reach §1.6.

1. In the Tailscale admin console, define tags `tag:ci-deploy`,
   `tag:pc-staging`, `tag:pc-prod` in the tailnet ACL.
2. Grant an ACL rule: `tag:ci-deploy` → SSH (port 22) → `tag:pc-staging` and
   `tag:pc-prod`. Do not grant `tag:ci-deploy` broader reach than SSH:22 to
   those two tags.
3. Create a GitHub OIDC federated identity / workload-identity client in
   Tailscale (Settings → OAuth clients / OIDC) that issues nodes tagged
   `tag:ci-deploy`. Restrict the federated-identity claims so only this
   repository and the `deploy-vps.yml` workflow can authenticate against it
   (repo + workflow claim limits) — do not leave it open to any
   repo/workflow in the GitHub org.
4. Record the resulting client ID and audience. They become the
   **non-secret** GitHub Actions Environment variables `TS_CLIENT_ID` and
   `TS_AUDIENCE` (§1.5) — `deploy-vps.yml` reads them as `vars.TS_CLIENT_ID`
   / `vars.TS_AUDIENCE`, scoped per-Environment (staging vs production can use
   different values if desired).
5. Generate a tag-scoped, **ephemeral** Tailscale auth key for the Droplet
   (Settings → Keys → Generate auth key; mark it ephemeral and scope it to
   the target tag — `tag:pc-staging` for staging, `tag:pc-prod` for
   production). This is `bootstrap.sh`'s `TAILSCALE_AUTH_KEY` env var (§1.6);
   have it ready before you provision the Droplet. It is a bootstrap secret —
   never commit it, and prefer a short expiry since `bootstrap.sh` only needs
   it for the one-time `tailscale up`.

### 1.2 Bitwarden Secrets Manager (BWS) — projects, tokens, secret inventory

`deploy-vps.yml`'s "Render secrets + ship deployment" step runs
`bws run -- ./backend/scripts/ship-deployment.sh ...`, so every secret name
`ship-deployment.sh` references by `${!k:?missing $k}` must exist in the BWS
project the runner's token can read.

1. Create two BWS projects: one for staging, one for production (kept
   separate so a staging token can never read a production secret). A third,
   **restore-scoped** project (separate from both) holds the credentials used
   only by the restore drill (Task 16/21, Group D/E) — B2 read key, cipher
   passphrase, age private key, Firebase test credential — and must never be
   readable by the primary deploy pipeline.
2. Populate the following 11 secrets in each of the staging and production
   BWS projects — this is the exact set `ship-deployment.sh` loops over
   (`database_url postgres_superuser_pw postgres_app_pw postgres_migrator_pw
   postgres_backup_pw migrator_database_url pgbackrest_cipher b2_key_id
   b2_key_secret web_form_signing_key ghcr_token`), which is also the exact
   allowlist enforced by `backend/scripts/write-secret.sh` on the Droplet
   side:

   | Secret name | Consumer (compose.prod.yaml) | Notes |
   |---|---|---|
   | `database_url` | `api`, `worker` (`DATABASE_URL_FILE`) | `peppercheck_app` role connection string |
   | `postgres_superuser_pw` | `postgres` (`POSTGRES_PASSWORD_FILE`) | |
   | `postgres_app_pw` | `postgres` (`POSTGRES_APP_PASSWORD_FILE`) | matches `database_url`'s password |
   | `postgres_migrator_pw` | `postgres` (`POSTGRES_MIGRATOR_PASSWORD_FILE`) | matches `migrator_database_url`'s password |
   | `postgres_backup_pw` | `postgres`, `backup` (`POSTGRES_BACKUP_PASSWORD_FILE`) | |
   | `migrator_database_url` | `migrate` one-shot (env var, no `_FILE`) | `peppercheck_migrator` role connection string |
   | `pgbackrest_cipher` | `postgres`, `backup` | pgBackRest repo cipher passphrase (symmetric, §8.5 of the design doc) |
   | `b2_key_id` | `postgres`, `backup` | B2 application key ID |
   | `b2_key_secret` | `postgres`, `backup` | B2 application key secret |
   | `web_form_signing_key` | `api`, `worker` (`WEB_FORM_SIGNING_KEY_FILE`) | HMAC key for the Phase 3b account-deletion form token (`internal/web`); any random string, `config.Load()` fails closed if missing |
   | `ghcr_token` | consumed by `remote-deploy.sh`'s scoped `docker login ghcr.io`, not a container secret | read-only GHCR pull token, see §1.4 |

   `AGE_RECIPIENT` (the age *public* key) is deliberately **not** in this
   list — it is not a secret and travels as a GitHub Actions Environment
   variable instead (§1.5). The age *private* key lives only in the
   restore-scoped BWS project.
3. Create a **read-only** BWS access token scoped to the staging project
   (and, separately, one scoped to the production project). These become the
   `BWS_TOKEN` secret in the matching GitHub Environment (§1.5) — never
   commit the token value, and never grant it write access.

### 1.3 B2 — bucket, Object Lock, lifecycle, application key

pgBackRest and the backup image push to a B2 bucket over the
`PGBACKREST_REPO1_S3_*` settings and the `b2_key_id`/`b2_key_secret` secrets
from §1.2.

1. Create a private B2 bucket per environment (or a shared bucket with
   per-environment key prefixes — pick one and keep it consistent with the
   `PGBACKREST_REPO1_S3_BUCKET` value you set in §1.5).
2. Enable **governance-mode Object Lock** on the bucket. Per the design
   doc's numeric invariant (§8.3), pgBackRest's retention must exceed the
   Object Lock period plus one full-backup interval plus a buffer — the
   production retention window is configured in a later Group D task
   (`backend/deploy/postgres/pgbackrest.conf`), not here; provisioning only
   needs the Object Lock itself enabled before any backup runs against it.
3. Add a lifecycle rule limited to cleaning up hidden/orphaned/noncurrent
   objects — pgBackRest, not the B2 lifecycle rule, owns backup retention and
   deletion; do not configure an age-based delete rule that could remove a
   full backup or WAL segment pgBackRest still needs.
4. Create a B2 application key scoped to this bucket, with **no
   `bypassGovernance`** capability. Its key ID and secret become
   `b2_key_id` / `b2_key_secret` in BWS (§1.2).

### 1.4 GHCR pull token

`remote-deploy.sh` logs into `ghcr.io` on the Droplet with a scoped
`DOCKER_CONFIG` before pulling images, using the `ghcr_token` secret rendered
by `ship-deployment.sh`.

1. Create a GitHub personal access token (classic, or a fine-grained token)
   scoped **read-only** to `read:packages` against the
   `cloveclovedev/peppercheck-*` GHCR packages. Do not grant `write:packages`
   or any repo scope beyond package read.
2. Store this token as the `ghcr_token` secret in both the staging and
   production BWS projects (§1.2) — it is not a GitHub Actions secret itself,
   only a BWS-managed value that `ship-deployment.sh` ships to the Droplet.

### 1.5 GitHub Environments — secrets and variables

Create two GitHub Environments, `staging` and `production`, in the repo
settings. `deploy-vps.yml` declares `environment: ${{ inputs.env }}` and
reads both secrets and non-secret vars scoped to whichever Environment name
was passed in (`staging` from `ci-backend.yml`'s `deploy-staging` job,
`production` from `deploy-vps-production.yml`).

For the `production` Environment, add a **required reviewer** protection
rule — this is what gives production deploys the manual-approval gate
described in the design doc; `deploy-vps-production.yml` itself is only
`workflow_dispatch`-triggered and cannot be triggered by a push, but the
Environment-level required reviewer is the actual approval gate on the job
that reads production's secrets.

Register these three **Environment secrets** on each Environment
(`staging` and `production`):

| Secret | Source | Read by |
|---|---|---|
| `BWS_TOKEN` | the read-only BWS access token from §1.2, scoped to the matching environment's BWS project | `deploy-vps.yml`'s `bws run` step (`BWS_ACCESS_TOKEN` env) |
| `SSH_DEPLOY_KEY` | private half of an SSH keypair generated for the deploy pipeline; the **public** half is `bootstrap.sh`'s `DEPLOY_SSH_PUBLIC_KEY` (§1.6) | `deploy-vps.yml`'s "Set up SSH + pinned host key" step, written to `~/.ssh/id` |
| `SSH_HOST_KEY` | the Droplet's SSH host public key, captured after `bootstrap.sh` brings Tailscale up (§1.6) | same step, appended to `~/.ssh/known_hosts`, pinning the host key against MITM |

Register these non-secret **Environment variables** (`vars.*`) on each
Environment — `ship-deployment.sh` requires every one of them (each is a
`${VAR:?missing VAR}` in the script) to render `images.env`, which
`compose.prod.yaml` in turn requires (`${VAR:?...}`) before its very first
`compose pull`:

| Variable | Value | Consumed by |
|---|---|---|
| `API_PORT` | the backend's listen port, e.g. `8765` | `compose.prod.yaml`'s `api`/`caddy` services |
| `FIREBASE_PROJECT_ID` | the Firebase project ID for this environment | `compose.prod.yaml`'s `api` service |
| `PGBACKREST_REPO1_S3_ENDPOINT` | the B2 S3-compatible endpoint from §1.3 | `compose.prod.yaml`'s `postgres`/`backup` services |
| `PGBACKREST_REPO1_S3_BUCKET` | the B2 bucket name from §1.3 | same |
| `PGBACKREST_REPO1_S3_REGION` | the B2 bucket's region | same |
| `AGE_RECIPIENT` | the age **public** key (not a secret) for the logical-dump fallback | `compose.prod.yaml`'s `backup` service |
| `TS_CLIENT_ID` | the Tailscale OIDC client ID from §1.1 | `deploy-vps.yml`'s Tailscale connect step |
| `TS_AUDIENCE` | the Tailscale OIDC audience from §1.1 | same |

`CADDY_SITE_ADDRESS` and `PC_ENV` are **not** Environment variables to
register — `deploy-vps.yml` derives `CADDY_SITE_ADDRESS` from its own `host`
workflow input (`staging.peppercheck.dev` / `peppercheck.dev`, hardcoded per
environment in `ci-backend.yml` / `deploy-vps-production.yml`) and `PC_ENV`
from its `env` input (`staging` / `production`). Do not add either as a
GitHub Environment variable — the workflow already supplies both.

### 1.6 Droplet — provisioning and host key capture

1. Create a DigitalOcean Droplet in region `sgp1`, sized 1 GiB RAM (per the
   design doc's accepted operational decisions), running Ubuntu.
2. Generate the deploy pipeline's SSH keypair if you have not already
   (§1.5); keep the private half only in the `SSH_DEPLOY_KEY` GitHub
   Environment secret.
3. Get a copy of this repo onto the Droplet (e.g. `git clone` over the
   DigitalOcean web console, or `scp`).
4. Run `bootstrap.sh` **as root**, from the DigitalOcean web console (not
   over a plain public-IP SSH session — see the script's own warning: once
   its `ufw` step enables, a plain public-IP SSH session is cut immediately,
   mid-script, because SSH becomes reachable only on the `tailscale0`
   interface):

   ```bash
   sudo TAILSCALE_TAG=tag:pc-staging \
     TAILSCALE_AUTH_KEY=tskey-... \
     DEPLOY_SSH_PUBLIC_KEY="ssh-ed25519 AAAA... deploy@ci" \
     ./backend/deploy/provision/bootstrap.sh
   ```

   Use `TAILSCALE_TAG=tag:pc-prod` for the production Droplet.
   `TAILSCALE_AUTH_KEY` is the ephemeral, tag-scoped Tailscale auth key you
   generated in §1.1 step 5 (distinct from the OIDC client the CI runner
   uses).
   `DEPLOY_SSH_PUBLIC_KEY` is the public half of `SSH_DEPLOY_KEY` (§1.5); if
   omitted, `bootstrap.sh` skips installing it and you must append it to
   `/home/deploy/.ssh/authorized_keys` by hand before SSH hardening is safe
   to enable — the script will not disable password auth until
   `authorized_keys` is non-empty, to avoid locking itself out.
   `SSH_PERMIT_ROOT_LOGIN` is optional (default `prohibit-password`; set to
   `no` for a stricter posture).

   `bootstrap.sh` is idempotent: it installs Docker + the compose plugin, a
   non-root `deploy` user in the `docker` group, Tailscale, `ufw` (deny by
   default; 22 on `tailscale0` only; 80/443 public for Caddy), `fail2ban`,
   `unattended-upgrades`, the `/opt/peppercheck/{deployments,scripts}` layout
   owned by `deploy`, and the on-Droplet helper scripts
   (`switch-deployment.sh`, `write-secret.sh`, `rollback.sh`). Re-running it
   is safe and only fixes drift.
5. Immediately after `bootstrap.sh` brings Tailscale up, capture the
   Droplet's SSH host public key (e.g. `ssh-keyscan` over the tailnet, or
   read `/etc/ssh/ssh_host_ed25519_key.pub` on the Droplet) and store it as
   the `known_hosts`-format value of the `SSH_HOST_KEY` Environment secret
   (§1.5).

### 1.7 DNS

Point `staging.peppercheck.dev` (or `peppercheck.dev` for production) at the
Droplet's public IP with an **A record set to DNS-only** (grey cloud, no
proxy) — Caddy performs its own ACME HTTP-01 challenge and TLS termination
on the Droplet; a proxying DNS layer in front of it would break that
challenge.

### 1.8 Verify before the first deploy

- Confirm SSH is reachable only via the tailnet: from a machine **not** on
  the tailnet, `ssh deploy@<public-ip>` should time out or be refused.
- On the Droplet, `sudo ufw status` should show port 22 allowed only `on
  tailscale0`, and 80/443 allowed on all interfaces.
- Confirm the Tailscale ACL only grants `tag:ci-deploy` SSH access to
  `tag:pc-staging`/`tag:pc-prod`, nothing broader.

## 2. First deploy

Once §1 is complete for the target environment, the first deploy is
triggered the same way every subsequent staging deploy is: push to the
`refactor/go-api-vps` integration branch with backend changes.

`ci-backend.yml`'s `push` trigger (paths `backend/**`,
`.github/workflows/ci-backend.yml`, branch `refactor/go-api-vps`) runs:

1. `go` — builds and tests the backend against a real Postgres service
   container.
2. `image` — builds and pushes the three images (`peppercheck-backend`,
   `peppercheck-postgres`, `peppercheck-backup`) to GHCR by digest, and
   publishes the OCI release manifest (`{sha, backend, postgres, backup,
   atlas, caddy}`) as `ghcr.io/cloveclovedev/peppercheck-release:<sha>`.
3. `guard` — re-confirms `github.sha` is still the branch head (protects
   against a stale run deploying over a newer one).
4. `deploy-staging` — calls the reusable `deploy-vps.yml` with
   `env: staging`, `host: staging.peppercheck.dev`, `ssh_host: pc-staging`.
   This is the job that consumes everything provisioned in §1: it connects
   over Tailscale as `tag:ci-deploy`, renders the 10 BWS secrets plus the
   non-secret vars via `bws run` + `ship-deployment.sh`, SSHes in as
   `deploy@pc-staging` to run the migration-gated deploy
   (`remote-deploy.sh`), then smoke-tests `https://staging.peppercheck.dev/readyz`
   (`smoke-or-rollback.sh`), rolling back automatically on failure.
5. `tag-validated` — stamps the manifest `staging-validated-<sha>` once the
   staging smoke test passes; this tag is what `deploy-vps-production.yml`
   later requires before it will promote a digest to production.

**Do not** use `workflow_dispatch` on `deploy-vps-production.yml` for this
first deploy — that workflow requires being present on the repo's default
branch (`main`) to be dispatchable at all, and it promotes an
already-`staging-validated` manifest rather than building anything itself.
It only becomes usable once `refactor/go-api-vps` is merged to `main` at
cutover (out of scope for Phase 7-A; see the design doc §13).

After `deploy-staging` finishes green, verify manually:

- `curl https://staging.peppercheck.dev/readyz` returns healthy.
- The certificate served is a real Let's Encrypt certificate for
  `staging.peppercheck.dev` (Caddy's automatic ACME TLS), not a self-signed
  fallback.
- On the Droplet, `/opt/peppercheck/deployments/<sha>-<run_id>/secrets/*`
  files exist and are all `0400`. `remote-deploy.sh` chowns each one to its
  consumer UID — `65532` for `database_url`/`web_form_signing_key`, `999`
  for the postgres/pgBackRest secrets, `0` for `migrator_database_url` — with the one
  exception of `ghcr_token`, which stays owned by the `deploy` user (it is
  consumed by the runner's scoped `docker login ghcr.io`, not mounted into
  any container).

## 3. Post-deploy actions

These are one-time (or first-run) operator actions after the first
successful staging deploy. Most of the underlying tooling is authored in
Group D of the Phase 7-A plan and is referenced here only as a forward
pointer — do not attempt to hand-rebuild it from this runbook:

- **Monitoring.** Wire up Better Stack uptime monitors on `/livez` and
  `/readyz`, TLS-expiry checks, and heartbeats, plus DigitalOcean host
  alerts (CPU/memory/filesystem/bandwidth) and the custom inode
  (`df -i`) / container-restart-count / multi-signal RPO checks shipped by
  the `wal-freshness.sh` / `host-checks.sh` scripts and their systemd timers
  (Task 17, `backend/deploy/monitor/`, `backend/deploy/provision/
  MONITORING.md`). Staging alerts must be configured **non-paging**
  (dashboard-only); only production pages. Document any maintenance-window
  procedure needed before intentionally stopping staging.
- **First backup and restore drill.** Run `stanza-create` and a first
  `--type=full` pgBackRest backup against the real B2 bucket provisioned in
  §1.3, then run the isolated restore drill (Task 16,
  `backend/scripts/restore-drill.sh`) against staging: it restores into a
  separate volume (never the live `pgdata`), brings up an isolated
  Compose project with the worker disabled, verifies sentinel rows
  pre/post the restore target time, obtains a Firebase test ID token and
  calls `/api/v1/me` as an authenticated smoke test, and separately
  restores the age-encrypted logical dump with a real `pg_restore`.
- **Record RTO.** Note the wall-clock time the restore drill took, end to
  end, and compare it against the 4-hour RTO target from the design doc
  (§8.4, §12).
- **Backup chain verification.** Confirm the backup → expire → restore
  chain against a short-lived test bucket, and confirm the B2 application
  key used at runtime has no `bypassGovernance` capability (§1.3).
- **Dial down staging backup frequency.** Once the mechanism is validated,
  staging carries no production RPO/retention obligation (design doc
  §8.6) — reduce staging's pgBackRest schedule to low-frequency or
  on-demand.

## 4. Automated stand-up with `infra-foundation-setup.sh`

Instead of performing §1 (and §3's monitoring setup) by hand, run the
idempotent, state-reconciling `infra-foundation-setup.sh` orchestrator. It does
only what is missing on each run, **stops with precise instructions at every
browser-only manual gate**, and resumes from that gate when you re-run the same
command. It never deploys (§2 is unchanged) and never runs pgBackRest
backups/the restore drill (those §3 items stay manual — see §4.5).

Design: `docs/superpowers/specs/2026-07-26-infra-foundation-setup-design.md`.
The `config/<env>.env.example` template and the script's runtime messages are
the authoritative detail; if this section disagrees with them, they win.

### 4.1 Prerequisites for running the orchestrator

- The toolkit lives in `backend/deploy/provision/`:
  `infra-foundation-setup.sh`, `lib.sh`, `steps/*.sh`, `config/<env>.env.example`.
- CLIs on the machine you run it from: `gh`, `doctl`, `bws`, `b2`, `jq`,
  `age-keygen`, `openssl`, `ssh-keygen`, `ssh-keyscan`, `curl`. The script
  checks these at start and names any that are missing (it does **not** install
  them — install via Homebrew/your package manager).
- The machine must be **on the tailnet** (Tailscale up, MagicDNS working) —
  steps 60/80 capture the Droplet host key and verify SSH over the tailnet name
  (`pc-staging` / `pc-prod`).

### 4.2 Fill the config (never committed)

```bash
cd backend/deploy/provision
cp config/staging.env.example config/staging.env   # (or production.env)
chmod 600 config/staging.env
$EDITOR config/staging.env
```

It holds **only**: the bootstrap provider API tokens (DigitalOcean, Cloudflare
+ zone id, Backblaze B2 account key, Better Stack, a Tailscale API access
token), the three browser-gate values (§4.4), and non-secret inputs (public
domain, region, Firebase project id, the production reviewer id, etc.).
**Generated application secrets are NOT here** — the orchestrator creates them
and writes them straight to Bitwarden Secrets Manager. `config/*.env` is
gitignored; do not commit it. Every key is documented in the `.example`.

### 4.3 Run it

```bash
cd backend/deploy/provision
./infra-foundation-setup.sh staging              # or: production
./infra-foundation-setup.sh staging --dry-run    # preview intended actions, no changes
./infra-foundation-setup.sh staging --from b2    # resume from a step
./infra-foundation-setup.sh staging --only dns   # run a single step
```

Each step queries real cloud state and does only what is missing. At the first
action that needs a browser (or a not-yet-provided token) it prints an
`=== ACTION REQUIRED ===` block: what to do in which dashboard, and which
`config/<env>.env` key to paste the result into, then exits. **Do the action,
save the value, then re-run the same command** — completed steps are skipped
and execution resumes at the gate. There is no progress file; the real cloud
state is the checkpoint. Run `--dry-run` first to preview.

### 4.4 The manual gates it stops at (cross-referenced to §1)

The orchestrator automates everything scriptable, but these have no API and
stay manual — see the linked section for the exact dashboard steps:

- **Provider API bootstrap tokens** (one-time, each in that provider's
  dashboard): DigitalOcean, Cloudflare (+ zone id), Backblaze B2 account key
  (§1.3), Better Stack, and a Tailscale API access token (§1.1).
- **GitHub PAT `ghcr_token`** — read-only `read:packages` on
  `cloveclovedev/peppercheck-*` (§1.4). Browser-only; no API mints a PAT.
- **Bitwarden Secrets Manager** projects + machine-account tokens — a
  read-write token for the script and a read-only runtime token (§1.2).
  Web-vault-only.
- **Tailscale OAuth client** → `TS_CLIENT_ID` / `TS_AUDIENCE` (§1.1).
  Admin-console-only.
- **Operator-provided values**: the Firebase test-account credentials for the
  restore drill (§1.2, restore-scoped project), the production required-reviewer
  GitHub user id (§1.5), and the non-secret inputs (Firebase project id, domain,
  region).

### 4.5 What the orchestrator does NOT do

- **Deploy.** §2 is unchanged — the first deploy is still triggered by pushing
  to `refactor/go-api-vps` after §1 (or §4) is complete. The orchestrator only
  provisions prerequisites.
- **The §3 backup + restore drill.** Its monitoring step only *creates* the
  Better Stack monitors + DO host alerts; run the first `pgBackRest` backup, the
  restore drill, the RTO measurement, and the backup-chain verification by hand
  per §3.
- **The three browser gates in §4.4.** No API exists for them.

The API-hitting steps mutate real cloud accounts and are first exercised on the
real stand-up (they cannot be run against the real providers in CI); `--dry-run`
previews the commands, and the reconcile model makes a bad create safe to fix
and re-run.
