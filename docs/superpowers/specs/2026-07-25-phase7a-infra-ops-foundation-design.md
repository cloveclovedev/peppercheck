# Phase 7-A — Infrastructure & Operations Foundation (design)

> Part of the Supabase → Go API + VPS refactor.
>
> - Program strategy: `docs/superpowers/specs/2026-07-22-supabase-to-go-vps-refactor-design.md`
> - Phase 0 baseline (accepted operational decisions): `docs/superpowers/specs/2026-07-22-phase0-baseline.md` (§12)
> - Phase 1 foundation (local skeleton this phase productionizes): `docs/superpowers/plans/2026-07-23-phase1-foundation.md`
>
> This spec covers **Phase 7-A only** — the infrastructure/operations foundation
> that is largely independent of the feature phases (3–6) and can be built ahead
> of them. The feature-coupled cutover half (Phase 7-B) is out of scope (§13).

## 0. Revision note

**v7 (2026-07-25)** — plan review; folded back into the spec:

- **deploy≈root, simplified:** the `deploy` user is in the `docker` group (root-
  equivalent), so the intra-host root-install-helper is dropped; `deploy` installs
  secrets directly at the consumer UID. Trust boundary = SSH/tailnet access (§6.5).
- `*_FILE` is **fail-closed** in production (set-but-unreadable errors; no env
  fallback) (§6.2).
- The production Compose is a **standalone file**, not an overlay, to avoid
  merge-semantics footguns (§5.4, §7).

**v6 (2026-07-25)** — fifth code review; folded in:

- **release manifest vs deployment manifest** split into two layers: an
  environment-independent release manifest (SHA + 3 digests, promoted as-is), and a
  per-environment deployment manifest (release + secret revision, atomic `current`
  switch); promotion source fixed (§5.4).
- The backup container mounts **`pgdata` read-only**, with writable spool/socket/log
  separated; the restore drill writes to a separate volume (§8.1).

**v5 (2026-07-25)** — fourth code review; folded in:

- `archive_command` needs the WAL path arg: `pgbackrest --stanza=main archive-push
  %p` (§8.1).
- The Compose **project name is pinned** (`name: peppercheck-<env>` / `-p`) so
  running from `/releases/<sha>/` cannot fork a per-release network/volume/DB (§5.3,
  §7).
- First staging deploy triggers on **integration-branch push**, not
  `workflow_dispatch` (which requires the workflow on `main`) (§10, §12).
- **Production digest provenance:** the staging-validated `source SHA + 3 digests`
  release manifest is **promoted** to production, not rebuilt (§5.3–5.4).

**v4 (2026-07-25)** — third code review; all corrections verified and folded in:

- Workflow-level `cancel-in-progress` would kill an in-flight deploy → **per-job
  concurrency**; the deploy group serializes with `cancel-in-progress: false` (§5.2).
- The backup container's **connection path to Postgres** is defined: shared pgdata +
  shared Postgres Unix socket, unified UID, pinned pgBackRest version (§8.1).
- `run --rm migrate` then `up -d` could **re-run the migration** via the api→migrate
  dependency → the prod overlay removes that dependency; a CI `compose config` check
  enforces it (§5.3, §7, §11).
- RPO cannot be judged from the LSN byte-gap alone → a **multi-signal** RPO monitor,
  plus the `archive-push-queue-max` **WAL-drop / PITR-chain-break** hazard and its
  runbook (§8.2, §9).
- Release and secret revisions are switched as **one atomic deployment manifest**
  (single `current` symlink), rollback moves both (§5.3).
- A **numeric Object-Lock/retention invariant** is fixed (§8.3).
- The runbook is split into **Prerequisites / First deploy / Post-deploy** (§10).
- The Droplet **SSH host-key fingerprint** is pinned in the GitHub Environment (§5.5).

**v3** fixed: `workflow_run` default-branch; migration-gated deploy;
pgBackRest-as-retention-authority; atomic DB rotation; secret-chown ownership;
inode/restart provider; ufw `tailscale0` + OIDC; plaintext-at-rest wording.
**v2** fixed the first review (secret uid/gid, DB rotation, CI sequencing,
pgBackRest placement, Tailscale-OIDC, `/livez`, symmetric-key decision).

## 1. Why split Phase 7

Strategy §22's Phase 7 bundles subsystems with different dependencies:

- **Infrastructure/operations foundation** — deploy pipeline, runtime secrets,
  production Compose topology, backup/restore/PITR productionization, monitoring,
  Droplet provisioning. These build on the Phase 1 skeleton and Phase 0's accepted
  decisions (§12) and depend on **no** feature phase (two small caveats in §14).
  Standing up staging early gives Phases 3–6 a real deploy target and retires
  launch-blocker #10 (baseline §5.3) before cutover. Being upstream, it is built
  **first**.
- **Cutover/release** — release-journey suite, Supabase removal, `main` swap, data
  reset + reference seed, store/legal metadata, submission → **Phase 7-B**.

## 2. Scope & boundaries

**In scope:** CI image build → GHCR; sequenced CI-driven deploy (staging +
production); runtime secrets (BWS-rendered, per-container consumption); production
Compose overlay + Caddy TLS; pgBackRest backup/restore/PITR to B2 + age logical
fallback; monitoring/alerting with WAL-freshness; Droplet provisioning (bootstrap +
runbook + Tailscale); stand up staging + first restore drill; CI gates; production
overlay + workflow authored (Droplet provisioned at cutover).

**Out of scope (Phase 7-B):** release-journey suite; Supabase runtime/SDK removal;
`main` swap; data reset + reference seed; store/legal metadata + submission;
production Droplet provisioning; retiring old Supabase deploy workflows; RevenueCat
internal-UUID configuration.

## 3. Architecture overview

```
[GitHub Actions — ci-backend.yml]  (PR + push refactor/go-api-vps + workflow_dispatch)
   NO workflow-level concurrency; per-job groups:
    job go     (concurrency: ci-<ref>, cancel-in-progress: true) → gofmt/vet/test/atlas
    job image  (needs: go, same fast group) → push GHCR: backend / custom-postgres / backup @digest
    job deploy-staging (needs: image, if ref==refactor/go-api-vps;
                        concurrency: deploy-staging, cancel-in-progress: FALSE → serialized)
                → uses reusable deploy workflow (Tailscale OIDC → SSH over tailnet, pinned host key)
[deploy-production] reusable workflow ← workflow_dispatch (transition) → v* tag (post-cutover)
                    production Environment gate; concurrency: deploy-production, cancel-in-progress: FALSE
   deploy: ship release → pull → run --rm migrate (gate) → switch ONE current manifest symlink
           → up -d --no-build --wait → /readyz → rollback-on-fail (manifest = release+secret)
[DO Droplet: staging.peppercheck.dev]           [DO Droplet: peppercheck.dev] (designed; provisioned 7-B)
  Caddy (ACME TLS; only :80/:443 public; ufw 22 bound to tailscale0)
  ├─ api      ← DATABASE_URL_FILE ...  → /livez, /readyz   (NO migrate dependency in prod)
  ├─ worker   → heartbeat
  ├─ postgres (custom image +pgbackrest client; 5432 NOT published)
  │     shares pgdata + /var/run/postgresql socket with backup (unified UID)
  │     archive_command → pgbackrest archive-push (async, spool, queue-max) → B2 (S3 repo)
  └─ backup (custom image: pgbackrest + cron + age pg_dump)
        pgbackrest backup/expire/check (retention authority; connects via shared socket) → B2
        age pg_dump logical fallback (daily) → B2
[B2] private; Object Lock (governance) < pgBackRest retention (~40d invariant); lifecycle = orphan cleanup; SSE-B2
[Better Stack]  prod: uptime + TLS + heartbeats + RPO multi-signal + inode/restart(custom) → email
                staging: same monitors, non-paging + maintenance windows
[DO Monitoring] host CPU/load/mem/filesystem/bandwidth (inode/restart NOT here → custom checks)
```

## 4. Accepted decisions

| Topic | Decision |
|-------|----------|
| Deploy control | CI-driven; reuse tag/branch convention retargeted Supabase→VPS. Transition: VPS deploy runs from `ci-backend.yml` (staging job) / `workflow_dispatch` (production); does not take over `beta/v*`/`v*` until cutover. |
| CI→deploy | Staging deploy = **job in `ci-backend.yml`** (`needs: image`, ref-guarded, digests via outputs); `workflow_run` needs the workflow on `main`, so it is not used. Production = reusable workflow. **Per-job concurrency**; deploy groups `cancel-in-progress: false` (serialized). |
| Runtime secrets | BWS token in GitHub (CI-rendered), per-container consumption; hardened (§6). |
| Registry | GHCR; backend + custom-postgres + backup images all `@sha256:digest`. |
| Deploy strategy | No blue-green. Migration-gated ordering; **single atomic deployment manifest** (release+secret); expand-contract. |
| Runner→Droplet | Tailscale ephemeral node via OIDC; ufw 22 bound to `tailscale0`; **pinned host key** (§5.5). |
| Provisioning | Idempotent bootstrap + runbook (not Terraform). |
| Environment stand-up | Staging now; production designed now, provisioned at cutover. |
| Backup tooling | **pgBackRest** (physical + WAL + PITR + retention authority) to B2, connecting to Postgres via a **shared socket**; age `pg_dump` daily logical fallback. |
| Backup encryption | pgBackRest `aes-256-cbc` (symmetric; explicit decision §8.5); age (asymmetric) for the logical fallback. |
| Health paths | `/livez`, `/readyz`. |
| Alerting | Email only; per-environment (production pages; staging non-paging). |

## 5. Deploy pipeline

### 5.1 Images

Three CI-built images, pinned by `@sha256:digest`: `peppercheck-backend` (Go
api/worker/healthcheck via `command:`); `peppercheck-postgres` (`postgres:17` +
pgBackRest client, so `archive_command` can call `archive-push`);
`peppercheck-backup` (pgBackRest + cron + age `pg_dump`). **Both DB images pin the
identical pgBackRest version** (§8.1).

### 5.2 Concurrency & sequencing

- `ci-backend.yml` gains a `push` trigger for `refactor/go-api-vps`. The `image` job
  (`needs: go`) builds/pushes the three images after tests pass and **emits digests
  as job outputs**. Staging deploy is a downstream job `deploy-staging`
  (`needs: image`, `if: github.ref == 'refs/heads/refactor/go-api-vps'`) consuming
  those outputs — avoiding `workflow_run`, which only fires for a workflow on the
  **default branch (`main`)**.
- **No workflow-level `concurrency`** (a workflow-level `cancel-in-progress: true`
  would cancel the whole run, deploy job included). Instead:
  - `go` + `image`: `concurrency: ci-<ref>`, `cancel-in-progress: true` (fast CI).
  - `deploy-staging` / production workflow: their own `concurrency: deploy-<env>`
    group with **`cancel-in-progress: false`**, so a newer push **queues** behind an
    in-flight deploy instead of interrupting it.
- Deploy logic lives in a **reusable workflow** shared by staging + production.

### 5.3 Deploy ordering (migration-gated, atomic, rollback-safe)

A single `up -d` recreates changed containers and can drop the old API if the
migration then fails; and re-running `up` after `run --rm migrate` could re-execute
the migration via a leftover dependency (§7). The reusable deploy workflow:

1. Tailscale OIDC connect (`tag:ci-deploy`, pinned host key); `bws run` → render +
   **verify** secrets into a staging dir (§6).
2. Ship the versioned release dir (§5.4) to `/opt/peppercheck/releases/<sha>/` and
   the matching secret revision.
3. `docker compose pull` the pinned digests.
4. **`docker compose run --rm migrate`** — gate on success (`run --rm` leaves no
   stopped Atlas container holding the migrator password).
5. On success, **atomically switch a single `current` deployment-manifest symlink**
   that binds **both** the release dir and the secret revision, so one switch moves
   both together (no split-brain).
6. `docker compose up -d --no-build --wait` (prod overlay has **no** api→migrate
   dependency, so this does not re-run the migration).
7. Post-deploy `curl -fsS .../readyz`; on failure **repoint `current` to the prior
   manifest and `up -d`** (rollback release + secret together). Expand-contract
   migrations make code rollback safe.

**All Compose invocations** (migrate, up, rollback) pass a **fixed project name**
`-p peppercheck-<env>` (equivalently `name:` / `COMPOSE_PROJECT_NAME`), so running
from a per-SHA `/releases/<sha>/` directory never forks a new project (network /
volume / Postgres) per release.

### 5.4 Release vs deployment manifests (two layers)

Two distinct artifacts, kept separate:

- **Release manifest (environment-independent):** `source SHA` + the three image
  `@sha256:digest`s. Built once by the `image` job and published as an **OCI artifact
  to GHCR** (durable, digest-addressable, co-located with the images; a GitHub
  Actions artifact is the lighter, run-scoped alternative). After staging validation
  it is **promoted as-is to production**, which resolves nothing and rebuilds
  nothing, so production runs exactly what staging verified.
- **Deployment manifest (environment-specific):** the release manifest **+ that
  environment's secret revision**. The single `current` symlink points at it, so one
  atomic switch moves the release and its matching secrets together; rollback
  repoints it.

The shipped release directory contains: `compose.prod.yaml` (standalone);
`deploy/caddy/Caddyfile`; `migrations/`; `deploy/postgres/init/*` +
pgBackRest/archive configs; `deploy/backup/*`; and the rendered secret revision
(out-of-tree, restricted) referenced by the deployment manifest.

### 5.5 Runner → Droplet connectivity

- GitHub-hosted runner joins the tailnet as an **ephemeral, tagged** node via
  `tailscale/github-action` using **OIDC** (no long-lived Tailscale secret); needs
  `permissions: id-token: write`, the federated **client ID + audience**, and
  **repository/workflow OIDC claim restrictions** on the Tailscale side.
- Tailnet ACL: `tag:ci-deploy` → SSH (22) to `tag:pc-staging` / `tag:pc-prod`.
- **ufw allows 22 only on the `tailscale0` interface**; only Caddy 80/443 public.
- SSH auth: environment-scoped deploy key, **with the Droplet's host-key fingerprint
  pinned in the GitHub Environment (`known_hosts`)** to prevent SSH MITM. Tailscale
  SSH noted as a future key-less simplification.

### 5.6 Transition vs steady state

During transition the live app keeps `deploy-beta.yml` / `deploy-production.yml`;
VPS deploy does not touch them or the tag triggers. At cutover the triggers swap.
Reversible.

## 6. Runtime secrets mechanism

CI renders secrets from Bitwarden Secrets Manager at deploy; **each container
consumes them via its own supported mechanism** (a single owner/mode cannot serve
different UIDs; file-based Compose secrets do not apply `uid`/`gid`/`mode` outside
Swarm).

### 6.1 BWS + delivery

- Separate staging/production BWS projects; per-environment **read-only** tokens as
  environment-scoped GitHub Actions secrets (bootstrap secret per policy).
- The runner `bws run` → renders each secret to a tmpfs file, **verifies**, ships to
  a **staging directory** on the Droplet; the deploy then switches the active
  revision atomically **as part of the single `current` manifest** (§5.3, §6.5). Log
  masking (`::add-mask::`). **No plaintext `.env`** on the Droplet; the 0400 secret
  files are plaintext at rest but **restricted per consuming UID**.

### 6.2 Per-container consumption

| Consumer | Runtime UID | Mechanism | Secret file |
|----------|-------------|-----------|-------------|
| Go `api`/`worker` | `nonroot` 65532 | `core/config` `*_FILE` (falls back to `VAR` locally) | `0400`, owned 65532 |
| `postgres` (custom) | postgres 999 | `POSTGRES_*_PASSWORD_FILE`; role-init reads same files | `0400`, owned 999 |
| Atlas `migrate` one-shot | image default | migrator URL/password as an **env var** at deploy (Atlas has no `_FILE`; `run --rm`) | n/a |
| pgBackRest (postgres + backup) | **unified UID across both images** | pgBackRest config references repo cipher pass + B2 keys | `0400`, owned that UID |

`*_FILE` is **fail-closed in production**: if `K_FILE` is set but unreadable, config
errors rather than falling back to `K`. The env fallback exists only for local dev,
where `K_FILE` is unset.

### 6.3 Secret inventory

Postgres passwords (app/migrator/backup/superuser); **B2 application key (id+secret)**;
**pgBackRest repo cipher passphrase**; `AGE_RECIPIENT` (public, not a secret);
**age private key** (restore-only, in BWS, never on the primary Droplet). No
long-lived Tailscale secret (OIDC); no Firebase service-account secret (Phase 2
`WithoutAuthentication`). Stripe/R2/RevenueCat arrive with their phases.

### 6.4 Rotation runbooks

- **DB-role passwords** — roles are created once at DB init (`00-roles.sh`,
  empty-datadir only), and `ALTER ROLE` invalidates the running container's old
  password immediately. Use an **atomic rotation workflow**: stage the new secret →
  stop `api`/`worker` → `ALTER ROLE` over the **local socket** → atomically switch
  the manifest → start + verify (`/readyz`, `pgbackrest check`) → documented
  rollback. Or take an explicit short **maintenance window**. Pass the password via a
  **file / psql variable**, never a SQL literal, shell arg, or log.
- **B2 key** — create new → deploy → verify archive/backup/restore → delete old.
- **pgBackRest cipher pass** — infrequent, planned re-encrypt/repoint.
- Validate DB-password rotation once as a DoD item.

### 6.5 Ownership, deploy privilege & atomic switch

The `deploy` user is in the `docker` group, which is **root-equivalent** (it can
bind-mount the host as root via a container), so an intra-host privilege-separation
helper would be security theatre. The trust boundary is therefore **SSH/tailnet
access to `deploy`**, not intra-host separation. `deploy` — already privileged —
installs each secret file directly with its **consumer's UID and `0400`** (name
validated against an exact allowlist, no globs / `..` / `/`). Secrets are staged,
verified, and the deployment manifest (release + secret revision) is switched
atomically via `current` (with a `previous` pointer for rollback), so a partial
render never goes live.

**Rationale (recorded):** for a solo operator operational neglect dominates over
platform compromise; cheap, exercised rotation yields higher effective security.

## 7. Production Compose topology & Caddy

`compose.prod.yaml` is a **standalone** production Compose file (not an overlay of the
local `compose.yaml` — Compose merge appends/merges and cannot drop the local
`build:`, `migrate` dependency, or backup `profiles`, so a standalone file avoids the
footgun): fixed project `name: peppercheck-<env>` (§5.3); `@sha256:` images for
backend + custom postgres + backup; `restart: unless-stopped`; secrets per §6.2; **5432 not
published**; only Caddy 80/443 public, 22 tailnet-only; backup runs by default;
`CADDY_SITE_ADDRESS` = real domain → ACME TLS, `admin off`, HSTS; size-limited logs;
modest 1 GiB tuning + resize trigger. **The prod overlay removes the api/worker →
`migrate` dependency** (migration is deploy-workflow-driven via `run --rm`, §5.3), so
`up -d` never re-runs it; a CI `docker compose config` check (§11) asserts the
resolved prod config has **no runtime migrate dependency and no `build:`**.

## 8. Backup / restore / PITR

### 8.1 pgBackRest topology & Postgres connection path

`archive_command` runs **inside the Postgres container** → the custom
`peppercheck-postgres` image ships the **pgBackRest client**;
`archive_command = pgbackrest --stanza=main archive-push %p` (the WAL path `%p` arg
is required) with **async archiving**
(`archive-async=y` + spool + `archive-push-queue-max`, §8.2). Scheduled
`backup`/`expire`/`check` run from `peppercheck-backup` (cron). **Connection path
(fixed):** both containers share the Postgres Unix socket (`/var/run/postgresql`) and
the `pgdata` volume — the **backup container mounts `pgdata` read-only** (normal
backups only read production data), with **separate writable volumes for spool, logs,
and any socket dir**. Both run as a **unified UID**, use the same `pg1-path`, and pin
the **identical pgBackRest version** — the simplest local-cluster configuration for
this scale (no `pg1-host`/TLS-server remote setup). The **restore drill writes to a
separate volume**, never this `pgdata` (§8.4). Repository = pgBackRest **S3-type repo
on B2**. The age-encrypted `pg_dump` is the independent **daily logical
fallback** to a separate B2 prefix.

### 8.2 Schedule, retention, RPO & the WAL-drop hazard

- Schedule: weekly `full` + daily `differential` (+ optional `incremental`);
  continuous WAL.
- **pgBackRest is the retention authority**; retention keeps fulls **and all
  dependent WAL for ≥30-day PITR**, plus 30 daily logical dumps.
- **RPO is enforced by monitoring (§9), not `archive_timeout`** — `archive_timeout`
  only bounds segment-switch interval, not B2 arrival. It is lowered to leave
  B2-transfer headroom; the **concrete value is pinned in the implementation plan**.
- **WAL-drop hazard (critical):** when `archive-push-queue-max` is exceeded,
  pgBackRest **returns success to Postgres while dropping WAL**, silently breaking
  the PITR chain. Mitigation: set `archive-push-queue-max` deliberately; **pre-alert
  before the threshold** (spool depth); **detect WAL drop**; and a **runbook that
  takes a new full backup to re-establish the PITR chain** after any drop.

### 8.3 B2 Object Lock ↔ retention (numeric invariant)

- Bucket: private, **governance-mode Object Lock** + SSE-B2.
- **pgBackRest owns retention/deletion**; a naive age-based lifecycle delete could
  remove an older full / WAL / metadata still needed to restore within the window.
- **Numeric invariant:** `pgBackRest retention ≥ Object-Lock period + one full-backup
  interval + buffer`. Concretely, 30-day Object Lock + weekly full → **~40-day**
  pgBackRest retention, so a lock always lapses before pgBackRest wants to `expire`.
- **B2 lifecycle is limited to final cleanup of hidden/noncurrent/orphan objects.**
- Runtime B2 key has **no `bypassGovernance`**.
- **Exit criterion:** verify the full **backup → expire → restore chain** against a
  short-lived test bucket.

### 8.4 Restore drill (safe & verifiable)

- Isolated Compose project on a **separate volume**; never against production data
  services. **Worker disabled**, **no production external credentials**, outbound
  restricted.
- Point-in-time correctness: **sentinel before and after** the target time; restore
  and assert pre-present / post-absent.
- Bring the API up on the restored DB; obtain a **Firebase ID token** (test account /
  staging Firebase) → authenticated smoke (`/readyz` + `/api/v1/me`).
- Verify the **age logical dump** restores independently (`age -d | pg_restore`).
- **Measure RTO** vs 4 hours; **safely tear down** afterward.
- **Phase 7-A deliverable:** first drill on **staging** against real B2 (retires
  launch-blocker #10). Production runs it monthly from cutover.

### 8.5 Encryption threat-model decision (explicit)

pgBackRest repo encryption is **symmetric** (`aes-256-cbc`), so the primary Droplet
holds a key that can also decrypt the repo — weaker than the baseline's
public-key-only posture. **Accepted**: pgBackRest has no asymmetric repo cipher; the
operable PITR path outweighs the regression on a single-tenant host; mitigations are
the `0400` UID-scoped secret, B2 Object Lock against tampering, and the retained
**asymmetric age logical dump** as an independent second line.

### 8.6 Staging backup policy

Staging holds test data only → no production RPO/retention obligation. Enable
pgBackRest to validate the mechanism (especially restore), run the drill, then dial
to low-frequency/on-demand. Only production carries the 15-minute-RPO / 30-day-PITR
configuration.

## 9. Monitoring & alerting

- **Health:** `/livez`, `/readyz` (implemented routes).
- **Better Stack:** uptime on `/livez` + `/readyz`, TLS-expiry, heartbeats (worker +
  each backup/archive cycle). Email first.
- **RPO enforcement (multi-signal, not a single LSN byte-gap):** ship, and alert on,
  the combination of — **age of the oldest un-arrived WAL / spool entry** (the true
  time signal), **unarchived WAL bytes**, **spool bytes/count**, **archive-push
  failures / drops**, the **latest B2-confirmed WAL segment**, cross-checked against
  **`pg_stat_archiver`**, plus `pgbackrest check` and latest-backup age. (A bare LSN
  byte-gap is write-rate-dependent and misses B2 lag / idle DBs.)
- **inode & container restarts are not DO Monitoring metrics** → custom **`df -i`**
  and **`docker inspect -f '{{.RestartCount}}'`** checks shipped to Better Stack.
- **DigitalOcean Monitoring:** host CPU/load/memory/filesystem/bandwidth.
- **Per-environment:** production pages via email; **staging non-paging
  (dashboard-only)**; runbook documents Better Stack maintenance windows before
  stopping staging.
- Vendor-neutral app: structured stdout logs + Prometheus/OpenTelemetry-compatible
  telemetry; no Better Stack types in feature packages; opt-in log shipping.

## 10. Provisioning (bootstrap + runbook)

- `deploy/provision/bootstrap.sh` — idempotent: Docker + compose plugin; non-root
  `deploy` user (in the `docker` group, root-equivalent — §6.5); **Tailscale install +
  tagged join**; the `/opt/peppercheck` layout owned by `deploy` (which installs
  secrets directly at the consumer UID); `ufw` (default deny; 22 bound to `tailscale0`;
  80/443 public); `fail2ban`; `unattended-upgrades`;
  `/opt/peppercheck/{releases,secrets,compose}` layout; log rotation; SSH hardening.
- **Runbook** split into three phases (maps directly to the release-checklist skill):
  - **Prerequisites (before any deploy):** Tailscale tags/ACLs + GitHub OIDC
    federated identity client (claim limits); BWS project + read-only token → GitHub
    env secret; B2 bucket + Object Lock + lifecycle + key; GHCR pull auth; GitHub
    Environments + protection + secrets **incl. pinned Droplet host key**; Droplet
    (`sgp1`, 1 GiB) → run bootstrap; DNS `staging.peppercheck.dev` A record
    **DNS-only (grey cloud)** for ACME HTTP-01.
  - **First deploy:** trigger by **push to `refactor/go-api-vps`** (not
    `workflow_dispatch`, which requires the workflow on the default branch `main`;
    that path becomes available only post-cutover) → verify `/readyz` + TLS.
  - **Post-deploy actions:** Better Stack monitors (staging non-paging) + DO host
    alerts + custom inode/restart/RPO checks; run backup + restore drill; record RTO.

## 11. Testing & CI gates

- `ci-backend.yml`: integration-branch push trigger; `image` job (`needs: go`);
  `deploy-staging` job (`needs: image`, ref-guarded); per-job concurrency (§5.2);
  post-deploy `/readyz` smoke.
- Static: `docker compose config` on the prod overlay — **asserting no runtime
  `migrate` dependency and no `build:`** (§7) — plus `caddy validate`, `shellcheck`
  on bootstrap/backup/archive scripts, and custom-image builds.
- Unit test for `core/config` `*_FILE` precedence.
- Restore-drill script is the backup-path verification (staging).
- No CI job reads committed secrets (strategy §24).

## 12. Exit criteria

- [ ] Clean staging deploy via the in-`ci-backend` pipeline (go → image →
      deploy-staging) with **per-job concurrency** (deploy serialized, never
      interrupted), deploying the exact digests CI built, migration-gated with a
      **single atomic (release+secret) manifest** switch and rollback.
- [ ] Prod overlay has **no runtime migrate dependency / no `build:`** (CI
      `compose config` check passes); migration runs once, only via the deploy.
- [ ] Secrets consumed per-container; **`deploy` installs each secret at its consumer
      UID** (`0400`, exact-name allowlist); no plaintext `.env`; **DB-password
      rotation runbook validated once** with no broken-connection gap.
- [ ] `compose.prod.yaml` + Caddy TLS live on staging (real cert); SSH only via the
      tailnet (`tailscale0`-bound ufw) with a **pinned host key**.
- [ ] pgBackRest (custom postgres image; **shared-socket** connection; async
      `archive-push` with `archive-push-queue-max`) has physical base + WAL in B2
      (encrypted, Object Lock); **pgBackRest owns retention** (~40-day invariant); the
      **isolated, worker-disabled, sentinel-verified, RTO-measured PITR restore drill
      + authenticated smoke passes**; age logical dump also restores; a **WAL-drop /
      PITR-chain-rebuild runbook** exists.
- [ ] **backup → expire → restore chain** verified in a test bucket; runtime key has
      no `bypassGovernance`.
- [ ] Better Stack monitors + heartbeats + **multi-signal RPO** alert + custom
      inode/restart checks live (staging non-paging; production paging configured);
      DO host alerts on.
- [ ] Bootstrap + provisioning runbook (Prerequisites / First deploy / Post-deploy)
      complete and used to build staging.
- [ ] Production Compose overlay + production deploy (reusable) workflow authored
      (production Droplet not yet provisioned).

## 13. Out of scope → Phase 7-B

Release-journey suite; Supabase runtime/SDK removal; `main` swap; data reset +
reference seed; store/legal metadata + submission; production Droplet provisioning;
retiring old Supabase deploy workflows; RevenueCat internal-UUID configuration.

## 14. Independence caveats

Upstream of the feature phases; two small couplings: the **authenticated restore
smoke** uses Phase 2's `/api/v1/me` (essentially complete → available); **R2 object
backup** (baseline §12.1 daily R2→B2 copy) depends on Phase 4 R2 objects → shipped as
a **disabled skeleton**, enabled in / moved to Phase 4.

## 15. Risks

- Deploy pipeline first exercised at cutover → stand up staging now.
- Secrets blast radius (GitHub in trust boundary) → env-scoped read-only BWS tokens,
  Environment protection, Tailscale OIDC, pinned host key, masked logs, per-UID
  `0400` secret files (plaintext at rest but UID-restricted), no plaintext `.env`,
  single atomic manifest switch.
- A new push cancelling an in-flight deploy → per-job concurrency, deploy serialized.
- Migration taking the old API down / running twice → migration-gated ordering +
  prod overlay dependency removal + CI config check.
- Hand-rolled backup bugs = data loss → pgBackRest (retention authority) + isolated,
  sentinel-verified restore drill.
- **Silent WAL drop on queue overflow breaking PITR** → `archive-push-queue-max`,
  pre-alert, drop detection, chain-rebuild runbook.
- Backup-chain destruction via naive lifecycle deletion → pgBackRest owns retention;
  numeric Lock/retention invariant; lifecycle = orphan cleanup; test-bucket chain
  verification.
- WAL stalls undetected → multi-signal RPO monitoring.
- Symmetric repo key on the primary → explicit decision §8.5 + independent age dump.
- Staging alert fatigue → non-paging staging + maintenance windows.
- ACME behind Cloudflare → DNS-only staging record.
- 1 GiB pressure → size-limited logs, modest tuning, resize trigger.
