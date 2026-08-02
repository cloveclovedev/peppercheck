# PepperCheck

PepperCheck is a Flutter application backed by a Go API and PostgreSQL. The
repository is in an incremental migration from the legacy Supabase-based
implementation to the Go/VPS architecture, so both stacks remain present until
the cutover is complete.

## Start here

- [Documentation index](docs/index.md)
- [Getting started](docs/getting-started.md)
- [Current architecture](docs/architecture/overview.md)
- [Go/VPS refactoring strategy](docs/designs/2026-07-22-supabase-to-go-vps-refactor-design.md)

The shortest local development path is:

```sh
scripts/dev-run.sh --ios
```

Use `--android` for Android or omit the platform flag to launch both. See the
[getting-started guide](docs/getting-started.md) for prerequisites and backend-
only commands.

## Repository layout

- `backend/` — Go API, worker, PostgreSQL schema, migrations, and Compose stack
- `peppercheck_flutter/` — Flutter client
- `peppercheck-webapp/` — legacy web application retained during migration
- `supabase/` — legacy database and Edge Functions retained during migration
- `docs/` — canonical project documentation and design records

Do not treat `developer-docs/` as a project rule source. Agent rules come from
the applicable `AGENTS.md` files.
