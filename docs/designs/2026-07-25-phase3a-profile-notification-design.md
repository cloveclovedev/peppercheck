# Phase 3a — Profile & Notification-token (Design)

> Status: **Design (approved in brainstorming 2026-07-25).**
> Part of the Supabase → Go API + VPS refactor. Program strategy:
> `docs/designs/2026-07-22-supabase-to-go-vps-refactor-design.md`
> (see §22 Phase 3). Phase 0 baseline:
> `docs/designs/2026-07-22-phase0-baseline.md`. Builds on Phase 1
> (foundation, merged into the integration branch `refactor/go-api-vps`) and on
> Phase 2 (identity & client boundary), which is **being implemented in parallel**
> and not yet merged — this design targets Phase 2's contracts; Phase 3a
> implementation lands after Phase 2 merges. Phase 2 spec:
> `docs/designs/2026-07-24-phase2-identity-client-boundary-design.md`.
>
> Each phase is its own `spec → plan → implementation` cycle; this document
> covers **Phase 3a only**. The implementation plan is produced separately by the
> writing-plans workflow and is not committed.

---

## Amendments after approval

Naming refinements made during implementation (PR #479, 2026-08-02). Apply these
substitutions when reading the contract below; the rest of the design is
unchanged. See `docs/overview/naming-conventions.md`.

- **Table `user_fcm_tokens` → `device_push_tokens`** (provider-neutral: the value
  is still an FCM registration token, but the table models device push tokens;
  the provider name stays at the code boundary). Constraint/index names follow
  (`device_push_tokens_token_key`, `idx_device_push_tokens_*`).
- **Endpoints `PUT|DELETE /api/v1/me/fcm-tokens` → `PUT|DELETE /api/v1/me/device-push-tokens`**
  (the resource path matches the table). Request/response bodies (`{ token,
  deviceType }`, 204) are unchanged.

---

## 0. Phase 3 split — 3a vs 3b

Strategy §22 lists Phase 3 ("Low-risk slices + Go web") as one phase covering
`profile, reference data, notification-token registration, reports,
support/account; server-rendered public/legal pages; deletion request; Stripe
Connect return/refresh; remove obsolete web routes`. In brainstorming these were
found to be **two independent tracks** with different runtimes, deploy targets,
and test surfaces, so Phase 3 is split into two spec→plan→implementation cycles:

- **Phase 3a (this document)** — app data slices behind the Go JSON API +
  Flutter client: **profile** and **notification-token registration** (plus the
  provisioning fan-out that both need).
- **Phase 3b (separate spec)** — Go `html/template` server-rendered web:
  public/legal pages, Stripe Connect return/refresh landing pages, the
  provider-neutral web deletion-request resource, and retiring the obsolete
  Next.js routes. 3b carries a new surface not present in Phase 2 (browser-side
  auth for the authenticated web deletion page), which is the main reason to
  separate it.

### Scope decisions vs the strategy's Phase 3 grouping

These are **intentional narrowings** of the strategy's Phase 3 list, recorded so
the deviation is explicit:

| Item | Strategy placed in | Phase 3a decision | Why |
|------|--------------------|-------------------|-----|
| **reports** | Phase 3 | → **Phase 4** | `reports.task_id` is a `NOT NULL` FK to `tasks`, `content_type` references task/evidence/judgement, and the report UI entry points live **inside** the task/evidence/judgement screens — all of which arrive in Phase 4. A reports API built in 3a would have no caller and no FK target until Phase 4. |
| **account / deletion** | Phase 3 (request resource) | → **Phase 6** | In-app deletion is `check_account_deletable` + a multi-system saga (Firebase/RC/Stripe/R2/DB). The saga is Phase 6 and the eligibility gate is meaningless without it. "support" is a `mailto:` + external legal links (no backend) and needs no migration. |
| **reference data** | Phase 3 | → **each consuming phase** | Operator decision: reference tables (`subscription_plans`, `matching_config`, …) are seeded by the phase that consumes them (plans/prices → Phase 5; matching config → Phase 4). Phase 3a's own features (`profile`, `notification`) need **no** reference rows — timezone is a column default, notification defaults are column defaults, and `report_reason`/etc. are Postgres `ENUM` types (DDL, not seed rows). So 3a introduces no seed mechanism. |
| **Go web / legal / deletion-request web / Stripe Connect landing / remove Next.js** | Phase 3 | → **Phase 3b** | Different runtime & deploy target (Cloudflare → VPS/Caddy); separate spec. |

**Net Phase 3a scope:** `profile` (username / timezone / avatar) + `notification`
token registration + the **eager provisioning fan-out** both depend on.

---

## 1. Purpose

Phase 3a migrates the first two low-risk data features off Supabase onto the Go
API + Flutter API client, and extends the identity provisioning established in
Phase 2 so a first-time user is fully set up on the new backend:

- **`profile`** — the Go API owns the `profiles` table (username, avatar,
  timezone); Flutter reads/writes it through `ApiClient` instead of direct
  PostgREST. Avatar uploads go through a Go-issued **R2 presigned upload**
  (`platform/r2`), replacing the `generate-upload-url` Edge Function's avatar
  path.
- **`notification` token registration** — the Go API owns `user_fcm_tokens`;
  Flutter re-enables FCM token sync (disabled in Phase 2 P2-5) against the Go
  API.
- **Provisioning fan-out** — first-sighting provisioning is extended from
  `users` + `user_identities` (Phase 2) to **also** create `profiles`
  (auto-generated username) and `notification_settings`, atomically, matching
  today's `handle_new_user` behavior for the tables this phase owns.

This is the phase Phase 2 §5.4 anticipated: multiple authenticated endpoints now
need the internal user, so identity resolution is **promoted into middleware**.

---

## 2. Decisions locked in brainstorming (2026-07-25)

| # | Decision | Rationale |
|---|----------|-----------|
| P3a-D1 | **Scope = `profile` + `notification`-token registration + provisioning fan-out.** reports → Phase 4; account/deletion → Phase 6; reference data → consuming phases; Go web → Phase 3b (§0). | Dependency-clean, genuinely low-risk slices. reports/account/web each depend on things not present in 3a. |
| P3a-D2 | **`users` and `profiles` stay separate tables.** `profiles` is keyed `id uuid PK REFERENCES users(id) ON DELETE CASCADE` (1:1, PK = FK, column stays named `id`). | The Supabase-era reason (can't extend `auth.users`) is gone, but the separation is good design independent of it: `identity` owns a thin, stable anchor (`users`) that Phase 4/5/6 tables FK; `profile` owns mutable, public-readable presentation data. It also makes Phase 6 deletion clean — anonymize/clear `profiles` (PII), keep the anonymized `users` anchor for referential integrity. Keeping the DB column named `id` preserves continuity with the old schema; the API/Flutter contract nonetheless drops `id` (D10). |
| P3a-D3 | **Eager provisioning fan-out in one transaction.** First sighting creates `users` + `user_identities` + `profiles` (generated username) + `notification_settings` atomically. `user_ratings` (Phase 4-domain) and `point_wallets`/trial wallets (Phase 5) are **not** in the 3a fan-out. | Matches today's atomic `handle_new_user`; avoids "profile not yet created" states across an app that assumes `username NOT NULL` always exists. Extends the Phase 2 D4 onboarding seam as anticipated. |
| P3a-D4 | **Promote identity resolution into auth middleware.** A middleware after Phase 2's token-verify step resolves the verified `Identity` → internal `User` (provisioning on first sight) and exposes `CurrentUser(ctx)`; handlers read the internal UUID from context. | Phase 2 §5.4 deferred this "until multiple endpoints need it." Phase 3a is that phase (profile GET/PATCH, avatar, fcm-token endpoints all need the internal UUID). Replaces RLS `auth.uid()` scoping with server-side authz. |
| P3a-D5 | **Behavior-preserving port of `notification_settings` and `user_fcm_tokens` with deliberate constraint hardening** — no structural (shape) refactoring in 3a, but deliberate `NOT NULL` constraint hardening on always-present columns (timezone / timestamps / reminder arrays, §4.2). | Migration parity keeps behavior verifiable against the old system; shape change without a concrete need is YAGNI + added migration risk. The tightenings are `NOT NULL` only (§4.2), safe on a fresh DB. Candidates considered and rejected for now: normalizing `*_reminder_minutes int[]`, `device_type text` → enum. |
| P3a-D6 | **Avatar upload via a new `platform/r2` presigned-upload adapter;** mint endpoint `POST /api/v1/me/avatar/request-upload-url`. Avatar stays public-domain served. | Avatar editing is a self-contained low-risk slice. Phase 4 extends `platform/r2` for private evidence + authorized downloads; 3a keeps the public-avatar path only (YAGNI on the private-download shape). The action-named endpoint says what the caller wants (request an upload URL), not "upload a URL." |
| P3a-D7 | **`/api/v1/me` stays identity-only (Phase 2, unchanged); profile is a separate resource `/api/v1/me/profile`.** | Clean feature boundary; keeps the Phase 2 `/me` contract stable (also avoids colliding with the in-flight Phase 2 implementation). Leaves `/api/v1/users/{id}` for public other-user profiles in Phase 4 — "self = `/me/*`, others = `/users/{id}`." |
| P3a-D8 | **Restructure the Flutter `profile` and `notification` features to the Option E layout** (`data/ domain/ application/ ui/`, `*ViewModel`, DTOs in separate files) as opportunistic refactoring while their data layer is rewritten. | Strategy §15 — improve code you're already touching. Today they use `presentation/` + `*Controller`, not Option E. Scoped to the two migrated features, not a repo-wide big-bang. |
| P3a-D9 | **Two PRs: one Go, one Flutter.** Optionally split the Go PR (foundation vs feature endpoints) only if it grows too large to review. | Operator preference; both PRs keep the integration branch buildable (§3). |
| P3a-D10 | **Contract & robustness refinements (from review 2026-07-25).** The profile contract is **idless** (own profile identified by `CurrentUser`; other-user reads become a separate `PublicProfile` in Phase 4) and carries **no Stripe fields** (dropped from the new DB too). Avatar: no `filename` in the request (server derives the extension from `contentType`); `fileSizeBytes` 1..5 MiB (0 rejected); the **5 MiB cap is best-effort** — R2 enforces the signed `Content-Type` but a storage-layer size cap cannot be relied on (`Content-Length` enforcement is undocumented, presigned POST unsupported), and object creation is not self-bounding (new key per presign), so abuse is bounded by a **per-user rate limit + inline delete-previous** and size is checked best-effort by a client pre-check + finalize `HEAD` backstop (adapter gains `Head`/`Delete`) + a Phase 4 sweep — not a hard guarantee (a hard cap would need a Go-API proxy, deliberately avoided; §4.6); `avatarUrl` validated by **URL parse** (https, no userinfo, exact host incl. port, segment-wise path), not string prefix; the byte `PUT` uses a dedicated **`PresignedUploadClient`** (no Firebase bearer / no API interceptors / URL never logged). `timezone` is **IANA-validated** (`400 invalid_timezone`). Sign-out runs via an **app-layer coordinator** that deletes the FCM token **before** Firebase sign-out; FCM tokens / presigned URLs are never logged in full. | Correctness + security hardening: keeps dead/foreign concerns out of the contract, blocks avatarUrl spoofing (the size limit is a best-effort PATCH-time backstop, not a hard block — see §4.6 abuse handling), prevents leaking the Firebase token to Cloudflare (the presigned URL's signature is *meant* to go to R2 — the risk is logging that URL, not sending it), and keeps invalid timezones out of Phase 4 scheduling. |
| P3a-D11 | **`updated_at` remains Go-maintained, confirming the Phase 1 convention.** INSERT uses `DEFAULT now()`; every mutable Store `UPDATE` and `ON CONFLICT DO UPDATE` explicitly assigns `updated_at = now()`. The target schema adds no function or trigger for this housekeeping field. | Go is the sole write boundary, so keeping the assignment in typed Store SQL is explicit, testable, compatible with unauthenticated Atlas schema management, and avoids introducing a DB mechanism before a second writer or invariant requires it. PostgreSQL still evaluates `now()`, preserving transaction-time semantics. |

---

## 3. Execution model — narrowing continues

Per strategy D5 the integration branch stays buildable and runnable after each
PR. Phase 3a continues the Phase 2 "transitional narrowing": features not yet
migrated stay non-functional against real data.

**After Phase 3a the integration-branch app:**
- ✅ builds and launches (clean clone),
- ✅ signs in (Google + Apple) and resolves the internal user (Phase 2),
- ✅ **profile** works end-to-end against the Go API: view own profile, edit
  username (with taken-name error), change timezone, upload/replace avatar,
- ✅ **FCM token registration** works against the Go API (re-enabled from the
  Phase 2 P2-5 disable),
- ⏸ task / evidence / judgement / point / payout / reports / account-deletion
  remain non-functional until their phases. Expected and accepted.

`Supabase.initialize(...)` **remains** in startup for the still-un-migrated data
features. The `profile` and `notification` features stop importing
`supabase_flutter` (CI import check).

---

## 4. Backend design

### 4.1 Package layout (new / changed)

```
cmd/peppercheck/main.go              # wires profile + notification provisioners
                                     #   into identity; mounts new handlers;
                                     #   adds the ResolveUser middleware
internal/
  core/
    httpserver/                      # (Phase 2) error envelope; small helpers
  platform/
    auth/                            # (Phase 2) TokenVerifier + verify middleware
    r2/                              # NEW — S3-compatible R2 adapter
                                     #   (platform/r2 vs core/objectstore is an
                                     #    open non-blocking classification, §4.7)
      r2.go                          # Uploader: PresignPut + Head + Delete
  identity/                          # (Phase 2) + resolution middleware
    domain.go                        # User (anchor) — unchanged
    service.go                       # ResolveOrProvision extended: runs the fan-out tx
    store.go                         # users / user_identities — CreateUserInTx
    middleware.go                    # NEW — ResolveUser; CurrentUser(ctx) accessor
    handler.go                       # GET /api/v1/me — unchanged (identity only)
  profile/                           # NEW feature
    domain.go                        # Profile
    service.go                       # GetOwn, UpdateOwn, RequestAvatarUploadURL,
                                     #   ProvisionInTx (username generation)
    store.go                         # profiles table; CreateInTx, Get, Update
    handler.go                       # GET/PATCH /api/v1/me/profile;
                                     #   POST /api/v1/me/avatar/request-upload-url
  notification/                      # NEW backend feature
    domain.go                        # NotificationSettings, FCMToken
    service.go                       # RegisterToken, DeleteToken, ProvisionSettingsInTx
    store.go                         # user_fcm_tokens / notification_settings
    handler.go                       # PUT/DELETE /api/v1/me/fcm-tokens
```

### 4.2 Schema (Atlas) — new tables

Phase 1 created the identity core + jobs + inbox only. Phase 3a adds three
tables to the Atlas schema (`backend/schema`).

**`updated_at` housekeeping (P3a-D11).** `INSERT` uses `DEFAULT now()`. Every
mutable Store `UPDATE` and `ON CONFLICT DO UPDATE` explicitly assigns
`updated_at = now()`; PostgreSQL evaluates `now()` as the transaction-start
time, so two writes in one transaction intentionally share a timestamp. The
schema contains no housekeeping function or trigger. Tests cover each Store
update and upsert path that owns a mutable table. If a non-Go writer is added or
omissions become recurrent, a common trigger may be reconsidered through a new
design decision and versioned migration.

```
profiles (
  id                        uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  username                  text NOT NULL UNIQUE,
  avatar_url                text,
  timezone                  text NOT NULL DEFAULT 'UTC',
  created_at                timestamptz NOT NULL DEFAULT now(),
  updated_at                timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT profiles_username_length CHECK (char_length(username) BETWEEN 2 AND 20)
)

notification_settings (
  user_id                             uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  evidence_reminder_minutes           int[]  NOT NULL DEFAULT '{10}',
  judgement_reminder_minutes          int[]  NOT NULL DEFAULT '{10}',
  auto_confirm_reminder_minutes       int[],
  evidence_reminder_even_if_submitted boolean NOT NULL DEFAULT false,
  created_at                          timestamptz NOT NULL DEFAULT now(),
  updated_at                          timestamptz NOT NULL DEFAULT now()
)

user_fcm_tokens (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token          text NOT NULL UNIQUE,           -- upsert conflict target
  device_type    text,                            -- 'android' | 'ios' | 'web'
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  last_active_at timestamptz NOT NULL DEFAULT now()
)
-- indexes: user_fcm_tokens(user_id), user_fcm_tokens(last_active_at)
```

Structures are ported from the Supabase schema (P3a-D5) with these deliberate
changes: (1) `profiles.id → users(id)` replaces the old `profiles.id →
auth.users(id)`; (2) **`stripe_connect_account_id` is dropped** — the referee
payout / Stripe Connect account linkage is designed in Phase 5 (likely a
payments-owned table), not carried on `profiles`, and nothing in 3a reads it;
(3) **deliberate `NOT NULL` constraint hardening** on columns that were nullable
in the old schema but always have a value in practice — `profiles.timezone`
(default `'UTC'`), the `created_at`/`updated_at` timestamps across all three
tables, `user_fcm_tokens.last_active_at` (default `now()`), plus
`notification_settings.*_reminder_minutes` gaining `NOT NULL DEFAULT '{10}'`.
This is safe because go-live builds a fresh DB (no rows to violate it, §4.3).

### 4.3 Provisioning fan-out (eager, one transaction)

`identity.Service.ResolveOrProvision` is extended. The common path (identity
already known) is unchanged: `FindByIdentity → return existing user`. The
first-sighting path now runs a **single transaction** that fans out across
feature stores:

```
BEGIN
  users            := identity.Store.CreateUserInTx(tx)
  user_identities  := identity.Store.CreateIdentityInTx(tx, users.id, issuer, subject)
  profile.Provisioner.CreateInTx(tx, users.id)          -- generates username
  notification.Provisioner.CreateSettingsInTx(tx, users.id)
COMMIT
```

- **Dependency inversion.** `identity` depends on two **narrow interfaces** it
  declares, not on the concrete `profile`/`notification` packages:
  ```go
  // package identity
  type ProfileProvisioner  interface { CreateInTx(ctx, tx, userID uuid.UUID) error }
  type SettingsProvisioner interface { CreateSettingsInTx(ctx, tx, userID uuid.UUID) error }
  ```
  `profile.Service` and `notification.Service` implement them; `main.go` wires
  the concrete impls in. Each store's `*InTx` method accepts the shared
  transaction (a `Querier`/`*sql.Tx`), so the whole fan-out is atomic.
- **Concurrent first sighting** is still resolved by `user_identities
  UNIQUE(issuer, subject)` (Phase 2): the losing transaction rolls back (no
  orphan `users`/`profiles`/`settings` rows) and the row is re-selected.
- **Username generation lives in `profile`** (the feature that owns usernames),
  not identity — see §4.4.
- **No data backfill is needed.** Go-live builds a fresh DB and
  testers re-create accounts via normal login (strategy D9); provisioning creates
  `profiles`/`notification_settings` for each user at first sighting going
  forward, so there are no pre-existing rows to migrate. Existing Phase 1/2
  tables already follow the same Go-maintained convention and need no retrofit.

### 4.4 Username generation — faithful port with bounded retry

Ported from `handle_new_user`: `user_` + `hex(4 random bytes)` (13 chars, within
2–20), retried on `profiles_username_key` violation, **max 5 attempts**, then a
hard error (never an unbounded loop — Phase 2 §9's carried-forward requirement).

The old `plpgsql` loop relied on the implicit savepoint of a `BEGIN … EXCEPTION`
block. The Go/`database-sql` port makes that explicit **inside the provisioning
transaction**:

```
for attempt := 1..5:
    SAVEPOINT sp_username
    try INSERT INTO profiles(id, username, ...) VALUES (userID, gen(), ...)
        -> success: RELEASE SAVEPOINT sp_username; break
    catch unique_violation on profiles_username_key:
        ROLLBACK TO SAVEPOINT sp_username; continue
if still failing after 5: return error (rolls back the whole provisioning tx)
```

Random bytes come from `crypto/rand`. This is the only place a username is
minted in Phase 3a (no user-chosen username at signup); username **editing** is
a separate authenticated `PATCH` (§4.6).

### 4.5 Identity resolution middleware (`identity/middleware.go`)

The new middleware runs **after** Phase 2's token-verify middleware and turns the
verified external `Identity` into the internal `User`:

```
RequestID → AccessLog → Recover → VerifyToken (Phase 2, Identity in ctx)
          → ResolveUser (Phase 3a, User in ctx) → handler
```

- `ResolveUser` reads the `Identity` from context, calls
  `identity.Service.ResolveOrProvision` (first sight provisions via the §4.3
  fan-out), and stores the internal `User` in context. Handlers read it via
  `identity.CurrentUser(ctx) (User, bool)`.
- It lives in the `identity` package because it depends on `identity.Service`
  (a feature) — `platform/auth` must not depend on a feature, so the resolution
  step cannot live there. Token **verification** stays in `platform/auth`;
  internal-user **resolution** is an identity concern.
- Cost: one indexed `FindByIdentity` per authenticated request (acceptable;
  caching deferred until measured).
- `GET /api/v1/me` (Phase 2) is refactored to read `CurrentUser(ctx)` instead of
  calling `ResolveOrProvision` itself, but its response is unchanged (P3a-D7).

### 4.6 `profile` feature

Server-side authorization: every operation is scoped to
`identity.CurrentUser(ctx).ID` (replaces RLS `id = auth.uid()`).

- **`GET /api/v1/me/profile`** → `200`
  ```json
  { "username": "user_1a2b3c4d", "avatarUrl": "https://…/avatar/…jpg",
    "timezone": "Asia/Tokyo", "createdAt": "…", "updatedAt": "…" }
  ```
  The DTO has **no `id`** — `/me/profile` is implicitly the caller's own profile
  (identified by `CurrentUser`), so an id field is redundant. No Stripe fields.
  Other-user profiles are a separate future `PublicProfile` resource (§10), not
  this contract.
- **`PATCH /api/v1/me/profile`** — partial update, body any subset of
  `{ username?, timezone?, avatarUrl? }`:
  - `username`: server validates length 2–20 and charset `^[\p{L}\p{N}_\-]+$`
    (mirrors the Flutter client-side rule); unchanged value is a no-op; a unique
    violation → **`409 { code: "username_taken" }`**.
  - `timezone`: validated as an **IANA timezone** via `time.LoadLocation`; an
    invalid value → **`400 { code: "invalid_timezone" }`** (keeps bad values out
    of Phase 4's deadline/notification scheduling). The api container must ship
    the tz database — import `time/tzdata` (embedded) or install OS tzdata.
  - `avatarUrl`: the server **parses the URL** (never a raw string-prefix check,
    which authority/query tricks like `https://evil/?x=https://domain/avatar/uid/`
    bypass) and requires **all** of: scheme `https`; **no userinfo**; host an
    **exact match** (including port) of the configured R2 public domain; the path
    validated **segment-by-segment** as exactly `avatar / {userId} / <file>` with
    `..`, encoded slashes (`%2F`), and encoded/dot path segments rejected. So a
    caller cannot set an arbitrary or another user's object. On a successful
    avatar change the server **deletes the user's previous avatar object** (inline
    delete-previous, see size/abuse handling below).
- **`POST /api/v1/me/avatar/request-upload-url`** — **rate-limited per user**
  (`429 { code: "rate_limited" }` when exceeded); body
  `{ contentType, fileSizeBytes }` → `200`
  ```json
  { "uploadUrl": "https://<r2-presigned-PUT>", "publicUrl": "https://<domain>/avatar/…",
    "expiresAt": "…" }
  ```
  No `filename` is accepted — the server derives the extension from
  `contentType`. Validates `contentType` against the allow-list
  (jpeg/png/webp/gif/heic/heif) and `fileSizeBytes` in **1..5 MiB** (0 rejected);
  the presign **signs `Content-Type`** (R2 **enforces** the signed `Content-Type`
  — a mismatch fails with `403 SignatureDoesNotMatch`) and best-effort signs
  `Content-Length`. Presign TTL **600 s**; object key
  `avatar/{userId}/{uuid}.{ext}`. The client PUTs bytes to `uploadUrl` (via the
  dedicated `PresignedUploadClient`, §5.1.1), then calls `PATCH /me/profile {
  avatarUrl: publicUrl }` to persist. (3-step flow, same shape as today's Edge
  Function path, now Go-issued.)

  **Size/abuse handling is best-effort (not a hard guarantee).** Per the R2 docs,
  R2 enforces a signed `Content-Type` but does **not** document enforcing a signed
  `Content-Length`, and R2 does **not support presigned POST** (so S3's
  `content-length-range` policy is unavailable). A direct-to-R2 PUT therefore
  cannot be size-capped at the storage layer, and — correcting an earlier claim —
  object creation is **not** self-bounding either: each `request-upload-url` mints
  a **new key**, so without a limit an authenticated user could create many
  objects (the 600 s TTL bounds URL validity, not object count or retention). The
  only place that could *hard*-cap transferred bytes is a Go-API proxy, which we
  deliberately avoid here (avatars are small; proxying all future evidence too is
  undesirable). Phase 3a bounds abuse with a **rate limit + inline
  delete-previous** (the intent of "bound issuance + bound object count") plus a
  finalize backstop:
  - **Per-user rate limit** on `POST /me/avatar/request-upload-url` — a token
    bucket keyed by internal user id allowing a **burst of 10** (capacity 10) and
    a **sustained ~10 requests/hour** (refill 10 tokens/hour = 1 per 6 min); idle
    bucket entries are **evicted after 1 h** of inactivity to
    bound memory (in-memory is sufficient for the single-instance api topology;
    revisit if scaled). Over-limit → `429 { code: "rate_limited" }` with a
    **`Retry-After`** header (seconds until the next token). Values are the initial
    tunable defaults; they cap object creation at ~10/hour/user.
  - **Versioned per-upload key** `avatar/{userId}/{uuid}.{ext}` — a new key per
    upload gives natural CDN cache-busting and never clobbers the current avatar
    (a fixed key would let a bad upload overwrite the live avatar).
  - **Inline delete-previous on commit — precise contract** (avoids deleting the
    live avatar on a PATCH retry, and never turns a committed change into a 503):
    1. Verify the new object (`HEAD`), then **commit the DB update first**
       (set `avatar_url` to the new URL).
    2. **Only after** the DB commit succeeds, delete the **previous** object.
    3. If `oldKey == newKey` (idempotent retry with the same `avatarUrl`), **do
       not delete** — otherwise a retry would delete the current avatar.
    4. If the DB update fails, **do not delete** anything.
    5. An R2 delete failure is **logged only** — it does **not** fail the
       already-successful `PATCH` (the stale object is reclaimed by the Phase 4
       sweep). Bounds *referenced* objects to ~1 per user without a sweep.
  - **Client pre-check (UX):** the Flutter client refuses a file > 5 MiB before
    uploading (bypassable by a modified client, so not a guarantee).
  - **Finalize `HEAD` backstop:** on commit the server calls `Head` (§4.7) and
    persists `avatar_url` **only if** the object exists, is 1..5 MiB, and is an
    allowed `Content-Type`. Not a hard cap — the presigned URL is reusable within
    its TTL and finalize can be skipped (TOCTOU); it checks the object's state at
    PATCH time only.
  - **Phase 4 sweep** reclaims **abandoned** objects (uploaded but never
    committed — bounded by the rate limit) **and** must size/type-check the
    **referenced** object, clearing `avatar_url` if it is invalid. The existing
    sweep excludes referenced keys unconditionally; Phase 4 must change that.
  - **Accepted residual risk (documented):** until the Phase 4 sweep lands,
    abandoned objects can accumulate up to the rate limit and a user could leave
    one oversized object at a just-minted key. Bounded and low-severity pre-launch
    (no real users, disposable data, §4.3) — accepted.
  - An optional real-R2 smoke test (§8) **records the observed behavior** of R2
    for an oversized PUT (whether it is accepted or rejected). Refs: R2 Presigned
    URLs; R2 Limits (single PUT ≤ 5 GiB — the 5 MiB cap is entirely ours).

### 4.7 `platform/r2` adapter

A thin S3-compatible adapter over the R2 endpoint, providing a **presigned PUT**
(client's direct upload), a **`Head`** (finalize backstop, §4.6), and a
**`Delete`** (inline delete-previous, §4.6) in Phase 3a:

```go
type PresignPutInput struct {
    Key           string
    ContentType   string
    ContentLength int64          // best-effort signed; size is NOT enforced here
                                 //   — the finalize Head is a PATCH-time backstop
                                 //   only (§4.6), not a hard cap
    TTL           time.Duration
}
type ObjectMetadata struct {
    ContentLength int64
    ContentType   string
}
type Uploader interface {
    PresignPut(ctx context.Context, in PresignPutInput) (url string, err error)
    Head(ctx context.Context, key string) (ObjectMetadata, error)
    Delete(ctx context.Context, key string) error   // inline delete-previous
}
```

- Constructed from R2 config (account ID, access key/secret, bucket, public
  domain) — injected as env/secrets per the secrets policy, never committed. The
  credentials themselves are operator-provisioned (release-checklist).
- SDK types (AWS S3 SDK for R2) **stop at this package** (the `platform` rule);
  `profile` depends only on the `Uploader` interface.
- Phase 4 extends this package (private bucket, authorized presigned **GET** for
  evidence); Phase 3a adds only the public-avatar presigned PUT.
- **Open, non-blocking classification:** because R2 is reached over the
  provider-neutral S3 API (not Cloudflare's proprietary API), this could instead
  live as a neutral `core/objectstore` (per the global architecture note). It is
  named `platform/r2` for now; revisiting the placement is deferred and does not
  block 3a.

### 4.8 `notification` feature (token registration)

- **`PUT /api/v1/me/fcm-tokens`** — body `{ token, deviceType }`; **upsert on
  `token`** (unique): set `user_id = CurrentUser`, `device_type`,
  `last_active_at = now(), updated_at = now()` (§4.2). `PUT` is idempotent,
  matching the client's
  register-on-start / on-refresh / on-sign-in triggers and the old
  `onConflict: 'token'` rebind semantics (a device re-logging-in rebinds its
  token to the new user).
- **`DELETE /api/v1/me/fcm-tokens`** — body `{ token }`; deletes the row scoped
  to `user_id = CurrentUser AND token = ?` (a user can only remove their own
  binding). Called on sign-out.
- `notification_settings` has **no** read/update endpoint in 3a — the row is
  created at provisioning (§4.3) with defaults; there is no settings-editing UI
  today, and `*_reminder_minutes` are consumed by the Phase 4 notification
  worker. Editing endpoints arrive with that UI's migration.
- Invalid-token cleanup (currently inside `send-notification`) belongs to the
  Phase 4 notification-send path, not 3a.

### 4.9 Config

- R2 settings for `platform/r2` (account ID, bucket, public domain, access
  key/secret) added to the api service config, fail-closed for required values,
  with dummies in `.env.example` / CI. Secret values follow the secrets policy
  (operator-provisioned; only names/references committed).
- No new port or Firebase config (Phase 2 covers those).

---

## 5. Flutter design

### 5.1 `profile` feature → API client + Option E layout

Restructured from `data/ domain/ presentation/` (+ `*Controller`) to the Option
E layout while the data layer is rewritten (P3a-D8):

```
lib/features/profile/
  domain/profile.dart                     # Profile (Freezed): username / avatarUrl /
                                          #   timezone / timestamps — no id, no Stripe
  data/profile_repository.dart            # ApiClient-backed; no supabase_flutter
  data/profile_dto.dart                   # ProfileDto (mirrors /me/profile JSON)
  data/avatar_upload_dto.dart             # request-upload-url response DTO
  application/…                           # (only if orchestration warrants it)
  ui/profile_screen.dart
  ui/profile_view_model.dart              # was *Controller
  ui/username_edit_view_model.dart
  ui/timezone_view_model.dart
  ui/avatar_edit_view_model.dart
  ui/widgets/…
```

- `ProfileRepository` calls `ApiClient` (Phase 2) for the JSON endpoints:
  `GET /me/profile`, `PATCH /me/profile` (username/timezone/avatar), and
  `POST /me/avatar/request-upload-url`. The avatar bytes `PUT` goes to the R2
  `uploadUrl` via the dedicated **`PresignedUploadClient`** (§5.1.1), **not**
  `ApiClient`. Full 3-step: request-upload-url (ApiClient) → `PUT` bytes
  (PresignedUploadClient) → `PATCH /me/profile { avatarUrl }` (ApiClient). The
  avatar view model **pre-checks the file is ≤ 5 MiB before requesting the upload
  URL** (UX-level early rejection; the server finalize `HEAD` is the backstop,
  §4.6). Cropping already yields a small 512×512 jpg, so this rarely triggers.
- The Flutter `Profile` domain drops `id` and `stripe_connect_account_id` to
  match the new contract (P3a-D2/D6). Other-user profiles will be a separate
  `PublicProfile` model in Phase 4, not this one.
- DTOs are **separate files**; the repository maps DTO ↔ domain; domain never
  imports DTOs (strategy §8).
- `currentProfileProvider` fetches `GET /me/profile` (keyed off the Phase 2
  current-user contract's signed-in state). It is **separate** from the auth
  contract (which stays identity-only, P3a-D7).
- Username taken → `ApiException(code: "username_taken")` → the existing
  taken-name UI. Client-side validation (length/charset, skip-if-unchanged) is
  retained as a fast pre-check; the server is authoritative.
- `*ViewModel` classes must not define an `update` method (`AsyncNotifier`
  override clash — project rule); use domain-specific names.
- `supabase_flutter` removed from this feature (CI import check).

### 5.1.1 `core/network/PresignedUploadClient` — bytes-to-R2 client

The presigned `PUT` must **not** use `ApiClient`: `ApiClient` attaches the
Firebase `Authorization: Bearer` header (which would leak the token to
Cloudflare and can break the presigned signature), runs the API error-mapping /
request-id interceptors (wrong for an R2 response), and could log the URL. So
`core/network` gains a separate `PresignedUploadClient` — a bare `Dio` that:

- attaches **no** Firebase bearer and runs **none** of the API interceptors;
- **never logs the presigned URL** (its query string contains the signature,
  which is a credential) — redact it in any logging;
- shares only the common **timeout** configuration;
- `PUT`s the bytes with the `Content-Type` / `Content-Length` matching the
  request-upload-url call, and surfaces a plain success/failure (not `ApiException`).

### 5.2 `notification` feature → re-enable token sync via Go API

- Re-enable the FCM token sync **disabled in Phase 2 P2-5** (which was keyed on
  the now-null Supabase user), now against the Go API:
  - `fcm_service` upserts via `PUT /me/fcm-tokens` on app start,
    `onTokenRefresh`, and on the Phase 2 auth-state `signedIn` transition.
  - A refresh/upsert while **signed out is a no-op** (no bearer to authenticate).
  - The **full FCM token is never logged** (redact in any diagnostics).
- **Sign-out is orchestrated by an app/application-layer sign-out coordinator,**
  not by `notification` depending on `auth` (or the reverse). The coordinator
  runs the legs in order and, critically, calls **`DELETE /me/fcm-tokens`
  *before* Firebase sign-out** — after sign-out there is no valid bearer to
  authenticate the delete. Each leg is independent and idempotent: a token-delete
  failure is logged and the remaining sign-out legs (Phase 5 RC logout, Firebase
  sign-out) still run. This supersedes the Phase 2 §6.2 sketch that had the auth
  repository call FCM unregister directly.
- Restructured to the Option E layout for the parts touched (repository →
  `data/`, `fcm_service` stays application-layer orchestration in
  `application/`). The client-side notification **text resolver** (i18n loc-keys)
  is unchanged — it is not a backend concern.
- `supabase_flutter` removed from this feature's token path.

### 5.3 Post-login

Unchanged from Phase 2 §6.3: the app enters past login after Firebase auth +
`GET /api/v1/me` succeed. Profile load (`GET /me/profile`) happens right after
and is provisioned-guaranteed (eager fan-out), so it does not gate login; a
transient profile-fetch failure shows a retry, not a limbo.

---

## 6. API contract summary

| Method & path | Auth | Body | Success | Errors |
|---------------|------|------|---------|--------|
| `GET /api/v1/me` | yes | — | user + identity (Phase 2, unchanged) | 401/503 |
| `GET /api/v1/me/profile` | yes | — | `{username, avatarUrl, timezone, createdAt, updatedAt}` | 401/503 |
| `PATCH /api/v1/me/profile` | yes | `{username?, timezone?, avatarUrl?}` | updated profile | 400 validation, **409 `username_taken`**, 401/503 |
| `POST /api/v1/me/avatar/request-upload-url` | yes | `{contentType, fileSizeBytes}` | `{uploadUrl, publicUrl, expiresAt}` | 400 (type/size), **429 `rate_limited`**, 401/503 |
| `PUT /api/v1/me/fcm-tokens` | yes | `{token, deviceType}` | 204 | 400, 401/503 |
| `DELETE /api/v1/me/fcm-tokens` | yes | `{token}` | 204 | 400, 401/503 |

All errors use the Phase 2 stable envelope `{ error: { code, message, requestId } }`.

---

## 7. Error handling & edge cases

- **Username exhaustion at provisioning** → 5 savepoint-bounded attempts, then
  the whole provisioning transaction fails with an error (surfaced as a
  provisioning failure, retryable by the idempotent resolve path). Never an
  unbounded loop.
- **Concurrent first sighting** → `user_identities UNIQUE(issuer, subject)`
  rolls back the loser cleanly (no orphan profile/settings); re-select resolves.
- **Username taken on edit** → `409 username_taken`, no partial write.
- **Invalid timezone** → `400 invalid_timezone` (IANA-validated), no write.
- **avatarUrl tampering** → server **parses** the URL and enforces scheme
  `https`, no userinfo, exact host (incl. port), and a segment-wise
  `avatar/{userId}/<file>` path (rejecting `..`, `%2F`, encoded dot segments);
  string-prefix checks are insufficient. Finalize `HEAD` backstop confirms the
  object exists and is 1..5 MiB / allowed type (best-effort, not a hard cap — R2
  cannot cap direct PUT size, §4.6).
- **Avatar object abuse** → not self-bounding (each presign mints a new key), so:
  per-user rate limit on presign issuance (`429`) + inline delete-previous bound
  the objects; abandoned (never-committed) objects are swept in Phase 4;
  residual pre-launch risk is documented and accepted (§4.6).
- **FCM token rebind** → a token previously bound to another user is re-bound to
  the current user on upsert (matches old `onConflict: 'token'`).
- **Sign-out ordering / token-delete failure** → coordinator deletes the token
  before Firebase sign-out; a delete failure is logged and does not block the
  remaining sign-out legs. FCM tokens and presigned URLs are never logged in full.
- **Profile fetch failure post-login** → retry affordance; login not gated on it
  (provisioning guarantees the row exists).

---

## 8. Testing & CI

**Go unit:**
- `profile` username generation: success within 5 attempts; exhaustion errors
  after exactly 5; generated names satisfy length/charset.
- Provisioning fan-out: first sighting creates `users` + `user_identities` +
  `profiles` + `notification_settings` atomically; a forced failure rolls all
  back (no orphans); concurrent first sighting → one user, no duplicate.
- `profile.Service` update: username validation, taken-name error mapping,
  timezone IANA validation (valid accepted, garbage → `invalid_timezone`),
  avatarUrl host+path parse validation (including bypass attempts like an
  attacker host with the good URL in the query string).
- authz isolation: a token for user B cannot read/patch user A's profile or
  delete A's fcm-token.

**Go API integration** (HTTP + real Postgres + fake `TokenVerifier`):
- `GET/PATCH /me/profile` happy paths; `409 username_taken`; `400
  invalid_timezone`; `POST /me/avatar/request-upload-url` type/size validation
  (R2 presign faked) — including `fileSizeBytes` **0 and > 5 MiB both rejected**;
  **finalize `HEAD` backstop** — `PATCH /me/profile { avatarUrl }` rejects when
  the faked `Head` reports the object missing / **0 bytes** / oversized (> 5 MiB)
  / wrong `Content-Type`, and accepts a valid object; **inline delete-previous** —
  a valid avatar change calls the faked `Delete` with the *prior* key **after** the
  DB commit; a **same-URL PATCH retry** (`oldKey == newKey`) does **not** delete;
  a **DB-update failure** does **not** call `Delete`; a **faked `Delete` failure**
  is logged but the `PATCH` still returns success (not 503); **rate limit** — `request-upload-url` returns `429 rate_limited` with
  a `Retry-After` header past the per-user quota; `PUT/DELETE /me/fcm-tokens`
  upsert/rebind/delete; ownership violations; stable error envelope with
  `requestId` through the real middleware chain (now including `ResolveUser`).

**R2 smoke test** (optional, real R2, not in unit CI — needs credentials):
**records the observed behavior** of R2 for a size-mismatched presigned PUT
(accepted or rejected; `Content-Type` signing is documented, `Content-Length`
enforcement is not). The finalize `HEAD` (§4.6) is a PATCH-time backstop, not
authoritative enforcement, so this is informational only — a post-deploy check
(§12), not a code gate.

**DB integration** (assert-SQL in `backend/db/tests/*.sql`, run by CI as in
Phase 2): `profiles_username_key` uniqueness + length check; `user_fcm_tokens`
token uniqueness; FK cascade `users` → profiles / settings / fcm-tokens; no
orphan rows after a rolled-back provisioning. For every mutable Store path,
seed a past `updated_at`, execute the normal `UPDATE` or `ON CONFLICT DO UPDATE`,
and assert that PostgreSQL advances it. Do not compare two writes within one
transaction for strict ordering because `now()` is transaction-scoped. No
trigger-catalog assertion is required.

**Flutter:**
- `profile`: DTO ↔ domain mapping; each `*ViewModel` success/error (fake
  `ApiClient`); avatar 3-step (request-url → PUT → PATCH) with a fake HTTP layer;
  `username_taken` surfaces the taken-name UI.
- `notification`: token upsert on start/refresh/sign-in; no-op when signed out.
- **sign-out coordinator** (app/application layer): FCM `DELETE` is called
  **before** Firebase sign-out; and when the FCM `DELETE` **fails**, Firebase
  sign-out still runs (order + failure-continuation both asserted with fakes).

**CI gates:** Go — gofmt, `go vet`, unit, Postgres integration, race, Atlas
fmt/lint, apply-to-empty-DB, schema-drift, image build. Flutter — dart format,
`flutter analyze`, tests, **architecture import checks** (`supabase_flutter` not
imported by `profile`/`notification`; Dio construction only in `core/network`),
flavored debug build. The Flutter client carries no R2/S3 SDK — presigning is
server-side and the client only `PUT`s the bytes to the returned `uploadUrl` via
the dedicated `PresignedUploadClient` (§5.1.1). Per project convention each
Flutter PR runs `flutter build`
only; a single emulator pass runs at the end of Phase 3a on the integration
branch.

---

## 9. PR breakdown

Two PRs into `refactor/go-api-vps`; the branch builds after each (§3). Go first
(curl-verifiable), then Flutter.

| PR | Layer | Content |
|----|-------|---------|
| **P3a-1** | Go | Atlas tables (`profiles`, `notification_settings`, `user_fcm_tokens`) with `DEFAULT now()` timestamps; explicit `updated_at = now()` in every mutable Store update/upsert plus integration coverage; `identity/middleware.go` ResolveUser + `CurrentUser(ctx)` and the fan-out extension (savepoint username retry in `profile`); `platform/r2` presigned PUT + `Head` (finalize size/type backstop) + object delete (inline delete-previous); `profile` feature (`GET/PATCH /me/profile`, `POST /me/avatar/request-upload-url` with **per-user rate limit** + **inline delete-previous** on avatar change); `notification` feature (`PUT/DELETE /me/fcm-tokens`, settings provisioning); all Go unit/API/db tests. *Optional split if too large:* P3a-1a foundation (schema + middleware + fan-out) / P3a-1b feature endpoints (profile + r2 + notification). |
| **P3a-2** | Flutter | `profile` → `ApiClient` + `PresignedUploadClient` for the avatar `PUT` + Option E restructure + DTOs; re-enable `notification` token sync against the Go API + Option E restructure; **app-layer sign-out coordinator** (FCM delete before Firebase sign-out, failure-continuation); remove `supabase_flutter` from both; import-check CI; single emulator verification pass. |

---

## 10. Out of scope (deferred)

- reports → Phase 4 (FK + UI coupling to tasks/evidence/judgement).
- account deletion (eligibility + saga) → Phase 6.
- reference-data seeding → each consuming phase (Phase 4 matching, Phase 5
  subscription).
- Go web / legal pages / Stripe Connect landing / web deletion-request / Next.js
  retirement → **Phase 3b** (separate spec).
- `notification_settings` read/update endpoints & UI → whenever that UI migrates.
- Public other-user profiles → a separate `PublicProfile` resource
  (`/api/v1/users/{id}`) + Flutter model in **Phase 4**; private R2 downloads
  (authorized presigned GET for evidence) also Phase 4.
- Referee payout / Stripe Connect account linkage (the dropped
  `stripe_connect_account_id`) is designed in **Phase 5**, not carried on
  `profiles`.
- **Avatar sweep** (Go port of `sweep-r2-stale-objects`) → **Phase 4** (bundled
  with the R2 evidence + sweep work). **Requirement:** unlike the current sweep
  (which unconditionally excludes referenced keys), the Phase 4 sweep must reclaim
  **abandoned** (never-committed) avatar objects **and** size/type-check the
  **referenced** avatar object, clearing `avatar_url` if it is invalid (§4.6).
- **FCM notification send + invalid-token cleanup** (the `send-notification`
  path) → **Phase 4** notification worker.
- Phase-2-dependent doc details (exact `backend/db/*` paths, final middleware
  wiring) are confirmed once Phase 2 merges.

---

## 11. Done criteria (Phase 3a)

- [ ] A clean clone builds and runs; a first-time sign-in provisions `users` +
      `user_identities` + `profiles` (generated username) + `notification_settings`
      atomically.
- [ ] Profile works end-to-end via the Go API: view, edit username (with
      `username_taken`), change timezone, upload/replace avatar (Go-issued R2
      presigned PUT). Avatar `request-upload-url` is per-user rate-limited (`429`);
      a successful avatar change **best-effort deletes** the previous object after
      the DB commit (inline delete-previous; a delete failure is logged, not
      surfaced); the finalize `HEAD` backstop rejects missing/0/oversized/
      wrong-type objects.
- [ ] FCM token registration/deregistration works via the Go API (Phase 2 P2-5
      disable removed); no Supabase in the `profile`/`notification` token paths.
- [ ] Sign-out coordinator deletes the FCM token **before** Firebase sign-out and
      continues sign-out even if the token delete fails (both tested).
- [ ] Identity resolution runs in middleware; authenticated handlers read
      `CurrentUser(ctx)`; a token for one user cannot read/modify another's
      profile or fcm-token (authz-isolation test passes).
- [ ] `profile` and `notification` follow the Option E layout (`data`/`domain`/
      `ui`, `*ViewModel`, separate DTOs).
- [ ] `platform/r2` isolates the R2 SDK; `profile` depends only on its interface;
      the avatar byte `PUT` goes through `PresignedUploadClient` (no Firebase
      bearer reaches R2).
- [ ] Every mutable Store `UPDATE` and `ON CONFLICT DO UPDATE` explicitly sets
      `updated_at = now()`, and its integration test verifies the write path.
- [ ] CI gates (§8) pass; `/api/v1/me` (Phase 2) contract unchanged.

**Not** Phase 3a criteria: reports; account deletion; reference-data seeding; Go
web; notification-settings editing; public other-user profiles; payout linkage.

---

## 12. Deployment / operator actions

Independent of code scope; added to the release-checklist when the PR that first
deploys to **staging** lands (not now).

- **Pre-deploy — R2 configuration** (operator): per-environment credentials,
  bucket, and public domain for `platform/r2`, injected as secrets (secrets
  policy: only names/references committed). The api will not serve avatar
  upload/finalize without these.
- **Post-deploy — R2 smoke test** (optional, informational): run the real-R2
  size-mismatch check (§8) against the deployed environment to **record the
  observed behavior**. The size limit is best-effort via the client pre-check +
  finalize `HEAD` backstop + rate limit + inline delete-previous + the future
  Phase 4 sweep (§4.6), not a code gate.
