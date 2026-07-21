# PepperCheck Refactoring Strategy: Supabase → Go API + PostgreSQL on VPS

> Status: **Program-level strategy (agreed direction)**. Umbrella policy for the
> third large refactor. Each phase gets its own `spec → plan → implementation`
> cycle; this document is the shared context that keeps parallel work (across
> chats/sessions) aligned.
>
> Authoritative sources, in order: the global **Engineering Policy** (CLAUDE.md /
> AGENTS.md) governs; `mobile_app_refactoring_policy.md` is a reference template
> adapted here to the real codebase. This document also integrates an independent
> parallel review.
>
> Last updated: 2026-07-22 — formalized as a design doc; incorporates multi-round
> review integration and re-measured codebase facts.

---

## 1. Purpose & Context

PepperCheck is a mobile-first marketplace (tasks / matching / evidence /
judgement / referee payouts / ratings / rewards) that is **pre-launch**: internal
("身内") testing is done, but the store release stalled because infra rework,
code-structure cleanup, and bug fixes all piled onto the launch path.

This refactor **separates the app from direct Supabase dependency and re-centers
it on a Go API + PostgreSQL stack that is portable and cheap to operate**, so that
post-launch change is small. It is **not** a full rewrite.

Because there are **no production users yet** and internal-test data is
disposable (§20 / D9), we can take a decisive single cutover a live system could not.

### Grounding facts (re-measured 2026-07-22, declarative schema only)

- **Two clients bind directly to Supabase.**
  - Flutter: 24 files import `supabase_flutter`; **31** `.from(` (PostgREST);
    **19** `.rpc(` call sites in `lib/` (each a distinct DB function); **7**
    `.functions.invoke` calls across **6** edge
    functions. No Realtime, no Storage.
  - webapp (Next.js on Cloudflare/OpenNext): `@supabase/ssr` +
    `@supabase/supabase-js` for login / auth-callback / dashboard / pricing /
    subscribe / account-deletion.
- **DB carries heavy logic**: `CREATE FUNCTION` **68** (across 65 files); RLS
  `POLICY` **63** (across 31 files; `auth.uid()` used widely); `cron.schedule`
  **10**; **36 triggers** (21 are `set_updated_at` housekeeping, 15 are business
  triggers); `VIEW` **0** in the current schema; `TABLE` 34; **12 edge
  functions** (~3.6k LoC TypeScript).
- **Auth is Supabase Auth** (Google federation: GoogleSignIn → Google ID token →
  `supabase.auth.signInWithIdToken`). `auth.users(id)` is referenced by **13 FK
  constraints** (including `profiles.id` itself, today's user anchor).
- **Billing is raw IAP** (`in_app_purchase` + Google Play RTDN edge function);
  **RevenueCat not yet integrated**; **no Apple sign-in yet** (Google only).
  **Stripe Connect (Express)** powers referee/tasker payouts (money out) — core.
- **Known defect:** `stripe_payout_repository.dart:93` invokes edge function
  `payout-request`, which **does not exist** in `supabase/functions/` — a
  Phase-0 investigation item and launch-blocker candidate.
- **Positive baseline:** Flutter domain files do not import Flutter/Riverpod/
  Firebase/Supabase; the schema is already split by feature. Both are worth
  preserving.

---

## 2. Locked Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | **Full migration is a launch gate.** Go API + VPS Postgres + backup/restore rehearsal precede the store release. | User's explicit choice; accepts the schedule slip and up-front solo-ops burden. |
| D2 | **Firebase Auth for authentication, but PepperCheck owns a stable internal user ID.** A random **internal `users.id` UUID** is the FK anchor and the RevenueCat App User ID; a **`user_identities(issuer, subject)`** row (today `subject` = Firebase UID) resolves the verified Firebase token to it — `users` carries **no** provider column (provider-independent). Provider unification (Google/Apple) is handled by **Firebase account linking**, not Go-side email merge. Firebase UID is an *external* key only. | Avoids a *new* provider lock-in (using Firebase UID as a domain PK would repeat the mistake we are removing). Survives a future auth-provider change without rewriting task/ledger/payout history. |
| D3 | **webapp shrinks** to marketing + legal + account-deletion. web is an **independent logical component**, **initially recommended in the same Go process/image** as the api (separability retained), rebuilt in Go + html/template + htmx + Tailwind behind Caddy. | IAP-only, mobile-first; no Next.js justification remains; collapses the stack to **Flutter + Go + Postgres**, removing Cloudflare/OpenNext/Node. |
| D4 | **Adopt RevenueCat** for subscription entitlement (money in) with a **durable, deduplicated, reconciled webhook**. Keep **Stripe Connect** for payouts (money out) — orthogonal. Drop web Stripe Checkout subscribe. | Money-state-machine is the highest-risk code; RC collapses Apple+Google lifecycle into one entitlement + one webhook. Endorsed by Engineering Policy. Nets to *less* total work. |
| D5 | **Big-bang cutover to `main`, incremental on an integration branch.** Land small feature-sized PRs into a long-lived integration branch; swap `main` once at the end. The exact branch name is **not** fixed here and must be coordinated with other in-flight work before starting. | No production users to protect; single cutover is simpler than dual-running. The base branch stays green + runnable after each PR to eliminate a giant untested delta. |
| D6 | **Move business decisions & authorization to Go; keep atomic integrity in Postgres.** Business orchestration/authz/external side effects → Go services + tests. Atomic routines (ledger mutation, locking, state transitions) **may remain** as SQL behind a Go store. Business cron/triggers → **Go `worker` with Postgres-backed durable jobs**; housekeeping triggers (`set_updated_at`) stay in DB. | Follows the reference policy's DB-logic split; details in §13. Deleting *all* functions is **not** a release condition. |
| D7 | **Pivot now.** In-flight multi-env (#418) and iOS IAP work are paused; their intent (per-env separation, IAP) is absorbed into the new architecture. | Continuing Supabase-premised work is rework. |
| D8 | **Bounded opportunistic cleanup allowed** (unused/messy schema; Flutter clean-arch violations), governed by the §27 stop rule. | Tidy what we already touch; no beautification pass. |
| D9 | **Fresh-start data, no historical migration, no dual-write.** Go-live builds a new DB from Atlas + seeds reference data. Testers **re-create their account via normal Firebase login** (new internal UUID); importing old profile rows from a dump is avoided (identity mismatch under §10) — a few testers can re-enter their profile. dump/restore is retained as a *capability rehearsal*, not the go-live path. | Internal-test data is disposable; the cheapest time to replace Auth and the IAP backend. |

---

## 3. Scope: In / Out

### In scope
- Supabase dependency inventory (§16) and its removal; **the Go application is the
  only data-access boundary** for both clients.
- Go API (feature-based light clean architecture) with a hardened HTTP surface
  (error envelope, timeouts, graceful shutdown, request IDs).
- Auth: Supabase Auth → Firebase Auth with the internal-UUID identity model (D2).
  **Sign in with Apple is net-new work** (currently Google only), required for
  the iOS release if Google is offered.
- RevenueCat entitlement + durable webhook; keep Stripe Connect payouts (D4).
- Move business logic out of Postgres (D6); durable Go `worker` for background work.
- Atlas declarative schema (feature-split) + versioned migrations; migration/
  runtime DB role separation.
- Rebuild webapp in Go + htmx (D3); provider-neutral account-deletion path.
- VPS Docker Compose; Caddy HTTPS; off-site backups (B2); restore + migration
  rehearsals.
- Fix internal-test launch blockers (incl. the `payout-request` orphan).
- Verify auth, billing, payouts, and account-deletion critical paths.
- **Bounded** opportunistic schema and Flutter clean-arch cleanup (D8).

### Out of scope
- Full UI redesign; new features; blanket beautification; interfaces on every type.
- Microservices; Kubernetes; Redis / external message queue.
- Homegrown framework; speculative future-feature work.
- Zero-downtime pre-launch migration (a maintenance-window cutover is fine).
- **Historical data migration / dual-write** (D9); supporting existing internal
  users or purchases.
- 100% coverage; performance work without measured evidence.
- Dual-repository production coexistence.
- Multi-env build-out beyond what the new architecture needs (D7).

---

## 4. Target Architecture

```text
Flutter ─┐
         │ HTTPS + Firebase ID token
         │
         ▼
       Caddy   ── only :80/:443 exposed; TLS
         │
         ▼
       Go "api"  ─── JSON API (/api/v1) + server-rendered HTML/htmx
         │            (the ONLY data-access path)
         ├── PostgreSQL       (VPS; :5432 internal-only)
         ├── Firebase Auth    (verify ID token → internal user UUID)
         ├── Cloudflare R2     (presigned upload/download; opaque object keys)
         ├── RevenueCat        (entitlement; durable signed webhook)
         ├── Stripe Connect    (payouts; Express dashboard; signed webhook)
         └── Firebase Cloud Messaging (push notifications)

       Go "worker" ─ same image, different command; Postgres-backed durable jobs
       backup      ─ pg_dump (custom format) → Backblaze B2
```

### Principles
- Flutter and the web frontend **never** touch Postgres, PostgREST, RLS, RPC, or
  edge functions directly. Supabase SDK removed from both.
- One Go deployable serves the JSON API **and** the server-rendered web pages;
  a second process (`worker`) from the same image runs durable background work.
- Handlers do HTTP↔domain translation only; services own use-cases +
  authorization; SQL is confined to the Postgres store. Firebase / RevenueCat /
  Stripe / R2 SDK types stop at platform adapters and never reach domain code.
- R2 objects are referenced by opaque keys, not provider URLs.

---

## 5. Execution Model

Big-bang to `main`, incremental and continuously-verifiable on an integration
branch:

- Land **small, feature-sized PRs** into a long-lived integration branch.
- **Invariant: after every PR the branch builds and runs end-to-end.** If a PR
  can't keep it runnable, it is too big — split it or gate behind config.
- **Develop local-first** (Docker Compose); the DB is always reproducible from
  Atlas migrations + seed data.
- **`main` is swapped once**, at final cutover. No Supabase-repo/API-repo
  coexistence: Flutter's `ApiXxxRepository` **replaces** the Supabase
  implementation (interface retained for boundary + testing; one impl at a time).
- **Branch name and worktree layout are not fixed here** — coordinate with other
  in-flight sessions before starting, and never commit directly to `main`.

---

## 6. Container & Service Naming Standard

Role-honest names, reusable across products.

| Role | Service name | Note |
|------|--------------|------|
| Reverse proxy / TLS | `caddy` | Actual software name. Only service binding 80/443. |
| JSON API **+ server-rendered web** | `api` | One Go deployable serves both; web is not a separate container unless justified. |
| Durable background jobs | `worker` | Same image as `api`, different command. Postgres-backed durable jobs — `worker` is accurate here (it consumes from a durable store); `jobs`/supercronic-only was rejected because a cron trigger gives no resume/dedup/retry/mutual-exclusion. |
| Database | `postgres` | `:5432` never exposed externally. |
| Off-site backup | `backup` | Distinct failure/monitoring semantics. |

Multiple products on one VPS: Caddy routes by `Host`; a shared external Docker
network connects Caddy to each product; role names stay the same inside each
Compose project.

---

## 7. Go Backend Structure

Feature-based light clean architecture.

```text
cmd/peppercheck/main.go
internal/
  identity/  profile/  task/  matching/  evidence/  judgement/
  subscription/  point/  reward/  payout/  notification/  account/  report/
    (each: model.go service.go handler.go postgres_store.go [+ adapter.go])
  platform/
    auth/ (Firebase token verification → TokenVerifier boundary)
    config/  database/  httpserver/  logging/  r2/  revenuecat/  stripe/
  web/  (handler.go templates/ static/)
```

Three entrypoints share one set of services — the `worker` does **not** call the
HTTP API:

```text
API handler ─┐
Web handler ─┼→ shared application services → Store / Gateway boundary
Job handler ─┘
```

Dependency direction: `Handler → Service → Store / external-service boundary →
PostgreSQL / Firebase / R2 / RevenueCat / Stripe`.

### HTTP rules
- `net/http` + `ServeMux`; explicit JSON request/response types; version under
  `/api/v1`; HTML routes outside the API namespace.
- Request size limits + strict JSON decoding; **consistent error envelope with a
  stable machine-readable code**; never expose raw provider errors.
- Propagate `context` cancellation; set server + downstream **timeouts**; add
  **request IDs** + structured `slog`; implement **graceful shutdown**.

### Authorization
- Token verification in middleware → verified external `(issuer, subject)`.
- Identity service resolves that to the **internal user UUID**; feature services
  authorize each action by internal UUID; store queries are user-scoped.
- Tests must prove one user cannot read/mutate another's data.

### Transactions
The service picks transaction boundaries. A store may expose a small transactional
operation when Postgres must atomically lock/consume/grant/release points, append
immutable ledger entries, claim jobs, transition task/evidence/judgement state, or
protect payout idempotency. Never split one invariant across multiple HTTP calls.

Stdlib-first; no large web framework. Thin CRUD services are fine; add interfaces
only for a real boundary/alternative/test need.

---

## 8. Flutter Structure

Keep the feature-based layout (`features/<f>/{domain,application,infrastructure,
presentation}`); changes are surgical, per-feature during its migration.

- Replace each feature's repository with an API implementation talking to the Go
  API; remove `supabase_flutter` entirely by the end.
- **One configured Dio client** in core networking: base URL by build env,
  Firebase ID token on authenticated requests, bounded timeouts, stable API-error
  decoding, request IDs preserved, **no auto-retry of non-idempotent mutations**.
  Features must not build their own HTTP clients.
- **API DTOs describe the HTTP contract, not DB rows** (task responses must not
  reproduce PostgREST relation shapes / synthetic placeholders). Infrastructure
  maps DTOs → domain types; domain stays provider-free.
- **The authentication feature owns the Firebase SDK** and publishes an
  app-level current-user contract; other features must not import `firebase_auth`
  or read an SDK singleton. Login flow: Firebase auth → ID token → `GET
  /api/v1/me` → internal UUID + profile → configure RevenueCat with internal UUID
  → register FCM token via API. Sign-out clears state, unregisters FCM, logs out
  RevenueCat, then ends the Firebase session.
- **Fix clean-arch violations we touch**: several `presentation/` widgets call the
  Supabase SDK directly (evidence submission, judgement section, task-detail info,
  report menu button, withdraw-matching button); these disappear via the
  repository. No unrelated widget refactors.
- Cross-feature coordination via public application contracts / explicit
  coordinators; no importing another feature's infrastructure; no generic event bus.
- Emulator base URL: Android → `10.0.2.2`, iOS sim → `localhost`, device → LAN /
  Tailscale / dev HTTPS.

---

## 9. Web Frontend (Go + htmx)

- **Routes to keep:** `/`, `/{locale}/legal/privacy`, `/{locale}/legal/terms`,
  `/{locale}/legal/refund`, `/{locale}/legal/tokushoho`, `/{locale}/account/delete`,
  `/{locale}/stripe/connect/return`, `/{locale}/stripe/connect/refresh`, and a
  support/contact route if needed. Removed Next.js URLs must 301-redirect.
- **Routes to remove:** Supabase OAuth callback, web login, subscription
  dashboard, web pricing/checkout, `SubscribeButton`, Supabase SSR middleware/client.
- **Account deletion is provider-neutral.** In-app deletion is the primary path;
  the web page must let any user (Google **or** Sign in with Apple) request account
  + data deletion without reinstalling — for v1 a clearly documented,
  provider-neutral support-request path is acceptable (a Google-only Firebase web
  login would exclude Apple-only users and violate store rules). The page states
  what is deleted/retained and any prerequisite (e.g. resolve outstanding payout).
- Stack: Go `html/template` + htmx (only where partial updates help) + Tailwind;
  embed templates/assets in the binary; preserve locale behavior; port `next-intl`
  messages to a Go i18n mechanism.
- **Legal pages must be updated** to reflect actual providers (Firebase Auth,
  RevenueCat, R2, VPS/Postgres operator, Stripe Connect, backup storage) as
  compliance content, not generated from architecture assumptions.

---

## 10. Identity & Authentication

The hardest structural change, done pre-launch while re-login is free.

- **Identity model** (replaces the `auth.users` anchor; provider-independent):
  ```text
  users(id uuid pk, status, created_at, updated_at)     -- no provider column
  user_identities(user_id → users, issuer, subject, unique(issuer, subject))
  profiles(user_id → users, ...)          # was profiles.id → auth.users(id)
  ```
  A verified Firebase token resolves to `(issuer, subject)` → `user_identities` →
  internal `users.id`. Today `subject` holds the **Firebase UID** (Firebase unifies
  Google + Apple under one UID → one row per user); the same table can later hold
  real per-provider subjects without touching `users`. **All 13 domain FKs re-point
  to `users.id`** — never to the Firebase UID.
- **Provider unification is done by Firebase, not by Go.** Google + Apple for the
  same person converge to **one Firebase UID** via Firebase **account linking**.
  Under *one-account-per-email*, Firebase may **auto-link** trusted verified-email
  providers, or raise `account-exists-with-different-credential` (e.g. custom /
  Workspace domains) requiring **re-auth then `linkWithCredential`** — the app must
  handle **both** paths. Apple sign-in is **net-new** (currently Google only).
  > **Rule:** same *verified* email Google/Apple converge to one account via Firebase
  > (auto- or explicit link). PepperCheck never merges users on email-string match
  > alone. When emails differ (e.g. Apple **Hide My Email** relay), the accounts stay
  > separate **unless explicitly linked** with re-auth to the existing account.
- **RLS is retired**; authorization moves to the Go service layer. RLS may be kept
  only as tested, transaction-local defense-in-depth after clients can no longer
  connect directly — and must not reintroduce Supabase-specific auth functions.
- **DB roles separated:** a migration role may change schema; the runtime app role
  has least-privilege read/write only. `:5432` never public; admin access via
  Docker network / localhost / Tailscale.
- The Go domain/service packages must not import Firebase SDK types (narrow
  `TokenVerifier` boundary).

---

## 11. Billing & Payouts

Two orthogonal money flows — keep them strictly separate.

### Money in — subscription entitlement → RevenueCat
- Flutter uses a small `PurchaseGateway` implemented by `purchases_flutter`; SDK
  types stay in infrastructure. Behaviors: load offerings, purchase, restore,
  identify after login, log out on sign-out, refresh entitlement, open native
  management, show pending/recoverable states.
- **The internal PepperCheck UUID is the RevenueCat App User ID** across iOS +
  Android (stable cross-device restore). Never use email / Firebase UID / anon id.
- **Backend webhook**: verify auth + HMAC → record raw event id + metadata →
  accept durably & return promptly → **ignore duplicate event ids** → reconcile via
  the RevenueCat API → update the subscription projection transactionally →
  **allocate points exactly once**. Sandbox vs production events must be
  distinguishable; staging/production use separate endpoints + secrets.
- Product-to-plan mapping is config/DB data, not scattered conditionals.
- **Removes** `handle-google-play-rtdn` (RC ingests RTDN) and avoids building an
  Apple ASSN handler from scratch. RC is authoritative; Postgres stores a
  queryable projection used by business rules.
- **Cost/plan (Phase 0):** confirm RevenueCat pricing for this project —
  **webhooks may require a paid (Pro) plan** — before committing to it.

### Money out — payouts → Stripe Connect (Express), unchanged
- Behind Go: onboarding session, account status refresh, `create-express-dashboard-
  link`, payout request, payout execution (durable worker), signed idempotent
  `handle-stripe-webhook`. Stripe account/event IDs protected by unique constraints.
- **Distinguish Stripe Billing from Stripe Connect** before deleting shared code.

### Dropped now — but not foreclosed
- The current **web Stripe Checkout** subscription (`create-stripe-checkout`) is
  removed; subscription is IAP-only via RevenueCat for this release. This drops the
  web *checkout*, **not** future web billing — a later RevenueCat + Stripe Billing
  web path is not precluded. `billing-setup` (Stripe card setup) is a separate,
  **currently-unused** flow — see §17.

---

## 12. Background Work

Supabase cron + trigger-driven external calls → a **Go `worker` using PostgreSQL
as durable coordination** (not an external queue; honors the no-Redis/MQ rule).

**Execution model (receive vs run):** `api` *receives* webhooks (verify → persist to
an inbox row → return 200); the `worker` *runs* inbox + scheduled jobs with retries;
the periodic scheduler lives **inside** `worker`. A "job" is a durable row/unit, not a
container — `api` and `worker` share one image as two processes, and `web` is routes
inside `api`.

- Handles: matching requests; evidence/judgement/auto-confirm deadlines;
  notification delivery; RevenueCat webhook reconciliation; payout preparation +
  execution; stale R2 cleanup; retryable account-deletion work.
- Use **persistent job/event rows, idempotency keys, bounded retry schedules, and
  `FOR UPDATE SKIP LOCKED`**. No in-memory queue for work that must survive
  restarts. No external queue until Postgres coordination is proven insufficient.
- supercronic (or a ticker) may serve only as a periodic *enqueue trigger*.

---

## 13. Database & Logic Policy

### Schema management — Atlas (feature-split)
- The declarative schema stays **split by feature** (matches `schemas/<domain>/`),
  not collapsed into one unreviewable file. Atlas loads the modular schema →
  `atlas migrate diff` → versioned SQL → format/lint/review/test → staging → prod.
- Baseline: design the provider-independent schema (no `auth.users`/`auth.uid()`;
  ownership → `users.id`) → Atlas baseline migration → apply to empty Postgres →
  load reference data + fixtures → verify no unexpected diff. Historical Supabase
  migrations remain in git history only.

### Logic classification (each function/trigger → one of)
1. **Integrity & atomicity** — keep in Postgres when it is the clearest safe impl.
2. **Query / set operation** — keep as SQL owned by the store.
3. **Business orchestration** — move to a Go service.
4. **Authorization** — move to Go + explicit user-scoped SQL.
5. **External side effect** — move to Go + durable job/webhook record.
6. **Obsolete Supabase support** — delete after its caller is removed.

Retain initially: wallet/ledger mutations, job claiming, row-locked state
transitions. Move: `auth.uid()` checks, notification dispatch, external HTTP,
provider webhooks, UI-oriented response assembly.

### Triggers & cron (measured)
- **36 triggers**: **21 `set_updated_at`** housekeeping → stay as minimal DB
  triggers; **15 business** (matching insert/update, judgement settle/notify/
  close, evidence validation/notify, rating update, `on_auth_user_created`) →
  classify in Phase 0: validation → invariant triggers may stay; side-effect /
  orchestration → Go worker.
- **10 `cron.schedule`** → business jobs to the Go `worker`; DB-internal
  maintenance only (if any) → `pg_cron`.

> **Completion is NOT "all functions deleted."** Complex transactional routines may
> remain behind the Go store; they can be simplified later without a store release.

---

## 14. Account Deletion

A domain workflow, not a provider cascade. **Idempotent, persisted deletion state**
so external-service failures retry. Covers: recent-auth/reauth, active task/
judgement restrictions, subscription guidance, pending rewards/payouts, R2 objects,
FCM tokens, Stripe Connect data, RevenueCat customer, Firebase user deletion/token
revocation, legally-required financial/abuse retention, anonymization where
retention prevents deletion. A partially-deleted account must not resume normal
activity. Tests cover retrying each external step. In-app **and** web paths validated.

---

## 15. Opportunistic Refactor Scope (bounded)

Allowed **only within areas already being migrated**, governed by §27:
- **Schema:** during Atlas baselining and per-feature migration, remove
  provably-unused objects and tidy bolted-on tables — only where it *reduces*
  migration risk. No aesthetic-only changes; large restructures → backlog.
- **Flutter:** fix clean-arch violations in the migrated feature (notably Supabase
  SDK in `presentation/`). No unrelated UI refactors.

---

## 16. Supabase Dependency Inventory

| Feature | Used? | Target |
|---------|-------|--------|
| PostgreSQL | Yes | Self-hosted Postgres on VPS |
| Supabase Auth | Yes (Google) | **Firebase Auth** + internal-UUID identity (§10) |
| PostgREST (`.from` ×31) | Yes | **Go API** endpoints |
| RLS (63 policies) | Yes | **Go service-layer authorization** |
| Storage | **No** | R2 |
| Realtime | **No** | n/a (polling per existing subscription-refresh design) |
| Edge Functions (12) | Yes | Go endpoints / worker (§17) |
| DB Functions (68) | Yes | Split business→Go, integrity/query→DB (§13) |
| Triggers (36) | Yes | 21 housekeeping→DB, 15 business→Go/worker (§13) |
| Cron (10) | Yes | Business→Go worker; maintenance→`pg_cron` |
| Webhooks | Stripe + Google Play RTDN | Stripe→Go; RTDN→RevenueCat (removed our side) |

Record per item in Phase 0: which feature uses it, direct client call?, Go
replacement, data/config conversion, temporary coexistence.

---

## 17. Edge Function → Go Mapping

| Edge function | Destination |
|---------------|-------------|
| `billing-setup` | **Drop — currently unused.** Stripe card-registration (`SetupIntent`, off-session); its UI `BillingSetupSection` is **not mounted** on any screen — legacy from a pre-IAP billing design. Do not port; remove with the dormant Stripe billing UI/repo (D8). |
| `create-stripe-checkout` | **Dropped** (web subscribe removed) |
| `create-express-dashboard-link` | Go endpoint (Stripe Connect) |
| `payout-setup` | Go endpoint (Stripe Connect onboarding) |
| `execute-pending-payouts` | Go **worker** (durable) |
| `recommend-payout-topup` | **Operator tool** (`X-Operator-Secret`): recommends how much the operator tops up their own Stripe balance to cover projected referee payout obligations. Phase 0: port to a Go operator endpoint or keep as an operator script. |
| `handle-stripe-webhook` | Go endpoint (signed, idempotent) |
| `handle-google-play-rtdn` | **Removed** (RevenueCat ingests RTDN) |
| `generate-upload-url` | Go endpoint (R2 presigned upload) |
| `delete-account` | Go endpoint + worker (idempotent saga, §14) |
| `send-notification` | Go endpoint + worker (FCM) |
| `sweep-r2-stale-objects` | Go **worker** |
| **`payout-request`** (called by Flutter, **no edge fn exists**) | **Phase-0 bug**; implement as a Go payout endpoint |

---

## 18. VPS Production Topology

Single VPS, Docker Compose: `caddy · api · worker · postgres · backup`. `api` and
`worker` share one immutable multi-stage image, different commands.

Container requirements: read port from config; store no durable state on the
container FS; no in-memory sessions; secrets at runtime; non-root where practical;
structured logs to stdout; liveness + readiness endpoints; graceful shutdown.

Exposure: only `caddy` binds 80/443; `api`/`worker`/`postgres`/`backup` on a
private network; `:5432` never public. Initial size ~2 GB RAM is a
**single-environment working hypothesis**; **re-estimate if staging + production
share one VPS**. Grow disk conservatively.

**Environment separation** (staging vs production, even if co-located initially):
separate Compose project, network, Postgres volume + credentials, R2 bucket/prefix,
Firebase project/app, RevenueCat + Stripe webhook endpoints + secrets, and domain.

---

## 19. Environments

```text
Daily dev + migration tests   → local Docker Compose (primary)
Shared test + external integ  → VPS staging
Store release                 → VPS production
```

Local Compose is the default (offline, re-init DB, isolated per branch, no VPS
cost). VPS staging is for integration only (webhooks, HTTPS/DNS/Caddy, real
Firebase/RC/R2, device-over-internet, same-image final check). This is where the
paused multi-env intent (D7) is absorbed.

---

## 20. Backup & Restore, and Data Strategy

- **Daily** `pg_dump` (custom format) → **encrypt** → **Backblaze B2** (pg_dump is
  not encrypted by itself); 7–30 generations; success/failure alerts;
  checksum/integrity check.
- **Monthly** restore into a separate Postgres + post-restore API smoke test.
  **A backup counts only once restored.**
- **Recovery target (decide in Phase 0):** a daily dump alone risks up to **24 h
  data loss** (RPO ≈ 24 h). If unacceptable, add **WAL archiving / PITR** on the VPS
  Postgres or use **managed Postgres** — fix the acceptable **RPO/RTO before release**.
- **R2 objects are a separate recovery domain:** define object retention,
  versioning, and accidental-deletion recovery independently of the DB backup.
- **Migration rehearsals** (portability is an original goal): Supabase → VPS;
  VPS → another local Postgres; VPS → Supabase/other DaaS — driven by **fixtures**,
  followed by API integration + key flows.
- **Go-live data (D9):** build a fresh DB from Atlas + seed reference data.
  **Testers re-create their account via normal login**; importing old profile rows
  is avoided (identity mismatch under §10) — a few testers can re-enter their
  profile. **No dual-write**; the old Supabase env may stay read-only briefly for
  **comparison only** — **not rollback** (once the new DB takes writes the data has
  diverged; recovery is restore / roll-forward from backups). It is never in the
  runtime path.

---

## 21. Monitoring Minimums

API liveness/readiness; HTTP request count/latency/5xx; auth failures; Postgres
connection/query failures; **worker queue age + failed jobs**; RevenueCat webhook
failures + reconciliation lag; Stripe webhook/payout failures; R2 upload
intent/finalize failures; backup age + last restore result; VPS CPU/mem/**disk +
inode**; container restart count; TLS cert health. Logs carry request/job IDs and
stable error codes; never secrets, tokens, or full PII payloads. Managed uptime/log
alerting is fine; a custom monitoring platform is out of scope.

---

## 22. Migration Roadmap

Phases are PR-groups on the integration branch; each is its own `spec → plan →
implementation` cycle. Order reflects dependencies (feature order, not fixed dates).

| Phase | Content | "Done" means |
|-------|---------|--------------|
| **0 — Freeze & baseline** | Finalize Supabase/Stripe/Firebase/R2/cron/webhook inventory; classify the 68 functions / 36 triggers / 10 cron; identify launch-blockers (incl. `payout-request`); record user journeys + high-risk characterization tests; finalize reduced web routes; decide tester-profile seed subset. | Every integration has an owner/disposition; identity + subscription decisions accepted. |
| **1 — Foundation** | Go module + modular monolith skeleton; config/logging/HTTP lifecycle/health; Dockerfile/Compose/Caddy/Postgres/backup skeletons; Atlas + provider-independent baseline; CI for Go/Atlas/Postgres/container build. | A clean clone starts the stack locally; migrations recreate the DB; `api`/`worker` shut down cleanly. |
| **2 — Identity & client boundary** | `users` + `user_identities`; Firebase Google **+ Apple**; Go token verify + `/api/v1/me`; shared Flutter Dio client + auth contract; remove direct authenticated-user SDK access; configure RevenueCat with internal UUID. | Both providers create/restore the same internal user (**same verified email → one account via Firebase linking**; Apple Hide-My-Email stays separate unless explicitly linked); user-isolation authz tests pass. |
| **3 — Low-risk slices + Go web** | profile, reference data, notification-token registration, reports, support/account; server-rendered public/legal pages; provider-neutral deletion request resource; preserve Stripe Connect return/refresh; remove obsolete web login/dashboard/pricing/checkout after route parity. | These features have no Supabase imports; public web routes production-ready; old URLs redirect. |
| **4 — Core task lifecycle** | task, matching, R2 upload intents + evidence, judgement/confirmation/timeout/rating; deadline/notification work → worker; replace PostgREST-shaped models with DTOs. | Full tasker/referee journey via Go API; no client RPC/edge calls; concurrency/timeout tested. |
| **5 — Financial & subscription** | point/trial-point, reward/payout; retain necessary atomic SQL behind Go stores; replace IAP with RevenueCat; durable webhook ingestion + reconciliation; validate Apple/Google sandbox lifecycle; keep Stripe Connect payouts. | Ledgers balanced under retries; purchase/restore both platforms; duplicate webhooks have no double effect. |
| **6 — Account deletion & cleanup** | idempotent deletion saga across Firebase/RC/Stripe/R2/DB; document retention/anonymization; validate in-app + web paths. | Retrying partial deletion is safe; deleted user cannot regain access; store paths present. |
| **7 — Staging, restore, release** | deploy staging on target VPS topology; backup/restore rehearsal; run the release-journey suite; reset internal data + seed reference (testers re-create via login); update legal + store metadata; remove Supabase runtime/SDK; swap `main`; freeze code; fix blockers only; submit to stores. | §25 completion criteria pass. |

---

## 23. Schedule & Safety Valves

**Aspirational target: mid-September 2026 release.** Concrete dates and a code
freeze are **not fixed yet** — check velocity at the **end of Phase 0** (do not wait
for Phase 2) and set the dated milestones then. The timeline is aggressive for a solo
dev; the safety valves below are **load-bearing, not decorative**.

**If behind, reduce scope in this order:** keep complex atomic SQL behind the Go
API instead of rewriting; drop optional web content before legal/deletion; defer
non-essential UI cleanup; defer monitoring dashboards (keep alerts/health); defer
generalized API-client generation; defer historical-data work (D9 already does).

**Never defer:** Firebase token verification + internal-ID separation; Sign in with
Apple when iOS offers Google; API authorization tests; RevenueCat sandbox
purchase/restore; ledger + payout idempotency; in-app + web account deletion;
backup + restore verification; privacy + store metadata updates.

---

## 24. Testing Strategy

- **Go unit** — task state transitions, authorization, matching eligibility,
  deadlines, point lock/consume/release, reward calc, entitlement effects, deletion
  eligibility, payout transitions.
- **Postgres integration** (real container, **pgTAP** in `db/tests/` — pgTAP
  retained, relocated out of `supabase/`) — migrations apply to empty DB; checksums valid;
  constraints/indexes exist; user-scoped isolation; atomic ledgers; idempotent
  duplicate webhook/job; safe concurrent matching/payout claims.
- **API integration** (HTTP + real Postgres + fake external boundaries) — invalid/
  expired/missing auth; stable error envelopes; ownership violations; validation;
  idempotency; pagination/ordering; cancellation/timeout.
- **Flutter** — DTO mapping, auth-state transitions, controller success/error,
  Firebase current-user abstraction, RevenueCat purchase/restore, cache
  invalidation, deletion UI, key navigation. Prefer fake HTTP/repository over
  mocking internals.
- **Release journeys (on staging):** Google sign-in; Apple sign-in; sign-out/
  restore; profile; task draft→matching→withdrawal; evidence upload/resubmit/
  cleanup; judgement/confirm/timeout/rating; point lock/consume/release/allocation;
  referee reward + payout setup; Android + iOS sandbox subscription lifecycle; FCM
  + deadline notification; report; in-app deletion; web deletion request; backup→
  restore→smoke; network-loss/recoverable errors.

### CI gates
- **Go/DB:** gofmt, `go vet`, unit, Postgres integration, race (concurrent pkgs),
  Atlas fmt/lint, apply-to-empty-DB, schema-drift, image build.
- **Flutter:** dart format, `flutter analyze`, tests, architecture import checks,
  generated-code consistency, **flavored debug build** (`lib/main_dev.dart`).
- **Web (in Go CI):** template render tests, per-locale route tests, legal/
  deletion link checks, redirect checks for removed Next.js routes, embedded-asset
  validation. No CI job reads committed secrets or local secret files.

---

## 25. Launch Completion Criteria

- [ ] No direct DB access from Flutter or web; both use the Go API only.
- [ ] No database port publicly exposed.
- [ ] Firebase **Google + Apple** auth work in the required builds.
- [ ] Domain tables reference **internal user UUIDs**, not Firebase UIDs.
- [ ] Go performs authorization for every protected use case; cross-user tests pass.
- [ ] RevenueCat purchase/restore/renewal/cancellation/expiration validated in
      Apple + Google sandboxes; webhook authenticated + idempotent.
- [ ] Stripe Connect onboarding + payout flows work.
- [ ] Core task/matching/evidence/judgement/point/reward journeys work via the API.
- [ ] Account deletion works in-app **and** via the public web resource
      (provider-neutral).
- [ ] Required legal + support pages live and accurate.
- [ ] Store-console requirements done: Play Console **Data Safety** form, the
      **account-deletion URL** registered in both stores, App Store **review
      notes / demo access**, and IAP **product configuration** (Apple + Google).
- [ ] Atlas migrations recreate an empty DB with no unexpected drift.
- [ ] The same image runs local/staging/production.
- [ ] Backups stored off-VPS; a backup has been **restored** + smoke-tested;
      backup failure detectable.
- [ ] API/worker/Postgres/Caddy/disk/backup failures detectable.
- [ ] Internal release acceptance passes on Android + iOS.
- [ ] No unresolved launch-blocking defect (incl. `payout-request`).

**Not** completion criteria: every SQL function moved to Go; final naming
everywhere; every duplication removed; full coverage; speculative scalability.

---

## 26. Risk Register (top)

- **Schedule expansion** → out-of-scope list, per-phase exit criteria, safety valves.
- **Identity leakage** (Firebase UID into domain) → resolve to internal UUID at the
  boundary; architecture test + schema-review rule.
- **Cross-user access** (RLS removed) → service authz + user-scoped stores +
  least-privilege roles + real isolation tests.
- **Financial duplication** → unique provider event IDs, immutable ledgers,
  idempotency keys, transactions, retry tests.
- **RevenueCat dependency** → provider types at the boundary; store normalized
  projections + event references; explicit product mappings.
- **VPS operational burden** → minimal containers, alerts, off-host backups, restore
  drills, disk monitoring, documented updates.
- **Web route regression** → inventory published URLs, route tests, redirects, smoke
  tests from store/Stripe consoles.
- **Account-deletion partial failure** → persisted state, idempotent retryable steps,
  explicit retention/anonymization.

---

## 27. Scope Discipline / Stop Rule

Include a new finding before release **only if** it can cause data loss; violate
auth/authorization; duplicate or lose money; block store review; break account
deletion; prevent backup/restore; or make the runtime unsafe to operate. Otherwise
defer to backlog (naming, file splits, minor dedup/UI, optional abstractions,
unused flexibility). Once the criteria are met, stop and ship; future architecture
work must be justified by production evidence.

> This refactor separates Supabase dependency and re-centers on a portable,
> low-cost Go API + Postgres stack — not a perfect rebuild.

---

## 28. To Confirm During Phase 0

- Reconcile exact Flutter RPC count (measured 19; reviewer 21) and confirm the
  `payout-request` orphan fix.
- Classified list: which of the 68 functions / 15 business triggers move vs stay.
- Unused code/schema to drop (D8) — concrete candidates, incl. the **dormant Stripe
  user-billing** (`billing-setup`, `stripe_billing_repository`, `BillingSetupSection`,
  `billing_controller`, related `domain/` billing types) confirmed not mounted.
- Any tester data worth keeping (default: recreate via login, per D9).
- **Recovery policy:** acceptable **RPO/RTO**; whether **WAL/PITR or managed
  Postgres** is needed; **R2** object retention + accidental-deletion recovery (§20).
- RevenueCat product/entitlement mapping, point/trial-point reset behavior, **and
  plan/cost** (webhooks may need a paid tier).
- VPS provider/region/size; staging+production shared VPS or not; domains/DNS.
- Monitoring/alert provider; B2 retention count + encryption.
- Concrete dates + code freeze (§23) once velocity is known.
