# Phase 4b Backend — Evidence & Private R2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement, in Go, the task evidence lifecycle (upload intents, submit/update/resubmit, evidence-timeout) and authorized presigned downloads from a **private** R2 bucket, plus evidence deadline reminders and R2 stale-object hygiene — with no Supabase dependency.

**Architecture:** A new `internal/evidence` feature package (Option E layout: `domain.go`/`store.go`/`service.go`/`handler.go`/`worker.go` + `seams.go`). Evidence is task-level (one evidence per task, shared across referees); submitting transitions all of a task's `awaiting_evidence` judgements to `in_review` in one transaction and enqueues per-referee notifications via the Phase 4a `send_notification` outbox. Downloads use presigned **GET** URLs the Go API generates per-read after authorization and embeds in the task-detail read model. Point/reward settlement on evidence-timeout (Phase 5) and task closure on confirm (Phase 4c) are consumer-declared Go interface seams with no-op stubs. `platform/r2` is extended for a second (private) bucket + `PresignGet` + `List`. Two feature-owned sweep workers replace the legacy single R2 cron.

**Tech Stack:** Go 1.26, `database/sql` + pgx driver, `net/http` + `ServeMux`, Atlas (table-only schema), AWS S3 SDK for R2 (in `platform/r2` only), durable-jobs primitive (`internal/core/jobs`), FCM send path (`internal/notification` + `platform/fcm`, from 4a).

## Global Constraints

- **Do NOT execute this plan now.** The current working branch is mid-Phase-7. Execute later on a dedicated `feat/phase4b-evidence-private-r2` branch cut from `refactor/go-api-vps`, **after Phases 3a, 4a, and 4c-or-its-seam-consumers are considered.** Precisely: 4b depends on 4a (task/matching/judgement/notification packages) and 3a (`platform/r2`, `notification_settings`, `CurrentUser`). It does **not** require 4c to be merged — 4c/Phase-5 arrive as wiring swaps. The commit steps below are for that execution session.
- **Design source of truth:** `docs/designs/2026-07-26-phase4b-evidence-private-r2-design.md`. Read it before starting.
- **Depends on prior phases (assume merged at execution — verify exact symbol names/locations and adjust imports):**
  - Phase 2: `httpserver` stable error envelope + codes (`CodeNotFound`/`CodeForbidden`/`CodeValidation`/`CodeConflict`) + `httpserver.DecodeJSON`; Firebase token-verify middleware.
  - Phase 3a: `internal/platform/r2` with `Uploader { PresignPut; Head; Delete }`, `PresignPutInput`, `ObjectMetadata`; `identity.CurrentUserFrom(ctx) (identity.User, bool)` (the CurrentUser middleware); `public.profiles(timezone)`; `public.notification_settings(evidence_reminder_minutes int[] NOT NULL DEFAULT '{10}', evidence_reminder_even_if_submitted boolean NOT NULL DEFAULT false)`; the Go-maintained `updated_at` Store convention.
  - Phase 4a: `public.tasks(id, tasker_id, due_date, status, title)`, `public.referee_requests(id, task_id, matched_referee_id, status)`, `public.judgements(id, status, is_confirmed, reopen_count)` (created `awaiting_evidence` on match); `internal/task`, `internal/matching`, `internal/judgement`, `internal/notification` (with `Enqueue(tx, userID, keyBase, args, data)` outbox + `send_notification` worker + `platform/fcm`); `database.Querier` (tx/pool interface); `database.WithTx`; `jobs.Store.Enqueue` + `jobs.Store.EnqueueInTx`; `worker.Register(kind, Handler)`.
- **Schema is table-only with no functions or triggers initially.** Inserts use
  `DEFAULT now()`; every mutable Store `UPDATE` and `ON CONFLICT DO UPDATE`
  explicitly sets `updated_at = now()`. Use the pinned Atlas (Standard
  distribution, no login).
- **FKs target the identity core.** `evidences.task_id → tasks(id) ON DELETE CASCADE`; `evidence_assets.evidence_id → evidences(id) ON DELETE CASCADE`. Full deletion saga is Phase 6.
- **Evidence bucket is PRIVATE and SEPARATE.** Avatars stay on the existing public bucket (3a unchanged). Never build a public URL for evidence; downloads are always presigned GET.
- **English only** in all committed content (code, comments, tests, docs, log strings). Conventional Commits (`feat(backend): …`).
- **All layers provider-neutral except `platform/r2`** (AWS S3 SDK types stop there) and `platform/fcm` (from 4a).
- **Consult official docs at implementation time** (standing rule) for: AWS S3 SDK for Go v2 presign GET (`s3.PresignClient.PresignGetObject`) and `ListObjectsV2` pagination. Do not code these from memory.
- **Idempotency (#464):** `detect_evidence_timeouts`, `detect_evidence_deadline_warnings`, `sweep_evidence_objects`, and `sweep_orphan_avatars` must be safe under at-least-once execution. Reminder dedup uses `notification_sent_log`; sweeps are idempotent because deletes are idempotent.
- **Naming (from spec):** table `evidences` (drop `task_` prefix), `evidence_assets`; API singleton `/tasks/{id}/evidence` (singular); asset column `object_key`.
- **Content-type allow-list & size cap (port from `generate-upload-url`):** `image/jpeg`, `image/png`, `image/webp`, `image/gif`, `image/heic`, `image/heif`; 5 MiB cap (best-effort per 3a §4.6); presign PUT TTL 600 s; presign GET TTL 900 s.
- Every task: `gofmt`, `go vet`, `go test ./...` must pass before commit. Integration tests use `internal/testsupport` and skip without `DATABASE_URL`.

---

## File Structure

**New files**
- `internal/evidence/domain.go` — `Evidence`, `EvidenceAsset`, `EvidenceView`, `AssetView`, input structs, errors.
- `internal/evidence/seams.go` — `EvidenceTimeoutSettler`, `TaskCloser` interfaces + `NoopSettler`, `NoopTaskCloser`.
- `internal/evidence/store.go` — `Store` (evidences/assets CRUD, judgement transitions, timeout-detection query, deadline-warning query).
- `internal/evidence/service.go` — `Service` (RequestUploadURL, Submit, Update, Resubmit, ViewForTask, ConfirmEvidenceTimeout).
- `internal/evidence/handler.go` — `Handler` (HTTP).
- `internal/evidence/worker.go` — `detect_evidence_timeouts`, `sweep_evidence_objects` job handlers.
- `internal/evidence/*_test.go`, plus `internal/evidence/store_test.go` (integration).
- `internal/evidence/fakes_test.go` — a fake `r2.Uploader` test double used across the service/worker tests: seed objects with `Put(key, contentType string, size int64)`; `Head` returns the seeded metadata (or not-found error for unseeded keys); `PresignGet`/`PresignPut` return `"signed:"+key`; `List(prefix)` / `Delete(key)` / `exists(key)` back the sweep tests. Fixture helpers (`seedTaskWithTwoAwaitingJudgements`, etc.) expose it as `fx.FakeR2`.

**Modified files**
- `internal/platform/r2/r2.go` — add `PresignGet`, `List`; support the private bucket.
- `internal/notification/store.go` — add `notification_sent_log` dedup methods.
- `internal/notification/worker.go` — add `detect_evidence_deadline_warnings` handler (or `internal/notification/reminder_worker.go`).
- `internal/profile/worker.go` (new file in the 3a package) — `sweep_orphan_avatars` handler.
- `internal/task/handler.go` (+ `internal/matching/handler.go`) — embed the evidence view in task-detail / assignment-detail responses via an injected reader.
- `internal/api/api.go` — extend `Deps` + register evidence routes.
- `internal/worker/worker.go` — register the four new job handlers + schedule the self-rescheduling ones.
- `cmd/peppercheck/main.go` — construct the private-evidence `r2.Uploader`, wire `evidence.Service` with no-op stubs, inject the evidence reader into `task`/`matching`.
- Atlas schema dir — `evidences`, `evidence_assets`, `notification_sent_log`
  tables, constraints, and indexes.

---

## Task 1: Schema — `evidences`, `evidence_assets`, `notification_sent_log`

**Files:**
- Create/modify: Atlas schema files for the three tables (follow the established 4a/3a schema-file layout; verify the exact dir at execution).
- Test: `internal/evidence/schema_test.go` (integration; skip w/o `DATABASE_URL`).

**Interfaces:**
- Produces (DB): tables `public.evidences`, `public.evidence_assets`,
  `public.notification_sent_log`; mutable Store paths explicitly maintain the
  first two tables' `updated_at` columns.

- [ ] **Step 1: Write the failing integration test asserting the tables exist**

```go
// internal/evidence/schema_test.go
package evidence_test

import (
	"context"
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
)

func TestSchema_EvidenceTables(t *testing.T) {
	db := testsupport.DB(t) // skips without DATABASE_URL
	ctx := context.Background()

	for _, tbl := range []string{"evidences", "evidence_assets", "notification_sent_log"} {
		var exists bool
		err := db.QueryRowContext(ctx,
			`SELECT EXISTS (SELECT 1 FROM information_schema.tables
			 WHERE table_schema='public' AND table_name=$1)`, tbl).Scan(&exists)
		if err != nil {
			t.Fatalf("query %s: %v", tbl, err)
		}
		if !exists {
			t.Fatalf("table public.%s does not exist", tbl)
		}
	}
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `DATABASE_URL=... go test ./internal/evidence/ -run TestSchema_EvidenceTables -v`
Expected: FAIL (tables do not exist).

- [ ] **Step 3: Add the Atlas schema** (table-only; no functions or triggers)

```sql
-- evidences: one evidence per task, shared across referees.
-- UNIQUE(task_id) enforces the singleton at the DB layer (P4b-D9).
CREATE TABLE public.evidences (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id     uuid NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    description text NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    UNIQUE (task_id)
);

-- evidence_assets: R2 object references (private bucket). object_key only.
-- object_key format: evidence/{due-date}/{task-id}/{uuid}.{ext} (P4b-D10).
-- purged_at set when the 90-day sweep deletes the R2 object (P4b-D11); row kept.
CREATE TABLE public.evidence_assets (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    evidence_id     uuid NOT NULL REFERENCES public.evidences(id) ON DELETE CASCADE,
    object_key      text NOT NULL,
    file_size_bytes bigint NOT NULL,   -- R2-reported (Head), not client input; >0
    content_type    text   NOT NULL,   -- R2-reported (Head), allow-list re-checked
    purged_at       timestamptz,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    UNIQUE (object_key)
);
CREATE INDEX idx_evidence_assets_evidence_id ON public.evidence_assets (evidence_id);

-- notification_sent_log: dedup for reminder notifications (at-most-once).
-- UNIQUE includes user_id (P4b-D6 / review #6): one per (user, event, dedup_key).
CREATE TABLE public.notification_sent_log (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    event_key    text NOT NULL,
    dedup_key    text NOT NULL,   -- e.g. "{task_id}:{offset_minutes}"
    created_at   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, event_key, dedup_key)
);
```

Generate the migration with the pinned Atlas per the repo workflow (verify at execution).

- [ ] **Step 4: Apply to an empty DB and run the test to verify it passes**

Run: `DATABASE_URL=... go test ./internal/evidence/ -run TestSchema_EvidenceTables -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/evidence/schema_test.go <atlas schema + migration paths>
git commit -m "feat(backend): evidence + notification_sent_log schema (Phase 4b)"
```

---

## Task 2: `platform/r2` — `PresignGet`, `List`, private bucket

**Files:**
- Modify: `internal/platform/r2/r2.go`
- Test: `internal/platform/r2/r2_test.go`

**Interfaces:**
- Consumes: 3a `Uploader { PresignPut; Head; Delete }`, `PresignPutInput`, `ObjectMetadata`.
- Produces:
  - `type PresignGetInput struct { Key string; ExpiresIn time.Duration }`
  - `type ObjectInfo struct { Key string; LastModified time.Time; Size int64 }`
  - extend `Uploader`: `PresignGet(ctx, PresignGetInput) (string, error)` and `List(ctx, prefix string) ([]ObjectInfo, error)`
  - construction unchanged in shape; a second instance is built for the private evidence bucket in `main` (Task 16).

- [ ] **Step 1: Write the failing test for `PresignGet` URL shape**

```go
// internal/platform/r2/r2_test.go (add)
func TestPresignGet_ProducesSignedURLForKey(t *testing.T) {
	u := newTestUploader(t) // existing helper from 3a tests; static test creds, bucket "evidence-priv"
	url, err := u.PresignGet(context.Background(), r2.PresignGetInput{
		Key:       "evidence/2026-07-26/abc.jpg",
		ExpiresIn: 900 * time.Second,
	})
	if err != nil {
		t.Fatalf("PresignGet: %v", err)
	}
	if !strings.Contains(url, "evidence/2026-07-26/abc.jpg") {
		t.Fatalf("url missing key: %s", url)
	}
	for _, marker := range []string{"X-Amz-Signature", "X-Amz-Expires"} {
		if !strings.Contains(url, marker) {
			t.Fatalf("url missing %s: %s", marker, url)
		}
	}
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `go test ./internal/platform/r2/ -run TestPresignGet -v`
Expected: FAIL (`PresignGet` undefined).

- [ ] **Step 3: Implement `PresignGet` and `List`** (consult the AWS S3 SDK v2 presign + ListObjectsV2 docs)

```go
// internal/platform/r2/r2.go (add to the existing uploader)
type PresignGetInput struct {
	Key       string
	ExpiresIn time.Duration
}

type ObjectInfo struct {
	Key          string
	LastModified time.Time
	Size         int64
}

func (u *uploader) PresignGet(ctx context.Context, in PresignGetInput) (string, error) {
	req, err := u.presign.PresignGetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(u.bucket),
		Key:    aws.String(in.Key),
	}, s3.WithPresignExpires(in.ExpiresIn))
	if err != nil {
		return "", fmt.Errorf("presign get: %w", err)
	}
	return req.URL, nil
}

func (u *uploader) List(ctx context.Context, prefix string) ([]ObjectInfo, error) {
	var out []ObjectInfo
	p := s3.NewListObjectsV2Paginator(u.client, &s3.ListObjectsV2Input{
		Bucket: aws.String(u.bucket),
		Prefix: aws.String(prefix),
	})
	for p.HasMorePages() {
		page, err := p.NextPage(ctx)
		if err != nil {
			return nil, fmt.Errorf("list objects: %w", err)
		}
		for _, o := range page.Contents {
			out = append(out, ObjectInfo{
				Key:          aws.ToString(o.Key),
				LastModified: aws.ToTime(o.LastModified),
				Size:         aws.ToInt64(o.Size),
			})
		}
	}
	return out, nil
}
```

Add both methods to the `Uploader` interface.

- [ ] **Step 4: Run to verify it passes**

Run: `go test ./internal/platform/r2/ -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/platform/r2/
git commit -m "feat(backend): r2 PresignGet + List for private evidence bucket (Phase 4b)"
```

---

## Task 3: `evidence` domain, seams, and no-op stubs

**Files:**
- Create: `internal/evidence/domain.go`, `internal/evidence/seams.go`
- Test: `internal/evidence/seams_test.go`

**Interfaces:**
- Produces:
  - `Evidence{ ID, TaskID uuid.UUID; Description string; CreatedAt, UpdatedAt time.Time; Assets []EvidenceAsset }`
  - `EvidenceAsset{ ID, EvidenceID uuid.UUID; ObjectKey string; FileSizeBytes int64; ContentType string; PurgedAt *time.Time; CreatedAt, UpdatedAt time.Time }` (size/type NOT NULL — R2-verified)
  - `AssetInput{ ObjectKey string }` — **client sends only the key** (P4b-D10); size/content-type are read from R2 `Head` at submit and stored server-side, never trusted from the client.
  - `SubmitInput{ Description string; Assets []AssetInput }`
  - `UpdateInput{ Description string; AssetsToAdd []AssetInput; AssetIDsToRemove []uuid.UUID }` (Resubmit reuses this shape as `ResubmitInput = UpdateInput`)
  - `EvidenceView{ Description string; Assets []AssetView }`, `AssetView{ ID uuid.UUID; ContentType string; FileSizeBytes int64; DownloadURL string; Purged bool }` (purged → `DownloadURL` empty, `Purged` true)
  - errors: `ErrNotFound`, `ErrForbidden`, `ErrInvalidState`, `ErrValidation`, `ErrConflict` (singleton/object-key collision, submit-vs-timeout race)
  - `type EvidenceTimeoutSettler interface { SettleInTx(ctx context.Context, tx database.Querier, requestID uuid.UUID) error }`
  - `type TaskCloser interface { CloseIfAllConfirmedInTx(ctx context.Context, tx database.Querier, taskID uuid.UUID) error }`
  - `type NoopSettler struct{}` and `type NoopTaskCloser struct{}` implementing the above with `return nil`.

- [ ] **Step 1: Write the failing test for the no-op stubs**

```go
// internal/evidence/seams_test.go
package evidence_test

import (
	"context"
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/evidence"
	"github.com/google/uuid"
)

func TestNoopStubs_ReturnNil(t *testing.T) {
	if err := (evidence.NoopSettler{}).SettleInTx(context.Background(), nil, uuid.New()); err != nil {
		t.Fatalf("NoopSettler: %v", err)
	}
	if err := (evidence.NoopTaskCloser{}).CloseIfAllConfirmedInTx(context.Background(), nil, uuid.New()); err != nil {
		t.Fatalf("NoopTaskCloser: %v", err)
	}
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `go test ./internal/evidence/ -run TestNoopStubs -v`
Expected: FAIL (package/types undefined).

- [ ] **Step 3: Write `domain.go` and `seams.go`**

```go
// internal/evidence/seams.go
package evidence

import (
	"context"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
	"github.com/google/uuid"
)

type EvidenceTimeoutSettler interface {
	SettleInTx(ctx context.Context, tx database.Querier, requestID uuid.UUID) error
}
type TaskCloser interface {
	CloseIfAllConfirmedInTx(ctx context.Context, tx database.Querier, taskID uuid.UUID) error
}

type NoopSettler struct{}

func (NoopSettler) SettleInTx(context.Context, database.Querier, uuid.UUID) error { return nil }

type NoopTaskCloser struct{}

func (NoopTaskCloser) CloseIfAllConfirmedInTx(context.Context, database.Querier, uuid.UUID) error {
	return nil
}
```

Write `domain.go` with the structs, `AssetInput`/`SubmitInput`/`UpdateInput`/`EvidenceView`/`AssetView`, and sentinel errors (`errors.New`).

- [ ] **Step 4: Run to verify it passes**

Run: `go test ./internal/evidence/ -run TestNoopStubs -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/evidence/domain.go internal/evidence/seams.go internal/evidence/seams_test.go
git commit -m "feat(backend): evidence domain + Phase5/4c seams with no-op stubs"
```

---

## Task 4: `evidence` store — CRUD, judgement transitions, detection queries

**Files:**
- Create: `internal/evidence/store.go`
- Test: `internal/evidence/store_test.go` (integration; skip w/o `DATABASE_URL`)

**Interfaces:**
- Consumes: `database.Querier`, `database.WithTx`.
- Produces `Store` with (all take `database.Querier` so they compose in a tx):
  - `InsertEvidenceInTx(ctx, q, taskID uuid.UUID, description string) (uuid.UUID, error)`
  - `InsertAssetInTx(ctx, q, evidenceID uuid.UUID, objectKey, contentType string, sizeBytes int64) error` — inserts an asset with the **R2-verified** metadata (from `Head`, not client input). A `23505` on `UNIQUE(object_key)` surfaces as `ErrConflict` for the service to map.
  - `DeleteAssetsInTx(ctx, q, evidenceID uuid.UUID, ids []uuid.UUID) error`
  - `UpdateEvidenceDescriptionInTx(ctx, q, evidenceID uuid.UUID, description string) error`
  - `EvidenceByTask(ctx, q, taskID uuid.UUID) (*Evidence, error)` (with assets; `ErrNotFound` if none)
  - `TransitionAwaitingToInReviewInTx(ctx, q, taskID uuid.UUID) (refereeIDs []uuid.UUID, err error)` — sets every `awaiting_evidence` judgement of the task to `in_review`, returns the matched referee ids for notification.
  - `TransitionRejectedToInReviewInTx(ctx, q, taskID uuid.UUID) (refereeIDs []uuid.UUID, err error)` — sets the task's `rejected` judgements (`reopen_count < 1`) to `in_review`, `reopen_count+1`.
  - `TaskForEvidence(ctx, q, taskID uuid.UUID) (taskerID uuid.UUID, dueDate time.Time, err error)` (from `tasks`; `ErrNotFound` if missing).
  - `TaskTitle(ctx, q, taskID uuid.UUID) (string, error)` — task title for notification args.
  - `HasAwaitingEvidenceJudgement(ctx, q, taskID uuid.UUID) (bool, error)`
  - `HasInReviewJudgement` / `HasRejectedReopenableJudgement` (analogous gates).
  - `MatchedRefereeIDs(ctx, q, taskID uuid.UUID) ([]uuid.UUID, error)`
  - `IsTaskViewer(ctx, q, taskID, userID uuid.UUID) (bool, error)` — true if `userID` is the tasker or a matched referee.
  - `TimeoutCandidates(ctx, q) ([]TimeoutCandidate, error)` — judgements `awaiting_evidence` whose task `due_date < now()` and the task has **no** evidence row. `TimeoutCandidate{ JudgementID, RequestID, TaskID, TaskerID, RefereeID uuid.UUID; TaskTitle string }` (JudgementID == RequestID == referee_requests.id).
  - `MarkEvidenceTimeoutInTx(ctx, q, judgementID uuid.UUID) (bool, error)` — **self-contained CAS** (review #3): transitions only when the judgement is still `awaiting_evidence` **and** its task `due_date < now()` **and** the task has **no** evidence row; returns whether a row changed. A candidate that received a submit between the candidate query and this call does not fire.
  - `CloseRefereeRequestInTx(ctx, q, requestID uuid.UUID) error` — `UPDATE referee_requests SET status='closed', updated_at=now() WHERE id=$1`.
  - `ConfirmEvidenceTimeoutInTx(ctx, q, judgementID, taskerID uuid.UUID) (taskID uuid.UUID, changed bool, err error)` — sets `is_confirmed=true` where the judgement is `evidence_timeout`, not yet confirmed, and the task's `tasker_id=$2`; returns the task id + whether it changed (idempotent: already-confirmed → `changed=false`, no error).
  - `DeadlineWarningCandidates(ctx, q, now time.Time) ([]DeadlineWarningCandidate, error)` — see Task 13.
  - `PurgeCandidates(ctx, q, cutoff time.Time) ([]PurgeCandidate, error)` — `PurgeCandidate{ AssetID uuid.UUID; ObjectKey string }` for `evidence_assets` whose task `due_date < cutoff` and `purged_at IS NULL` (Task 14).
  - `MarkAssetPurgedInTx(ctx, q, assetID uuid.UUID) error` — set `purged_at = now(), updated_at = now()`.
  - `AllReferencedObjectKeys(ctx, q) (map[string]struct{}, error)` — every live `evidence_assets.object_key` (for orphan detection, Task 14).

- [ ] **Step 1: Write the failing integration test for submit-path transition**

```go
// internal/evidence/store_test.go
func TestStore_TransitionAwaitingToInReview_AllRefereesOneTask(t *testing.T) {
	db := testsupport.DB(t)
	ctx := context.Background()
	st := evidence.NewStore()

	// seed: 1 task, 2 matched referees, 2 awaiting_evidence judgements
	fx := seedTaskWithTwoAwaitingJudgements(t, db) // helper: returns taskID + refereeIDs

	var refs []uuid.UUID
	err := database.WithTx(ctx, db, func(q database.Querier) error {
		var e error
		refs, e = st.TransitionAwaitingToInReviewInTx(ctx, q, fx.TaskID)
		return e
	})
	if err != nil {
		t.Fatalf("transition: %v", err)
	}
	if len(refs) != 2 {
		t.Fatalf("expected 2 referee ids, got %d", len(refs))
	}
	// both judgements now in_review
	var n int
	db.QueryRowContext(ctx,
		`SELECT count(*) FROM judgements j JOIN referee_requests r ON r.id=j.id
		 WHERE r.task_id=$1 AND j.status='in_review'`, fx.TaskID).Scan(&n)
	if n != 2 {
		t.Fatalf("expected 2 in_review, got %d", n)
	}
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `DATABASE_URL=... go test ./internal/evidence/ -run TestStore_Transition -v`
Expected: FAIL (`NewStore`/method undefined).

- [ ] **Step 3: Implement `store.go`**

Representative load-bearing methods (write all listed above following these patterns):

```go
// internal/evidence/store.go
package evidence

import (
	"context"
	"database/sql"
	"errors"
	"time"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
	"github.com/google/uuid"
	"github.com/lib/pq" // or pgx array support already used in 4a; match the repo
)

type Store struct{}

func NewStore() *Store { return &Store{} }

func (s *Store) TransitionAwaitingToInReviewInTx(ctx context.Context, q database.Querier, taskID uuid.UUID) ([]uuid.UUID, error) {
	rows, err := q.QueryContext(ctx, `
		UPDATE judgements j
		SET status='in_review', updated_at=now()
		FROM referee_requests r
		WHERE j.id=r.id AND r.task_id=$1 AND j.status='awaiting_evidence'
		RETURNING r.matched_referee_id`, taskID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var ids []uuid.UUID
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}

// Self-contained CAS (review #3): re-checks due_date + no-evidence inside the
// UPDATE so a submit landing after the candidate query cannot be timed out.
func (s *Store) MarkEvidenceTimeoutInTx(ctx context.Context, q database.Querier, judgementID uuid.UUID) (bool, error) {
	res, err := q.ExecContext(ctx, `
		UPDATE judgements j
		SET status='evidence_timeout', updated_at=now()
		FROM referee_requests r
		JOIN tasks t ON t.id=r.task_id
		WHERE j.id=r.id AND j.id=$1 AND j.status='awaiting_evidence'
		  AND now() > t.due_date
		  AND NOT EXISTS (SELECT 1 FROM evidences e WHERE e.task_id=t.id)`, judgementID)
	if err != nil {
		return false, err
	}
	n, _ := res.RowsAffected()
	return n > 0, nil
}

func (s *Store) ConfirmEvidenceTimeoutInTx(ctx context.Context, q database.Querier, judgementID, taskerID uuid.UUID) (uuid.UUID, bool, error) {
	var taskID uuid.UUID
	err := q.QueryRowContext(ctx, `
		UPDATE judgements j
		SET is_confirmed=true, updated_at=now()
		FROM referee_requests r JOIN tasks t ON t.id=r.task_id
		WHERE j.id=r.id AND j.id=$1 AND t.tasker_id=$2
		  AND j.status='evidence_timeout' AND j.is_confirmed=false
		RETURNING t.id`, judgementID, taskerID).Scan(&taskID)
	if errors.Is(err, sql.ErrNoRows) {
		// Either not found / not owner / wrong state, OR already confirmed (idempotent).
		// Distinguish already-confirmed to keep confirm idempotent:
		var alreadyTask uuid.UUID
		e2 := q.QueryRowContext(ctx, `
			SELECT t.id FROM judgements j
			JOIN referee_requests r ON r.id=j.id JOIN tasks t ON t.id=r.task_id
			WHERE j.id=$1 AND t.tasker_id=$2 AND j.status='evidence_timeout' AND j.is_confirmed=true`,
			judgementID, taskerID).Scan(&alreadyTask)
		if e2 == nil {
			return alreadyTask, false, nil // already confirmed → no-op
		}
		return uuid.Nil, false, ErrInvalidState
	}
	if err != nil {
		return uuid.Nil, false, err
	}
	return taskID, true, nil
}

func (s *Store) TimeoutCandidates(ctx context.Context, q database.Querier) ([]TimeoutCandidate, error) {
	rows, err := q.QueryContext(ctx, `
		SELECT j.id, r.task_id, t.tasker_id, r.matched_referee_id, t.title
		FROM judgements j
		JOIN referee_requests r ON r.id=j.id
		JOIN tasks t ON t.id=r.task_id
		LEFT JOIN evidences e ON e.task_id=t.id
		WHERE j.status='awaiting_evidence' AND now() > t.due_date AND e.id IS NULL`)
	// scan into []TimeoutCandidate ...
}
```

Implement the remaining methods (`InsertEvidenceInTx`, `InsertAssetInTx`, `DeleteAssetsInTx` scoped by `evidence_id`, `UpdateEvidenceDescriptionInTx`, `EvidenceByTask` with an assets join, `TransitionRejectedToInReviewInTx` with `reopen_count=reopen_count+1 WHERE status='rejected' AND reopen_count<1`, `TaskForEvidence`, the `Has*Judgement` gates, `MatchedRefereeIDs`, `IsTaskViewer`, `CloseRefereeRequestInTx`).

- [ ] **Step 4: Run to verify it passes**

Run: `DATABASE_URL=... go test ./internal/evidence/ -run TestStore -v`
Expected: PASS.

- [ ] **Step 5: Add + run tests for the timeout CAS and confirm idempotency**

```go
func TestStore_MarkEvidenceTimeout_CASOnceThenNoop(t *testing.T) { /* first call true, second false */ }
func TestStore_ConfirmEvidenceTimeout_Idempotent(t *testing.T)    { /* changed=true then changed=false, no err */ }
func TestStore_ConfirmEvidenceTimeout_WrongOwner(t *testing.T)    { /* ErrInvalidState */ }
```

Run: `DATABASE_URL=... go test ./internal/evidence/ -run TestStore -v` → PASS.

- [ ] **Step 6: Commit**

```bash
git add internal/evidence/store.go internal/evidence/store_test.go
git commit -m "feat(backend): evidence store (CRUD, judgement transitions, timeout detection)"
```

---

## Task 5: `evidence` service — `RequestUploadURL`

**Files:**
- Create: `internal/evidence/service.go` (add the `Service` struct + this method)
- Test: `internal/evidence/service_test.go`

**Interfaces:**
- Consumes: `r2.Uploader` (private-evidence instance), `*Store`, `*sql.DB`, `EvidenceTimeoutSettler`, `TaskCloser`, `notification` enqueuer (Task 6), a clock `func() time.Time` (injectable for tests).
- Produces:
  - `type Service struct { … }` + `func NewService(...) *Service`
  - `type UploadIntentInput struct { Filename, ContentType string; FileSizeBytes int64 }`
  - `type UploadIntent struct { UploadURL, ObjectKey string; ExpiresIn int }`
  - `RequestUploadURL(ctx, taskerID, taskID uuid.UUID, in UploadIntentInput) (UploadIntent, error)`
- Key rule (port `generate-upload-url`): validate content-type allow-list + extension match + 5 MiB cap + task ownership + `due_date > now()`; object key `evidence/{due_date as YYYY-MM-DD}/{uuid}.{ext}`.

- [ ] **Step 1: Write failing tests (table-driven) for validation + key derivation**

```go
func TestRequestUploadURL_RejectsBadContentType(t *testing.T) {
	svc, _ := newServiceWithFakes(t) // fake uploader records PresignPut input
	_, err := svc.RequestUploadURL(ctx, taskerID, taskID, evidence.UploadIntentInput{
		Filename: "x.txt", ContentType: "text/plain", FileSizeBytes: 100,
	})
	if !errors.Is(err, evidence.ErrValidation) {
		t.Fatalf("want ErrValidation, got %v", err)
	}
}

func TestRequestUploadURL_DerivesDateKeyFromDueDate(t *testing.T) {
	svc, fake := newServiceWithFakes(t) // task due 2026-08-01
	out, err := svc.RequestUploadURL(ctx, taskerID, taskID, evidence.UploadIntentInput{
		Filename: "p.jpg", ContentType: "image/jpeg", FileSizeBytes: 1024,
	})
	if err != nil { t.Fatal(err) }
	wantPrefix := "evidence/2026-08-01/" + taskID.String() + "/"
	if !strings.HasPrefix(out.ObjectKey, wantPrefix) || !strings.HasSuffix(out.ObjectKey, ".jpg") {
		t.Fatalf("bad key: %s (want prefix %s)", out.ObjectKey, wantPrefix)
	}
	if fake.lastPut.Key != out.ObjectKey { t.Fatal("presign key mismatch") }
}

func TestRequestUploadURL_RejectsPastDueDate(t *testing.T)   { /* due in the past → ErrValidation */ }
func TestRequestUploadURL_RejectsNonOwner(t *testing.T)      { /* ErrForbidden */ }
func TestRequestUploadURL_RejectsOversize(t *testing.T)      { /* >5 MiB → ErrValidation */ }
```

- [ ] **Step 2: Run to verify they fail**

Run: `go test ./internal/evidence/ -run TestRequestUploadURL -v`
Expected: FAIL.

- [ ] **Step 3: Implement `RequestUploadURL`**

```go
var allowedContentExt = map[string][]string{
	"image/jpeg": {"jpg", "jpeg"}, "image/png": {"png"}, "image/webp": {"webp"},
	"image/gif": {"gif"}, "image/heic": {"heic"}, "image/heif": {"heif"},
}

const maxEvidenceBytes = 5 * 1024 * 1024
const uploadTTL = 600 * time.Second

func (s *Service) RequestUploadURL(ctx context.Context, taskerID, taskID uuid.UUID, in UploadIntentInput) (UploadIntent, error) {
	exts, ok := allowedContentExt[in.ContentType]
	if !ok {
		return UploadIntent{}, fmt.Errorf("%w: content_type %q", ErrValidation, in.ContentType)
	}
	ext := strings.ToLower(path.Ext(in.Filename))
	ext = strings.TrimPrefix(ext, ".")
	if !slices.Contains(exts, ext) {
		return UploadIntent{}, fmt.Errorf("%w: extension does not match content_type", ErrValidation)
	}
	if in.FileSizeBytes <= 0 || in.FileSizeBytes > maxEvidenceBytes {
		return UploadIntent{}, fmt.Errorf("%w: file too large", ErrValidation)
	}
	tasker, dueDate, err := s.store.TaskForEvidence(ctx, s.db, taskID)
	if err != nil {
		return UploadIntent{}, err // ErrNotFound
	}
	if tasker != taskerID {
		return UploadIntent{}, ErrForbidden
	}
	if !s.now().Before(dueDate) {
		return UploadIntent{}, fmt.Errorf("%w: past due date", ErrValidation)
	}
	// Task-bound key (P4b-D10): the task id is part of the prefix so submit can
	// verify an asset belongs to this task, and no other task can reference it.
	key := fmt.Sprintf("evidence/%s/%s/%s.%s",
		dueDate.UTC().Format("2006-01-02"), taskID.String(), uuid.NewString(), ext)
	url, err := s.uploader.PresignPut(ctx, r2.PresignPutInput{
		Key: key, ContentType: in.ContentType, ExpiresIn: uploadTTL,
	})
	if err != nil {
		return UploadIntent{}, err
	}
	return UploadIntent{UploadURL: url, ObjectKey: key, ExpiresIn: int(uploadTTL.Seconds())}, nil
}
```

(Verify `r2.PresignPutInput` field names against 3a and adjust.)

- [ ] **Step 4: Run to verify they pass**

Run: `go test ./internal/evidence/ -run TestRequestUploadURL -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/evidence/service.go internal/evidence/service_test.go
git commit -m "feat(backend): evidence request-upload-url (validation + key derivation)"
```

---

## Task 6: `evidence` service — `Submit` (one transaction)

**Files:**
- Modify: `internal/evidence/service.go`
- Test: `internal/evidence/service_test.go` (unit with fakes) + `internal/evidence/submit_integration_test.go`

**Interfaces:**
- Consumes: the notification enqueuer. Declare it as a consumer interface to keep evidence decoupled: `type Notifier interface { EnqueueInTx(ctx context.Context, q database.Querier, userID uuid.UUID, keyBase string, args []string, data map[string]any) error }` (adapts 4a's `notification` outbox; verify the 4a signature and adapt).
- Produces: `Submit(ctx, taskerID, taskID uuid.UUID, in SubmitInput) (Evidence, error)`.
- Behavior: one tx — gate on task ownership + **`due_date > now()`** (P4b-D12) + ≥1 asset + ≥1 `awaiting_evidence` judgement; **for each asset: verify the key prefix is `evidence/{due-date}/{task-id}/` and `r2.Head` succeeds, using the R2-reported content-type/size** (P4b-D10; reject foreign-prefix / missing / oversize with `ErrValidation`); insert evidence (a `UNIQUE(task_id)` `23505` → `ErrConflict` → 409, P4b-D9); insert assets (R2 metadata); `TransitionAwaitingToInReviewInTx` — **if it returns 0 referee ids, return `ErrConflict` so the tx rolls back** (a concurrent `evidence_timeout` already moved the judgements, review #3); enqueue `notification_evidence_submitted_referee` per referee id.

- [ ] **Step 1: Write the failing integration test**

```go
func TestSubmit_CreatesEvidence_TransitionsAll_EnqueuesPerReferee(t *testing.T) {
	db := testsupport.DB(t)
	svc := newRealServiceWithFakeUploaderAndRealNotifier(t, db)
	fx := seedTaskWithTwoAwaitingJudgements(t, db)

	// Task-bound key (P4b-D10): built from the fixture's due-date + task id.
	// seedTaskWithTwoAwaitingJudgements sets due_date = 2026-08-01.
	key := fmt.Sprintf("evidence/2026-08-01/%s/a.jpg", fx.TaskID)
	fx.FakeR2.Put(key, "image/jpeg", 1024) // fake Head returns this content-type/size
	ev, err := svc.Submit(ctx, fx.TaskerID, fx.TaskID, evidence.SubmitInput{
		Description: "done",
		Assets:      []evidence.AssetInput{{ObjectKey: key}},
	})
	if err != nil { t.Fatal(err) }
	if ev.ID == uuid.Nil || len(ev.Assets) != 1 { t.Fatal("evidence not persisted") }

	assertJudgementCount(t, db, fx.TaskID, "in_review", 2)
	assertJobCount(t, db, "send_notification", 2) // one per referee
}

func TestSubmit_NoAwaitingJudgement_Rejected(t *testing.T) { /* ErrInvalidState */ }
func TestSubmit_NonOwner_Forbidden(t *testing.T)           { /* ErrForbidden */ }
func TestSubmit_NoAssets_Validation(t *testing.T)          { /* ErrValidation */ }
func TestSubmit_PastDue_Rejected(t *testing.T)             { /* due_date in past → ErrValidation (P4b-D12) */ }
func TestSubmit_ForeignPrefixKey_Rejected(t *testing.T)    { /* key scoped to another task → ErrValidation (P4b-D10) */ }
func TestSubmit_MissingObject_Rejected(t *testing.T)       { /* fake Head returns not-found → ErrValidation */ }
func TestSubmit_AdoptsR2Metadata(t *testing.T)             { /* fake Head returns type/size; asset row stores those, ignoring any client-claimed values */ }

// Concurrency (review #1, #3): needs the real DB.
func TestSubmit_ConcurrentDouble_OneWinsOne409(t *testing.T) {
	// two goroutines Submit the same task; exactly one evidence row exists,
	// the other returns ErrConflict (UNIQUE(task_id) 23505).
}
func TestSubmit_TransitionZeroRowsRollsBack(t *testing.T) {
	// force the judgements to evidence_timeout between gate and transition
	// (or seed none awaiting after the gate) → Submit returns ErrConflict and
	// leaves NO evidence row.
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `DATABASE_URL=... go test ./internal/evidence/ -run TestSubmit -v`
Expected: FAIL.

- [ ] **Step 3: Implement `Submit`**

```go
func (s *Service) Submit(ctx context.Context, taskerID, taskID uuid.UUID, in SubmitInput) (Evidence, error) {
	if strings.TrimSpace(in.Description) == "" {
		return Evidence{}, fmt.Errorf("%w: description required", ErrValidation)
	}
	if len(in.Assets) == 0 {
		return Evidence{}, fmt.Errorf("%w: at least one asset required", ErrValidation)
	}
	var ev Evidence
	err := database.WithTx(ctx, s.db, func(q database.Querier) error {
		tasker, dueDate, err := s.store.TaskForEvidence(ctx, q, taskID)
		if err != nil {
			return err
		}
		if tasker != taskerID {
			return ErrForbidden
		}
		if !s.now().Before(dueDate) { // P4b-D12: reject submit past the deadline
			return fmt.Errorf("%w: past due date", ErrValidation)
		}
		ok, err := s.store.HasAwaitingEvidenceJudgement(ctx, q, taskID)
		if err != nil {
			return err
		}
		if !ok {
			return ErrInvalidState
		}
		evID, err := s.store.InsertEvidenceInTx(ctx, q, taskID, in.Description)
		if err != nil {
			return err // UNIQUE(task_id) 23505 → ErrConflict (mapped in the store) → 409
		}
		// P4b-D10: verify each asset belongs to this task and exists in R2; store R2 metadata.
		wantPrefix := fmt.Sprintf("evidence/%s/%s/", dueDate.UTC().Format("2006-01-02"), taskID.String())
		for _, a := range in.Assets {
			if !strings.HasPrefix(a.ObjectKey, wantPrefix) {
				return fmt.Errorf("%w: object key not scoped to this task", ErrValidation)
			}
			meta, err := s.uploader.Head(ctx, a.ObjectKey)
			if err != nil {
				return fmt.Errorf("%w: object not found for key", ErrValidation) // missing upload
			}
			// Re-validate the R2-reported metadata (defense in depth; the columns are NOT NULL).
			if _, ok := allowedContentExt[meta.ContentType]; !ok {
				return fmt.Errorf("%w: object content_type not allowed", ErrValidation)
			}
			if meta.ContentLength <= 0 || meta.ContentLength > maxEvidenceBytes {
				return fmt.Errorf("%w: object size out of range", ErrValidation)
			}
			if err := s.store.InsertAssetInTx(ctx, q, evID, a.ObjectKey, meta.ContentType, meta.ContentLength); err != nil {
				return err
			}
		}
		refs, err := s.store.TransitionAwaitingToInReviewInTx(ctx, q, taskID)
		if err != nil {
			return err
		}
		if len(refs) == 0 { // review #3: a concurrent evidence_timeout moved them → roll back
			return ErrConflict
		}
		title, err := s.store.TaskTitle(ctx, q, taskID)
		if err != nil {
			return err
		}
		for _, refID := range refs {
			if refID == uuid.Nil {
				continue
			}
			if err := s.notifier.EnqueueInTx(ctx, q, refID,
				"notification_evidence_submitted_referee",
				[]string{title}, map[string]any{"task_id": taskID}); err != nil {
				return err
			}
		}
		// Re-read the full evidence (assets with generated ids/metadata) in-tx so
		// the caller/test gets a complete value, not a partial one.
		full, err := s.store.EvidenceByTask(ctx, q, taskID)
		if err != nil {
			return err
		}
		ev = *full
		return nil
	})
	if err != nil {
		return Evidence{}, err
	}
	return ev, nil
}
```

(For the notification title arg, load the task title in-tx or thread it from `TaskForEvidence`; keep the arg contract identical to the legacy `notify_event` call — `ARRAY[task_title]`.)

- [ ] **Step 4: Run to verify it passes**

Run: `DATABASE_URL=... go test ./internal/evidence/ -run TestSubmit -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/evidence/service.go internal/evidence/submit_integration_test.go internal/evidence/service_test.go
git commit -m "feat(backend): evidence submit (atomic create + transition + notify)"
```

---

## Task 7: `evidence` service — `Update` and `Resubmit`

**Files:**
- Modify: `internal/evidence/service.go`
- Test: `internal/evidence/service_test.go`

**Interfaces:**
- Produces:
  - `Update(ctx, taskerID, taskID uuid.UUID, in UpdateInput) error` — gate on `in_review` + ownership + **`due_date > now()`** (P4b-D12; legacy `validate_evidence_due_date` fires on UPDATE too); update description; **`Head`-verify + prefix-check each added asset and store R2 metadata** (P4b-D10); apply removals/additions but **reject if the result leaves 0 assets** (P4b-D12); enqueue `notification_evidence_updated_referee`.
  - `Resubmit(ctx, taskerID, taskID uuid.UUID, in UpdateInput) error` — gate on `rejected && reopen_count<1 && due_date>now()` + ownership; **`Head`-verify + prefix-check each added asset** (P4b-D10); apply changes but **keep ≥1 asset** (P4b-D12); `TransitionRejectedToInReviewInTx`; enqueue `notification_evidence_resubmitted_referee`. **Dormant until 4c** (no `rejected` judgements exist before 4c) — the test seeds a `rejected` judgement directly to exercise it.
  - Both share an in-tx helper `applyAssetChanges(ctx, q, dueDate, taskID, evidenceID, in)` doing, for each added asset, the same checks as submit (prefix match + `Head` + allow-list content-type re-check + size 0<n≤5 MiB, store R2 metadata), then removals, additions, and the "≥1 remaining asset" check (count after apply).

- [ ] **Step 1: Write the failing tests**

```go
func TestUpdate_InReview_EditsAndNotifies(t *testing.T) {
	db := testsupport.DB(t)
	svc := newRealServiceWithFakeUploaderAndRealNotifier(t, db)
	fx := seedTaskWithSubmittedEvidenceInReview(t, db) // helper; due_date = 2026-08-01
	addKey := fmt.Sprintf("evidence/2026-08-01/%s/b.jpg", fx.TaskID)
	fx.FakeR2.Put(addKey, "image/jpeg", 2048) // fake Head metadata for the added asset
	err := svc.Update(ctx, fx.TaskerID, fx.TaskID, evidence.UpdateInput{
		Description: "revised", AssetsToAdd: []evidence.AssetInput{{ObjectKey: addKey}},
	})
	if err != nil { t.Fatal(err) }
	assertEvidenceDescription(t, db, fx.TaskID, "revised")
	assertJobCount(t, db, "send_notification", 1)
}

func TestUpdate_NotInReview_Rejected(t *testing.T) { /* awaiting_evidence → ErrInvalidState */ }

func TestResubmit_Rejected_ReopensAndNotifies(t *testing.T) {
	db := testsupport.DB(t)
	svc := newRealServiceWithFakeUploaderAndRealNotifier(t, db)
	fx := seedTaskWithRejectedJudgement(t, db) // directly seeds rejected + reopen_count=0
	err := svc.Resubmit(ctx, fx.TaskerID, fx.TaskID, evidence.UpdateInput{Description: "again"})
	if err != nil { t.Fatal(err) }
	assertJudgementCount(t, db, fx.TaskID, "in_review", 1)
	assertReopenCount(t, db, fx.TaskID, 1)
}

func TestResubmit_ReopenLimitReached_Rejected(t *testing.T) { /* reopen_count=1 → ErrInvalidState */ }
func TestUpdate_PastDue_Rejected(t *testing.T)              { /* due_date past → ErrValidation (P4b-D12) */ }
func TestUpdate_RemovingLastAsset_Rejected(t *testing.T)    { /* removing the only asset → ErrValidation (P4b-D12) */ }
func TestUpdate_AddedAssetForeignPrefix_Rejected(t *testing.T) { /* ErrValidation (P4b-D10) */ }
```

- [ ] **Step 2: Run to verify they fail**

Run: `DATABASE_URL=... go test ./internal/evidence/ -run 'TestUpdate|TestResubmit' -v`
Expected: FAIL.

- [ ] **Step 3: Implement `Update` and `Resubmit`** (both in one tx via `database.WithTx`, gate → mutate → transition (resubmit only) → notify; reuse `DeleteAssetsInTx`/`InsertAssetInTx`/`UpdateEvidenceDescriptionInTx`).

- [ ] **Step 4: Run to verify they pass**

Run: `DATABASE_URL=... go test ./internal/evidence/ -run 'TestUpdate|TestResubmit' -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/evidence/service.go internal/evidence/service_test.go
git commit -m "feat(backend): evidence update + resubmit (resubmit dormant until 4c)"
```

---

## Task 8: `evidence` service — `ViewForTask` (authz + presigned GET)

**Files:**
- Modify: `internal/evidence/service.go`
- Test: `internal/evidence/service_test.go`

**Interfaces:**
- Produces: `ViewForTask(ctx, viewerID, taskID uuid.UUID) (*EvidenceView, error)` — returns `nil, nil` when the task has no evidence; `ErrForbidden` when `viewerID` is neither the tasker nor a matched referee; otherwise the evidence with a **presigned GET `DownloadURL`** per **live** asset (TTL 900 s). For a **purged** asset (`PurgedAt != nil`, P4b-D11) no presign is attempted; `Purged=true`, `DownloadURL=""`.

- [ ] **Step 1: Write the failing tests**

```go
func TestViewForTask_AuthorizedRefereeGetsDownloadURLs(t *testing.T) {
	db := testsupport.DB(t)
	svc, fake := newRealServiceWithFakeUploader(t, db) // fake PresignGet returns "signed:"+key
	fx := seedTaskWithSubmittedEvidenceInReview(t, db)
	v, err := svc.ViewForTask(ctx, fx.RefereeIDs[0], fx.TaskID)
	if err != nil { t.Fatal(err) }
	if v == nil || len(v.Assets) == 0 { t.Fatal("expected evidence view") }
	if !strings.HasPrefix(v.Assets[0].DownloadURL, "signed:") {
		t.Fatalf("expected presigned url, got %q", v.Assets[0].DownloadURL)
	}
}

func TestViewForTask_UnauthorizedForbidden(t *testing.T) {
	// a random third user → ErrForbidden, no URL
}

func TestViewForTask_NoEvidenceReturnsNil(t *testing.T) {
	// task with only awaiting_evidence, no evidence row → nil, nil
}

func TestViewForTask_PurgedAssetHasNoURL(t *testing.T) {
	// asset with purged_at set → AssetView{Purged:true, DownloadURL:""}; PresignGet not called
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `DATABASE_URL=... go test ./internal/evidence/ -run TestViewForTask -v`
Expected: FAIL.

- [ ] **Step 3: Implement `ViewForTask`**

```go
const downloadTTL = 900 * time.Second

func (s *Service) ViewForTask(ctx context.Context, viewerID, taskID uuid.UUID) (*EvidenceView, error) {
	ok, err := s.store.IsTaskViewer(ctx, s.db, taskID, viewerID)
	if err != nil {
		return nil, err
	}
	if !ok {
		return nil, ErrForbidden
	}
	ev, err := s.store.EvidenceByTask(ctx, s.db, taskID)
	if errors.Is(err, ErrNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	out := &EvidenceView{Description: ev.Description}
	for _, a := range ev.Assets {
		if a.PurgedAt != nil { // P4b-D11: image file deleted by the 90-day sweep; keep the record
			out.Assets = append(out.Assets, AssetView{
				ID: a.ID, ContentType: a.ContentType, FileSizeBytes: a.FileSizeBytes, Purged: true,
			})
			continue
		}
		url, err := s.uploader.PresignGet(ctx, r2.PresignGetInput{Key: a.ObjectKey, ExpiresIn: downloadTTL})
		if err != nil {
			return nil, err
		}
		out.Assets = append(out.Assets, AssetView{
			ID: a.ID, ContentType: a.ContentType, FileSizeBytes: a.FileSizeBytes, DownloadURL: url,
		})
	}
	return out, nil
}
```

- [ ] **Step 4: Run to verify they pass** → PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/evidence/service.go internal/evidence/service_test.go
git commit -m "feat(backend): evidence authorized presigned-GET read model"
```

---

## Task 9: `evidence` service — `ConfirmEvidenceTimeout`

**Files:**
- Modify: `internal/evidence/service.go`
- Test: `internal/evidence/service_test.go`

**Interfaces:**
- Consumes: `TaskCloser` seam.
- Produces: `ConfirmEvidenceTimeout(ctx, taskerID, judgementID uuid.UUID) error` — one tx: `ConfirmEvidenceTimeoutInTx` → if changed, call `taskCloser.CloseIfAllConfirmedInTx(ctx, q, taskID)` (no-op in 4b). Idempotent (already-confirmed → nil).

- [ ] **Step 1: Write the failing tests**

```go
func TestConfirmEvidenceTimeout_SetsConfirmed_CallsCloser(t *testing.T) {
	db := testsupport.DB(t)
	closer := &recordingCloser{}
	svc := newServiceWithCloser(t, db, closer)
	fx := seedTaskWithEvidenceTimeoutJudgement(t, db)
	if err := svc.ConfirmEvidenceTimeout(ctx, fx.TaskerID, fx.JudgementID); err != nil { t.Fatal(err) }
	assertConfirmed(t, db, fx.JudgementID, true)
	if closer.calls != 1 { t.Fatalf("expected closer called once, got %d", closer.calls) }
}

func TestConfirmEvidenceTimeout_Idempotent(t *testing.T)  { /* second call → nil */ }
func TestConfirmEvidenceTimeout_WrongOwner(t *testing.T)  { /* ErrInvalidState (or ErrForbidden) */ }
```

- [ ] **Step 2: Run to verify they fail** → FAIL.

- [ ] **Step 3: Implement**

```go
func (s *Service) ConfirmEvidenceTimeout(ctx context.Context, taskerID, judgementID uuid.UUID) error {
	return database.WithTx(ctx, s.db, func(q database.Querier) error {
		taskID, changed, err := s.store.ConfirmEvidenceTimeoutInTx(ctx, q, judgementID, taskerID)
		if err != nil {
			return err
		}
		if !changed {
			return nil // idempotent no-op
		}
		return s.taskCloser.CloseIfAllConfirmedInTx(ctx, q, taskID)
	})
}
```

- [ ] **Step 4: Run to verify they pass** → PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/evidence/service.go internal/evidence/service_test.go
git commit -m "feat(backend): confirm-evidence-timeout (4c closure seam)"
```

---

## Task 10: `evidence` handler + routes

**Files:**
- Create: `internal/evidence/handler.go`
- Test: `internal/evidence/handler_test.go`

**Interfaces:**
- Consumes: `identity.CurrentUserFrom(ctx)`, `httpserver.DecodeJSON`, `httpserver` error codes/writer, `*Service`.
- Produces: `type Handler struct{ svc *Service }` + `NewHandler` + a `Routes(mux *http.ServeMux)` (or the repo's routing convention) registering:
  - `POST /api/v1/tasks/{id}/evidence/request-upload-url`
  - `PUT  /api/v1/tasks/{id}/evidence`
  - `PATCH /api/v1/tasks/{id}/evidence`
  - `POST /api/v1/tasks/{id}/evidence/resubmit`
  - `POST /api/v1/judgements/{id}/confirm-evidence-timeout`
- Map service errors → envelope: `ErrValidation`→400 `validation`, `ErrForbidden`→403 `forbidden`, `ErrNotFound`→404 `not_found`, `ErrInvalidState`→409 `conflict`, `ErrConflict`→409 `conflict` (singleton/object-key/race).

- [ ] **Step 1: Write failing handler tests** (httptest, fake service or real service + fakes; assert status + envelope for: happy submit 200/201; non-owner 403; bad content-type 400; missing auth 401 via middleware).

```go
func TestHandler_RequestUploadURL_OK(t *testing.T) { /* 200 + {uploadUrl,objectKey,expiresIn} */ }
func TestHandler_Submit_NonOwner_403(t *testing.T) { /* forbidden envelope */ }
func TestHandler_Submit_BadContentType_400(t *testing.T) { /* validation envelope */ }
```

- [ ] **Step 2: Run to verify they fail** → FAIL.

- [ ] **Step 3: Implement `handler.go`** — decode DTOs, read `CurrentUser`, parse the `{id}` path value (`r.PathValue("id")`), call the service, map errors via a shared `writeServiceError(w, err)` helper. DTOs mirror the API contract (`objectKey`, not `object_key`, in JSON per the repo's JSON naming; verify 4a's convention).

- [ ] **Step 4: Run to verify they pass** → PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/evidence/handler.go internal/evidence/handler_test.go
git commit -m "feat(backend): evidence HTTP handlers + routes"
```

---

## Task 11: Embed the evidence view in task-detail / assignment-detail

**Files:**
- Modify: `internal/task/handler.go` (and/or `internal/task/service.go`), `internal/matching/handler.go`
- Modify: `internal/evidence/service.go` (nothing new — reuse `ViewForTask`)
- Test: `internal/task/handler_test.go` (or an integration test)

**Interfaces:**
- Consumes (declared on the task/matching side, mirroring 4a's cross-feature composition): `type EvidenceReader interface { ViewForTask(ctx context.Context, viewerID, taskID uuid.UUID) (*evidence.EvidenceView, error) }` — `*evidence.Service` satisfies it.
- Produces: `GET /api/v1/tasks/{id}` and `GET /api/v1/me/assignments` detail responses gain an optional `evidence` object for authorized viewers.

- [ ] **Step 1: Write the failing test** — an authorized referee's `GET /tasks/{id}` includes `evidence.assets[].downloadUrl`; a task with no evidence omits/nulls it.

- [ ] **Step 2: Run to verify it fails** → FAIL.

- [ ] **Step 3: Inject the `EvidenceReader` into the task/matching handler `Deps`; call `ViewForTask(ctx, currentUserID, taskID)` when building the detail DTO; add the `Evidence *EvidenceDTO` field** (omitempty). Since `ViewForTask` already authorizes, and the task-detail read already authorizes task access, callers who can read the task and are viewers get URLs; others get `nil`.

- [ ] **Step 4: Run to verify it passes** → PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/task/ internal/matching/
git commit -m "feat(backend): embed evidence view (presigned GET) in task/assignment detail"
```

---

## Task 12: Worker — `detect_evidence_timeouts`

**Files:**
- Create: `internal/evidence/worker.go`
- Test: `internal/evidence/worker_test.go` (integration)

**Interfaces:**
- Consumes: `*Store`, `*sql.DB`, `EvidenceTimeoutSettler`, `Notifier`, `jobs.Store` (for self-reschedule), a clock.
- Produces: `func (s *Service) HandleDetectEvidenceTimeouts(ctx context.Context, j *jobs.Job) error` (job kind `detect_evidence_timeouts`). Self-reschedules (~5 min): schedule the next run **first** (bucketed idempotency key), then process.
- Per candidate, one tx: `MarkEvidenceTimeoutInTx` (CAS) → if changed: `EvidenceTimeoutSettler.SettleInTx` (P5 no-op) + `CloseRefereeRequestInTx` + `Notifier.EnqueueInTx(tasker, "notification_evidence_timeout_tasker", …)` + `Notifier.EnqueueInTx(referee, "notification_evidence_timeout_referee", …)`.

- [ ] **Step 1: Write the failing integration test**

```go
func TestDetectEvidenceTimeouts_TransitionsSettlesClosesNotifies(t *testing.T) {
	db := testsupport.DB(t)
	settler := &recordingSettler{}
	svc := newWorkerServiceWithSettler(t, db, settler)
	fx := seedTaskPastDueNoEvidence(t, db) // awaiting_evidence, due_date in the past, no evidence row

	if err := svc.HandleDetectEvidenceTimeouts(ctx, &jobs.Job{Kind: "detect_evidence_timeouts"}); err != nil {
		t.Fatal(err)
	}
	assertJudgementStatus(t, db, fx.JudgementID, "evidence_timeout")
	assertRefereeRequestStatus(t, db, fx.RequestID, "closed")
	if settler.calls != 1 { t.Fatalf("settler calls=%d", settler.calls) }
	assertJobCount(t, db, "send_notification", 2) // tasker + referee
}

func TestDetectEvidenceTimeouts_Idempotent(t *testing.T) {
	// run twice → judgement transitioned once, settler called once, 2 notifications total (not 4)
}

func TestDetectEvidenceTimeouts_SkipsWhenEvidenceExists(t *testing.T) {
	// past due but evidence row present → no transition
}
```

- [ ] **Step 2: Run to verify it fails** → FAIL.

- [ ] **Step 3: Implement the handler**

```go
func (s *Service) HandleDetectEvidenceTimeouts(ctx context.Context, _ *jobs.Job) error {
	// self-reschedule first (bucketed key so a crash cannot break the chain)
	if err := s.scheduleNextTimeoutSweep(ctx); err != nil {
		return err
	}
	cands, err := s.store.TimeoutCandidates(ctx, s.db)
	if err != nil {
		return err
	}
	for _, c := range cands {
		if err := database.WithTx(ctx, s.db, func(q database.Querier) error {
			changed, err := s.store.MarkEvidenceTimeoutInTx(ctx, q, c.JudgementID)
			if err != nil || !changed {
				return err // skip: a concurrent run already handled it
			}
			if err := s.settler.SettleInTx(ctx, q, c.RequestID); err != nil {
				return err
			}
			if err := s.store.CloseRefereeRequestInTx(ctx, q, c.RequestID); err != nil {
				return err
			}
			if err := s.notifier.EnqueueInTx(ctx, q, c.TaskerID,
				"notification_evidence_timeout_tasker", []string{c.TaskTitle},
				map[string]any{"task_id": c.TaskID, "judgement_id": c.JudgementID}); err != nil {
				return err
			}
			return s.notifier.EnqueueInTx(ctx, q, c.RefereeID,
				"notification_evidence_timeout_referee", []string{c.TaskTitle},
				map[string]any{"task_id": c.TaskID, "judgement_id": c.JudgementID})
		}); err != nil {
			return err // job retries; CAS makes the retry safe
		}
	}
	return nil
}
```

(`scheduleNextTimeoutSweep` enqueues the next `detect_evidence_timeouts` with `RunAt=now+5m` and a time-bucketed `IdempotencyKey` so duplicate schedules collapse — mirror 4a's `sweep_pending_requests` pattern.)

- [ ] **Step 4: Run to verify it passes** → PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/evidence/worker.go internal/evidence/worker_test.go
git commit -m "feat(backend): detect_evidence_timeouts worker (CAS + settle seam + close + notify)"
```

---

## Task 13: Notification — `notification_sent_log` + `detect_evidence_deadline_warnings`

**Files:**
- Modify: `internal/notification/store.go` (dedup methods)
- Create: `internal/notification/reminder_worker.go` (or add to `internal/evidence/worker.go` — keep the *evidence* candidate query in `evidence/store.go`, the dedup in `notification`)
- Test: `internal/notification/store_test.go`, `internal/evidence/reminder_worker_test.go`

**Interfaces:**
- Produces (notification):
  - `MarkSentInTx(ctx, q database.Querier, userID uuid.UUID, eventKey, dedupKey string) (firstTime bool, err error)` — `INSERT … ON CONFLICT (user_id, event_key, dedup_key) DO NOTHING` (review #6); `firstTime = rowsAffected > 0`.
- Produces (evidence store):
  - `type DeadlineWarningCandidate struct { TaskID, TaskerID uuid.UUID; TaskTitle string; DueDate time.Time; ReminderMinutes []int }`
  - `DeadlineWarningCandidates(ctx, q, now time.Time) ([]DeadlineWarningCandidate, error)` — **legacy parity (review #6):** tasks whose judgement is `awaiting_evidence` **with no evidence row**, whose `due_date` is within a reminder offset of the tasker's `evidence_reminder_minutes` and not yet past. `evidence_reminder_even_if_submitted` is **inert** (read nowhere in the legacy) — not consulted here; recorded in the spec §11 as a future feature, not ported.
- Produces (worker): `HandleDetectEvidenceDeadlineWarnings(ctx, *jobs.Job) error` (kind `detect_evidence_deadline_warnings`), self-rescheduling (~1 min). For each candidate × matching offset: `dedupKey = fmt.Sprintf("%s:%d", taskID, offsetMinutes)`; `MarkSentInTx` first-time → enqueue `notification_evidence_deadline_warning_tasker`.

- [ ] **Step 1: Write the failing tests**

```go
func TestMarkSentInTx_OnceThenDuplicate(t *testing.T) {
	db := testsupport.DB(t); st := notification.NewStore(...)
	var first, second bool
	database.WithTx(ctx, db, func(q database.Querier) error {
		first, _ = st.MarkSentInTx(ctx, q, userID, "evt", "k1"); return nil
	})
	database.WithTx(ctx, db, func(q database.Querier) error {
		second, _ = st.MarkSentInTx(ctx, q, userID, "evt", "k1"); return nil
	})
	if !first || second { t.Fatalf("want first=true second=false, got %v/%v", first, second) }
}

func TestDetectEvidenceDeadlineWarnings_SendsOncePerOffset(t *testing.T) {
	db := testsupport.DB(t)
	svc := newReminderService(t, db)
	fx := seedTaskDueIn10Min_ReminderMinutes10(t, db) // awaiting_evidence, no evidence
	// run twice
	svc.HandleDetectEvidenceDeadlineWarnings(ctx, &jobs.Job{})
	svc.HandleDetectEvidenceDeadlineWarnings(ctx, &jobs.Job{})
	assertJobCount(t, db, "send_notification", 1) // deduped
}
```

- [ ] **Step 2: Run to verify they fail** → FAIL.

- [ ] **Step 3: Implement** `MarkSentInTx`, `DeadlineWarningCandidates`, and the handler (self-reschedule first; per candidate, per matching offset, dedup then enqueue in one tx).

- [ ] **Step 4: Run to verify they pass** → PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/notification/ internal/evidence/
git commit -m "feat(backend): evidence deadline reminders + notification_sent_log dedup"
```

---

## Task 14: Worker — `sweep_evidence_objects` (90-day purge + orphan pass)

**Files:**
- Modify: `internal/evidence/worker.go`
- Test: `internal/evidence/sweep_test.go` (integration for the DB passes + fake object store)

**Interfaces:**
- Consumes: the private-evidence `r2.Uploader` (`List` + `Delete`), `*Store`, `*sql.DB`, a clock.
- Produces: `HandleSweepEvidenceObjects(ctx, *jobs.Job) error` (kind `sweep_evidence_objects`), self-rescheduling (daily). Honors a `dry_run` payload flag (log-only). Two passes (P4b-D11):
  1. **90-day purge (retention policy):** `PurgeCandidates(cutoff = now-90d by task due_date)` → for each, `Delete` the R2 object and `MarkAssetPurgedInTx` (**keep the DB row**). Idempotent: `purged_at IS NULL` excludes already-purged rows; a re-`Delete` of a gone object is a no-op.
  2. **Orphan pass:** `List("evidence/")` cross-referenced against `AllReferencedObjectKeys`; `Delete` objects with **no** referencing row **and** `LastModified` older than a short grace (e.g. 24 h — covers uploaded-but-not-submitted and assets removed by update/resubmit). Never deletes a referenced object (purged rows still count as referenced until their retention removes the row in a future phase, but their object is already gone — a re-list simply finds nothing).

- [ ] **Step 1: Write the failing tests**

```go
func TestSweepEvidenceObjects_PurgesReferencedPastDue90d_KeepsRow(t *testing.T) {
	db := testsupport.DB(t)
	fake := newFakeStore(map[string]time.Time{}) // object store; seed below
	fx := seedEvidenceWithAssetTaskDue100dAgo(t, db, fake) // asset row + object present
	svc := newSweepService(t, db, fake, fixedNow)
	if err := svc.HandleSweepEvidenceObjects(ctx, &jobs.Job{}); err != nil { t.Fatal(err) }
	if fake.exists(fx.ObjectKey) { t.Fatal("object not purged") }
	assertAssetPurgedAtSet(t, db, fx.AssetID, true) // DB row kept, purged_at set
}

func TestSweepEvidenceObjects_KeepsReferencedWithin90d(t *testing.T) {
	// asset whose task due_date is 10 days ago → object kept, purged_at NULL
}

func TestSweepEvidenceObjects_DeletesTrueOrphanPastGrace(t *testing.T) {
	// object under evidence/ with NO evidence_assets row, LastModified 2 days ago → deleted
}

func TestSweepEvidenceObjects_KeepsRecentOrphanWithinGrace(t *testing.T) {
	// unreferenced object uploaded 5 min ago → kept (grace)
}

func TestSweepEvidenceObjects_DryRunDeletesNothing(t *testing.T) { /* payload {"dry_run":true} */ }

func TestSweepEvidenceObjects_Idempotent(t *testing.T) { /* run twice → one purge, no error on the second */ }
```

- [ ] **Step 2: Run to verify they fail** → FAIL.

- [ ] **Step 3: Implement** both passes (self-reschedule first; `dry_run` short-circuits every `Delete`/`MarkAssetPurgedInTx`, logging counts). Purge pass in one tx per asset (delete object, then `MarkAssetPurgedInTx`); orphan pass deletes objects only (no DB row exists).

- [ ] **Step 4: Run to verify they pass** → PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/evidence/worker.go internal/evidence/sweep_test.go
git commit -m "feat(backend): sweep_evidence_objects (90d purge keeps records + orphan cleanup)"
```

---

## Task 15: Worker — `sweep_orphan_avatars` (public bucket, `internal/profile`)

**Files:**
- Create: `internal/profile/worker.go`
- Test: `internal/profile/worker_test.go` (integration for the avatar_url lookup + fake object store)

**Interfaces:**
- Consumes: the public-avatar `r2.Uploader` (`List` + `Delete`), a profile store method `CurrentAvatarKeys(ctx, q) (map[string]bool, error)` (derive object keys from `profiles.avatar_url`), a clock.
- Produces: `HandleSweepOrphanAvatars(ctx, *jobs.Job) error` (kind `sweep_orphan_avatars`), self-rescheduling (daily). For each `avatar/{userId}/…` object: delete if it is **not** any user's current avatar key **and** older than the 10-minute grace period. `dry_run` supported.

- [ ] **Step 1: Write the failing test** — an object that is not the current `avatar_url` and older than 10 min is deleted; the current avatar and a <10-min-old orphan are kept.

- [ ] **Step 2: Run to verify it fails** → FAIL.

- [ ] **Step 3: Implement** (`CurrentAvatarKeys` parses each `avatar_url` into its object key with the same URL-parse rigor as 3a; then `List("avatar/")` → delete non-current + past-grace).

- [ ] **Step 4: Run to verify it passes** → PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/profile/worker.go internal/profile/worker_test.go
git commit -m "feat(backend): sweep_orphan_avatars worker (public bucket, grace period)"
```

---

## Task 16: Wiring — buckets, routes, handler registration, event keys

**Files:**
- Modify: `cmd/peppercheck/main.go`, `internal/api/api.go`, `internal/worker/worker.go`
- Modify: notification key registry / `.claude/rules/notification-keys.md` reference (add the 6 new keys if the repo tracks a key list)
- Test: `internal/api/api_test.go` (routes wired), `internal/worker/worker_test.go` (handlers registered)

**Interfaces:**
- Consumes: everything above.
- Produces: a running api that serves the evidence routes and a worker that registers + schedules the four new jobs, with the private-evidence bucket wired and the Phase-5/4c stubs injected.

- [ ] **Step 1: Write the failing wiring tests** — `api` responds (non-404) on the five evidence routes; `worker` has handlers for `detect_evidence_timeouts`, `detect_evidence_deadline_warnings`, `sweep_evidence_objects`, `sweep_orphan_avatars`.

- [ ] **Step 2: Run to verify they fail** → FAIL.

- [ ] **Step 3: Wire everything**

```go
// cmd/peppercheck/main.go (sketch)
avatarR2 := r2.New(cfg.R2Avatar)   // existing public bucket (3a)
evidenceR2 := r2.New(cfg.R2Evidence) // NEW private bucket

notifier := notification.NewOutbox(...) // 4a
evSvc := evidence.NewService(db, evidenceR2, evidence.NewStore(), notifier,
	evidence.NoopSettler{}, evidence.NoopTaskCloser{}, time.Now)

// api routes
evidence.NewHandler(evSvc).Routes(mux)
// task/matching detail readers
taskHandler.SetEvidenceReader(evSvc)

// worker
w.Register("detect_evidence_timeouts", evSvc.HandleDetectEvidenceTimeouts)
w.Register("detect_evidence_deadline_warnings", evSvc.HandleDetectEvidenceDeadlineWarnings)
w.Register("sweep_evidence_objects", evSvc.HandleSweepEvidenceObjects)
w.Register("sweep_orphan_avatars", profileSvc.HandleSweepOrphanAvatars)
// bootstrap the self-rescheduling chains once at startup if not already scheduled
```

Add `R2Evidence` to `core/config` (account id, access key/secret, **private** bucket name; **no public domain**). Follow the secrets policy — names/refs only, values injected at runtime.

- [ ] **Step 4: Run to verify they pass** → PASS. Then run the full suite: `go test ./...` and (with `DATABASE_URL`) the integration suite.

- [ ] **Step 5: Commit**

```bash
git add cmd/peppercheck/main.go internal/api/ internal/worker/ internal/core/config/ .claude/rules/notification-keys.md
git commit -m "feat(backend): wire evidence feature, private bucket, jobs, and routes (Phase 4b)"
```

---

## Task 17: Characterization + full regression

**Files:**
- Create: `internal/evidence/characterization_test.go`

**Interfaces:** none new.

- [ ] **Step 1: Port the Phase 0 high-risk evidence fixtures** — (a) submit across 2 referees transitions both to `in_review`; (b) evidence-timeout detection only fires past-due with no evidence; (c) resubmit reopens exactly once (`reopen_count` 0→1, second resubmit rejected). Assert the Go behavior matches the documented legacy behavior.

- [ ] **Step 2: Run the full suite**

Run: `go test ./...` then `DATABASE_URL=... go test ./... -count=1`
Expected: all PASS; race clean on concurrent pkgs (`go test -race ./internal/evidence/...`).

- [ ] **Step 3: Run the CI gates locally** — `gofmt -l .`, `go vet ./...`, Atlas fmt/lint + apply-to-empty-DB + schema-drift, image build (per the repo's CI targets).

- [ ] **Step 4: Commit**

```bash
git add internal/evidence/characterization_test.go
git commit -m "test(backend): evidence characterization + Phase 4b regression"
```

---

## Task 18: Operator & Post-deploy actions (private R2 bucket + CORS)

**Not TDD — operator/infra actions.** Track via the `release-checklist` skill; the
code in Tasks 1–17 assumes the bucket exists and is reachable. Do these per
environment (staging first, then production) at deploy time. (Spec §8.5 / review #7.)

- [ ] **Create a dedicated PRIVATE evidence bucket** per environment (separate
  from the public avatar bucket). Confirm **no public access** and **no
  custom/public domain** is bound to it.
- [ ] **Provision bucket-scoped credentials** (access key/secret limited to the
  evidence bucket). Store in BWS; deliver via the Phase 7a Docker file-secret
  mechanism; expose to api + worker as `R2Evidence` config (Task 16). Do **not**
  reuse the avatar bucket's credentials.
- [ ] **Configure CORS** on the evidence bucket: allowed origins = the app/web
  origins; allowed methods = `GET`, `PUT`; allowed headers include `Content-Type`.
  A presigned URL fails in a browser without CORS even with a valid signature.
  Verify the exact JSON against the Cloudflare R2 CORS docs
  (`developers.cloudflare.com/r2/buckets/cors/`) at setup.
- [ ] **Smoke test** (staging, then production): request-upload-url → PUT a small
  image → submit → read back as an authorized viewer and confirm the presigned
  GET renders in a browser → confirm an unauthorized caller gets 403.
- [ ] Record the new secret names/refs in `scripts/setup-github-secrets.sh` /
  the secret inventory (names only, never values).
- [ ] **Add a Pending entry to the operator-private release-checklist at ship-PR
  time.** When the PR that ships Phase 4b is opened, invoke the `release-checklist`
  skill and append a Pending entry per environment (staging, production) capturing:
  the **environment**, the exact **commands** (bucket create, public-access/domain
  off, credential provisioning, CORS apply), the **smoke test** steps above, and a
  **reference to this design** (`2026-07-26-phase4b-evidence-private-r2-design.md`
  §8.5). **Completion condition:** the entry exists in the operator-private Pending
  list and is checked off only after the production smoke test passes.

**Task 18 done** = both environments provisioned (private, no public access, CORS
set, bucket-scoped creds), smoke tests pass, and the release-checklist Pending
entry is recorded and resolved.

---

## Self-Review (completed against the spec)

- **§2 data model** → Task 1 (tables/triggers), Task 4 (store). Dropped columns are simply absent from the new schema; §11 records them.
- **§3 reachability** → submit (T6), update (T7), resubmit dormant (T7, seeded rejected in tests), evidence-timeout (T12), confirm (T9).
- **§4 seams** → `EvidenceTimeoutSettler`/`TaskCloser` + no-op stubs (T3); consumed in T12/T9; wired in T16.
- **P4b-D2 private downloads** → `PresignGet` (T2), `ViewForTask` authorized presign (T8), embedded in detail (T11).
- **P4b-D3 separate private bucket** → `R2Evidence` config + second uploader (T16); avatar bucket untouched.
- **P4b-D6 singleton API** → routes under `/tasks/{id}/evidence` (T10).
- **P4b-D7 two sweeps** → `sweep_evidence_objects` in evidence (T14), `sweep_orphan_avatars` in profile (T15).
- **§7 workers / #464 idempotency** → CAS (T12), dedup (T13), idempotent deletes (T14/T15); each has an explicit "run twice" test.
- **§8 notifications** → six event keys enqueued in T6/T7/T12/T13; registry updated in T16.
- **§9 testing** → unit + integration + worker + characterization across T3–T17.

**Review 2026-07-26 coverage:**
- #1 singleton → `UNIQUE(task_id)` (T1) + concurrent-submit 409 test (T6).
- #2 object integrity → task-bound key (T5), prefix-check + `Head` + adopt R2 metadata + `UNIQUE(object_key)` (T3/T4/T6/T7).
- #3 stale timeout CAS → self-contained `MarkEvidenceTimeoutInTx` (T4) + submit transition-rowcount rollback (T6).
- #4 sweep breaking references → 90-day purge keeps DB rows + `purged_at` + empty-frame read (T1/T4/T8/T14), orphan pass (T14).
- #5 due-date guard → submit (T6) + update (T7) + resubmit (existing).
- #6 dedup + reminder state → `UNIQUE(user_id,event_key,dedup_key)` (T1), awaiting+no-evidence target, `even_if_submitted` inert (T13).
- #7 R2 provisioning/CORS/smoke → Task 18 (operator).
- additional (≥1 asset) → submit requires ≥1 (T6); update/resubmit keep ≥1 (T7).

**Type-consistency check:** `database.Querier` used uniformly for tx-scoped store methods; `r2.PresignGetInput`/`PresignPutInput`/`ObjectMetadata.ContentLength` field names to be verified against 3a at execution (flagged in T2/T5/T6); `Notifier.EnqueueInTx` signature to be reconciled with 4a's `notification` outbox at execution (flagged in T6); `AssetInput` is key-only (client), `InsertAssetInTx` takes R2-verified metadata (T3/T4/T6).
