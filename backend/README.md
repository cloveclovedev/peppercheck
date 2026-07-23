# peppercheck backend

Go backend for PepperCheck (Phase 1 foundation). One binary (`peppercheck`) run
as `api`, `worker`, or `healthcheck`; PostgreSQL managed with Atlas; Docker
Compose for local development. **No feature endpoints yet** — this is the
foundation the rest of the Supabase → Go + VPS refactor builds on.

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
- `internal/platform/*` — shared infrastructure: `config`, `logging`,
  `httpserver`, `database`, `jobs` (durable queue), `inbox` (webhook dedup).
- `schema/<feature>/NN_*.sql` — Atlas **table-only** declarative schema;
  `migrations/` — generated versioned migrations; `atlas.hcl` — Atlas env.
- `deploy/` — Caddy, Postgres init + WAL archiver, backup container.

Feature packages (`internal/identity`, `internal/task`, …) with the
`handler → service → store` layering arrive from Phase 2 onward.

## Notes & caveats

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
- **DB passwords in connection strings must be URI-safe.** DSNs embed the
  password in a `postgres://user:pass@host/db` URL, and Atlas requires this URL
  form, so a real password containing `/ # % @ :` etc. must be **percent-encoded**
  when injected (or constrain the generated password to a URI-safe charset). The
  local dev defaults are URI-safe.
- **Production deploys must use `-f compose.yaml` explicitly** (no
  `compose.override.yaml`), since the committed dev override publishes Postgres
  to host loopback for local tooling.
