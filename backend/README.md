# peppercheck backend

Go backend for PepperCheck. One binary (`peppercheck`) runs as `api`, `worker`,
or `healthcheck`; PostgreSQL is managed with Atlas; Docker Compose supports
local development. The foundation and identity slice are implemented, and the
remaining Supabase-backed features migrate here incrementally.

## Quick start

```sh
make up                 # creates .env from .env.example, builds + starts the core stack
curl localhost/livez    # -> ok
curl localhost/readyz   # -> ready
make down-v             # stop and clear volumes (incl. the local WAL archive)
```

`make up` creates `.env` from `.env.example` if it's missing, then runs
`docker compose up -d --build`. A bare `docker compose up` on a clean clone
**fails on purpose** — secrets are fail-closed (`${VAR:?}`), so `.env` must exist
first. Run `make help` for all targets.

`.env` holds **non-sensitive local defaults only** (throwaway dev passwords, an
age public key). Never put a real provider secret or real DB password in it —
real secrets are injected at runtime via Bitwarden Secrets Manager / Docker
secrets (Phase 7).

## Structure

- `cmd/peppercheck/` — the single binary's entry point (command dispatch).
- `internal/api`, `internal/worker` — the `api` and `worker` command assemblies.
- `internal/core/*` — shared infrastructure: `config`, `logging`,
  `httpserver`, `database`, `jobs` (durable queue), `inbox` (webhook dedup).
- `schema/<feature>/NN_*.sql` — Atlas **table-only** declarative schema;
  `migrations/` — generated versioned migrations; `atlas.hcl` — Atlas env.
- `deploy/` — Caddy, Postgres init + WAL archiver, backup container.

Feature packages use `handler → service → store` role separation. The identity
feature is present; later feature directories are added as their migration
phases land.

## Notes & caveats

- **Changing the DB bootstrap needs a fresh volume.** The role/schema bootstrap
  in `deploy/postgres/init/*` (including the migrator-owned `atlas` schema) runs
  **only on an empty Postgres data dir** (`docker-entrypoint-initdb.d`). After
  pulling a change there onto an existing local volume, run **`make reset`**
  (`down-v` then `up`) — the migrator can't create the `atlas` schema on its own
  (no database-level `CREATE`), so a stale volume would fail migration. Local
  data is disposable (fresh-start policy). For a persistent DB you would instead
  apply the delta once by hand — create the schema **and move the existing
  history table into it**, otherwise Atlas reads an empty `atlas.atlas_schema_revisions`
  and thinks no migrations are applied:

  ```sql
  CREATE SCHEMA atlas AUTHORIZATION peppercheck_migrator;
  ALTER TABLE public.atlas_schema_revisions SET SCHEMA atlas;
  ```
- **Atlas is pinned to `v1.2.0`** (Standard distribution, used unauthenticated =
  free). Match it on your machine — Homebrew can't pin a specific version, so
  use the install script:
  ```sh
  curl -sSf https://atlasgo.sh | sh -s -- --version v1.2.0
  ```
  The schema is table-only (no DB functions/triggers), so no `atlas login` /
  Atlas Pro feature is ever needed. Atlas's migration-history table lives in a
  dedicated `atlas` schema, isolated from the least-privilege app role.
- **Backup is an opt-in Compose profile** (`make backup`), not started by the
  core stack. It needs `AGE_RECIPIENT` (an age public key) in `.env`.
- **WAL archiving is a local skeleton.** It archives to the `wal-archive` volume
  with `archive_timeout=900` (matches the 15-minute RPO), but has **no
  retention/pruning and no off-site upload**. Real WAL retention, off-site (B2)
  shipping, physical base backups, and restore drills are **Phase 7 and required
  before any VPS deploy**. Locally, `make down-v` clears the archive.
- **DB passwords must be URI-safe (single-variable design).** Each password
  variable (e.g. `POSTGRES_APP_PASSWORD`) is used BOTH to create the DB role
  (raw literal, in `00-roles.sh`) AND embedded in a `postgres://user:pass@host/db`
  DSN (which URI-**decodes** it), and Atlas requires the URL form. The two only
  agree when the value contains no URI-reserved characters. So **constrain real
  (Bitwarden) passwords to a URI-safe charset** (alphanumeric + `-_.~`). Do NOT
  try to fix a special-char password by percent-encoding this single shared
  variable — the role would be created with the encoded literal (e.g. `p%40ss`)
  while the DSN connects with the decoded value (`p@ss`), so they mismatch and
  the connection fails. If arbitrary special characters are truly unavoidable,
  split into two variables: a raw value for role creation and a separately
  percent-encoded value for every DSN. The local dev defaults are URI-safe.
- **Production deploys must use `-f compose.yaml` explicitly** (no
  `compose.override.yaml`), since the committed dev override publishes Postgres
  to host loopback for local tooling.
