# Phase 4b — Evidence & Private R2 (Design)

> Part of the Supabase → Go API + VPS refactor. See the strategy doc
> `docs/superpowers/specs/2026-07-22-supabase-to-go-vps-refactor-design.md`, the
> Phase 0 baseline `docs/superpowers/specs/2026-07-22-phase0-baseline.md`, and the
> Phase 4a spec `docs/superpowers/specs/2026-07-25-phase4a-task-authoring-matching-design.md`.
> Each phase is its own `spec → plan → implementation` cycle.

## §0 Scope & Context

Phase 4 ("core task lifecycle") is decomposed into three sub-phases along the
state machine (P4a-D1):

- **4a — task authoring + matching** (done: spec written).
- **4b — evidence + private R2** (this document): upload intents, submit / update
  / resubmit, evidence-timeout, **authorized presigned downloads from a private
  R2 bucket**, evidence deadline reminders, R2 stale-object hygiene.
- **4c — judgement + rating** (judge, confirm, reopen, threads, auto-confirm,
  review timeouts, rating).

**This document covers 4b backend only.** The Flutter client for evidence is a
separate follow-on `spec → plan` cycle (mirroring Phase 2 / 3a / 4a).

**Porting philosophy (locked, inherited from 4a):** behavior- and
concept-preserving port; only the *structure* is redesigned (Go
`service`/`store`/`handler`/worker, DTOs, no *business* DB functions/triggers —
`updated_at` is maintained by the common `set_updated_at()` trigger per P3a-D11 /
P4a-D15, not by Go). Clearly-poor implementations may be improved during the Go
port as long as the intent is preserved. Anything dead, no-op, or deliberately
deferred is recorded in §11 Follow-ups rather than silently carried or dropped.

**Transitional narrowing (Phase 2 / 4a principle):** on the integration branch
the Go point/reward system (Phase 5) and the judgement lifecycle beyond
`awaiting_evidence` (4c) do not exist yet. 4b implements the full evidence
lifecycle it owns, expressing its dependencies on 4c (`rejected` state, task
closure) and Phase 5 (point consume + referee reward on evidence-timeout) as **Go
interface seams with no-op stubs**. 4c and Phase 5 arrive by swapping the wiring,
without changing evidence code. Code paths that require a state only 4c produces
(resubmit needs `rejected`) are built but **dormant** until 4c ships — the same
forward-build pattern 4a used for `in_review` (produced by 4b, consumed by 4c).

**Dependencies on prior phases:**
- Phase 2 — Firebase token verify + internal user UUID; stable error envelope.
- Phase 3a — `platform/r2` presigned-PUT adapter (`PresignPut` / `Head` /
  `Delete`, avatar public-domain served); `CurrentUser(ctx)` auth middleware;
  `notification_settings` (already carries `evidence_reminder_minutes int[]
  NOT NULL DEFAULT '{10}'`, `evidence_reminder_even_if_submitted`); the
  `send_notification` outbox/worker foundation groundwork; `set_updated_at()`.
- Phase 4a — `tasks`, `referee_requests`, `judgements` (created
  `awaiting_evidence` on match); `internal/task`, `internal/matching`,
  `internal/notification` (send path + `platform/fcm`); the `core` UoW tx helper
  + `database.Querier`; the leased-jobs primitive (+ `EnqueueInTx`).

## §1 Decision Log

| ID | Decision | Rationale |
|----|----------|-----------|
| **P4b-D1** | **Implement the full evidence lifecycle in 4b as forward-build with seams** (upload intents, submit, update, resubmit, evidence-timeout detection + confirm, authorized downloads). `rejected` (4c) and point/reward settlement (Phase 5) are Go interface seams with no-op stubs. | Matches 4a §0's assignment of submit/resubmit/evidence-timeout to 4b and the established transitional-narrowing pattern (4a builds `in_review` with no consumer until 4c). Keeps 4c/Phase 5 as pure wiring swaps. |
| **P4b-D2** | **Private-bucket downloads = the Go API issues short-lived presigned GET URLs after authorization and embeds them in the read response.** `platform/r2` gains `PresignGet`. The client never receives R2 keys or credentials; presigned URLs are generated per-read, never persisted. | Resolves the launch-blocker (baseline §5.3 #5: evidence must not use a public domain). Matches the engineering policy ("the Go API issues presigned URLs; never hand keys to the client"). R2 keeps serving the bytes (edge delivery, no API bandwidth bottleneck). S3 presigning is a **local HMAC operation** (no R2 round-trip), so embedding URLs in reads is cheap. Authorization happens once, in the Go API. |
| **P4b-D3** | **Evidence uses a new, dedicated private R2 bucket.** Avatars stay on the existing public bucket + public domain (3a unchanged). The stale-object sweep targets both buckets (via two feature-owned workers, P4b-D7). | Sensitivity-appropriate separation. R2 cannot cleanly make one prefix private and another public under a single public custom domain, so prefix-mixing on one bucket does not work. Avatars are intentionally public (P3a-D6) — shown to many people in many contexts; evidence is private. |
| **P4b-D4** | **Drop unused evidence columns/enums** (recorded in §11): `public_url` → drop (private bucket; presigned GET generated on read); `file_url` → consolidate into a single `object_key` (R2 key only); `processing_status` / `error_message` → drop (no server-side image pipeline — normalization is client-side, `ImageNormalizer`, JPEG re-encode); `evidence_status` enum (`pending_upload` / `ready`) → drop (`pending_upload` is never persisted — `submit_evidence` inserts `ready` directly; a row's existence *is* "ready"). | Dead data/scaffolding; the Phase 7 reset removes any migration cost. The two-phase upload-status was designed but never used (the client uploads to R2 first, then submits metadata). |
| **P4b-D5** | **Drop the `task_` prefix: `task_evidences` → `evidences`, `task_evidence_assets` → `evidence_assets`** (the 4a follow-up for evidences). | The task linkage is the `task_id` FK; the prefix is redundant. Consistent with 4a's `task_referee_requests` → `referee_requests`. |
| **P4b-D6** | **Evidence is a task-singleton in the API: `/tasks/{id}/evidence` (singular), no top-level `/evidence/{id}`.** The table stays plural (`evidences`). | Evidence is exactly one per task (task-level, shared across all referees; submit creates it, update/resubmit edit it) and "evidence" is an uncountable noun — both point to a singular singleton path. Matches the in-repo precedent 3a `profiles` (plural table) ↔ `/me/profile` (singular singleton API): table plurality and API-resource singularity follow independent conventions. `judgements` stays plural + id-addressed because it is genuinely N-per-task (per referee). |
| **P4b-D7** | **Two feature-owned stale-object sweeps, not one shared cron:** `sweep_evidence_objects` in `internal/evidence` (age-based, private bucket) and `sweep_orphan_avatars` in `internal/profile` (orphan-based, public bucket). | The legacy single `sweep-r2-stale-objects` cron mixed two features. Splitting is correct regardless of future upload contexts: different buckets, different retention logic (evidence = 90-day age; avatar = "not the current `avatar_url`" orphan with a grace period), and feature ownership (an evidence sweep reaching into `profiles` is a cross-feature reach). New upload contexts each get their own feature-owned sweep instead of growing a central grab-bag. |
| **P4b-D8** | **Evidence-timeout settlement splits by concern.** The `detect_evidence_timeouts` worker owns the `awaiting_evidence → evidence_timeout` transition, the referee-request close, and both notifications. The **financial settlement (consume tasker's locked points + grant referee reward) is a Phase 5 seam** (`EvidenceTimeoutSettler`), no-op in 4b. `confirm_evidence_timeout` sets `is_confirmed` and calls a **4c task-closure seam** (no-op in 4b). | Mirrors 4a's split (its sweep does "expire → refund via seam → notify"): the worker owns the state machine + notifications; only the point/reward math is deferred to Phase 5. Task closure (open → closed on all judgements confirmed) is 4c, exactly as in 4a. |
| **P4b-D9** | **Enforce the task-singleton at the DB layer: `UNIQUE (task_id)` on `evidences`;** a `23505` on insert maps to `409 conflict`. Submit's judgement transition must affect ≥1 row or the whole tx rolls back. | The state gate (submit requires an `awaiting_evidence` judgement) does not stop two concurrent submits from both passing the gate and both inserting an evidence row before either commits. A unique constraint makes double-create impossible regardless of interleaving; the transition-rowcount check closes the submit-vs-timeout race (a submit whose judgements a concurrent `evidence_timeout` already moved must not create evidence). (Review 2026-07-26 #1, #3.) |
| **P4b-D10** | **Server-verified, task-bound object keys.** The upload key is `evidence/{due-date}/{task-id}/{uuid}.{ext}` (task-scoped, not just date+uuid). On submit/update/resubmit the server (a) rejects any `objectKey` whose prefix does not match the target task, and (b) calls `r2.Head` to confirm the object exists and to read its **actual** `Content-Type` and size — the DB stores the **R2-reported** metadata, never the client-supplied values. `evidence_assets` carries `UNIQUE (object_key)`. | The legacy `generate-upload-url` trusted client-submitted asset metadata and used a task-agnostic key, so a client could persist an arbitrary/other-task/nonexistent key with spoofed size/type. Task-binding + `Head` (already available in `platform/r2` from 3a's finalize backstop) closes this; a "clearly-poor implementation improved during the port" per §0. (Review 2026-07-26 #2.) |
| **P4b-D11** | **Evidence retention = image-file purge at 90 days, records retained (matches the privacy policy).** The privacy policy commits to: *evidence image files are auto-deleted 90 days after the task due date*, while *task-related content (incl. evidence text/metadata) is retained anonymized*. So `sweep_evidence_objects` deletes the **R2 object** for any asset whose task `due_date` is >90 days past and sets `evidence_assets.purged_at`; it **keeps the DB rows**. `ViewForTask` returns purged assets with no `downloadUrl` and a `purged` flag; the client renders an empty/"deleted" frame. A separate orphan pass deletes **unreferenced** objects (abandoned uploads, or objects removed by update/resubmit) older than a short grace period. | The legacy sweep deleted objects by age but left the DB rows, breaking references (the public URL 404'd too) — a latent bug. Deleting the DB rows as well (data-minimization) would contradict the policy's "evidence retained anonymized." Purge-object-keep-record + graceful empty-frame is the faithful, correct implementation of the stated policy (privacy `retention.evidenceFiles`). (Review 2026-07-26 #4.) |
| **P4b-D12** | **Evidence invariants: at least one asset always; `due_date > now()` enforced on every evidence write.** Submit requires ≥1 asset; update/resubmit must not remove the last asset (reject if the result would be zero). `due_date > now()` is checked inside the submit **and** update transactions (not only at upload-URL issuance); resubmit already checks it. | Ports the legacy `validate_evidence_due_date` trigger, which fired on evidence **INSERT and UPDATE** (an upload URL minted before the deadline could otherwise be submitted after it). The ≥1-asset rule prevents a meaningless empty evidence record. (Review 2026-07-26 #5, additional.) |

## §2 Data Model

Atlas table-only for *business* logic (no business DB functions/triggers).
`updated_at` is maintained by the common `set_updated_at()` trigger (P3a-D11,
P4a-D15) — every new table carries it. FKs target the Go identity core
`users(id)` (Phase 2) and `tasks(id)` (Phase 4a). Full deletion semantics are
Phase 6 (the FKs below are `ON DELETE CASCADE` from the task, matching today).

```
evidences                          (was task_evidences)
  id           uuid PK  DEFAULT gen_random_uuid()
  task_id      uuid NOT NULL → tasks(id) ON DELETE CASCADE
  description  text NOT NULL
  created_at   timestamptz NOT NULL DEFAULT now()
  updated_at   timestamptz NOT NULL DEFAULT now()      -- set_updated_at trigger
  -- task-level: one evidence per task, shared across all referees.
  -- `evidence_status` enum dropped (P4b-D4); a row's existence == "ready".
  UNIQUE (task_id)                       -- singleton enforced (P4b-D9); 23505 → 409

evidence_assets                    (was task_evidence_assets)
  id              uuid PK  DEFAULT gen_random_uuid()
  evidence_id     uuid NOT NULL → evidences(id) ON DELETE CASCADE
  object_key      text NOT NULL          -- R2 key in the private evidence bucket
                                         -- (consolidates file_url + public_url)
                                         -- format: evidence/{due-date}/{task-id}/{uuid}.{ext} (P4b-D10)
  file_size_bytes bigint NOT NULL        -- R2-reported (from Head), not client input (P4b-D10); >0
  content_type    text   NOT NULL        -- R2-reported (from Head), re-checked against the allow-list (P4b-D10)
  purged_at       timestamptz            -- set when the 90-day sweep deletes the R2 object (P4b-D11); NULL = live
  created_at      timestamptz NOT NULL DEFAULT now()
  updated_at      timestamptz NOT NULL DEFAULT now()   -- set_updated_at trigger
  UNIQUE (object_key)                    -- (P4b-D10)
  INDEX (evidence_id)
```
**Dropped vs the legacy schema** (→ §11): `task_evidences.status` +
`evidence_status` enum; `task_evidence_assets.public_url`,
`.file_url` (→ `object_key`), `.processing_status`, `.error_message` and their
indexes.

**Multi-referee:** evidence is task-level. `submit` transitions **all** of the
task's `awaiting_evidence` judgements to `in_review`; the referee notification is
sent to every matched referee.

## §3 State Machine & Reachability (within 4b)

The judgement rows are created `awaiting_evidence` by 4a on match. 4b drives the
evidence-adjacent transitions:

```
awaiting_evidence ──(submit_evidence)──────────────▶ in_review ──(4c: judge)──▶ …
        │                                                 ▲
        │                                        (update_evidence: edit in place,
        │                                         no state change, no reopen)
        │
        └──(detect_evidence_timeouts: due_date passed, no evidence)──▶ evidence_timeout
                                                                            │
                                              (confirm_evidence_timeout)────┘ is_confirmed=true
                                                                            → 4c closure seam

rejected ──(resubmit_evidence: reopen_count<1)──▶ in_review     [DORMANT until 4c]
```

| Transition | Trigger | Reachable in 4b? |
|---|---|---|
| `awaiting_evidence → in_review` | submit_evidence | ✅ (4a produces `awaiting_evidence`) |
| in-review edit (no reopen) | update_evidence | ✅ |
| `awaiting_evidence → evidence_timeout` | `detect_evidence_timeouts` worker | ✅ |
| `evidence_timeout` + `is_confirmed=true` | confirm_evidence_timeout (tasker) | ✅ (closure is a 4c seam) |
| `rejected → in_review` (`reopen_count+1`) | resubmit_evidence | ⛔ dormant — `rejected` is produced by 4c; built now, exercised after 4c |

## §4 Phase 5 & 4c Seams

Declared on the consumer (`internal/evidence`); `main` wires no-op stubs in 4b,
real implementations later. `database.Querier` is the Phase 3a tx/pool interface
(P4a-D14).

```go
// Phase 5 — financial settlement on evidence timeout. Extends the 4a
// PointLocker family. The 4a PointLocker locked the tasker's points per request
// at publish; on evidence timeout those points are CONSUMED (not refunded) and
// the referee is REWARDED.
type EvidenceTimeoutSettler interface {
    // SettleInTx consumes the tasker's locked cost for this request and grants
    // the referee reward, keyed by requestID (== judgementID) for idempotency.
    // The 4b stub no-ops. Phase 5 writes the point/reward ledgers.
    SettleInTx(ctx context.Context, tx database.Querier, requestID uuid.UUID) error
}

// 4c — task closure after a tasker confirms a terminal judgement.
type TaskCloser interface {
    // CloseIfAllConfirmedInTx closes the task (open → closed) iff every one of
    // its judgements is confirmed. The 4b stub no-ops (task close is 4c, as in
    // 4a). Phase 4c provides the real check.
    CloseIfAllConfirmedInTx(ctx context.Context, tx database.Querier, taskID uuid.UUID) error
}
```

- 4b stubs: `EvidenceTimeoutSettler` no-ops; `TaskCloser` no-ops.
- Phase 5 / 4c: swap the wiring only; evidence code unchanged (settlement
  correlates per `requestID`; closure is a task-scoped check).

## §5 Go Structure (extends 4a / 3a)

Option E layout (`internal/<feature>/` with `domain.go` / `service.go` /
`store.go` / `handler.go`).

| Package | Role |
|---|---|
| `internal/evidence` **(new)** | `Evidence` / `EvidenceAsset` domain; service (request-upload-url; submit; update; resubmit; read-with-download-URLs; confirm-evidence-timeout); `store.go` (evidences/assets CRUD, timeout detection query); `handler.go`; **workers `detect_evidence_timeouts` + `sweep_evidence_objects`**. Declares the `EvidenceTimeoutSettler` (P5) and `TaskCloser` (4c) seams. |
| `internal/notification` (4a extended) | Adds the `notification_sent_log` dedup table + store; **worker `detect_evidence_deadline_warnings`** (tasker-facing evidence reminder); the 4b evidence notification events. Reuses the 4a `send_notification` outbox + `platform/fcm`. |
| `internal/profile` (3a extended) | Adds **worker `sweep_orphan_avatars`** (orphan avatar objects on the public bucket, using `profiles.avatar_url`). No new endpoints. |
| `platform/r2` (3a extended) | Adds `PresignGet` (authorized download URLs) and private-evidence-bucket selection alongside the existing public-avatar bucket. SDK/DTO types stop here. |

**Read integration:** the evidence read model (assets + embedded presigned
download URLs) is surfaced through 4a's `GET /tasks/{id}` and
`GET /me/assignments` detail for authorized viewers (see §6). `internal/evidence`
exposes a read method the `task`/`matching` handlers call to enrich their detail
responses (a consumer-declared seam, mirroring 4a's cross-feature composition),
keeping evidence's presign logic inside `internal/evidence`.

**Composition root** (`cmd/peppercheck` api + worker): wires the services, the
no-op Phase 5 / 4c stubs, the private evidence bucket in `platform/r2`, and
registers the new job handlers.

## §6 API Contract (`/api/v1`)

Under Phase 2 token-verify + 3a `CurrentUser` middleware; Go-layer ownership
authz; Phase 2 stable error envelope. Evidence is a task-singleton (P4b-D6).

**Tasker — evidence authoring (all under the task singleton):**
- `POST /tasks/{id}/evidence/request-upload-url` — issue a presigned PUT for the
  **private evidence bucket**. Validates: task ownership; `content_type` in the
  allow-list; `file_size_bytes` within the 5 MiB cap (best-effort, per 3a §4.6 —
  R2 enforces the signed `Content-Type`, size is a client pre-check + a `Head`
  backstop, not a hard guarantee); **`due_date > now()`** (evidence cannot be
  uploaded after the due date — ports `validate_evidence_due_date`, now a Go
  service check per baseline §4.6). The presign **signs `Content-Type`**; TTL
  600 s; **task-bound** object key `evidence/{YYYY-MM-DD from due_date}/{task-id}/{uuid}.{ext}`
  (P4b-D10). → `{ uploadUrl, objectKey, expiresIn }`.
- `PUT /tasks/{id}/evidence` — **submit**. Body `{ description, assets:
  [{ objectKey }] }` (client sends only the key; size/type come from R2). One tx:
  gate on task ownership + **`due_date > now()`** (P4b-D12) + ≥1 asset + at least
  one `awaiting_evidence` judgement; for each asset verify the **key prefix
  matches this task** and `r2.Head` succeeds, **re-check the R2-reported
  `content_type` is in the allow-list and size is >0 and ≤5 MiB**, and store the
  **R2-reported** `content_type`/`file_size_bytes` (NOT NULL; P4b-D10); insert the evidence (a `23505` on
  `UNIQUE(task_id)` → `409 conflict`, P4b-D9); transition all of the task's
  `awaiting_evidence` judgements → `in_review` — if that affects **0 rows**, roll
  the whole tx back (a concurrent `evidence_timeout` won, P4b-D9/#3); enqueue
  `notification_evidence_submitted_referee` per matched referee.
- `PATCH /tasks/{id}/evidence` — **update** (edit while `in_review`, no reopen).
  Body `{ description, assetsToAdd?[{objectKey}], assetIdsToRemove? }`. One tx:
  gate on ownership + `in_review` + **`due_date > now()`** (P4b-D12); `Head`-verify
  + prefix-check each added asset (adopt R2 metadata); apply removals/additions
  but **reject if the result would leave 0 assets** (P4b-D12); enqueue
  `notification_evidence_updated_referee`.
- `POST /tasks/{id}/evidence/resubmit` — **resubmit** after rejection
  (`rejected` && `reopen_count < 1` && `due_date > now()`). Edits evidence,
  transitions the task's `rejected` judgements → `in_review` with
  `reopen_count + 1`, enqueues `notification_evidence_resubmitted_referee`.
  **Dormant until 4c** (no `rejected` judgement exists before 4c).

**Tasker — evidence-timeout:**
- `POST /judgements/{id}/confirm-evidence-timeout` — the tasker acknowledges an
  `evidence_timeout` judgement (`is_confirmed = true`), then the 4c `TaskCloser`
  seam runs (no-op in 4b). Idempotent (already-confirmed → no-op).

**Read (extends 4a detail responses):**
- `GET /tasks/{id}` and `GET /me/assignments` detail — for authorized viewers
  (the task's **tasker** or a **matched referee**), the response includes the
  task's evidence: `{ description, assets: [{ id, contentType, fileSizeBytes,
  downloadUrl, purged }] }`, where `downloadUrl` is a **short-lived presigned
  GET** for the private bucket, generated per-read (P4b-D2). For a **purged**
  asset (`purged_at` set by the 90-day sweep, P4b-D11) `purged` is `true`,
  `downloadUrl` is omitted/null, and no presign is attempted; the client renders
  an empty/"deleted" frame. Unauthorized callers never reach this read model (403
  at the task/authz layer), so they never receive a URL.

## §7 Workers

Phase 1 leased jobs. These are subject to the issue #464 at-least-once
idempotency checklist (call it out in review, as in 4a).

| Job | Trigger | Idempotency |
|---|---|---|
| `detect_evidence_timeouts` | self-rescheduling (~5 min; bucketed idempotency key; schedules the next run first) | Per candidate, one tx: **CAS** `UPDATE judgements SET status='evidence_timeout' WHERE status='awaiting_evidence' AND <task due_date passed> AND <no evidence row>` → only on success: `EvidenceTimeoutSettler.SettleInTx` (P5 no-op) + close the referee request + enqueue `notification_evidence_timeout_tasker` / `_referee`. A row already transitioned by a concurrent run is skipped by the CAS. |
| `detect_evidence_deadline_warnings` | self-rescheduling (~1 min) | Candidate = judgement **`awaiting_evidence` with no evidence row** (legacy parity — see §8) whose task `due_date` is within one of the tasker's `evidence_reminder_minutes` offsets. Enqueue `notification_evidence_deadline_warning_tasker`. **Dedup via `notification_sent_log`** `UNIQUE (user_id, event_key, dedup_key)` (`dedup_key = task_id:offset`) so a reminder is sent at most once per (tasker, task, offset) — one reminder per task even with multiple referee judgements. |
| `send_notification` | reused from 4a | unchanged (at-least-once; duplicate push low-harm; best-effort dedup by job/notification id). |
| `sweep_evidence_objects` | self-rescheduling (daily) | **(1) 90-day purge (P4b-D11):** for each `evidence_assets` row whose task `due_date` is >90 days past and `purged_at IS NULL`, delete the R2 object and set `purged_at=now()` — **keep the DB row**. **(2) orphan pass:** delete objects under `evidence/` in the private bucket that have **no** referencing `evidence_assets.object_key` and are older than a short grace period (abandoned uploads / assets removed by update/resubmit). `dry_run` supported; deletes are idempotent. |
| `sweep_orphan_avatars` (`internal/profile`) | self-rescheduling (daily) | Delete objects under `avatar/<userId>/` in the **public bucket** that are not the user's current `profiles.avatar_url`, with a 10-minute grace period to avoid racing a fresh upload. `dry_run` supported. |

## §8 Notification Foundation (4b additions)

Reuses the 4a send path: the server emits FCM localization **keys**
(`notification_{event}_{recipient}`, `title_loc_key = key + '_title'` /
`body_loc_key = key + '_body'` + args; `.claude/rules/notification-keys.md`); the
device resolves them (client-side `loc_key`, P4a-D12). `notification_settings`
(reminder minutes) already exists from 3a — 4b adds no settings columns.

**New in 4b:**
- `notification_sent_log` table + store — reminder dedup, `UNIQUE (user_id,
  event_key, dedup_key)` (deferred from 4a §8).
- `detect_evidence_deadline_warnings` worker (§7).

**Reminder target state (clarified):** the legacy `detect_evidence_deadline_warnings`
targets **`awaiting_evidence` judgements with no evidence row** — a reminder to
submit before the deadline. `notification_settings.evidence_reminder_even_if_submitted`
exists in the schema but is **read nowhere** (not by the legacy function, not by
the client) — it is inert config. 4b ports the live behavior (awaiting + no
evidence) and records `even_if_submitted` as inert in §11; wiring it up (remind
even after submission, i.e. include `in_review`) is a deliberate future feature,
not a port (YAGNI).

**4b events:** `notification_evidence_submitted_referee`,
`notification_evidence_updated_referee`,
`notification_evidence_resubmitted_referee` (dormant until 4c),
`notification_evidence_timeout_tasker`, `notification_evidence_timeout_referee`,
`notification_evidence_deadline_warning_tasker`.

**Out of 4b (→ 4c):** review-deadline reminders (`detect_review_deadline_warnings`,
referee-facing) and auto-confirm reminders — 4c adds those jobs on the same
`notification_sent_log` foundation.

## §8.5 Operator & Post-deploy Actions (private R2 bucket)

The private evidence bucket is new infrastructure and needs operator provisioning
per environment; these are **post-deploy actions**, tracked via the
`release-checklist` skill (not code). (Review 2026-07-26 #7.)

- **Create a dedicated evidence bucket per environment** (staging, production),
  separate from the public avatar bucket.
- **Public access disabled** — no public/custom domain bound to the evidence
  bucket (evidence is only ever reached via presigned URLs).
- **Bucket-scoped credentials** — an access key/secret restricted to the evidence
  bucket, delivered through the Phase 7a file-based secret mechanism (BWS →
  Docker file-secret); the api/worker read them from `core/config` (`R2Evidence`).
  Never reuse the avatar bucket's credentials.
- **CORS** — configure CORS on the evidence bucket so browser clients can use the
  presigned URLs: allowed origins (the app/web origins), methods `GET` + `PUT`,
  and the `Content-Type` header. A presigned URL fails in a browser without CORS
  even when the signature is valid. (Native mobile HTTP does not enforce CORS, but
  the webapp and any browser preview do.) Ref: Cloudflare R2 CORS docs
  (`developers.cloudflare.com/r2/buckets/cors/`) — verify the exact JSON at setup.
- **Smoke test on staging then production** — request an upload URL, PUT a small
  image, submit evidence, read it back as an authorized viewer and confirm the
  presigned GET renders; confirm an unauthorized caller gets 403.

## §9 Testing Strategy

- **Go unit:** submit authz + state gate (only `awaiting_evidence`); update gate
  (`in_review`); resubmit gate (`rejected` && `reopen_count<1` && before due);
  upload-intent validation (content-type, size, `due_date>now`, key derivation);
  evidence-timeout candidate selection (due passed × no evidence); presigned-GET
  URL construction (correct bucket/key/TTL); `EvidenceTimeoutSettler` /
  `TaskCloser` stubs invoked with the right args.
- **Postgres integration** (real container): migrations apply to empty DB;
  constraints/indexes/FKs; `set_updated_at` present on every new table with
  `updated_at`; submit atomicity (evidence + assets + all judgements→in_review +
  notification jobs all-or-nothing); `detect_evidence_timeouts` idempotency
  (twice → one transition, one settle-seam call, one pair of notifications);
  concurrent timeout of the same judgement (CAS → exactly one wins);
  `notification_sent_log` dedup (reminder sent once); user-scoped isolation.
- **API integration** (HTTP + real Postgres + **fake R2 / fake seams**): auth
  required; ownership violations (403); upload-intent validation; submit →
  in_review + jobs enqueued; update/resubmit gates; **authorized read embeds a
  presigned GET; a non-owner/non-referee cannot read evidence (403) and receives
  no URL**; confirm-evidence-timeout idempotency; stable error envelopes.
- **Worker:** `detect_evidence_timeouts` (transition + settle-seam + close +
  notify; idempotent; skips already-transitioned); `detect_evidence_deadline_warnings`
  (reminder once via `notification_sent_log`); `sweep_evidence_objects` /
  `sweep_orphan_avatars` (age/orphan selection, grace period, `dry_run`, against
  a fake object store).
- **Characterization:** port the Phase 0 high-risk evidence fixtures (submit →
  in_review across multiple referees; evidence-timeout detection; resubmit
  reopen-once).
- **Review-2026-07-26 additions (required):** concurrent-submit → exactly one
  evidence row (`UNIQUE(task_id)` → the loser gets 409); submit with a foreign/
  nonexistent/oversized object key rejected (prefix check + `Head`); DB stores
  R2-reported metadata, not client input; submit-vs-timeout race (a submit whose
  judgements a concurrent timeout moved rolls back and creates no evidence, and
  the self-contained timeout CAS never fires once evidence exists); `due_date`
  guard rejects submit **and** update after the deadline; update/resubmit cannot
  remove the last asset; reminder dedup collides only within (user, event, task,
  offset); `sweep_evidence_objects` purges the object + sets `purged_at` but keeps
  the DB row for >90-day evidence, deletes true orphans, and never touches a
  <90-day referenced object; `ViewForTask` returns `purged=true`/no URL for a
  purged asset.
- **CI gates:** gofmt, `go vet`, unit, Postgres integration, race, Atlas
  fmt/lint, apply-to-empty-DB, schema-drift, image build.

## §10 Completion Criteria ("done")

- Via the Go API a tasker can request an evidence upload URL (private bucket),
  submit evidence (→ all `awaiting_evidence` judgements go `in_review`, referees
  notified), and update it while in review. `evidence` has no Supabase imports.
- An **authorized** viewer (tasker or matched referee) reads the task and
  receives short-lived **presigned GET** URLs for evidence assets from the
  **private** bucket; an unauthorized caller gets 403 and no URL. No public
  evidence domain is used.
- `detect_evidence_timeouts` transitions past-due evidence-less judgements to
  `evidence_timeout`, closes the referee request, notifies both parties, and
  calls the Phase 5 settlement seam (no-op in 4b); a tasker can confirm the
  timeout (task closure is the 4c seam, no-op in 4b).
- `detect_evidence_deadline_warnings` sends the tasker reminder at most once
  (`notification_sent_log`).
- `sweep_evidence_objects` (private bucket, 90-day) and `sweep_orphan_avatars`
  (public bucket, orphan + grace) run as separate feature-owned workers with
  `dry_run`.
- Resubmit is implemented but dormant until 4c; point/reward settlement and task
  closure are interface seams with no-op stubs.
- `detect_evidence_timeouts` / `detect_evidence_deadline_warnings` / sweeps are
  safe under at-least-once (#464).
- All tests green; CI gates pass; api/worker shut down cleanly (Phase 1
  lifecycle).
- Flutter is a separate follow-on spec (not in this "done").

## §11 Follow-ups

**Dropped in 4b (removed dead / no-op schema):**

| Item | Why dropped | If revived |
|------|-------------|-----------|
| `evidence_status` enum (`pending_upload` / `ready`) + `task_evidences.status` | `pending_upload` never persisted — the client uploads to R2 first, then submits metadata, which inserted `ready` directly. A row's existence *is* "ready". | Re-add a status column if a server-tracked two-phase upload-intent (record intent → confirm) is ever built. |
| `task_evidence_assets.public_url` | The public-domain URL is the launch-blocker being removed; downloads are now authorized presigned GETs generated per-read. | n/a (public delivery of evidence is the anti-goal). |
| `task_evidence_assets.file_url` | Consolidated into `object_key` (the R2 key is the only durable reference needed). | n/a. |
| `task_evidence_assets.processing_status` / `.error_message` | Reserved for a server-side image pipeline that was never built; normalization is client-side (`ImageNormalizer`). | Re-add if a server-side processing/derivative pipeline is introduced. |
| Single shared `sweep-r2-stale-objects` cron | Split into two feature-owned workers (P4b-D7). | n/a (the split is the improvement). |

**Deferred / seams to resolve later:**

| Item | Notes |
|------|-------|
| **Resubmit dormancy** | Built in 4b but not reachable until 4c produces `rejected`. 4c must include a resubmit → judge round-trip in its tests. |
| **Phase 5 `EvidenceTimeoutSettler`** | 4b no-ops the consume/reward. Phase 5 wires the real point-consume + referee-reward ledgers, keyed by `requestID`. |
| **4c `TaskCloser`** | 4b no-ops task closure on confirm. 4c provides the all-judgements-confirmed close (shared with the rest of the judgement lifecycle). |
| **Reminder settings read/update endpoints** | `notification_settings.*_reminder_minutes` are consumed by 4b's worker but have no read/update endpoint yet (deferred by 3a to "whenever that UI migrates"). |
| **Best-effort size cap** | The 5 MiB cap remains best-effort (3a §4.6): client pre-check + `Head` backstop + sweep; a hard cap would need a Go-API proxy, deliberately avoided. Note 4b's `Head`-at-submit now enforces the cap at persist time (reject oversize), so the cap is stronger than 3a's avatar path. |
| **Flutter cache keying + purged frames** | With private downloads, `downloadUrl` changes per-read; the Flutter spec must key its image cache by `object_key` / asset id, not URL, and render an empty/"deleted" frame for `purged=true` assets (P4b-D11). Recorded for the 4b Flutter spec. |
| **`evidence_reminder_even_if_submitted` is inert** | Defined in `notification_settings` (3a) but read nowhere; 4b ports the live behavior only (remind while `awaiting_evidence`, no evidence). Wiring "remind even after submission" (include `in_review`) is a future feature, not a port. |
| **Evidence retention reconciled to policy** | P4b-D11 implements the privacy policy (`retention.evidenceFiles`): purge image files 90 days after due date, keep records. If the policy's retention window or scope changes, update the sweep's cutoff + the purged-frame copy together. |
```
