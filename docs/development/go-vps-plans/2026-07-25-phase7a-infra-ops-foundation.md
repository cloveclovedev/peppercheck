# Phase 7-A — Infrastructure & Operations Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the Phase 1 local skeleton into a production-grade VPS deploy +
backup/restore + monitoring foundation, stood up on staging, ahead of feature Phases 3–6.

**Architecture:** CI (`ci-backend.yml`) builds three digest-pinned images (backend,
custom postgres+pgBackRest, backup), pushes a release manifest (source SHA + 3 image
digests) as an OCI artifact and records its **manifest digest**; on the integration
branch a `deploy-staging` job calls a reusable deploy workflow that connects over
Tailscale (WIF), pulls+verifies the manifest **by digest**, renders secrets from BWS,
ships a uniquely-named deployment (release + secret revision), chowns secrets to their
consumer UIDs via a throwaway root container, runs a migration-gated deploy behind
Caddy TLS, and smokes or rolls back. Postgres archives WAL via pgBackRest (async) to a
B2 S3 repo; an age-encrypted `pg_dump` is the logical fallback. Monitoring is Better
Stack + DO with per-environment alerting.

**Tech Stack:** Go (stdlib + pgx), Docker Compose, GitHub Actions, Tailscale, Caddy,
PostgreSQL 17, pgBackRest, Backblaze B2 (+ MinIO for local/CI), age, Bitwarden Secrets
Manager, Better Stack, DigitalOcean.

## 0. Revision note

**v6** — fifth plan review; three fixes:

- **Full immutable image references:** the manifest stores complete refs
  (`ghcr.io/cloveclovedev/peppercheck-backend@sha256:…`, `arigaio/atlas@sha256:…`,
  `docker.io/library/caddy@sha256:…`), and `images.env` uses them **verbatim** —
  the previous `ghcr.io/.../peppercheck-<name>@digest` reconstruction pointed Atlas/Caddy
  at non-existent GHCR paths. Manifest verification covers **all** entries (T7/8/10).
- **chown helper pinned + isolated:** secret ownership is set **after pull**, inside
  `remote-deploy`, by the **digest-pinned, already-pulled postgres image** run with
  `--network none --pull never` — not a mutable, networked `alpine` mounting every
  plaintext secret (T8/10).
- **Correct WAL-queue signal:** async pgBackRest transfers straight from `pg_wal` and
  does **not** stage WAL bytes in the spool, so monitor the backlog in
  `pg_wal/archive_status/*.ready` (total bytes + oldest age), not spool size; set
  `archive-push-batch-size` well below `archive-push-queue-max` since the limit is
  only checked at async-run start (T2/17).

**v5** — fourth plan review; three fixes:

- **Promote covers the whole release, not just images:** the deploy `checkout` uses
  `ref: ${{ inputs.sha }}` so the shipped compose/migrations/scripts match the
  validated SHA; **Atlas and Caddy are also digest-pinned** (in `images.env` + the
  release manifest), so nothing in the release floats on a mutable tag (T5/7/8/10).
- **GHCR token hygiene:** the pull token is shipped as a `0400` secret and used inside
  `remote-deploy` with a **scoped `DOCKER_CONFIG` (login → pull → logout → rm)** — never
  on a command line, never persisted to `~/.docker/config.json` (T8/10). *(Lower
  severity — a read-only token on a tailnet-only single-tenant box — but cheap.)*
- **Logical-backup auth path:** the backup entrypoint builds a `0600` `.pgpass` from
  `POSTGRES_BACKUP_PASSWORD_FILE` (for `pg_dump`) and exports explicit S3 creds for the
  age-dump upload, **fail-closed** — otherwise the daily logical backup fails (T3).

**v4** — third plan review; four pre-implementation fixes folded into the task bodies:

- **SSH target ≠ public domain:** SSH goes to the **tailnet MagicDNS/IP** (`ssh_host`,
  e.g. `pc-staging`), while `/readyz` curls the **public domain** (`host`). ufw allows
  22 only on `tailscale0`, so SSHing the public name would be refused (T8/9/10/12).
- **Silent WAL-drop detection:** a queue-max overflow makes pgBackRest return success
  and **drop WAL without setting `last_failed_wal`**, so monitoring also checks the
  **latest WAL present+continuous in B2**, **latest-backup age**, and **persistently
  detects the queue-max-exceeded log line** (T17).
- **Drill waits for the target WAL in B2:** after the `post` sentinel, `pg_switch_wal()`
  and **wait until `last_archived_wal` covers the target** before restoring; restore
  with **`--target-action=promote`** (default `pause` blocks the API) (T16).
- **CI freshness + validated record:** the `image` job gets its own concurrency
  (older in-flight builds cancelled); `deploy-staging` adds a **head-SHA guard**; the
  promotion record is a GHCR tag **`staging-validated-<sha>` created only after the
  staging smoke passes**, which production **verifies** before deploying (T7/9).

**v3** — second plan review, folded into the task bodies. Key design fixes:

- **Secret ownership:** `deploy` (a normal process, even in the docker group) cannot
  `chown` to 999/0. A **throwaway root container** chowns each secret to its consumer
  UID at deploy (Task 6/10). Each deployment stages into a **unique dir**
  `deployments/<sha>-<run_id>/` and is `mv`d into place (same-SHA redeploy/rotation
  safe).
- **Secret → process:** Compose does not convert a secret file to an env var. Custom
  postgres/backup images ship a **root entrypoint wrapper** that reads secret files and
  `export`s `PGBACKREST_*`/cipher/B2, then execs the stock entrypoint. `00-roles.sh`
  gains `*_FILE`. Atlas gets the migrator URL via a file read in its one-shot command
  (Task 2/3/5).
- **Local smoke** swaps postgres for the custom image; MinIO by host+port+TLS-off (Task 4).
- **`workflow_call` cannot receive Environment secrets from the caller:** the reusable
  workflow references `secrets.BWS_TOKEN`/`SSH_DEPLOY_KEY`/`SSH_HOST_KEY` directly; both
  Environments register them (Task 8/9).
- **Promote by digest:** output the ORAS-push manifest digest; pull by `@sha256:`;
  production verifies it matches the staging-validated digest (Task 7/8/9).
- **Tailscale** `@v4` + `oauth-client-id` + `audience` + `tags` (Task 8).
- **Backup ops:** `archive_timeout` in prod; S3 client in the backup image; **root cron
  daemon + postgres crontab**; shared `pgdata`/socket/spool/log volumes (Task 3/5/14).
- **Restore drill:** `restore_sentinel` migration; DB-clock target; B2 config; volume
  ownership; dump from B2; real `pg_restore`; cleanup trap; Firebase cred from the
  restore-scoped BWS project (Task 16).
- **Monitoring:** concrete scripts; clear the WAL alert when `last_archived_wal`
  supersedes `last_failed_wal` (not on empty string); BWS→systemd URL delivery; unit
  install/enable (Task 17).
- **Ordering:** the release-checklist task moves before Group E (Task 13).

Illustrative shell/YAML remains version-pinned at implementation (exact `bws`/`oras`
install URLs, the atlas image's shell) — the per-task `actionlint`/`shellcheck`/
`compose config | jq`/smoke/drill gates finalize the runnable form.

## Global Constraints

- Images built in **CI, never on the VPS**; deploys reference `@sha256:digest`. Registry = **GHCR**.
- **Build once → promote**: validate a release (SHA + 3 digests, an OCI manifest referenced by its **manifest digest**) on staging; production promotes the **same digest**.
- Deploy is **CI-driven over Tailscale** (`@v4`, **WIF**; no long-lived Tailscale secret). SSH **never public**; **ufw allows 22 only on `tailscale0`**; the Droplet **host key is pinned** in the GitHub Environment.
- **No blue-green. Migration-gated**: `docker compose run --rm migrate` succeeds before recreate; migrations **expand-contract**.
- Production Compose is **standalone** (no api/worker→`migrate` dependency; no `build:`); a CI `config --format json | jq` check asserts both.
- **Fixed project name** `-p peppercheck-<env>` on every Compose call.
- Each deployment stages into a **unique dir** and binds release + secret revision; `current`/`previous` symlinks; rollback repoints.
- **`deploy` is docker-group (root-equivalent via `docker run`, not as a process)**; secret files are written by deploy and **chowned to their consumer UID (`0400`) by a throwaway root container**. Trust boundary = SSH/tailnet. **No plaintext `.env`.** `*_FILE` **fail-closed**.
- Secret **file contents reach each process** via a root entrypoint wrapper (`PGBACKREST_*`), `POSTGRES_*_PASSWORD_FILE`, `00-roles.sh` `*_FILE`, or a file-read in the atlas one-shot — **never** by Compose "secret→env" (which does not exist).
- Secrets rendered in CI from **BWS, per-environment read-only tokens** referenced **inside** the reusable workflow (`workflow_call` can't take Environment secrets from the caller). **No CI job reads committed secrets.**
- **pgBackRest owns retention** (time-based, ≥ lock+interval+buffer). `archive_command` uses `%p`. **Async archiving**; **`archive-push-queue-max`** with a pre-alert (overflow drops WAL → breaks PITR). Prod sets **`archive_timeout`** (monitored). Both DB images pin the **identical pgBackRest version**; config baked in.
- **Local/CI object storage = MinIO** (host+port+TLS-off, path style); real **B2 only on staging**.
- Health: **`/livez`**, **`/readyz`**. Alerting: production pages (email); **staging non-paging**.
- Touches `backend/` + `.github/workflows/` only. Atlas pinned **v1.2.0**.

---

## Group A — Local-testable building blocks

### Task 1: `core/config` `*_FILE` support (fail-closed)

**Files:** Modify `backend/internal/core/config/config.go`; Test `backend/internal/core/config/config_test.go`

**Interfaces:** `func lookupEnvOrFile(key string) (string, bool, error)` — if `K_FILE` is set it MUST be readable (returns trimmed contents, else **error**, never a silent env fallback); if unset, returns `K` from env.

- [ ] **Step 1: Failing tests (fail-closed + precedence + env fallback)** — as in the three sub-tests: file wins & trims; `K_FILE` set-but-unreadable → error; no `K_FILE` → env.
- [ ] **Step 2: Run** — `cd backend && go test ./internal/core/config/ -run TestLookupEnvOrFile -v` → FAIL.
- [ ] **Step 3: Implement** the fail-closed `lookupEnvOrFile` (reads `K_FILE`, errors on read failure, else env); route `DATABASE_URL` + DB passwords through it and propagate the error from config load so a missing secret file aborts startup.
- [ ] **Step 4: Run** — `go test ./internal/core/config/ -v` → PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(backend): fail-closed *_FILE config resolution for Docker secrets"`.

---

### Task 2: Custom `peppercheck-postgres` image (pgBackRest, entrypoint secret→env, roles *_FILE)

**Files:** Create `backend/deploy/postgres/Dockerfile`, `pgbackrest.conf`, `entrypoint.sh`, `init/10-archive.sh`; Modify `backend/deploy/postgres/init/00-roles.sh`

**Interfaces:** image with pinned `pgbackrest`, a root entrypoint that exports `PGBACKREST_*` from secret files then execs the stock entrypoint, `archive_command` wired with `%p`, and `00-roles.sh` reading passwords from `*_FILE`.

- [ ] **Step 1: Dockerfile** — `FROM postgres:17`, pin `pgbackrest=${PGBACKREST_VERSION}*`, `COPY pgbackrest.conf /etc/pgbackrest/`, `COPY entrypoint.sh /usr/local/bin/`, `COPY init/* /docker-entrypoint-initdb.d/`, create+chown `/var/spool/pgbackrest` `/var/log/pgbackrest` to postgres, `ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]`.

- [ ] **Step 2: `entrypoint.sh` (root: export PGBACKREST_* from files, then stock entrypoint)**

```bash
#!/usr/bin/env bash
set -euo pipefail
read_secret() { [ -f "$1" ] && tr -d '\n' < "$1"; }
export PGBACKREST_REPO1_CIPHER_PASS="$(read_secret /run/secrets/pgbackrest_cipher)"
export PGBACKREST_REPO1_S3_KEY="$(read_secret /run/secrets/b2_key_id)"
export PGBACKREST_REPO1_S3_KEY_SECRET="$(read_secret /run/secrets/b2_key_secret)"
exec docker-entrypoint.sh postgres "$@"   # drops to postgres; env inherited by archive_command
```

- [ ] **Step 3: `pgbackrest.conf`** — `[global]` `repo1-type=s3`, `repo1-s3-uri-style=path`, `repo1-cipher-type=aes-256-cbc`, `archive-async=y`, `archive-push-queue-max=1GiB`, `archive-push-batch-size` well below queue-max (the limit is only re-checked at async-run start), `spool-path`, `log-path`, `start-fast=y`; `[main]` `pg1-path=/var/lib/postgresql/data`, `pg1-socket-path=/var/run/postgresql`. (`repo1-s3-endpoint`/`bucket`/`region` come from `PGBACKREST_*` env; endpoint is host only, no scheme.)

- [ ] **Step 4: `10-archive.sh`** — append to `postgresql.auto.conf`: `wal_level=replica`, `archive_mode=on`, `archive_command='pgbackrest --stanza=main archive-push %p'`, `archive_timeout=120s`, `max_wal_senders=3`.

- [ ] **Step 5: `00-roles.sh` `*_FILE` support** — read `POSTGRES_{APP,MIGRATOR,BACKUP}_PASSWORD` from the corresponding `_FILE` when set (the files mount at `/run/secrets/*`; init runs during the stock entrypoint), else env. Keep the existing role SQL.

- [ ] **Step 6: Build + verify** — `docker build -t pc-postgres-test deploy/postgres && docker run --rm --entrypoint pgbackrest pc-postgres-test version` → version.

- [ ] **Step 7: shellcheck + commit** — `shellcheck backend/deploy/postgres/entrypoint.sh backend/deploy/postgres/init/*.sh`; `git commit -m "feat(backend): custom postgres image (pgBackRest, secret->env entrypoint, roles *_FILE)"`.

---

### Task 3: Custom `peppercheck-backup` image (S3 client, root cron + postgres crontab, one-shot dump)

**Files:** Modify `backend/deploy/backup/Dockerfile`, `backup.sh`; Create `backend/deploy/backup/entrypoint.sh`, `crontab`, `pgbackrest.conf` (identical to Task 2's)

**Interfaces:** image whose root entrypoint exports pgBackRest env from secrets and starts a **root cron daemon** running a **postgres crontab**; cron drives pgBackRest + a one-shot age dump uploaded to B2 via an S3 client.

- [ ] **Step 1: `backup.sh` — one-shot** age-encrypted `pg_dump` → `pg_restore -l` verify → **upload to B2** (`mc cp`/`rclone`) → exit. Remove the Phase 1 `while true` loop. `AGE_RECIPIENT` from `/run/secrets` or env.

- [ ] **Step 2: `crontab`** (postgres user) — weekly `--type=full`, daily `--type=diff`, daily `backup.sh`, hourly `check` (see §8 schedule).

- [ ] **Step 3: `entrypoint.sh` (root: export env, start cron daemon in foreground)**

```bash
#!/usr/bin/env bash
set -euo pipefail
read_secret() { [ -f "$1" ] && tr -d '\n' < "$1"; }
export PGBACKREST_REPO1_CIPHER_PASS="$(read_secret /run/secrets/pgbackrest_cipher)"
export PGBACKREST_REPO1_S3_KEY="$(read_secret /run/secrets/b2_key_id)"
export PGBACKREST_REPO1_S3_KEY_SECRET="$(read_secret /run/secrets/b2_key_secret)"
# pg_dump auth: fail-closed .pgpass (0600, owned postgres) from the backup password
: "${POSTGRES_BACKUP_PASSWORD_FILE:?}"; umask 077
printf 'localhost:5432:*:peppercheck_backup:%s\n' "$(cat "$POSTGRES_BACKUP_PASSWORD_FILE")" > /var/lib/postgresql/.pgpass
chown postgres:postgres /var/lib/postgresql/.pgpass; export PGPASSFILE=/var/lib/postgresql/.pgpass
# age-dump S3 upload auth: pass B2 creds explicitly (mc/rclone/aws do not inherit PGBACKREST_*)
export AWS_ACCESS_KEY_ID="$PGBACKREST_REPO1_S3_KEY" AWS_SECRET_ACCESS_KEY="$PGBACKREST_REPO1_S3_KEY_SECRET"
printenv | grep -E '^(PGBACKREST_|AWS_|PGPASSFILE|AGE_)' > /etc/environment   # cron jobs inherit
exec cron -f    # root cron daemon; runs the postgres crontab as user postgres
```

- [ ] **Step 4: Dockerfile** — `FROM postgres:17`, install `age cron pgbackrest=<pinned> mc` (or rclone), `COPY` conf/backup.sh/entrypoint.sh/crontab (crontab → `/var/spool/cron/crontabs/postgres`, `0600 postgres`), create spool/log dirs, `ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]` (stays root for the cron daemon).

- [ ] **Step 5: Verify identical pgBackRest version across both DB images** (diff the two `pgbackrest version` outputs) → no diff.

- [ ] **Step 6: shellcheck + commit** — `git commit -m "feat(backend): backup image (S3 client, root cron + postgres crontab, one-shot dump)"`.

---

### Task 4: Local pgBackRest smoke against MinIO (custom image, WAL switch)

**Files:** Create `backend/compose.test.yaml`, `backend/scripts/pgbackrest-local-smoke.sh`

- [ ] **Step 1: `compose.test.yaml`** — `minio` + a `createbucket` (`mc mb m/pcbackup`); a `postgres` override that uses **`build: ./deploy/postgres`** (the custom image) with `PGBACKREST_REPO1_S3_ENDPOINT=minio` `..._S3_BUCKET=pcbackup` `..._S3_REGION=us-east-1` `..._S3_KEY/KEY_SECRET=minioadmin` `..._CIPHER_PASS=testpass` and `repo1-s3-uri-style=path` (TLS off since endpoint is plain host:9000).
- [ ] **Step 2: Smoke script** — bring up (test profile); `compose exec postgres pgbackrest --stanza=main stanza-create`; `compose exec postgres psql -c "select pg_switch_wal();"` (forces an `archive-push`); `... --type=full backup`; `... check` → `pgbackrest local smoke OK`.
- [ ] **Step 3: Run** → OK.
- [ ] **Step 4: shellcheck + commit** — `git commit -m "test(backend): local pgBackRest smoke (custom image) against MinIO"`.

---

### Task 5: Standalone production Compose + shared volumes + Caddy + jq check

**Files:** Create `backend/compose.prod.yaml`, `backend/scripts/assert-prod-config.sh`; Modify `backend/deploy/caddy/Caddyfile`

- [ ] **Step 1: `compose.prod.yaml` (standalone)** — `name: peppercheck-${PC_ENV}`;
  - `postgres` (`image: ${IMAGE_POSTGRES}`, `secrets:` all pg + pgbackrest + b2, `POSTGRES_PASSWORD_FILE`, `PGBACKREST_REPO1_S3_*` non-secret env, healthcheck, no published 5432);
  - `backup` (`image: ${IMAGE_BACKUP}`, same secrets);
  - **shared volumes**: `pgdata` (postgres rw, backup **ro**), `pgsocket` mounted at `/var/run/postgresql` (both), `pgspool` at `/var/spool/pgbackrest` (both), `pglog` (both);
  - `api`/`worker` (`image: ${IMAGE_BACKEND}`, `DATABASE_URL_FILE`, `depends_on postgres: service_healthy` — **no migrate**);
  - `caddy` (`image: ${IMAGE_CADDY}`, real domain, 80/443);
  - `migrate` under `profiles: ["deploy"]` (`image: ${IMAGE_ATLAS}` — the `arigaio/atlas:1.2.0` digest, pinned via the manifest, `command` reads the migrator URL from its mounted secret file, e.g. `sh -c 'atlas migrate apply --dir file:///migrations --url "$(cat /run/secrets/migrator_database_url)"'`);
  - `secrets:` block with `file: ./secrets/<name>`.
- [ ] **Step 2: `assert-prod-config.sh`** — `config --format json | jq -e` asserts: no `.build` on any service; `.services.api.depends_on` has no `migrate`; `.services.postgres.ports` empty.
- [ ] **Step 3: Run assertions + `caddy validate`** → OK.
- [ ] **Step 4: shellcheck + commit** — `git commit -m "feat(backend): standalone prod compose (shared pgBackRest volumes) + jq assertions"`.

---

### Task 6: Deployment structure — unique dir, current/previous, secret write

**Files:** Create `backend/scripts/switch-deployment.sh`, `backend/scripts/write-secret.sh`; Test `backend/scripts/deployment.bats`

**Interfaces:** `switch-deployment.sh <id>` records `previous`, atomically repoints `current`→`deployments/<id>`. `write-secret.sh <name>` (run as deploy) validates `<name>` against an **exact allowlist** and writes stdin to `$DEPLOY_SECRET_DIR/<name>` (owned deploy; the **chown to the consumer UID happens later via a root container**, Task 10).

- [ ] **Step 1: Failing bats** — switch updates `current` + records `previous`; `write-secret.sh` rejects a name outside the allowlist.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement** both (switch: `basename $(readlink current) > previous` then atomic `ln -sfn` + `mv -Tf`; write-secret: exact `case` allowlist, `umask 077`, write file).
- [ ] **Step 4: Run + shellcheck** → PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(backend): deployment current/previous switch + validated secret write"`.

---

## Group B — CI/CD pipeline

### Task 7: CI `image` job — 3 images + OCI manifest, output manifest digest

**Files:** Modify `.github/workflows/ci-backend.yml`

**Interfaces:** outputs `sha`, `backend/postgres/backup` image digests, and `manifest_digest` (the ORAS-push digest).

- [ ] **Step 1: Triggers + remove workflow-level concurrency**; add integration-branch push.
- [ ] **Step 2: `go` job** gets its own `concurrency: ci-go-<ref>, cancel-in-progress: true`.
- [ ] **Step 3: `image` job (needs: go)** — its own `concurrency: { group: ci-image-${{ github.ref }}, cancel-in-progress: true }` (an older in-flight build is cancelled when a newer push arrives, so an out-of-order finish can't ship an older SHA); GHCR login; build+push the 3 images by SHA (capture each `digest` output); **install `oras`**; write `manifest.json` with **full immutable references** (`{sha, backend:"ghcr.io/cloveclovedev/peppercheck-backend@sha256:…", postgres:"…", backup:"…", atlas:"arigaio/atlas@sha256:…", caddy:"docker.io/library/caddy@sha256:…"}` — resolve the atlas/caddy digests via `docker buildx imagetools inspect`); `oras push ghcr.io/cloveclovedev/peppercheck-release:<sha> ...` and capture the **pushed manifest digest** into `outputs.manifest_digest`.
- [ ] **Step 4: `actionlint`** → no errors.
- [ ] **Step 5: Commit** — `git commit -m "ci(backend): build 3 images + OCI release manifest, output manifest digest"`.

---

### Task 8: Reusable deploy workflow (env secrets in-workflow, manifest-by-digest, Tailscale v4)

**Files:** Create `.github/workflows/deploy-vps.yml`; Create `backend/scripts/remote-deploy.sh`, `smoke-or-rollback.sh`

**Interfaces:** `workflow_call` inputs `{env, host, sha, manifest_digest}`; **no `secrets:` inputs** — the job references `secrets.BWS_TOKEN`/`SSH_DEPLOY_KEY`/`SSH_HOST_KEY` directly. Job declares `environment: ${{ inputs.env }}`.

- [ ] **Step 1: `remote-deploy.sh`** — fixed project name; `source images.env`; **GHCR login with a scoped `DOCKER_CONFIG`** (`export DOCKER_CONFIG=$(mktemp -d)`; `trap 'docker logout ghcr.io; rm -rf $DOCKER_CONFIG' EXIT`; `docker login ghcr.io -u cloveclovedev --password-stdin < secrets/ghcr_token`) so no creds persist; `pull`; **set secret ownership** via `docker run --rm --network none --pull never --entrypoint sh "$IMAGE_POSTGRES" -c 'chown 65532 /s/database_url; chown 999 /s/postgres_* /s/pgbackrest_cipher /s/b2_*; chown 0 /s/migrator_database_url; chmod 0400 /s/*'` (`-v $d/secrets:/s`; digest-pinned, already-pulled, no network while secrets are mounted; `ghcr_token` stays deploy-owned for the login above); `run --rm --profile deploy migrate`; `switch-deployment.sh <id>`; `up -d --no-build --wait`.

- [ ] **Step 2: `smoke-or-rollback.sh <host> <ssh_host> <env>`** — `curl https://<host>/readyz` (public) else `ssh deploy@<ssh_host>` (tailnet) `rollback.sh` and fail.

- [ ] **Step 3: Reusable workflow**

```yaml
on:
  workflow_call:
    inputs: { env: {type: string}, host: {type: string}, ssh_host: {type: string}, sha: {type: string}, manifest_digest: {type: string} }
    # host = public domain (curl /readyz); ssh_host = tailnet MagicDNS/IP (SSH; ufw allows 22 on tailscale0 only)
concurrency: { group: deploy-${{ inputs.env }}, cancel-in-progress: false }
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.env }}
    permissions: { id-token: write, contents: read, packages: read }
    steps:
      - uses: actions/checkout@v4
        with: { ref: ${{ inputs.sha }} }   # ship compose/migrations/scripts matching the validated SHA (not the dispatch ref)
      - uses: tailscale/github-action@v4
        with: { oauth-client-id: ${{ vars.TS_CLIENT_ID }}, audience: ${{ vars.TS_AUDIENCE }}, tags: tag:ci-deploy }
      - name: setup ssh + host key
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.SSH_HOST_KEY }}" >> ~/.ssh/known_hosts
          echo "${{ secrets.SSH_DEPLOY_KEY }}" > ~/.ssh/id && chmod 600 ~/.ssh/id
      - name: install bws + oras   # pin real release URLs at implementation
        run: ./backend/scripts/install-cli.sh
      - name: pull + verify manifest by digest
        run: |
          oras pull ghcr.io/cloveclovedev/peppercheck-release@${{ inputs.manifest_digest }} -o m
          jq -e --arg s "${{ inputs.sha }}" '.sha==$s and .backend and .postgres and .backup and .atlas and .caddy' m/manifest.json
      - name: render secrets + ship deployment
        env: { BWS_ACCESS_TOKEN: ${{ secrets.BWS_TOKEN }} }
        run: bws run -- ./backend/scripts/ship-deployment.sh "${{ inputs.env }}" "${{ inputs.ssh_host }}" "${{ inputs.sha }}" "${{ github.run_id }}" m/manifest.json
      - name: deploy
        run: ssh -i ~/.ssh/id deploy@${{ inputs.ssh_host }} 'bash -s' "${{ inputs.env }}" "${{ inputs.sha }}-${{ github.run_id }}" < backend/scripts/remote-deploy.sh
      - name: smoke or rollback
        run: ./backend/scripts/smoke-or-rollback.sh "${{ inputs.host }}" "${{ inputs.ssh_host }}" "${{ inputs.env }}"
```

- [ ] **Step 4: `actionlint` + shellcheck** → no errors.
- [ ] **Step 5: Commit** — `git commit -m "ci(backend): reusable deploy (in-workflow env secrets, manifest-by-digest, tailscale v4)"`.

---

### Task 9: `deploy-staging` job + `deploy-production` (promote by digest)

**Files:** Modify `.github/workflows/ci-backend.yml`; Create `.github/workflows/deploy-vps-production.yml`

- [ ] **Step 1: `deploy-staging`** — `needs: image`, `if: github.ref == 'refs/heads/refactor/go-api-vps'`, `uses: ./.github/workflows/deploy-vps.yml`, `with: { env: staging, host: staging.peppercheck.dev, ssh_host: pc-staging, sha: ${{ needs.image.outputs.sha }}, manifest_digest: ${{ needs.image.outputs.manifest_digest }} }` (`pc-staging` = tailnet MagicDNS). **No `secrets:` block.** Add a **head-SHA guard** (skip/fail if `github.sha` is no longer the branch head) so a slow older run can't deploy after a newer one. On success (staging smoke passed), tag the manifest **`staging-validated-<sha>`** in GHCR — created *only here* — as the promotion record.
- [ ] **Step 2: `deploy-production.yml`** — `workflow_dispatch` (input `manifest_digest`; tag post-cutover). A job **verifies the manifest carries the `staging-validated-<sha>` tag** (else fails — production only deploys staging-validated artifacts), then `uses: ./.github/workflows/deploy-vps.yml` with `env: production, host: peppercheck.dev, ssh_host: pc-prod` (the reusable job's `environment: production` provides the required-reviewer gate). No caller `secrets:`.
- [ ] **Step 3: `actionlint`** → no errors.
- [ ] **Step 4: Commit** — `git commit -m "ci(backend): staging deploy + production promotion (digest-verified)"`.

---

### Task 10: `install-cli.sh`, `ship-deployment.sh` (root-container chown), `rollback.sh`

**Files:** Create `backend/scripts/install-cli.sh`, `ship-deployment.sh`, `rollback.sh`

**Interfaces:** `ship-deployment.sh <env> <ssh_host> <sha> <run_id> <manifest>` (SSH target is the **tailnet** `ssh_host`, not the public domain) renders secrets (tmpfs, masked), rsyncs the release into `deployments/<sha>-<run_id>/`, writes digest-pinned `images.env`, `docker login ghcr.io` (read-only) on the Droplet, writes secret files (deploy-owned), then **chowns them to consumer UIDs via a throwaway root container**.

- [ ] **Step 1: `install-cli.sh`** — download+install `bws` and `oras` from pinned release URLs (verified by the workflow run; `set -euo pipefail`, checksum if available).

- [ ] **Step 2: `ship-deployment.sh`** — key steps:

```bash
id="$sha-$run_id"; d="/opt/peppercheck/deployments/$id"
ssh deploy@"$ssh_host" "mkdir -p $d/secrets"
rsync -a backend/ deploy@"$ssh_host":"$d/"
# digest-pinned image refs from the verified manifest
for kv in "BACKEND backend" "POSTGRES postgres" "BACKUP backup" "ATLAS atlas" "CADDY caddy"; do set -- $kv;
  echo "IMAGE_$1=$(jq -r ".$2" "$man")"; done \       # full immutable refs (GHCR / Docker Hub) verbatim
  | ssh deploy@"$ssh_host" "cat > $d/images.env"
# GHCR login is NOT done here — the token ships as a 0400 secret (ghcr_token) below and is
# used inside remote-deploy.sh with a scoped DOCKER_CONFIG (never on a command line / ~/.docker/config.json)
# write secret files (deploy-owned); ownership is set later inside remote-deploy AFTER pull,
# using the digest-pinned, already-pulled postgres image with --network none (no unpinned,
# networked helper ever mounts the plaintext secrets)
for k in database_url postgres_superuser_pw postgres_app_pw postgres_migrator_pw \
         postgres_backup_pw migrator_database_url pgbackrest_cipher b2_key_id b2_key_secret ghcr_token; do
  printf '%s' "${!k:?missing $k}" | ssh deploy@"$ssh_host" "DEPLOY_SECRET_DIR=$d/secrets /opt/peppercheck/scripts/write-secret.sh '$k'"; done
```

- [ ] **Step 3: `rollback.sh`** — repoint to `previous`, `up -d --no-build --wait` with the fixed project name.
- [ ] **Step 4: shellcheck + commit** — `git commit -m "ci(backend): ship deployment (digest images, root-container chown) + rollback"`.

---

## Group C — Provisioning

### Task 11: `bootstrap.sh` (idempotent; deploy in docker group)

**Files:** Create `backend/deploy/provision/bootstrap.sh`

- [ ] **Step 1: Idempotent script** — Docker + compose plugin; `deploy` user **in `docker`**; Tailscale install + tagged `up`; ufw (default deny; `allow in on tailscale0 to any port 22`; `allow 80,443`); fail2ban; unattended-upgrades; `/opt/peppercheck/{deployments,scripts}` owned by deploy; copy `switch-deployment.sh`/`write-secret.sh`; SSH hardening. Guards on every step.
- [ ] **Step 2: shellcheck + `bash -n`** → clean.
- [ ] **Step 3: Commit** — `git commit -m "feat(backend): idempotent Droplet bootstrap"`.

---

### Task 12: Provisioning runbook

**Files:** Create `backend/deploy/provision/RUNBOOK.md`

- [ ] **Step 1:** Three sections (spec §10): **Prerequisites** (Tailscale tags/ACL + GitHub WIF client `TS_CLIENT_ID`/`TS_AUDIENCE`; BWS staging + restore-scoped projects, read-only tokens → `BWS_TOKEN`; B2 bucket + Object Lock + lifecycle + key; `GHCR_PULL_TOKEN`; GitHub Environments `staging`/`production` registering `BWS_TOKEN`/`SSH_DEPLOY_KEY`/`SSH_HOST_KEY` (production: required reviewer); Droplet + bootstrap; DNS DNS-only); **First deploy** (push integration branch); **Post-deploy** (monitoring; first B2 backup + restore drill; RTO).
- [ ] **Step 2: Commit** — `git commit -m "docs(backend): Phase 7-A provisioning runbook"`.

---

### Task 13: Add staging post-deploy items to the release-checklist

- [ ] **Step 1:** In the operator `release-checklist` skill's "Pending: next deploy", add first staging B2 backup, restore drill (record RTO), and Better Stack + DO monitoring setup. (Operator-private; via the release-checklist mechanism, not this repo.) Placed here so it functions as a reminder **before** the Group E staging work.

---

## Group D — Backup / restore / monitoring productionization

### Task 14: pgBackRest production retention + archive_timeout

**Files:** Modify `backend/deploy/postgres/pgbackrest.conf` (+ the backup copy)

- [ ] **Step 1:** `repo1-retention-full-type=time` + `repo1-retention-full=45` (≥ 30d lock + 7d interval + buffer; count-based `=6` gives only ~35d at the minimum). Confirm `archive_timeout=120s` (Task 2 `10-archive.sh`) is set and monitored (§Task 17), not relied on for RPO.
- [ ] **Step 2:** Re-run the MinIO smoke → OK.
- [ ] **Step 3: Commit** — `git commit -m "feat(backend): time-based pgBackRest retention (45d)"`.

---

### Task 15: `restore_sentinel` migration

**Files:** Create a migration `backend/migrations/*_restore_sentinel.sql` (via the Atlas workflow)

- [ ] **Step 1:** Add `restore_sentinel(id bigserial pk, tag text, created_at timestamptz default now())` so the drill can prove point-in-time correctness with real rows.
- [ ] **Step 2:** Apply to the local DB + `go test` DB suite still green.
- [ ] **Step 3: Commit** — `git commit -m "feat(backend): restore_sentinel table for PITR drill verification"`.

---

### Task 16: Restore-drill script (isolated, DB-clock, B2 config, real restore)

**Files:** Create `backend/scripts/restore-drill.sh`, `backend/compose.restore.yaml`, `backend/scripts/firebase-test-token.sh`

- [ ] **Step 1:** Drill: secrets from the **restore-scoped BWS project** (B2 read key, cipher, age key, Firebase test cred) — never production creds; `trap 'cleanup' EXIT`; restrict outbound. Steps: insert `restore_sentinel('pre')`; **capture target = DB `now()`** (`select now()`); `select pg_sleep(2)`; insert `('post')`; **`select pg_switch_wal()`, then poll `pg_stat_archiver.last_archived_wal` until it covers the WAL containing the target time (the target WAL has reached B2)**; create + **chown** an empty restore volume for the pgBackRest UID; `pgbackrest --type=time --target="<DB now>" --target-action=promote --delta restore` into it (the default `pause` would block the API; with B2 endpoint/bucket/key/region/cipher env); `compose.restore.yaml` up **postgres + api only** (no worker, isolated network); assert pre-present/post-absent; get a Firebase ID token → `curl /api/v1/me`; **fetch the latest `.age` dump from B2** and run a real `pg_restore` into a scratch DB (not just `-l`); print RTO; teardown `down -v`.
- [ ] **Step 2: shellcheck + `bash -n`** → clean.
- [ ] **Step 3: Commit** — `git commit -m "feat(backend): isolated DB-clock PITR restore drill with real pg_restore"`.

---

### Task 17: Monitoring (heartbeats, WAL-drop-aware freshness, host checks, systemd)

**Files:** Modify `backend/internal/worker/*`; Create `backend/deploy/monitor/{wal-freshness.sh,host-checks.sh,*.timer,*.service}`, `backend/deploy/provision/MONITORING.md`

- [ ] **Step 1:** Worker heartbeat test-first (POST `HEARTBEAT_URL_WORKER` after a success); backup appends `curl "$HEARTBEAT_URL_BACKUP"`.
- [ ] **Step 2: `wal-freshness.sh`** — read `last_archived_wal`, `last_failed_wal`, and their times from `pg_stat_archiver`; compute the un-archived backlog from **`pg_wal/archive_status/*.ready`** — its total WAL bytes and the oldest `.ready` **age** (async pgBackRest transfers straight from `pg_wal`, so the **spool holds no WAL bytes**; spool size would miss the backlog); alert when the oldest `.ready` age `> archive_timeout+headroom` OR (**`last_failed_wal` newer than `last_archived_wal`** — an unrecovered failure; a stale one superseded by a later `last_archived_wal` does NOT alert) OR the `.ready` backlog bytes approach `archive-push-queue-max`. **Additionally — because a queue-max overflow drops WAL while returning success and may leave `last_failed_wal` unset — verify the latest expected WAL segment is present and continuous in B2, check the latest-backup age is within bounds, and persistently detect the `archive-push-queue-max` exceeded log line.** POST values + status.
- [ ] **Step 3: `host-checks.sh`** — `df -i` inode %, summed `docker inspect .RestartCount`; POST + alert on thresholds.
- [ ] **Step 4:** systemd `.timer`/`.service` units (wal 2 min, host 5 min); `MONITORING.md` documents Better Stack monitors (uptime `/livez`,`/readyz`; TLS; heartbeats — **staging non-paging**), DO host alerts, **Better Stack URLs delivered from BWS → an env file the units read**, unit **install/enable** steps, and the **WAL-drop → new-full-backup PITR-rebuild runbook**.
- [ ] **Step 5: shellcheck + go test + commit** — `git commit -m "feat(backend): heartbeats + WAL-drop-aware freshness + host checks + monitoring runbook"`.

---

### Task 18: R2 → B2 daily copy (disabled skeleton)

**Files:** Create `backend/scripts/r2-to-b2-copy.sh`

- [ ] **Step 1:** `R2_BACKUP_ENABLED` guard (default false; exits 0 with a note); the enabled body (rclone copy) is Phase 4.
- [ ] **Step 2: shellcheck + commit** — `git commit -m "feat(backend): R2->B2 copy skeleton (disabled; Phase 4)"`.

---

## Group E — Stand up staging (operator + integration)

> Operator-run against real services per `RUNBOOK.md`; verified, not unit-tested.

### Task 19: Execute prerequisites
- [ ] Tailscale tags/ACL + GitHub WIF client (`TS_CLIENT_ID`/`TS_AUDIENCE`, repo/workflow claim limits).
- [ ] BWS staging + restore-scoped projects; secret inventory (§6.3); read-only tokens → env-scoped `BWS_TOKEN`.
- [ ] B2 private bucket + governance Object Lock (30d) + lifecycle (orphan cleanup) + key.
- [ ] `GHCR_PULL_TOKEN` (read-only).
- [ ] GitHub Environments `staging`/`production` registering `BWS_TOKEN`/`SSH_DEPLOY_KEY`/`SSH_HOST_KEY` (production: required reviewer); Droplet (`sgp1`, 1 GiB); run `bootstrap.sh`; capture host key → `SSH_HOST_KEY`.
- [ ] DNS `staging.peppercheck.dev` A → Droplet, **DNS-only**.
- [ ] Verify: SSH only via tailnet; `ufw status` shows 22 on `tailscale0` only.

### Task 20: First staging deploy
- [ ] Push `refactor/go-api-vps` → go → image → deploy-staging; `/readyz` green; real TLS.
- [ ] Secrets at `deployments/<sha>-<run_id>/secrets/*` chowned to consumer UIDs (65532/999/0), `0400`; no plaintext `.env`.
- [ ] Validate the **atomic DB-password rotation runbook** once (no broken-connection gap).
- [ ] Force a failed migration once; confirm the **old deployment stays up** and the job fails.

### Task 21: Backups + first restore drill
- [ ] `stanza-create` + first `--type=full backup` to real B2; encryption + Object Lock confirmed.
- [ ] Run `restore-drill.sh`; sentinel PITR + authenticated smoke pass; real `pg_restore` of the age dump; **record RTO** vs 4h.
- [ ] Verify **backup → expire → restore chain** in a test bucket; runtime key has no `bypassGovernance`.
- [ ] Simulate WAL drop (queue overflow) in the test bucket; alert fires; **PITR-rebuild runbook** restores the chain.
- [ ] Dial staging backups to low-frequency/on-demand.

### Task 22: Wire staging monitoring
- [ ] Better Stack uptime/TLS/heartbeats/WAL-freshness — **non-paging** for staging.
- [ ] DO host alerts + `wal-freshness`/`host-checks` timers enabled.
- [ ] Document the maintenance-window/pause procedure in `RUNBOOK.md`.

---

## Group F — Production authoring

### Task 23: Confirm production overlay + workflow authored
- [ ] `compose.prod.yaml` parameterizes `PC_ENV`/domain (no staging-only assumptions).
- [ ] `deploy-vps-production.yml` authored, digest-verified promotion, gated by the `production` environment, not run (Droplet at cutover).
- [ ] Commit final parameterization — `git commit -m "chore(backend): finalize production compose + promotion workflow (authored)"`.

---

## Self-Review

**Spec coverage:** §5 pipeline → T7–10; §6 secrets → T1, 2(entrypoint/roles), 6, 10, 20; §7 standalone compose → T5; §8 pgBackRest/restore → T2–4, 14, 15, 16, 21; §9 monitoring → T17, 22; §10 provisioning → T11, 12, 19; §11 CI gates → T4, 5, 7, 17; §12 exit criteria → T20–23; §14 R2 skeleton → T18; release-checklist → T13. All mapped.

**Placeholder scan:** `install-cli.sh` download URLs and the atlas one-shot's shell are
marked to pin at implementation (version-specific); every other step has concrete code
or a concrete console action.

**Type consistency:** deployment id `<sha>-<run_id>` flows T8 → T10 → `remote-deploy.sh`
→ `switch-deployment.sh`; `write-secret.sh <name>` (allowlist) + the root-container
chown to UIDs 65532/999/0 are consistent T6/10; manifest `{sha,backend,postgres,backup}`
+ `manifest_digest` flow T7 → T8 → T9 → `images.env` → `compose.prod.yaml`
`IMAGE_BACKEND/POSTGRES/BACKUP`; `PGBACKREST_*` env is produced by the entrypoint
wrappers (T2/T3) and consumed by `archive_command`/cron.
