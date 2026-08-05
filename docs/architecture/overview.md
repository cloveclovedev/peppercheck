# Current architecture

Status: Current during the Go/VPS refactoring program. This document describes
the repository as it exists on the integration branch, not only the target end
state.

## System shape

PepperCheck currently has a transitional architecture:

```text
Flutter
  ├── Firebase Authentication ── ID token ──> Go API
  │                                      └──> PostgreSQL
  └── unmigrated features ────────────────> Supabase

Go worker ──> PostgreSQL-backed jobs

Go API (internal/web) ──> server-rendered public web (html/template)
```

The Go backend foundation, internal identity model, Firebase token verification,
durable jobs, inbox deduplication, PostgreSQL migration flow, and local/VPS
infrastructure foundation are present. The Flutter identity path uses Firebase
Authentication and the Go API. Profile, task, matching, evidence, judgement,
billing, payout, report, and several supporting client paths still contain
Supabase access and are migrated phase by phase.

The `supabase/` tree therefore remains a build input and historical
implementation reference until its replacement phases land. Its presence does
not make it the target architecture. The legacy Next.js public web application
(`peppercheck-webapp/`) has been fully replaced by `backend/internal/web` and
removed from the integration branch; the live production site still serves
from `main`/Cloudflare until the Phase 7 cutover.

## Go backend

The `backend/` directory builds one `peppercheck` binary with `api`, `worker`,
and `healthcheck` commands. The API and worker share PostgreSQL-backed
infrastructure but run as separate processes.

Current packages follow a lightweight feature-based structure:

- `cmd/peppercheck/` is the composition root.
- `internal/core/` contains provider-neutral foundations such as configuration,
  HTTP serving, database access, jobs, inbox deduplication, and logging.
- `internal/platform/` contains provider-specific adapters such as Firebase
  authentication.
- `internal/identity/` owns the migrated identity feature.
- `internal/api/` and `internal/worker/` assemble the process-specific entry
  points.

Handlers translate protocols, services own application behavior, and stores own
SQL. PostgreSQL schema files are declarative and Atlas produces reviewed,
versioned migrations.

## Identity boundary

Firebase Authentication proves an external identity. The application resolves
the verified issuer and subject through `user_identities` to a provider-neutral
internal UUID in `users`. Domain foreign keys use the internal UUID rather than
a Firebase or Supabase identifier.

The Flutter client sends a Firebase ID token to the Go API. Features that have
not migrated yet still use the legacy Supabase client; this split is temporary
and must not be copied into new features.

## Database responsibilities

Go owns business decisions, authorization, transaction boundaries, background
orchestration, and write-time housekeeping. PostgreSQL owns tables, defaults,
constraints, foreign keys, indexes, locks, and set-oriented queries.

For `updated_at`, inserts use `DEFAULT now()`. Every mutable Store `UPDATE` and
`ON CONFLICT DO UPDATE` explicitly assigns `updated_at = now()`. PostgreSQL
evaluates the transaction timestamp, but the Go-owned Store statement is
responsible for requesting the update. The target schema starts without
housekeeping functions or triggers; adding one later requires a concrete
second-writer or invariant requirement and a new design decision.

## Deployment shape

Docker Compose runs PostgreSQL, a one-shot Atlas migrator, the Go API, the Go
worker, and Caddy. Only Caddy is the application ingress. Local development may
publish PostgreSQL to loopback for tooling; production does not expose it.

The backup and monitoring assets in `backend/deploy/` establish the operational
foundation, but the refactoring strategy's production-readiness and cutover
gates still apply before release.

## Direction of travel

The approved target removes direct database access from clients, moves the
remaining behavior into feature-oriented Go packages, and removes Supabase
after the cutover. The legacy Next.js web application has already been
replaced by the small Go-rendered surface in `internal/web`. See the
[Go/VPS refactoring strategy](../designs/2026-07-22-supabase-to-go-vps-refactor-design.md)
for durable decisions and phase boundaries.
