# Infra Foundation Setup — Idempotent Provisioning Orchestrator (Design)

> Status: **Design (approved in brainstorming 2026-07-26).**
> Follow-up to the Phase 7-A infrastructure/operations foundation
> (`docs/superpowers/specs/2026-07-25-phase7a-infra-ops-foundation-design.md`).
> It automates the operator stand-up currently documented as a manual runbook
> in `backend/deploy/provision/RUNBOOK.md`. This is its own spec → plan →
> implementation cycle; the implementation plan is produced separately by the
> writing-plans workflow and is not committed.

## 1. Purpose

Phase 7-A delivered the deploy pipeline, backup/PITR, and monitoring code, plus
`RUNBOOK.md` — a ~40-action manual checklist an operator follows to stand up a
staging (and later production) environment: Tailscale ACL/keys, Bitwarden
Secrets Manager (BWS) projects/secrets, a Backblaze B2 bucket, GitHub
Environments with ~22 secrets/variables, a DigitalOcean Droplet + `bootstrap.sh`,
DNS, verification, and Better Stack / DigitalOcean monitoring.

Doing this by hand — twice (staging now, production at cutover) — is tedious and
error-prone (a single mistyped secret name or variable breaks the first deploy).
This project replaces the runbook's mechanical steps with a **single idempotent
orchestrator** that reconciles the environment against its desired state, stops
with precise instructions whenever a genuinely-manual action is required, and
resumes cleanly on re-run.

## 2. Goals / non-goals

**Goals**
- One command, run per environment, that drives the RUNBOOK §1 (prerequisites)
  and §3 (post-deploy monitoring) stand-up as far as automation allows.
- **Idempotent**: safe to re-run; only creates what is missing.
- **Stop-and-resume**: when a browser-only action or a not-yet-obtained
  bootstrap credential is required, print exactly what to do and where to put
  the resulting value, then exit; a re-run picks up from there.
- Never write generated secrets to disk or git; push them straight to BWS.

**Non-goals (explicit)**
- The three irreducibly-manual, browser-only credential creations remain manual
  (they have no API — verified §7): a GitHub PAT for GHCR pulls, a Bitwarden
  machine-account access token, and a Tailscale OAuth client. The orchestrator
  *gates* on them, it does not create them.
- Obtaining each provider's first API token (DigitalOcean, Cloudflare, B2,
  Better Stack) is a one-time dashboard action per provider; also a gate.
- **Not** re-architecting the deploy pipeline. In particular, replacing the
  hand-created GHCR PAT (`ghcr_token`) by passing the workflow's own
  `GITHUB_TOKEN` to the Droplet at deploy time is a **separate, recommended
  future follow-up** (§9), out of scope here — it touches already-merged
  `deploy-vps.yml` / `ship-deployment.sh`, not this orchestrator.
- Monitoring stays on the **ping model** (§3 decision): the orchestrator only
  *creates* Better Stack uptime + heartbeat monitors and DigitalOcean host
  alerts. It does **not** modify the already-merged `wal-freshness.sh` /
  `host-checks.sh` scripts (no Incidents-API payload push).

## 3. Decisions locked in brainstorming (2026-07-26)

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | **Scope = RUNBOOK §1 (all prerequisites) + §3 (monitoring/backup-drill).** | The stop-and-resume value is greatest walking the whole stand-up; the operator wanted the full journey automated. |
| D2 | **Monitoring = ping model, monitoring scripts untouched.** | Solo-operator, pre-launch, single VPS: a page + `journalctl` is fine; the Incidents-API payload model adds incident-lifecycle complexity for marginal benefit (YAGNI). Upgrading later is additive — the scripts already emit structured status. |
| D3 | **Idempotency = state reconciliation ("real state is the checkpoint").** | Each step queries actual cloud state and creates only what is missing; no local checkpoint file to drift or lie. Survives partial failure and out-of-band deletes. Every provider used here exposes a get/list to check existence (§7). |
| D4 | **Per-environment invocation** (`<staging\|production>`). | Production reuses the identical script at cutover, substituting environment-scoped values. |
| D5 | **Generated secrets go to BWS only; a gitignored per-env config holds bootstrap tokens + non-secret inputs + manually-obtained values.** Claude never reads the config. | Keeps secret values out of disk/git; respects the operator's "never read `.env`" rule (the script reads config, not the assistant). |
| D6 | **Three-valued step contract: SATISFIED / DID_IT / NEEDS_MANUAL.** | Manual gates are modeled as an unmet precondition in the same reconcile framework — no special-casing; the orchestrator stops at the first NEEDS_MANUAL. |

## 4. Architecture

### 4.1 Layout

Under `backend/deploy/provision/` alongside `bootstrap.sh` and `RUNBOOK.md`:

```
infra-foundation-setup.sh        # thin orchestrator (arg parsing, step ordering, stop-on-gate)
provision/lib.sh                 # config load, tool-presence check, reconcile framework, logging, dry-run
provision/steps/
  10-secrets.sh                  # generate app secret VALUES (openssl/age) -> BWS
  20-bws.sh                      # BWS projects + secret population; runtime read-only token gate
  30-tailscale.sh                # ACL (tags+grants), ephemeral auth key; OAuth-client gate
  40-b2.sh                       # bucket + Object Lock + lifecycle + restricted key
  50-github-env.sh               # Environments + required reviewer + 3 secrets + 8 vars; ghcr_token PAT gate
  60-droplet.sh                  # Droplet (cloud-init runs bootstrap.sh) + host-key capture -> GH secret
  70-dns.sh                      # Cloudflare A record, DNS-only
  80-verify.sh                   # SSH-off-tailnet / ufw / TLS-cert / 0400 assertions
  90-monitoring.sh               # Better Stack uptime+heartbeat monitors, DO host alerts (ping model)
config/<env>.env                 # gitignored, 0600, operator-managed (NOT committed; NOT read by Claude)
config/<env>.env.example         # committed template documenting every key (no values)
```

Each `steps/*.sh` exposes one idempotent `reconcile()` (internally check-then-do)
that returns SATISFIED / DID_IT / NEEDS_MANUAL and, on NEEDS_MANUAL, emits a
precise instruction block. Modules are small and independently testable.

### 4.2 Command interface

```
infra-foundation-setup.sh <staging|production> [--dry-run] [--from <step>] [--only <step>]
```

- No flags: run every step in order, reconciling; stop at the first NEEDS_MANUAL.
- `--dry-run`: read real state but print intended mutations instead of executing.
- `--from <step>` / `--only <step>`: operator escape hatches for targeted re-runs.

### 4.3 Step execution model (the core)

The orchestrator loads `config/<env>.env`, checks required tools, then walks the
ordered steps. For each: call `reconcile()`.

- **SATISFIED** — real state already matches desired; log and continue.
- **DID_IT** — created/updated only the missing piece; log and continue.
- **NEEDS_MANUAL** — a browser-only action or an un-provided bootstrap value is
  required. Print (a) exactly what to do in which dashboard, (b) which
  `config/<env>.env` key to paste the resulting value into, then **exit with a
  distinct exit code** (e.g. 10). No further steps run.

Re-running the same command after the manual action + config edit: completed
steps report SATISFIED and are skipped; execution resumes at the newly-unblocked
step. The **real cloud state (plus the config's presence of a required value) is
the resume checkpoint** — there is no separate progress file.

### 4.4 Config & secret boundary

- `config/<env>.env` (gitignored, `0600`, operator-owned) holds **only**:
  bootstrap provider API tokens (DigitalOcean, Cloudflare + zone id, B2
  account key id/secret, Better Stack), the three manual-gate values (GitHub
  `ghcr_token` PAT, BWS write + runtime-read-only tokens, Tailscale OAuth client
  id/secret), and non-secret inputs (public domain, region, Firebase project id,
  Droplet size/region, `ssh_host` names, age is generated not supplied). Values
  may alternatively be supplied via the environment for operators who inject
  from their own secret manager.
- **Generated application secrets** (`postgres_superuser_pw`, `postgres_app_pw`,
  `postgres_migrator_pw`, `postgres_backup_pw`, `pgbackrest_cipher`, the age
  keypair, and the composed `database_url` / `migrator_database_url`) are
  generated in step 10 and written **directly to BWS**; they are never written
  to `config`, disk, or git. `database_url`'s password is generated to match
  `postgres_app_pw` and `migrator_database_url`'s to match
  `postgres_migrator_pw` in one pass (the RUNBOOK's stated invariant); the DB
  host in both is the compose service name `postgres`. The age **public** key
  becomes the `AGE_RECIPIENT` GitHub variable; the age **private** key goes to
  the restore-scoped BWS project only. On re-run, a secret already present in
  BWS is reused, never regenerated.
- A committed `config/<env>.env.example` documents every key with placeholder
  values so the operator knows what to fill.
- The assistant does not read `config/<env>.env`; only the script does.

## 5. Step catalog

Each step reconciles against real state (get/list → create-if-missing). "Gate"
marks the sub-actions that must stop for a manual/browser step.

| Step | Reconciles | Auto / Gate |
|------|-----------|-------------|
| 10-secrets | Are the app secrets present in BWS? If not, generate (openssl `rand`, `age-keygen`) and store. | Auto |
| 20-bws | BWS staging/production/restore projects exist; the 10 secrets populated; a **read-only runtime token** exists → GitHub `BWS_TOKEN` secret. | Populate = auto (needs a write-capable BWS token in config). **Gate:** creating the BWS projects + machine-account tokens is web-vault-only. |
| 30-tailscale | ACL has `tag:ci-deploy`/`tag:pc-staging`/`tag:pc-prod` + the `ci-deploy → SSH:22 → pc-*` grant; a tag-scoped **ephemeral auth key** minted for the Droplet. | ACL + auth key = auto (Tailscale API). **Gate:** creating the OAuth client (`TS_CLIENT_ID`/`TS_AUDIENCE`) is admin-console-only. |
| 40-b2 | Private bucket with governance Object Lock + orphan-only lifecycle; a bucket-restricted key **without `bypassGovernance`**. | Auto (`b2 bucket create --file-lock-enabled` + `b2 bucket update --default-retention-mode governance --lifecycle-rule …` + `b2 key create --bucket`). |
| 50-github-env | `staging`/`production` Environments exist; production has a required-reviewer rule; the 3 secrets (`BWS_TOKEN`, `SSH_DEPLOY_KEY`, `SSH_HOST_KEY`) and 8 variables (`API_PORT`, `FIREBASE_PROJECT_ID`, `PGBACKREST_REPO1_S3_{ENDPOINT,BUCKET,REGION}`, `AGE_RECIPIENT`, `TS_CLIENT_ID`, `TS_AUDIENCE`) are set. | Auto (`gh api` + `gh secret/variable set --env`). **Gate:** the `ghcr_token` PAT (stored in BWS via step 20) is a browser-only GitHub creation. |
| 60-droplet | A Droplet named for the env exists in `sgp1`/1 GiB/Ubuntu; `bootstrap.sh` has run (Tailscale up, ufw, deploy user, helper scripts); the host key is captured → GitHub `SSH_HOST_KEY`. Deploy SSH keypair generated if absent (`ssh-keygen`) → private half to `SSH_DEPLOY_KEY` (step 50). | Auto (`doctl compute droplet create --user-data-file` running bootstrap via cloud-init with `TAILSCALE_AUTH_KEY`/`TAILSCALE_TAG`/`DEPLOY_SSH_PUBLIC_KEY`; `ssh-keyscan` over the tailnet). |
| 70-dns | An A record for `staging.peppercheck.dev` / `peppercheck.dev` → Droplet IP, **DNS-only (grey cloud)**. | Auto (Cloudflare API — the domain is on Cloudflare; not DigitalOcean DNS). |
| 80-verify | SSH refused from off-tailnet; `ufw` shows 22 only on `tailscale0`; (post first deploy) the served cert is a real Let's Encrypt cert and secret files are `0400`. | Auto (assertion-only; non-mutating). |
| 90-monitoring | Better Stack uptime monitors (`/livez`, `/readyz`, TLS-expiry) + heartbeat monitors (worker, backup, wal-freshness, host-checks); DigitalOcean host alert policies. Staging non-paging. | Auto (Better Stack API; `doctl monitoring alert create`). |

`bootstrap.sh` itself is unchanged; step 60 invokes it. Steps 80/90 reference the
already-merged verification and monitoring artifacts.

## 6. Error handling & idempotency

- `set -euo pipefail`; every API wrapper fails closed (a non-2xx / non-zero
  aborts with a clear message, never a silent skip).
- Existence checks use each provider's get/list (all available — §7), so a
  half-applied run or an out-of-band delete self-heals on the next run.
- A NEEDS_MANUAL exit is a normal, expected outcome, not a failure: it uses a
  distinct exit code so the operator (and any wrapping automation) can tell
  "action required" from "error".
- Generated secrets are written to BWS transactionally per secret; a re-run
  reconciles the set, adding only missing names.

## 7. Verified provider capabilities (official docs, 2026-07-26)

Confirmed scriptable (get/list + create) unless noted:

- **GitHub Environments/secrets/variables** — `PUT …/environments/{name}`
  (+ `reviewers`), `gh secret set --env` (libsodium-encrypted), `gh variable
  set --env`. Fully scriptable.
- **GitHub PAT creation** — **no API** (browser-only). GitHub App installation
  tokens are **not** accepted by GHCR. → `ghcr_token` is a hard gate.
- **Bitwarden `bws`** — `bws project create`, `bws secret create` scriptable;
  **machine-account + access-token creation is web-vault-only** → gate.
- **Tailscale API** — ACL `POST …/acl`, ephemeral key `POST …/keys` scriptable;
  **OAuth-client creation is admin-console-only** → gate.
- **Backblaze B2 `b2` (v4)** — `bucket create --file-lock-enabled`, `bucket
  update --default-retention-mode governance --lifecycle-rule …`, `key create
  --bucket … <caps without bypassGovernance>`. Fully scriptable.
- **Better Stack** — `POST /api/v2/monitors`, `POST /api/v2/heartbeats`
  (team API token). Scriptable.
- **DigitalOcean `doctl`** — `droplet create --user-data-file`, `monitoring
  alert create`, `compute domain records create` (DNS here is Cloudflare, so
  DNS uses the Cloudflare API instead). Scriptable.

Three hard blockers (browser-only): GitHub PAT, BWS machine-account token,
Tailscale OAuth client — each created once, then everything downstream is
scriptable.

## 8. Testing

- **Pure logic via bats** (same pattern as `backend/scripts/deployment.bats`,
  now wired into CI): config parsing/validation, required-tool detection, the
  secret-value generation (openssl/age, and the `database_url` ↔ `app_pw`
  matching invariant), the reconcile dispatch + three-valued contract, gate
  detection, and `--dry-run` rendering. Provider API calls are behind thin
  wrappers that the tests stub, so the orchestration logic is verified without
  hitting real clouds.
- **Real execution** of the API-hitting steps is inherently verified during the
  actual staging stand-up (they mutate real cloud accounts); `--dry-run` previews
  the intended commands beforehand. This is the same "first real run" caveat that
  applies to the rest of Group E.
- No test reads committed secrets; test fixtures use obvious dummies.

## 9. Out of scope / future

- **GHCR-token simplification.** The `ghcr_token` browser gate could be removed
  by having `ship-deployment.sh` pass the workflow's own `GITHUB_TOKEN` (which
  has `packages: read`, valid for the run — long enough for the pull) to the
  Droplet instead of a BWS-stored PAT. This removes one hard gate but changes
  already-merged `deploy-vps.yml` / `ship-deployment.sh`, so it is a separate
  follow-up needing its own quick real-world verification (does the runner's
  `GITHUB_TOKEN` authenticate `docker login ghcr.io` from the Droplet).
- Monitoring Incidents-API payload push (the alternative to the ping model, D2)
  — additive later if context-less paging proves painful in production.
- Fully unattended provisioning (removing the browser gates) is impossible given
  the three hard blockers; not pursued.

## 10. Risks

- **Real-cloud verification only.** The API steps cannot be unit-tested against
  the real providers; a wrong endpoint/field surfaces on the first stand-up.
  Mitigation: `--dry-run`, thin well-tested wrappers, and the reconcile model
  (a bad create is safe to fix and re-run).
- **Bootstrap-token blast radius.** `config/<env>.env` concentrates several
  write-capable provider tokens. Mitigation: gitignored, `0600`, documented as
  operator-managed and revocable; the script never persists it elsewhere; prefer
  short-lived/least-privilege tokens where the provider allows.
- **Provider CLI drift** (e.g. `b2` v3→v4 command renames). Mitigation: pin/detect
  CLI versions in the tool-check step and cite the doc'd command forms.
