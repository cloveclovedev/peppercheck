# Phase 4a — Task Authoring & Matching (Design)

> Part of the Supabase → Go API + VPS refactor. See the strategy doc
> `docs/superpowers/specs/2026-07-22-supabase-to-go-vps-refactor-design.md` and
> the Phase 0 baseline `docs/superpowers/specs/2026-07-22-phase0-baseline.md`.
> Each phase is its own `spec → plan → implementation` cycle.

## §0 Scope & Context

Phase 4 ("core task lifecycle") is the largest phase of the refactor. It is
decomposed into three sub-phases along the state machine:

- **4a — task authoring + matching** (this document)
- **4b — evidence + private R2** (upload intents, submit/resubmit, evidence
  timeout, authorized presigned downloads)
- **4c — judgement + rating** (judge, confirm, reopen, threads, auto-confirm,
  review/evidence timeouts, rating)

**This document covers 4a backend only.** The Flutter client for task authoring
and matching is a separate follow-on `spec → plan` cycle (mirroring Phase 2's
backend-then-Flutter split and Phase 3a).

**Porting philosophy (locked):** behavior- and concept-preserving port; only the
*structure* is redesigned (Go `service`/`store`/`handler`/worker, DTOs, no
*business* DB functions/triggers — `updated_at` is maintained by the common
`set_updated_at()` trigger per Phase 3a P3a-D11, not by Go). Clearly-poor implementations may
be improved during the Go port as long as the intent is preserved. Anything that
is dead, no-op, or deliberately deferred is recorded in the companion follow-up
doc `2026-07-25-phase4a-follow-ups.md` rather than silently carried or dropped.

**Transitional narrowing (Phase 2 principle):** on the integration branch, the
Go point/reward system does not exist yet (Phase 5). 4a defines interface seams
for point locking and referee obligations and wires **no-op stubs**; the real
implementations arrive in Phase 5 by swapping the wiring, without changing
matching code.

## §1 Decision Log

| ID | Decision | Rationale |
|----|----------|-----------|
| **P4a-D1** | **Split Phase 4 into 4a/4b/4c along the state machine; 4a = task authoring + matching.** | Phase 4 is too large for one spec; the seams to Phase 5 (points, reward) localize to 4a (point lock) and 4c (reward grant). |
| **P4a-D2** | **This spec = backend only. Flutter is a separate follow-on spec.** | Keeps each spec focused; matches the Phase 2/3a pattern. |
| **P4a-D3** | **Matching is asynchronous via a worker job**, not a synchronous in-request computation. Publish locks points (seam) + creates N `pending` requests + enqueues a matching job in one transaction and returns immediately (`status: pending`). | The old synchronous behavior was an artifact of running matching inside a DB trigger, not a product-considered behavior. `pending` is already a first-class state. Async unifies the initial-match and the retry paths (today `process_matching` is duplicated across the insert-trigger and the hourly cron), aligns with the Phase 1 durable-job primitive and the at-least-once idempotency requirement (issue #464). Deliberate, recorded deviation; the observable outcome (matched + notified / expired + refunded) is unchanged — only the timing (a moment later, via the worker). |
| **P4a-D4** | **Phase 5 coupling is expressed as Go interfaces with no-op stubs**: `PointLocker` (lock/refund) and `ObligationChecker`. Interfaces are declared on the consumer (`matching`); `main` wires stubs in 4a and real implementations in Phase 5. `point_source` / `is_obligation` columns are present but their meaning is assigned in Phase 5 (`is_obligation` fixed `false` in 4a). | Go idiom (wrap boundaries whose alternative implementation — Phase 5 — is known); lets matching be fully unit-tested with fakes; Phase 5 injects without editing Phase 4 code. |
| **P4a-D5** | **Collapse the `matching_strategy` dimension to a single value `standard`.** Drop `premium` and `direct` values and their dead code (per-strategy cost function, strategy selector); keep a single-value enum column as a forward-compatible seam. | Live behavior is already standard-only: the UI only ever sends `standard`, `preferred_referee_id` is never set, and `get_point_for_matching_strategy` already rejects non-standard. `premium`/`direct` are intended-but-unbuilt (follow-up). Keeping a single-value enum makes reintroducing strategies a value-add + branch, not a structural migration. |
| **P4a-D6** | **Drop unused columns/tables**: `tasks.fee_amount` / `tasks.fee_currency` (defined in the Flutter model but never read), `task_referee_requests.preferred_referee_id` (direct dropped), the KV `matching_config` table (its only key was removed by a later migration). | Dead data/scaffolding; the big-bang migration resets internal data (Phase 7), so no migration cost. Recorded in follow-ups. |
| **P4a-D7** | **Keep the backend concept name `referee`** (the UI uses its localized referee label; 1:1 mapping). | `referee` is semantically accurate (renders a pass/fail ruling) and a standard general term (academic peer "referees"); it is already pervasive across every backend domain and the `notification_{event}_{recipient}` key convention. Renaming to `reviewer` would be a cross-cutting churn that contradicts the finish-the-port priority and would introduce a permanent term mismatch with the UI. |
| **P4a-D8** | **Drop the `task_` prefix: `task_referee_requests` → `referee_requests`.** | The task linkage is the `task_id` FK; the prefix is redundant. (`task_evidences` → `evidences` is a 4b follow-up.) |
| **P4a-D9** | **Single typed config table.** The KV `matching_config` is dropped; the typed singleton (deadline hours + ordering invariant) becomes the one matching config table, seeded by 4a. | Typed columns + CHECK invariants (`open > rematch > cancel`) are type-safe and enforce cross-setting invariants; the KV bag is untyped and already empty. |
| **P4a-D10** | **Design for multiple referees per task from the start** (schema already supports 1:N). Publish takes a referee count `N`; cap via config `max_referees_per_task` (default 2, current behavior). Matching excludes referees already in an active (pending/accepted) request on the same task. | Retrofitting multi-referee later touches read models, close logic, and matching exclusion; the schema is already 1:N; cheap to keep now. |
| **P4a-D11** | **Forward-build a per-referee availability parent** `referee_availability` (`user_id` PK, `is_accepting boolean DEFAULT true`, `max_concurrent_assignments int NULL`). 4a adds the table + wires both into the matching candidate query (no-op at defaults); the edit endpoint/UI is deferred to the imminent "accepting on/off + concurrency cap" feature. | The operator confirmed these are imminent features, so this is a stated need, not speculation; adding now avoids a near-future migration (Phase 7 reset removes data cost). |
| **P4a-D12** | **Build a feature-neutral notification-send foundation in 4a** (`platform/fcm` + `send_notification` worker + invalid-token cleanup), reused by 4b/4c. **Keep client-side localization (FCM `loc_key`)** for the port; the job contract makes a later swap to server-side localization a single isolated change. | Matching notifications are the first consumer of the Phase-4 send path (3a §4.8 deferred it here). `loc_key` reuses the app's existing i18n (no second catalog) and tracks OS locale; server-side localization is a high-value follow-up, not a port. |
| **P4a-D13** | **`publish` cross-feature transaction** is owned by `task.Service`, which opens the single transaction and passes the tx handle into `matching` via a consumer-declared `RefereeRequestCreator.CreateInTx` seam (mirrors 3a's in-tx provisioner). | Publish spans `task` (status→open) and `matching` (requests + point lock + job enqueue) and must be atomic; one tx opened in one place, shared by handle, keeps the two features' writes all-or-nothing without either feature opening its own tx. |
| **P4a-D14** | **The transaction boundary uses the `core` tx helper (Unit of Work); stores are typed to the Phase 3a `Querier` interface** (`database.Querier`, introduced by 3a's provisioning fan-out) satisfied by both the pool and a tx. `jobs` gains an `EnqueueInTx` accepting that `Querier` (Phase 1's `Enqueue` is `*sql.DB`-fixed). This plumbing lands first. The exact pgx/`database/sql` tx-helper and FCM Admin SDK messaging APIs are verified against official docs at plan time. | Best-practice tx management; reuses 3a's `Querier` rather than inventing a parallel type; the outbox (same-tx enqueue) is impossible without `EnqueueInTx`. |
| **P4a-D15** | **`updated_at` is maintained by the common `set_updated_at()` trigger** (Phase 3a P3a-D11), one per new 4a table; Go SQL does **not** write `updated_at`. | Aligns 4a with 3a's convention amendment; no write path (esp. `ON CONFLICT DO UPDATE`) can forget it. `updated_at` is housekeeping, not business logic, so the max-Go stance holds. |
| **P4a-D16** | **Concurrent matching is guarded against same-task double-assignment by a partial unique index** on `referee_requests (task_id, matched_referee_id) WHERE status = 'accepted' AND matched_referee_id IS NOT NULL`. The match handler treats a `23505` on accept as "lost the race" and leaves the request `pending` (the sweep retries with a fresh candidate set). A "two concurrent match jobs for two requests of the same task, same eligible referee → exactly one assigned" test is required. **`max_concurrent_assignments` cap enforcement under concurrency** (a `COUNT < cap` race a unique index cannot express) is deferred to the imminent availability-cap feature, which must add a per-referee advisory lock (`pg_advisory_xact_lock`) + re-count; at 4a's default (`NULL` = unlimited) the cap is a no-op. | The per-request CAS only guards one request; it cannot stop two requests concurrently selecting the same referee. A DB constraint makes same-task double-assignment impossible regardless of interleaving; the cap race is not live until the cap feature ships. |
| **P4a-D17** | **`PointLocker` is a per-request lock/refund contract that returns a receipt** so Phase 5 is a pure wiring swap. `LockForRequestInTx(ctx, tx, taskerID, requestID, cost) (pointSource string, err error)` reserves points for one request and returns the funding source recorded on that request's `point_source`; `RefundForRequestInTx(ctx, tx, requestID, reason)` idempotently reverses it, keyed by `requestID`. `CreateInTx` inserts each request, locks per request, and stamps `point_source` from the lock result; the sweep refunds per request. | The original "lock N together, refund per request" left no per-request receipt, so Phase 5 would have had to change matching code to correlate refunds. Per-request lock + a receptor column (`point_source`) keyed by `requestID` makes refund idempotent and swap-only. Per-request locking also gives correct atomic affordability (a tasker who can fund 1 of 2 referees fails the whole publish). |
| **P4a-D18** | **FCM sending requires a Firebase service-account credential** (worker-only, least-privilege: Firebase Cloud Messaging only). **4a owns adding this secret** through Phase 7a's established file-based secret mechanism: assuming 7a provisions secrets as Docker file-based secrets rendered from BWS at deploy, 4a adds a worker-only Firebase service-account secret delivered the same way and exposed to the worker via `GOOGLE_APPLICATION_CREDENTIALS` (Application Default Credentials). 7a's §6.3 inventory predates 4a's FCM need and does not list it (it records "no Firebase service-account secret" because Phase 2 token *verification* uses `WithoutAuthentication`); this is a 4a-side addition, **not** a change to the 7a docs. | The VPS is not a Google runtime, so ADC needs an explicit service-account file. FCM *sending* (unlike token verification) is an authenticated API and needs the credential. Ref: Firebase Admin SDK setup (`firebase.google.com/docs/admin/setup`). |
| **P4a-D19** | **The `notification_matching_cancelled_pending_tasker` message is sent at most once per re-match request**, using the job idempotency key `cancelled_pending:{requestID}`: the match handler enqueues it (with that key) when a cancel-originated request finds no candidate; `ON CONFLICT (idempotency_key) DO NOTHING` guarantees once-only even across sweep retries. | Async matching makes "did the re-match succeed?" unknowable at cancel time; deciding the send point + a dedup key removes implementation drift and sweep-retry spam. |

## §2 Data Model

Atlas table-only for *business* logic (no business DB functions/triggers).
`updated_at` is maintained by the common `set_updated_at()` trigger (P3a-D11,
P4a-D15) — every new table below carries it. FKs target the Go identity core
`users(id)` (Phase 2); referee timezone is read from `profiles` (Phase 3a). Full
deletion semantics are Phase 6.

**Concurrency guard (P4a-D16):** `referee_requests` carries a partial unique
index `UNIQUE (task_id, matched_referee_id) WHERE status = 'accepted' AND
matched_referee_id IS NOT NULL`, making same-task double-assignment impossible
regardless of how concurrent match jobs interleave.

**Tables**

| Table | Notes |
|-------|-------|
| `tasks` | Drop `fee_amount`/`fee_currency`. Columns: `id, tasker_id → users(id) ON DELETE SET NULL, title, description, criteria, due_date, status, created_at, updated_at`. `status` enum `task_status` = `draft / open / closed`. |
| `referee_requests` (was `task_referee_requests`) | `matching_strategy` enum collapsed to single value `standard`; drop `preferred_referee_id`. Columns: `id, task_id → tasks(id) ON DELETE CASCADE, matching_strategy, status, matched_referee_id → users(id) ON DELETE SET NULL, responded_at, point_source, is_obligation, created_at, updated_at`. |
| `judgements` | Created here (PK = request id, 1:1). 4a only INSERTs `awaiting_evidence` on match and DELETEs on cancel (when still `awaiting_evidence`). Full lifecycle in 4c. |
| `referee_available_time_slots` | Faithful port (weekly recurring: `dow`, `start_min`, `end_min`, `is_active`; unique `(user_id, dow, start_min)`). `user_id → users(id) ON DELETE CASCADE`. |
| `referee_blocked_dates` | Faithful port (date ranges `start_date`, `end_date`, `reason`). `user_id → users(id) ON DELETE CASCADE`. |
| `referee_availability` **(new)** | Per-referee availability knobs. `user_id` PK → `users(id) ON DELETE CASCADE`, `is_accepting boolean NOT NULL DEFAULT true`, `max_concurrent_assignments int NULL` (NULL = unlimited), timestamps. |
| `matching_config` (typed) | The single matching config table (typed singleton). Fields: `open_deadline_hours`, `cancel_deadline_hours`, `rematch_cutoff_hours` (ordering invariant `open > rematch > cancel`), plus `max_referees_per_task` (default 2) and the matching point cost (flat 1). **Seeded by 4a with the current production values: `open_deadline_hours=24`, `cancel_deadline_hours=12`, `rematch_cutoff_hours=14`.** The KV `matching_config` is dropped. |

**Enums**
- `task_status`: `draft`, `open`, `closed`.
- `matching_strategy`: `standard` (single value; seam for future strategies).
- `referee_request_status`: `pending`, `accepted`, `expired`, `cancelled`,
  `closed`, `payment_processing`. **Drop `matched`, `declined`** (unreached in
  the auto-accept flow; reintroduced with the future accept/decline flow —
  follow-up). 4a drives `pending / accepted / expired / cancelled`; `closed` is
  4c; `payment_processing` is Phase 5.
- `judgement_status`: full set exists; 4a only writes `awaiting_evidence`.

## §3 State Machines

**task:** `draft → open → closed`
- 4a drives `draft → open` (publish, after open-requirement validation).
  `open → closed` (all judgements confirmed) is 4c.

**referee_request:**
```
pending ──(worker: match found)──▶ accepted ──(referee cancel, before cutoff)──▶ cancelled ─▶ (new pending)
   │                                    │
   └──(sweep: past rematch cutoff)──▶ expired    └─(4c)─▶ closed  /  (Phase 5) payment_processing
```
- 4a drives `pending / accepted / expired / cancelled`.

**judgement:** `awaiting_evidence` (created by 4a on match) → the rest in 4c.

## §4 Matching Algorithm (`standard`, behavior-preserving)

The `match_referee_request` worker attempts one match for a `pending` request:

1. **Candidate selection** — referees whose `referee_available_time_slots`
   (active) cover the task `due_date` converted to the referee's timezone
   (day-of-week + minute-of-day), excluding:
   - the tasker themselves;
   - referees who previously `cancelled` a request on this task;
   - referees whose `referee_blocked_dates` cover the due date (in their tz);
   - referees with `referee_availability.is_accepting = false` **(new)**;
   - referees whose active workload ≥ `max_concurrent_assignments` **(new)**;
   - referees already in an active (`pending`/`accepted`) request on this task
     **(new, for multi-referee)**.
2. **Least-workload** — restrict to candidates with the minimum active-judgement
   workload count.
3. **Obligation priority** — `ObligationChecker` filters least-workload
   candidates for pending obligations (Phase 5 seam; 4a stub returns none, so
   this reduces to a random pick from the least-workload set), `is_obligation`
   recorded (fixed `false` in 4a).
4. On a match: set request `accepted` (+ `matched_referee_id`, `responded_at`)
   via a CAS that requires **both** `status='pending'` **and** the task still
   within the matching window (`due_date > now() + rematch_cutoff_hours`) — so a
   delayed/stale match job (e.g. after a worker outage crossed the cutoff) cannot
   assign a referee to a request the sweep should expire. Then INSERT the
   `awaiting_evidence` judgement, enqueue `send_notification`. On no match (or a
   failed CAS): leave `pending` (the sweep retries or expires it).

**Concurrency (P4a-D16):** two concurrent match jobs for two requests of the
same task may both pick the same eligible referee. The partial unique index
(§2) makes the second `accepted` write fail with `23505`; the handler treats
that as losing the race and leaves the request `pending` for the sweep to retry
against a fresh candidate set. Enforcing `max_concurrent_assignments` under
concurrency (a `COUNT < cap` race) is deferred to the availability-cap feature
(per-referee `pg_advisory_xact_lock` + re-count); it is a no-op at the 4a default.

## §5 Execution Model

**Publish (synchronous API, one transaction):**
`task.Service.Publish` opens one tx (via the `core` UoW helper) and:
1. validate ownership + open requirements → `tasks.status = open`. **Open
   requirements** (porting `validate_task_open_requirements`): title present;
   criteria present; **`due_date > now() + matching_config.open_deadline_hours`**
   (the minimum-lead rule, not merely "in the future"). The point-balance check
   the old function also did is **not** repeated here — affordability is enforced
   by `PointLocker.LockForRequestInTx` (a no-op in 4a; real in Phase 5), so a
   failed per-request lock rolls back publish.
2. `matching.RefereeRequestCreator.CreateInTx(tx, taskID, taskerID, N)` → for each
   of N requests: INSERT `pending` `referee_requests` → `PointLocker.LockForRequestInTx(tx, taskerID, requestID, cost)`
   (stub returns `regular`) → stamp `point_source` on the request → enqueue a
   `match_referee_request` job (outbox, same tx). Per-request locking gives
   correct atomic affordability (funding fewer than N fails the whole publish).
3. commit → return `{ taskId, status: "open", requests: [{id, status:"pending"}] }`.

**Worker jobs (Phase 1 leased jobs):**

| Job | Trigger | Idempotency |
|-----|---------|-------------|
| `match_referee_request` | enqueued by publish / cancel | acts only when the request is `pending` (`UPDATE ... WHERE status='pending'` compare-and-set); the judgement INSERT is keyed by request PK (duplicate → already-done). |
| `sweep_pending_requests` | self-rescheduling (hourly; bucketed idempotency key), schedules the next run **first** so a failed run can't break the chain | per candidate, in one tx: **CAS** `expire WHERE status='pending'` → only then refund via seam + enqueue notification (so a request a concurrent match already accepted is not expired); retry the rest via the same match routine. |
| `send_notification` | enqueued by matching (reused by 4b/4c) | at-least-once; duplicate event push is low-harm; best-effort dedup by job/notification id. |

These are the first real handlers to which the issue #464 at-least-once
idempotency checklist applies; call it out in review.

**Cancel:** `POST /referee-requests/{id}/cancel` (assigned referee only, before
`cancel_deadline_hours`) sets the request `cancelled`, deletes the judgement if
still `awaiting_evidence`, inserts a new `pending` request (carrying the original
`point_source`), and enqueues a match job — atomically.

**Cancelled-then-pending notification (P4a-D19):** because matching is async,
whether the re-match succeeds is unknown at cancel time. The match handler, when
a **cancel-originated** request (its task has a prior `cancelled` request) finds
no candidate, enqueues `notification_matching_cancelled_pending_tasker` with
idempotency key `cancelled_pending:{requestID}` — `ON CONFLICT DO NOTHING`
guarantees exactly one send per re-match request even across sweep retries.

## §6 Go Structure

Option E layout (`internal/<feature>/` with `domain.go` / `service.go`
(`Service`) / `store.go` (`Store`) / `handler.go`).

| Package | Role |
|---------|------|
| `internal/task` | `Task`/`TaskStatus`; create/update/delete + **publish orchestration** (validation, tx boundary); tasks CRUD store; task handlers. |
| `internal/matching` | `RefereeRequest`/`RequestStatus`/`RefereeAvailability`/`TimeSlot`/`BlockedDate`; matching, cancel, availability, request creation; requests/availability/config stores; referee & availability handlers; **workers `match_referee_request` / `sweep_pending_requests`**. Declares the `PointLocker`, `ObligationChecker`, and `RefereeRequestCreator` seams. |
| `internal/notification` (extends 3a) | `Enqueue(tx, …)` (outbox) + send path; token/settings store + invalid-token cleanup; **worker `send_notification`**. |
| `internal/judgement` (minimal in 4a) | `awaiting_evidence` create / cancel-delete via a `Provisioner` seam; full lifecycle in 4c. |
| `platform/fcm` **(new)** | Firebase Admin SDK messaging adapter (loc_key multicast send + invalid-token identification); SDK/DTO types stop here. |

**Composition root** (`cmd/peppercheck` api + worker): wires the services, the
no-op Phase 5 stubs, `platform/fcm`, and registers the job handlers.

## §7 API Contract (`/api/v1`)

Under Phase 2 token-verify + 3a `CurrentUser` middleware; Go-layer ownership
authz; Phase 2 stable error envelope.

**`/me` vs top-level rule:** `/me/*` = the caller's own account-scoped
sub-resources and personalized views (identity implicit, no id). Top-level
`/resource/{id}` = first-class entities addressed by their own id and touched by
multiple actors; authz decides access.

Tasker task authoring:
- `POST /tasks` — create draft.
- `PATCH /tasks/{id}` / `DELETE /tasks/{id}` — own draft only.
- `POST /tasks/{id}/publish` — draft→open; body `{ refereeCount }`; locks points
  (stub), creates requests, enqueues matching, returns `pending`.
- `GET /me/tasks` — own authored tasks (status filter, paging).
- `GET /tasks/{id}` — task detail + referee-request states (top-level; a referee
  assigned to it may read it).

Referee:
- `GET /me/assignments` — tasks the caller referees.
- `POST /referee-requests/{id}/cancel` — cancel an assignment → re-match.

Referee availability (own — `/me`):
- `GET/POST/PUT/DELETE /me/availability/time-slots`
- `GET/POST/PUT/DELETE /me/availability/blocked-dates`
- (`referee_availability` `is_accepting`/`max_concurrent` editing is out of 4a;
  the table + matching enforcement only.)

Config:
- `GET /matching/config` — public deadline settings. Matching cost is flat
  (1 point/request); the per-strategy cost RPC is removed.

## §7.1 Wire Contract (JSON, camelCase) — pinned for the Flutter client

> **Amendment (2026-07-26, surfaced by the Phase 4a Flutter design review).** §7
> named endpoints but did not pin request/response bodies to a DTO-implementable
> granularity, and did not state that task/assignment responses **embed a minimal
> public profile** for display (tasker + matched referee username/avatar). Both
> are pinned here so the Flutter DTOs can be written test-first without "confirm
> the handler later". JSON is **camelCase** (consistent with the Phase 2 `/me` and
> Phase 3a `/me/profile` responses). Every error is the Phase 2 envelope
> `{ "error": { "code", "message", "requestId" } }`.

**Minimal public profile (embedded).** Task/assignment responses carry, for the
tasker and each matched referee, a minimal public profile — this is the Phase-3a-
deferred `PublicProfile` (that spec deferred other-user profiles to Phase 4). It
carries **only** display fields; it is not the owner's editable profile:

```json
{ "userId": "uuid", "username": "user_1a2b3c4d", "avatarUrl": "https://…/…jpg" }
```

`avatarUrl` may be `null`. Populated on `referee_requests` **only when matched**
(`matchedRefereeId != null`); `null` while `pending`.

**Task object** (`GET /tasks/{id}`, and the element of the list responses). No
`feeAmount`/`feeCurrency`, no `matchingStrategy`, no `preferredRefereeId`; **no
`judgement`/`evidence` in 4a** (those land in 4b/4c):

```json
{
  "id": "uuid",
  "taskerId": "uuid",
  "title": "…",
  "description": "…",            // nullable
  "criteria": "…",               // nullable
  "dueDate": "2026-08-01T00:00:00Z",  // nullable, RFC3339 UTC
  "status": "draft",             // draft | open | closed
  "createdAt": "…", "updatedAt": "…",
  "tasker": { "userId":"uuid","username":"…","avatarUrl":"…" },  // nullable
  "refereeRequests": [
    {
      "id": "uuid",
      "taskId": "uuid",
      "status": "pending",       // pending | accepted | expired | cancelled | closed | payment_processing
      "matchedRefereeId": "uuid",// nullable (null while pending)
      "respondedAt": "…",        // nullable
      "pointSource": "regular",  // nullable
      "isObligation": false,
      "createdAt": "…", "updatedAt": "…",
      "referee": { "userId":"uuid","username":"…","avatarUrl":"…" }  // nullable; set when matched
    }
  ]
}
```

**Endpoints:**

| Method & path | Request body | Success | Notes |
|---------------|--------------|---------|-------|
| `POST /tasks` | `{ "title", "description"?, "criteria"?, "dueDate"? }` | `201` Task (draft, `refereeRequests: []`) | server scopes `taskerId` to `CurrentUser` |
| `PATCH /tasks/{id}` | any subset of the create body | `200` Task | own draft only |
| `DELETE /tasks/{id}` | — | `204` | own draft only |
| `POST /tasks/{id}/publish` | `{ "refereeCount": 1 }` (1..`maxRefereesPerTask`) | `200` Task (`status:"open"`, N `pending` requests) | `400 validation_error` on open-requirement fail; `refereeCount` out of range → `400` |
| `GET /me/tasks?status=&cursor=&limit=` | — | `200 { "tasks": [Task], "nextCursor": "…"\|null }` | cursor paging |
| `GET /tasks/{id}` | — | `200` Task | tasker or an assigned referee may read |
| `GET /me/assignments?cursor=&limit=` | — | `200 { "assignments": [Task], "nextCursor": "…"\|null }` | each Task's `refereeRequests` includes the caller's request; `tasker` embedded for display |
| `POST /referee-requests/{id}/cancel` | — | `200` Task (updated) | assigned referee only, before cutoff |
| `GET /matching/config` | — | `200 { "openDeadlineHours":24, "cancelDeadlineHours":12, "rematchCutoffHours":14, "maxRefereesPerTask":2, "matchingPointCost":1 }` | public |
| `GET /me/availability/time-slots` | — | `200 { "timeSlots": [Slot] }` | `Slot = { "id","dow","startMin","endMin","isActive" }` |
| `POST /me/availability/time-slots` | `{ "dow","startMin","endMin","isActive" }` | `201` Slot | |
| `PUT /me/availability/time-slots/{id}` | same | `200` Slot | own only |
| `DELETE /me/availability/time-slots/{id}` | — | `204` | own only |
| `GET /me/availability/blocked-dates` | — | `200 { "blockedDates": [Blocked] }` | `Blocked = { "id","startDate","endDate","reason"? }` (dates `YYYY-MM-DD`) |
| `POST /me/availability/blocked-dates` | `{ "startDate","endDate","reason"? }` | `201` Blocked | |
| `PUT /me/availability/blocked-dates/{id}` | same | `200` Blocked | own only |
| `DELETE /me/availability/blocked-dates/{id}` | — | `204` | own only |

The embedded `PublicProfile` is the only cross-feature read the task/matching
handlers perform against `profiles` (Phase 3a); it is a **read of `username` +
`avatar_url` by `user_id`**, exposed as a shared minimal projection (not the
owner's `/me/profile` DTO).

## §8 Notification Foundation

The server emits FCM localization **keys**, not resolved text; the device
resolves them against the app's i18n (OS locale). Key convention preserved:
`notification_{event}_{recipient}`, with `title_loc_key = key + '_title'` /
`body_loc_key = key + '_body'` + args (`.claude/rules/notification-keys.md`).

- `platform/fcm`: Firebase Admin SDK messaging (`firebase.google.com/go/v4/messaging`)
  — send loc_key multicast (Android `TitleLocKey`/`BodyLocKey`, APNS
  `title-loc-key`), identify invalid tokens from the response. Exact API verified
  against official docs at plan time.
- `internal/notification`: `Enqueue(tx, userID, keyBase, args, data)` writes a
  `send_notification` job to the outbox in the caller's tx; the worker loads the
  user's `user_fcm_tokens`, sends via `platform/fcm`, and deletes invalid tokens
  (the cleanup migrated out of the old `send-notification` edge function, 3a §4.8).
- The old edge function / `pg_net` / `vault` / `service_role_key` path is removed;
  the Go worker calls FCM directly.

**Credentials (P4a-D18):** FCM *sending* needs a Firebase service-account
credential (unlike Phase 2 token *verification*, which uses `WithoutAuthentication`).
**Assumed 7a mechanism:** 7a renders secrets from BWS into Docker file-based
secrets at deploy, delivered to the `worker` container. **4a-side work (owned
here, no 7a doc change):** provision a **worker-only, least-privilege** service
account (Firebase Cloud Messaging only), store it in BWS, deliver it through that
same 7a file-secret path, and expose it to the worker via
`GOOGLE_APPLICATION_CREDENTIALS` so the Admin SDK picks it up through Application
Default Credentials. 7a's §6.3 inventory predates this and does not list the
secret; adding it is part of 4a. Ref: `firebase.google.com/docs/admin/setup`.

**4a notification events:** `notification_task_assigned_referee`,
`notification_request_matched_tasker`, `notification_matching_reassigned_tasker`,
`notification_matching_expired_refunded_tasker`,
`notification_matching_cancelled_pending_tasker`.

**Out of 4a (→ 4b/4c):** deadline-reminder scheduling — `notification_settings`
reminder minutes, the `detect_*_deadline_warnings` jobs, `notification_sent_log`
dedup.

## §9 Phase 5 Seams

```go
// declared in internal/matching; stubs wired in main (4a), real impl in Phase 5.
// database.Querier is the Phase 3a tx/pool interface (P4a-D14).
type PointLocker interface {
    // LockForRequestInTx reserves cost points for one request and returns the
    // funding source recorded on that request's point_source. Phase 5 writes a
    // ledger keyed by requestID; the 4a stub returns "regular" and no-ops.
    LockForRequestInTx(ctx context.Context, tx database.Querier, taskerID, requestID uuid.UUID, cost int) (pointSource string, err error)
    // RefundForRequestInTx idempotently reverses the lock for one request,
    // keyed by requestID. The 4a stub no-ops.
    RefundForRequestInTx(ctx context.Context, tx database.Querier, requestID uuid.UUID, reason string) error
}
type ObligationChecker interface {
    FilterObligated(ctx context.Context, candidateIDs []uuid.UUID) ([]uuid.UUID, error)
}
```
- 4a: `noopPointLocker` (`LockForRequestInTx` returns `"regular", nil`;
  `RefundForRequestInTx` returns nil) + `noObligations` (returns empty);
  `is_obligation = false`.
- Phase 5: swap the wiring only; matching code is unchanged (refunds already
  correlate per request via `requestID` + the stamped `point_source`).

## §10 Testing Strategy

- **Go unit:** task transitions (draft→open validation); candidate selection
  (availability × timezone × workload × exclusions × `is_accepting` ×
  `max_concurrent` × same-task exclusion); cancel eligibility (cutoff); match-job
  CAS idempotency; `PointLocker` called with cost = N × flat; obligation stub.
- **Postgres integration** (real container): migrations apply to empty DB;
  constraints/indexes (availability unique, FKs, config ordering invariant, the
  same-task partial unique index, `set_updated_at` present on every table with
  `updated_at`); publish atomicity (task open + requests + jobs all-or-nothing;
  rollback on failure or on a failed per-request lock); match-job idempotency
  (twice → one referee, one judgement); concurrent match of the **same request**
  (two workers → exactly one wins via CAS); concurrent match of **two requests of
  the same task** picking the same eligible referee (→ exactly one accepted, the
  other left pending via the unique index); user-scoped isolation.
- **API integration** (HTTP + real Postgres + fake FCM/seams): auth required;
  ownership violations (403); publish validation; publish returns pending +
  enqueues; cancel rules; list paging/ordering; stable error envelopes.
- **Worker:** `match_referee_request` (match / idempotent / leaves pending when
  no candidate); `sweep_pending_requests` (expire past cutoff + refund seam +
  notify; retry the rest); `send_notification` (load tokens → fake fcm → invalid
  token cleanup → at-least-once tolerated).
- **Characterization:** port the Phase 0 high-risk matching characterization
  fixtures; assert the Go selection matches the documented algorithm.
- **CI gates:** gofmt, `go vet`, unit, Postgres integration, race, Atlas
  fmt/lint, apply-to-empty-DB, schema-drift, image build.

## §11 Completion Criteria ("done")

- Via the Go API a tasker can create/edit/delete a draft and publish (→open:
  point-lock stub + N referee requests + matching enqueue, atomic); `task` and
  `matching` have no Supabase imports.
- `match_referee_request` assigns an available referee respecting availability,
  timezone, workload, exclusions, `is_accepting`, and `max_concurrent`; creates
  the `awaiting_evidence` judgement; notifies via `send_notification` + FCM.
- `sweep_pending_requests` expires past-cutoff pendings (refund stub) and retries.
- A referee manages availability (slots / blocked-dates) and cancels an
  assignment before cutoff (→ re-match). Multi-referee (up to the config cap)
  works.
- Point/obligation are interface seams with no-op stubs; `is_obligation = false`.
- `match` / `sweep` / `send` handlers are safe under at-least-once (#464).
- All tests green; CI gates pass; api/worker shut down cleanly (Phase 1 lifecycle).
- Flutter is a separate follow-on spec (not in this "done").

## §12 Follow-ups

See `docs/superpowers/specs/2026-07-25-phase4a-follow-ups.md`.
