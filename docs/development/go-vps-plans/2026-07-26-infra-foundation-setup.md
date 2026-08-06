# Infra Foundation Setup — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An idempotent, state-reconciling orchestrator (`infra-foundation-setup.sh`) that automates the RUNBOOK §1 (prerequisites) + §3 (monitoring) stand-up per environment, stopping with precise instructions at the browser-only manual gates and resuming cleanly on re-run.

**Architecture:** A thin orchestrator sources a shared `lib.sh` framework and a set of ordered `steps/*.sh` modules. Each module exposes one idempotent `reconcile_<name>()` that queries real cloud state through a **stubbable provider wrapper**, then returns SATISFIED / DID_IT (both = continue) or the NEEDS_MANUAL sentinel (print instructions, stop). Real cloud state is the resume checkpoint — no progress file. Generated secrets go straight to BWS; a gitignored per-env config holds only bootstrap tokens + non-secret inputs.

**Tech Stack:** POSIX-ish bash, `bats` (via `bats/bats` Docker image) for pure-logic tests, and the provider CLIs/APIs `gh`, `doctl`, `bws`, `b2`, plus `curl` for Tailscale / Cloudflare / Better Stack, with `jq`, `age`, `openssl`, `ssh-keygen`, `ssh-keyscan`.

Design: `docs/designs/2026-07-26-infra-foundation-setup-design.md`.

## Global Constraints

- **Reconcile contract:** every `reconcile_<name>()` returns `0` to continue (whether it found the resource SATISFIED or DID_IT create it) and the sentinel code **`75`** for NEEDS_MANUAL, after printing an ACTION-REQUIRED block naming the dashboard step and the exact `config/<env>.env` key to fill. The orchestrator stops at the first `75`.
- **State reconciliation only:** existence is checked via the provider's get/list every run; no local checkpoint/progress file. A half-applied run or an out-of-band delete self-heals on re-run.
- **Provider calls go through named wrapper functions** (`gh_api`, `bws_cli`, `ts_api`, `b2_cli`, `doctl_cli`, `cf_api`, `bs_api`) so bats tests override them. No step calls a CLI/curl directly.
- **`set -euo pipefail`** in every script. Every wrapper fails closed (non-2xx / non-zero aborts with a clear message).
- **Secret boundary:** generated app secrets are written to BWS only — never to `config`, disk, or git. `config/*.env` is gitignored + `0600`; only `config/*.env.example` is committed (placeholders, no values).
- **`--dry-run`** reads real state but prints intended mutations via `run_mutation` instead of executing them.
- **Per-env:** invoked as `infra-foundation-setup.sh <staging|production> [--dry-run] [--from <step>] [--only <step>]`.
- Files live under `backend/deploy/provision/`. Do NOT modify already-merged Phase 7-A files (`bootstrap.sh`, `wal-freshness.sh`, `host-checks.sh`, `deploy-vps.yml`, `ship-deployment.sh`). The GHCR-token `GITHUB_TOKEN` simplification is explicitly out of scope.
- Monitoring is the **ping model**: step 90 only *creates* Better Stack uptime+heartbeat monitors and DO alerts; it does not change any monitoring script.
- bats runs via Docker (operator policy: no host tool installs): `docker run --rm -v "$PWD/backend/deploy/provision":/code -w /code bats/bats:latest infra-setup.bats`.

---

## Task 1: Framework (`lib.sh`) + orchestrator skeleton + CI wiring

**Files:**
- Create: `backend/deploy/provision/lib.sh`
- Create: `backend/deploy/provision/infra-foundation-setup.sh`
- Create: `backend/deploy/provision/config/staging.env.example`
- Create: `backend/deploy/provision/infra-setup.bats`
- Modify: `backend/.gitignore` (or repo `.gitignore`) — ignore `backend/deploy/provision/config/*.env`
- Modify: `.github/workflows/ci-backend.yml` — run `infra-setup.bats` in the `go` job

**Interfaces (Produces — every later task consumes these):**
- `NEEDS_MANUAL=75` (exported constant).
- `log_info msg` / `log_ok msg` / `log_warn msg` / `log_err msg` — stderr, structured `{"level":..,"msg":..}` lines (matches `backup.sh` style).
- `need_manual KEY "instruction text"` — prints the ACTION-REQUIRED block (instruction + "put the value in config/<env>.env as KEY") to stderr and `return $NEEDS_MANUAL`.
- `require_tools t1 t2 …` — returns 0 if all present; else `log_err` the missing list and `exit 1`.
- `cfg KEY` — echoes the value of config key `KEY` (from the sourced config / environment), empty if unset.
- `require_cfg KEY` — echoes `cfg KEY`; if empty, `need_manual KEY "…"`-style is the caller's job — `require_cfg` just returns non-zero when empty (callers decide the message).
- `is_dry_run` — returns 0 when `--dry-run`.
- `run_mutation "description" cmd args…` — in dry-run prints `[dry-run] description`; else runs `cmd args…` (fail-closed).
- The orchestrator sources `steps/*.sh` in order and calls `reconcile_<name>`; a `75` return stops the run with a "re-run after the manual step" message and exit code 75.

- [ ] **Step 1: Write failing tests for the framework contract**

Create `backend/deploy/provision/infra-setup.bats`:

```bash
setup() {
  ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  # shellcheck disable=SC1091
  source "$ROOT/lib.sh"
}

@test "need_manual returns the sentinel and prints the key" {
  run need_manual GHCR_TOKEN "Create a read-only PAT"
  [ "$status" -eq 75 ]
  [[ "$output" == *"GHCR_TOKEN"* ]]
  [[ "$output" == *"Create a read-only PAT"* ]]
}

@test "require_tools exits 1 and names a missing tool" {
  run require_tools definitely_not_a_real_tool_xyz
  [ "$status" -eq 1 ]
  [[ "$output" == *"definitely_not_a_real_tool_xyz"* ]]
}

@test "cfg reads a value from the environment" {
  export CFG_TEST_KEY=hello
  run cfg CFG_TEST_KEY
  [ "$status" -eq 0 ]
  [ "$output" = "hello" ]
}

@test "run_mutation echoes in dry-run and does not execute" {
  DRY_RUN=1
  run run_mutation "would create bucket" touch "$BATS_TEST_TMPDIR/sentinel"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] would create bucket"* ]]
  [ ! -e "$BATS_TEST_TMPDIR/sentinel" ]
}

@test "run_mutation executes when not dry-run" {
  DRY_RUN=0
  run run_mutation "create file" touch "$BATS_TEST_TMPDIR/sentinel"
  [ "$status" -eq 0 ]
  [ -e "$BATS_TEST_TMPDIR/sentinel" ]
}
```

- [ ] **Step 2: Run tests — verify they fail**

Run: `docker run --rm -v "$PWD/backend/deploy/provision":/code -w /code bats/bats:latest infra-setup.bats`
Expected: FAIL (`lib.sh` not found / functions undefined).

- [ ] **Step 3: Implement `lib.sh`**

```bash
#!/usr/bin/env bash
# Shared framework for the infra-foundation-setup orchestrator: config loading,
# tool checks, the reconcile three-valued contract, logging, and the dry-run
# guard. Provider calls live in wrapper functions (gh_api/bws_cli/... added in
# later steps) so tests can override them; no step calls a CLI directly.
set -euo pipefail

NEEDS_MANUAL=75
DRY_RUN="${DRY_RUN:-0}"

_log() { printf '{"level":"%s","msg":%s}\n' "$1" "$(printf '%s' "$2" | jq -R -s .)" >&2; }
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

run_mutation() {
  local desc="$1"; shift
  if is_dry_run; then echo "[dry-run] ${desc}"; return 0; fi
  "$@"
}
```

- [ ] **Step 4: Run tests — verify they pass**

Run: `docker run --rm -v "$PWD/backend/deploy/provision":/code -w /code bats/bats:latest infra-setup.bats`
Expected: PASS (5/5).

- [ ] **Step 5: Implement the orchestrator + config example + gitignore + CI**

Create `backend/deploy/provision/infra-foundation-setup.sh`:

```bash
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
```

Create `backend/deploy/provision/config/staging.env.example` with a documented placeholder for every key the steps read (bootstrap tokens + non-secret inputs), e.g.:

```bash
# Copy to config/staging.env (gitignored, chmod 0600) and fill in.
# --- bootstrap provider tokens (write-capable; used by this script) ---
DO_TOKEN=
CLOUDFLARE_API_TOKEN=
CLOUDFLARE_ZONE_ID=
B2_APPLICATION_KEY_ID=
B2_APPLICATION_KEY=
BETTERSTACK_API_TOKEN=
TS_API_KEY=
BWS_WRITE_TOKEN=
# --- values obtained at manual gates ---
GHCR_TOKEN=
BWS_RUNTIME_TOKEN=
TS_CLIENT_ID=
TS_AUDIENCE=
# --- non-secret inputs ---
PUBLIC_DOMAIN=staging.peppercheck.dev
SSH_HOST=pc-staging
TS_TAG=tag:pc-staging
DO_REGION=sgp1
DO_SIZE=s-1vcpu-1gb
FIREBASE_PROJECT_ID=
API_PORT=8765
B2_BUCKET=
B2_REGION=
```

Append to `.gitignore`: `backend/deploy/provision/config/*.env`.

In `.github/workflows/ci-backend.yml` `go` job, add a step (next to the existing `deployment.bats` step) running:
`docker run --rm -v "$PWD/backend/deploy/provision":/code -w /code bats/bats:latest infra-setup.bats`.

Run `shellcheck` on `lib.sh` + `infra-foundation-setup.sh`, `actionlint` on the workflow, and the bats suite (5/5). Then commit.

- [ ] **Step 6: Commit**

```bash
git add backend/deploy/provision/lib.sh backend/deploy/provision/infra-foundation-setup.sh \
  backend/deploy/provision/config/staging.env.example backend/deploy/provision/infra-setup.bats \
  .gitignore .github/workflows/ci-backend.yml
git commit -m "feat(provision): infra-setup orchestrator framework + reconcile contract + CI bats gate"
```

---

## Task 2: `steps/10-secrets.sh` — generate app secrets → BWS

**Files:**
- Create: `backend/deploy/provision/steps/10-secrets.sh`
- Modify: `backend/deploy/provision/infra-setup.bats` (add secret-gen tests)

**Interfaces:**
- Consumes: `lib.sh` (`cfg`, `run_mutation`, `log_*`, `NEEDS_MANUAL`), the `bws_cli` wrapper (defined here, overridable).
- Produces: `reconcile_secrets()`; helper `gen_password()` (32-char url-safe), `bws_secret_exists NAME PROJECT_ID` / `bws_put_secret NAME VALUE PROJECT_ID` (via `bws_cli`).

- [ ] **Step 1: Write failing tests (generation invariants + reconcile skip)**

Add to `infra-setup.bats`:

```bash
@test "gen_password yields a 32+ char token with no shell-unsafe chars" {
  source "$ROOT/steps/10-secrets.sh"
  run gen_password
  [ "$status" -eq 0 ]
  [ "${#output}" -ge 32 ]
  [[ ! "$output" =~ [\'\"\`\$\\] ]]
}

@test "reconcile_secrets is a no-op when all secrets already exist in BWS" {
  source "$ROOT/steps/10-secrets.sh"
  bws_cli() { echo '[{"key":"database_url"},{"key":"postgres_app_pw"}]'; }  # list returns everything
  bws_secret_exists() { return 0; }  # stub: all present
  created=0; bws_put_secret() { created=1; }
  export BWS_WRITE_TOKEN=x BWS_PROJECT_ID=p
  run reconcile_secrets
  [ "$status" -eq 0 ]
  [ "$created" -eq 0 ]  # nothing regenerated
}

@test "reconcile_secrets stops with NEEDS_MANUAL when the BWS write token is absent" {
  source "$ROOT/steps/10-secrets.sh"
  unset BWS_WRITE_TOKEN || true
  run reconcile_secrets
  [ "$status" -eq 75 ]
  [[ "$output" == *"BWS_WRITE_TOKEN"* ]]
}
```

- [ ] **Step 2: Run — verify FAIL** (`reconcile_secrets`/`gen_password` undefined).

- [ ] **Step 3: Implement `steps/10-secrets.sh`**

Real content: `bws_cli() { command bws "$@"; }` wrapper; `gen_password() { openssl rand -base64 24 | tr '+/' '-_' | tr -d '=\n'; }`; `reconcile_secrets` that (a) `require_cfg BWS_WRITE_TOKEN` else `need_manual BWS_WRITE_TOKEN "…"`; (b) generates the four postgres passwords + `pgbackrest_cipher` + an age keypair (`age-keygen`), composes `database_url`/`migrator_database_url` from the matching passwords (`postgres://peppercheck_app:<app_pw>@postgres:5432/peppercheck?sslmode=disable` and the migrator variant), pushes the age **public** key as the `AGE_RECIPIENT` GitHub var input and the **private** key to the restore-scoped project; (c) for each of the 10 names, `bws_secret_exists` → skip, else `run_mutation "put <name>" bws_put_secret …`. Only generate a value for names not already present (read-back reuse keeps `database_url` consistent).

- [ ] **Step 4: Run — verify PASS** (3 new tests).
- [ ] **Step 5: Commit** — `git commit -m "feat(provision): 10-secrets — generate app secrets into BWS, idempotent"`.

---

## Task 3: `steps/20-bws.sh` — BWS projects/tokens gate + secret population

**Files:** Create `backend/deploy/provision/steps/20-bws.sh`; Modify `infra-setup.bats`.

**Interfaces:** Consumes `lib.sh` + `bws_cli`. Produces `reconcile_bws()`.

- [ ] **Step 1: Failing tests** — (a) missing `BWS_WRITE_TOKEN` → `NEEDS_MANUAL` naming the web-vault project+token creation; (b) with a stubbed `bws_cli` reporting the project exists and the runtime read-only token present in config, returns 0 and pushes `BWS_TOKEN` to the GH env once (stub `gh_secret_set`, assert called); (c) missing `BWS_RUNTIME_TOKEN` → `NEEDS_MANUAL` naming `BWS_RUNTIME_TOKEN`.
- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement** — `reconcile_bws`: `require_cfg BWS_WRITE_TOKEN` else `need_manual` ("Create the ${ENV_NAME} + restore-scoped BWS projects and a read-write machine-account token in the Bitwarden web vault"); confirm the project is reachable (`bws_cli project list`); ensure the 10 secrets exist (delegates to the same populate helpers from Task 2, invoked here if step 10 hasn't); `require_cfg BWS_RUNTIME_TOKEN` else `need_manual` ("Create a **read-only** machine-account token scoped to the ${ENV_NAME} project"); push it as the GH env secret `BWS_TOKEN` via `gh_secret_set` (defined in Task 6; stubbed in tests here).
- [ ] **Step 4: Run — PASS.**
- [ ] **Step 5: Commit** — `git commit -m "feat(provision): 20-bws — project/token gates + runtime BWS_TOKEN install"`.

---

## Task 4: `steps/30-tailscale.sh` — ACL + auth key + OAuth-client gate

**Files:** Create `backend/deploy/provision/steps/30-tailscale.sh`; Modify `infra-setup.bats`.

**Interfaces:** Consumes `lib.sh`. Produces `reconcile_tailscale()`, wrapper `ts_api METHOD PATH [body]` (curl to `https://api.tailscale.com/api/v2`, bearer `TS_API_KEY`, fail-closed).

- [ ] **Step 1: Failing tests** — (a) missing `TS_CLIENT_ID`/`TS_AUDIENCE` → `NEEDS_MANUAL` naming the admin-console OAuth-client creation; (b) `ts_api` stubbed so the ACL already contains the tags+grant → no ACL POST (assert not called); (c) ACL missing the grant → `run_mutation` POSTs the updated ACL (assert the stubbed `ts_api` POST /acl called once); (d) an ephemeral auth key is minted via `ts_api POST /keys` when none is cached for the run.
- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement** — `ts_api` wrapper; `reconcile_tailscale`: gate on the OAuth client vars; `GET /tailnet/-/acl`, check tags `tag:ci-deploy|pc-staging|pc-prod` + the `ci-deploy → ssh:22 → pc-*` grant present (jq), `POST` the reconciled ACL only if missing; mint a tag-scoped ephemeral key (`POST /tailnet/-/keys` with `capabilities.devices.create {tags:[TS_TAG], ephemeral:true, preauthorized:true, expirySeconds:600}`) and export it for step 60. Cite: https://tailscale.com/docs/features/access-control/auth-keys.
- [ ] **Step 4: Run — PASS.**
- [ ] **Step 5: Commit** — `git commit -m "feat(provision): 30-tailscale — ACL reconcile + ephemeral key + OAuth-client gate"`.

---

## Task 5: `steps/40-b2.sh` — bucket + Object Lock + lifecycle + restricted key

**Files:** Create `backend/deploy/provision/steps/40-b2.sh`; Modify `infra-setup.bats`.

**Interfaces:** Consumes `lib.sh`. Produces `reconcile_b2()`, wrapper `b2_cli(){ command b2 "$@"; }`.

- [ ] **Step 1: Failing tests** — (a) missing `B2_APPLICATION_KEY_ID`/`B2_APPLICATION_KEY`/`B2_BUCKET` → `NEEDS_MANUAL`; (b) stubbed `b2_cli` shows the bucket exists with Object Lock → no create; (c) bucket absent → `run_mutation` calls `b2 bucket create … --file-lock-enabled` then `b2 bucket update … --default-retention-mode governance … --lifecycle-rule …` (assert both stubbed calls); (d) the restricted key create omits `bypassGovernance` (assert the capability list passed to the stub excludes it).
- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement** — `reconcile_b2`: authorize via `b2 account authorize "$B2_APPLICATION_KEY_ID" "$B2_APPLICATION_KEY"` (wrapper); `b2 bucket get "$B2_BUCKET"` → if absent `b2 bucket create "$B2_BUCKET" allPrivate --file-lock-enabled`; ensure `b2 bucket update "$B2_BUCKET" --default-retention-mode governance --default-retention-period "7 days" --lifecycle-rule '{"daysFromHidingToDeleting":1,"fileNamePrefix":""}'`; ensure a bucket-restricted key exists via `b2 key create --bucket "$B2_BUCKET" pc-<env>-backup listBuckets,listFiles,readFiles,writeFiles,deleteFiles` (no `bypassGovernance`). Cite the v4 command forms. Note: a re-run reuses the existing key (b2 keys can't be re-read; if a fresh key is needed the operator rotates `b2_key_id`/`b2_key_secret` in BWS — document this in a comment).
- [ ] **Step 4: Run — PASS.**
- [ ] **Step 5: Commit** — `git commit -m "feat(provision): 40-b2 — bucket + governance Object Lock + lifecycle + restricted key"`.

---

## Task 6: `steps/50-github-env.sh` — Environments + secrets + vars + ghcr_token gate

**Files:** Create `backend/deploy/provision/steps/50-github-env.sh`; Modify `infra-setup.bats`.

**Interfaces:** Consumes `lib.sh`. Produces `reconcile_github_env()`, wrappers `gh_api …`, `gh_secret_set NAME VALUE` (env-scoped, used by Tasks 3/7 too), `gh_var_set NAME VALUE`.

- [ ] **Step 1: Failing tests** — (a) with stubs reporting the env + all 3 secrets + 8 vars present → no set calls (SATISFIED); (b) a missing var → `gh_var_set` called for exactly that var; (c) production env → a required-reviewer rule is set (assert the stubbed `gh_api PUT …/environments/production` body carries `reviewers`); (d) missing `GHCR_TOKEN` (needed to store in BWS via step 20) → the gate is surfaced (assert `NEEDS_MANUAL` naming `GHCR_TOKEN` and the GitHub web-UI PAT creation).
- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement** — `gh_api(){ command gh api "$@"; }`; `gh_secret_set(){ command gh secret set "$1" --env "$ENV_NAME" --body "$2"; }`; `gh_var_set(){ command gh variable set "$1" --env "$ENV_NAME" --body "$2"; }`. `reconcile_github_env`: `gh_api --method PUT "repos/{owner}/{repo}/environments/${ENV_NAME}"` (+ `reviewers` for production); reconcile the 8 vars (`API_PORT`, `FIREBASE_PROJECT_ID`, `PGBACKREST_REPO1_S3_{ENDPOINT,BUCKET,REGION}`, `AGE_RECIPIENT`, `TS_CLIENT_ID`, `TS_AUDIENCE`) from config/derived values, setting only the absent ones (list via `gh api …/variables`); ensure the 3 secrets (`BWS_TOKEN` via Task 3, `SSH_DEPLOY_KEY`/`SSH_HOST_KEY` via Task 7). The `ghcr_token` PAT is a gate here only in the sense that step 20 stores it in BWS; this step ensures the GitHub side (env + vars + the non-ghcr secrets). Cite the environments/secrets/variables REST endpoints.
- [ ] **Step 4: Run — PASS.**
- [ ] **Step 5: Commit** — `git commit -m "feat(provision): 50-github-env — Environments + reviewer + secrets/vars reconcile"`.

---

## Task 7: `steps/60-droplet.sh` — Droplet (cloud-init bootstrap) + host key

**Files:** Create `backend/deploy/provision/steps/60-droplet.sh`; Modify `infra-setup.bats`.

**Interfaces:** Consumes `lib.sh` + `gh_secret_set`. Produces `reconcile_droplet()`, wrapper `doctl_cli(){ command doctl "$@"; }`.

- [ ] **Step 1: Failing tests** — (a) missing `DO_TOKEN` → `NEEDS_MANUAL`; (b) stubbed `doctl_cli` reports the droplet exists → no create; (c) droplet absent → `run_mutation` calls `doctl compute droplet create` with `--user-data-file` (assert the rendered cloud-init contains `bootstrap.sh` + `TAILSCALE_TAG`/`TAILSCALE_AUTH_KEY`/`DEPLOY_SSH_PUBLIC_KEY`); (d) the deploy SSH keypair is generated when absent and its private half stored via `gh_secret_set SSH_DEPLOY_KEY` (assert called); (e) after create, the host key is captured (stub `ssh_keyscan`) and stored via `gh_secret_set SSH_HOST_KEY`.
- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement** — `reconcile_droplet`: gate on `DO_TOKEN`; ensure a deploy keypair exists (generate to a tmp with `ssh-keygen -t ed25519` if `SSH_DEPLOY_KEY` not yet in the GH env; store private→`SSH_DEPLOY_KEY`, keep public for cloud-init); `doctl compute droplet get "pc-${ENV_NAME}"` → if absent, render a cloud-init user-data (clone the repo + run `bootstrap.sh` with the tag, the ephemeral Tailscale key from step 30, and the deploy public key) and `doctl compute droplet create "pc-${ENV_NAME}" --region "$DO_REGION" --size "$DO_SIZE" --image ubuntu-… --user-data-file …`; wait for Tailscale up, then `ssh_keyscan` the host over the tailnet and store `SSH_HOST_KEY`. Cite doctl user-data + droplet create.
- [ ] **Step 4: Run — PASS.**
- [ ] **Step 5: Commit** — `git commit -m "feat(provision): 60-droplet — droplet + cloud-init bootstrap + host-key capture"`.

---

## Task 8: `steps/70-dns.sh` — Cloudflare A record (DNS-only)

**Files:** Create `backend/deploy/provision/steps/70-dns.sh`; Modify `infra-setup.bats`.

**Interfaces:** Consumes `lib.sh`. Produces `reconcile_dns()`, wrapper `cf_api METHOD PATH [body]` (curl to `https://api.cloudflare.com/client/v4`, bearer `CLOUDFLARE_API_TOKEN`, fail-closed).

- [ ] **Step 1: Failing tests** — (a) missing `CLOUDFLARE_API_TOKEN`/`CLOUDFLARE_ZONE_ID` → `NEEDS_MANUAL`; (b) stubbed `cf_api` shows the A record present with the right IP and `proxied:false` → no change; (c) record absent → `run_mutation` POSTs an A record with `proxied:false` (DNS-only) for `PUBLIC_DOMAIN`.
- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement** — `cf_api` wrapper; `reconcile_dns`: gate on the token+zone; `GET /zones/{zone}/dns_records?type=A&name=${PUBLIC_DOMAIN}`; if absent or wrong IP/proxied, `POST`/`PATCH` `{type:"A", name:PUBLIC_DOMAIN, content:<droplet ip>, proxied:false}`. The droplet IP comes from step 60 (via `doctl` or a shared var). Cite the Cloudflare DNS-records API.
- [ ] **Step 4: Run — PASS.**
- [ ] **Step 5: Commit** — `git commit -m "feat(provision): 70-dns — Cloudflare DNS-only A record reconcile"`.

---

## Task 9: `steps/80-verify.sh` — assertions (non-mutating)

**Files:** Create `backend/deploy/provision/steps/80-verify.sh`; Modify `infra-setup.bats`.

**Interfaces:** Consumes `lib.sh`. Produces `reconcile_verify()`.

- [ ] **Step 1: Failing tests** — (a) with all stubbed checks passing → returns 0; (b) if the off-tailnet SSH check unexpectedly *succeeds* (SSH reachable publicly) → the step returns non-zero with a clear message (assert failure). Stub the check helpers (`check_ssh_off_tailnet_refused`, `check_ufw_tailnet_only`, `check_tls_le`, `check_secret_perms`).
- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement** — `reconcile_verify`: run each check helper; aggregate; a failed assertion `log_err`s and returns non-zero (this step *asserts*, it never mutates, so it has no NEEDS_MANUAL). Real checks: a from-runner `ssh -o ConnectTimeout=5 deploy@<public-ip>` must time out/refuse; `ssh deploy@$SSH_HOST 'sudo ufw status'` shows 22 only on `tailscale0`; `curl`/`openssl s_client` confirms a real LE cert on `PUBLIC_DOMAIN` (post first deploy); `ssh deploy@$SSH_HOST 'stat -c %a /opt/peppercheck/deployments/*/secrets/*'` are `0400`.
- [ ] **Step 4: Run — PASS.**
- [ ] **Step 5: Commit** — `git commit -m "feat(provision): 80-verify — tailnet/ufw/TLS/perms assertions"`.

---

## Task 10: `steps/90-monitoring.sh` — Better Stack + DO alerts (ping model)

**Files:** Create `backend/deploy/provision/steps/90-monitoring.sh`; Modify `infra-setup.bats`.

**Interfaces:** Consumes `lib.sh`. Produces `reconcile_monitoring()`, wrapper `bs_api METHOD PATH [body]` (curl to `https://uptime.betterstack.com/api/v2`, bearer `BETTERSTACK_API_TOKEN`, fail-closed).

- [ ] **Step 1: Failing tests** — (a) missing `BETTERSTACK_API_TOKEN` → `NEEDS_MANUAL`; (b) stubbed `bs_api` shows the `/livez` + `/readyz` monitors and the 4 heartbeats already present → no create; (c) a missing monitor → `run_mutation` POSTs it; (d) staging monitors are created non-paging (assert the body sets the non-paging/team-escalation field for `ENV_NAME=staging`).
- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement** — `bs_api` wrapper; `reconcile_monitoring`: gate on the token; list monitors, ensure uptime monitors for `https://$PUBLIC_DOMAIN/livez` and `/readyz` (+ TLS-expiry) and heartbeat monitors for worker/backup/wal-freshness/host-checks; staging = non-paging. Then `doctl monitoring alert create` for host CPU/memory/disk (idempotent: list first). It does NOT touch any monitoring script. Cite the Better Stack monitors/heartbeats API + `doctl monitoring alert create`.
- [ ] **Step 4: Run — PASS.**
- [ ] **Step 5: Commit** — `git commit -m "feat(provision): 90-monitoring — Better Stack monitors + DO alerts (ping model)"`.

---

## Self-Review

**Spec coverage:** design §4.1 layout → Tasks 1-10 (all files created); §4.2 CLI → Task 1; §4.3 reconcile contract → Task 1 + every step; §4.4 config/secret boundary → Task 1 (config example, gitignore) + Task 2 (secrets→BWS); §5 step catalog → Tasks 2-10 one-for-one; §6 error/idempotency → Task 1 framework + per-step reconcile; §7 verified capabilities → cited in the relevant step tasks; §8 testing (bats + stubbable wrappers, CI wiring) → Task 1 + each task's tests; §2 non-goals (no GITHUB_TOKEN change, no monitoring-script edits, gates stay manual) → enforced by the Global Constraints. All mapped.

**Placeholder scan:** provider API step bodies (Tasks 3-10) give the concrete command/endpoint forms + the exact reconcile decisions + representative bats stubs, with the illustrative flag values (`expirySeconds`, retention period, lifecycle days) to be confirmed against the cited docs at implementation — the per-task `shellcheck`/bats/`actionlint` gates and the real stand-up finalize runnable specifics. No task is left as "similar to N" or "add error handling."

**Type/name consistency:** `NEEDS_MANUAL=75`, `need_manual`, `cfg`/`require_cfg`, `run_mutation`, `is_dry_run` (Task 1) are used verbatim by every step; the provider wrappers `gh_api`/`gh_secret_set`/`gh_var_set` (Task 6) are consumed by Tasks 3/7 and defined once; `reconcile_<name>` matches the orchestrator's `reconcile_${step//-/_}` dispatch; the 10 BWS secret names and 8 GH vars match the RUNBOOK/compose set used in Phase 7-A.
