# Phase 4a Backend — Task Authoring & Matching Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement, in Go, task authoring (draft CRUD + publish) and asynchronous referee matching behind the Go API/worker, with no Supabase dependency.

**Architecture:** Feature packages under `internal/` (Option E layout: `domain.go`/`service.go`/`store.go`/`handler.go`). Publishing a task runs one cross-feature transaction (task→open + N referee requests + point-lock seam + enqueue match jobs, transactional outbox); matching runs asynchronously in worker jobs (`match_referee_request`, `sweep_pending_requests`) and notifications in `send_notification`. Phase 5 (points/obligations) is expressed as consumer-declared Go interfaces with no-op stubs.

**Tech Stack:** Go 1.26, `database/sql` + pgx driver, `net/http` + `ServeMux`, Atlas (table-only schema), Firebase Admin SDK (`firebase.google.com/go/v4/messaging`) for FCM, durable-jobs primitive (`internal/core/jobs`).

## Global Constraints

- **Do NOT execute this plan now.** The current working branch is mid-Phase-7. Execute later on a dedicated `feat/phase4a-backend` branch cut from `refactor/go-api-vps`, **after Phase 3a is merged**. The commit steps below are for that execution session.
- **Depends on Phase 3a (assume merged at execution):** `profiles` (incl. `timezone text`), `notification_settings`, `user_fcm_tokens`, `notification.Provisioner`, and a CurrentUser middleware that resolves the verified identity to the internal user and exposes it as `identity.CurrentUserFrom(ctx) (identity.User, bool)`. Verify the exact 3a symbol names at execution and adjust imports.
- **Design source of truth:** `docs/designs/2026-07-25-phase4a-task-authoring-matching-design.md`. Follow-ups: `docs/designs/2026-07-25-phase4a-follow-ups.md`.
- **Schema is table-only with no functions or triggers initially.** Inserts use
  `DEFAULT now()`; every mutable Store `UPDATE` and `ON CONFLICT DO UPDATE`
  explicitly sets `updated_at = now()`. Atlas is pinned; use the pinned Atlas
  (Standard distribution, no login).
- **Reuse Phase 3a's `database.Querier`** (the tx/pool interface 3a introduced for its provisioning fan-out) as the store method receiver type. In this plan, wherever a code block says `database.DBTX`, use 3a's `database.Querier` if it already exists; only create the interface (Task 1) if 3a did not. Verify the exact name/location at execution.
- **FKs target the identity core `users(id)`.** `tasker_id` / `matched_referee_id` → `users(id) ON DELETE SET NULL`; availability tables' `user_id` → `users(id) ON DELETE CASCADE`. Full deletion saga is Phase 6.
- **Referee timezone** is read from `public.profiles.timezone` (default `UTC` when null).
- **English only** in all committed content (code, comments, tests, docs). Conventional Commits for messages (`feat(backend): …`).
- **All layers provider-neutral except `platform/fcm`** (Firebase SDK/DTO types stop there).
- **Consult official docs at implementation time** (standing rule) for: Firebase Admin SDK Go `messaging` (loc-key push, multicast, invalid-token detection) and pgx/`database/sql` transaction usage. Do not code these from memory.
- **Idempotency (#464):** `match_referee_request`, `sweep_pending_requests`, and `send_notification` must be safe under at-least-once execution.
- **Naming:** backend concept is `referee` (not reviewer). Table is `referee_requests` (no `task_` prefix). Matching strategy is single value `standard`.
- Every task: `gofmt`, `go vet`, `go test ./...` must pass before commit. Integration tests use `internal/testsupport` and skip without `DATABASE_URL`.

---

## File Structure

**New packages / files**
- `internal/core/database/tx.go` — `DBTX` interface + `WithTx` helper.
- `internal/core/jobs/jobs.go` — add `EnqueueInTx` (modify).
- `internal/core/httpserver/errors.go` — add codes + `DecodeJSON` helper (modify).
- `internal/matching/{domain,store,service,handler,worker}.go` + `seams.go`.
- `internal/task/{domain,store,service,handler}.go`.
- `internal/judgement/{domain,store}.go` (minimal 4a provisioner).
- `internal/notification/{domain,store,service,worker}.go` (extends 3a).
- `internal/platform/fcm/fcm.go` — Firebase messaging adapter.
- `internal/api/api.go` — extend `Deps` + routes (modify).
- `internal/worker/worker.go` — register real handlers (modify).
- `cmd/peppercheck/main.go` — wire services + stubs (modify).
- `db/schema/*.sql` (or the established Atlas schema dir) — new tables.

---

## Task 1: Core plumbing — `DBTX`, `WithTx`, `EnqueueInTx`, error helpers

**Files:**
- Create: `internal/core/database/tx.go`
- Test: `internal/core/database/tx_test.go`
- Modify: `internal/core/jobs/jobs.go` (add `EnqueueInTx`)
- Test: `internal/core/jobs/jobs_enqueue_intx_test.go`
- Modify: `internal/core/httpserver/errors.go` (add codes + `DecodeJSON`)
- Test: `internal/core/httpserver/errors_test.go`

**Interfaces:**
- Produces:
  - `type DBTX interface { ExecContext(ctx, query, args...) (sql.Result, error); QueryContext(...) (*sql.Rows, error); QueryRowContext(...) *sql.Row }`
  - `func WithTx(ctx context.Context, db *sql.DB, fn func(DBTX) error) error`
  - `func (s *jobs.Store) EnqueueInTx(ctx context.Context, tx database.DBTX, kind string, payload any, opts EnqueueOpts) (string, error)`
  - `httpserver.CodeNotFound="not_found"`, `CodeForbidden="forbidden"`, `CodeValidation="validation"`, `CodeConflict="conflict"`
  - `func httpserver.DecodeJSON(w, r, dst any) bool`

- [ ] **Step 1: Write the failing test for `WithTx` commit/rollback**

```go
// internal/core/database/tx_test.go
package database_test

import (
	"context"
	"database/sql"
	"errors"
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
)

func TestWithTxCommitsOnSuccess(t *testing.T) {
	db := testsupport.DB(t)
	_, _ = db.Exec(`CREATE TEMP TABLE tx_probe (n int)`)
	err := database.WithTx(context.Background(), db, func(tx database.DBTX) error {
		_, err := tx.ExecContext(context.Background(), `INSERT INTO tx_probe VALUES (1)`)
		return err
	})
	if err != nil {
		t.Fatalf("WithTx: %v", err)
	}
	var n int
	if err := db.QueryRow(`SELECT count(*) FROM tx_probe`).Scan(&n); err != nil || n != 1 {
		t.Fatalf("want 1 row, got n=%d err=%v", n, err)
	}
}

func TestWithTxRollsBackOnError(t *testing.T) {
	db := testsupport.DB(t)
	_, _ = db.Exec(`CREATE TEMP TABLE tx_probe2 (n int)`)
	sentinel := errors.New("boom")
	err := database.WithTx(context.Background(), db, func(tx database.DBTX) error {
		_, _ = tx.ExecContext(context.Background(), `INSERT INTO tx_probe2 VALUES (1)`)
		return sentinel
	})
	if !errors.Is(err, sentinel) {
		t.Fatalf("want sentinel, got %v", err)
	}
	var n int
	_ = db.QueryRow(`SELECT count(*) FROM tx_probe2`).Scan(&n)
	if n != 0 {
		t.Fatalf("want rollback (0 rows), got %d", n)
	}
	_ = sql.ErrNoRows
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `go test ./internal/core/database/ -run TestWithTx -v`
Expected: FAIL (undefined: `database.WithTx` / `database.DBTX`).

- [ ] **Step 3: Implement `DBTX` + `WithTx`**

```go
// internal/core/database/tx.go
package database

import (
	"context"
	"database/sql"
	"fmt"
)

// DBTX is the query surface shared by *sql.DB and *sql.Tx, so store methods can
// run either standalone or inside a caller-owned transaction.
type DBTX interface {
	ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error)
	QueryContext(ctx context.Context, query string, args ...any) (*sql.Rows, error)
	QueryRowContext(ctx context.Context, query string, args ...any) *sql.Row
}

// WithTx runs fn inside a single transaction, committing on nil error and
// rolling back on error or panic. It is the unit-of-work boundary used by
// application services that span more than one store.
func WithTx(ctx context.Context, db *sql.DB, fn func(DBTX) error) (err error) {
	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin: %w", err)
	}
	defer func() {
		if p := recover(); p != nil {
			_ = tx.Rollback()
			panic(p)
		}
		if err != nil {
			_ = tx.Rollback()
		}
	}()
	if err = fn(tx); err != nil {
		return err
	}
	if err = tx.Commit(); err != nil {
		return fmt.Errorf("commit: %w", err)
	}
	return nil
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `go test ./internal/core/database/ -run TestWithTx -v`
Expected: PASS.

- [ ] **Step 5: Write the failing test for `EnqueueInTx` (rolls back with the tx)**

```go
// internal/core/jobs/jobs_enqueue_intx_test.go
package jobs_test

import (
	"context"
	"errors"
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
	"github.com/cloveclovedev/peppercheck/backend/internal/core/jobs"
	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
)

func TestEnqueueInTxRollsBackWithTransaction(t *testing.T) {
	db := testsupport.DB(t)
	store := jobs.NewStore(db)
	before := countProbeJobs(t, db)

	_ = database.WithTx(context.Background(), db, func(tx database.Querier) error {
		if _, err := store.EnqueueInTx(context.Background(), tx, "probe_kind", map[string]any{"x": 1}, jobs.EnqueueOpts{}); err != nil {
			t.Fatalf("EnqueueInTx: %v", err)
		}
		return errors.New("force rollback")
	})

	if got := countProbeJobs(t, db); got != before {
		t.Fatalf("job survived rollback: before=%d after=%d", before, got)
	}
}

// countProbeJobs returns the number of probe_kind jobs currently in the queue.
func countProbeJobs(t *testing.T, db *sql.DB) int {
	t.Helper()
	var n int
	if err := db.QueryRow(`SELECT count(*) FROM public.jobs WHERE kind = 'probe_kind'`).Scan(&n); err != nil {
		t.Fatalf("count probe jobs: %v", err)
	}
	return n
}
```

> Import `database/sql` (for `*sql.DB`) and `errors` in this test file.

- [ ] **Step 6: Run to verify it fails**

Run: `go test ./internal/core/jobs/ -run TestEnqueueInTx -v`
Expected: FAIL (undefined `EnqueueInTx`).

- [ ] **Step 7: Implement `EnqueueInTx`** (refactor `Enqueue` to delegate)

```go
// internal/core/jobs/jobs.go  (add; keep existing Enqueue delegating here)
// EnqueueInTx inserts a job using the caller's transaction, so the enqueue
// commits or rolls back atomically with the caller's other writes (outbox).
func (s *Store) EnqueueInTx(ctx context.Context, tx interface {
	QueryRowContext(context.Context, string, ...any) *sql.Row
}, kind string, payload any, opts EnqueueOpts) (string, error) {
	raw, err := json.Marshal(payload)
	if err != nil {
		return "", fmt.Errorf("marshal payload: %w", err)
	}
	if opts.MaxAttempts == 0 {
		opts.MaxAttempts = 20
	}
	var runAt any
	if !opts.RunAt.IsZero() {
		runAt = opts.RunAt
	}
	var key any
	if opts.IdempotencyKey != "" {
		key = opts.IdempotencyKey
	}
	var id string
	err = tx.QueryRowContext(ctx, `
		INSERT INTO public.jobs (kind, payload, run_at, max_attempts, idempotency_key)
		VALUES ($1, $2, COALESCE($3, now()), $4, $5)
		ON CONFLICT (idempotency_key) DO NOTHING
		RETURNING id`,
		kind, raw, runAt, opts.MaxAttempts, key,
	).Scan(&id)
	if errors.Is(err, sql.ErrNoRows) {
		return "", nil
	}
	if err != nil {
		return "", fmt.Errorf("insert job in tx: %w", err)
	}
	return id, nil
}
```

- [ ] **Step 8: Run to verify it passes**

Run: `go test ./internal/core/jobs/ -run TestEnqueueInTx -v`
Expected: PASS.

- [ ] **Step 9: Add error codes + `DecodeJSON` helper**

```go
// internal/core/httpserver/errors.go  (add to the const block)
const (
	CodeNotFound   = "not_found"  // 404
	CodeForbidden  = "forbidden"  // 403
	CodeValidation = "validation" // 400/422: request failed validation
	CodeConflict   = "conflict"   // 409
)

// DecodeJSON decodes the request body into dst, rejecting unknown fields. On
// failure it writes a 400 validation envelope and returns false.
func DecodeJSON(w http.ResponseWriter, r *http.Request, dst any) bool {
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(dst); err != nil {
		WriteError(w, r, http.StatusBadRequest, CodeValidation, "invalid request body")
		return false
	}
	return true
}
```

- [ ] **Step 10: Add a unit test for `DecodeJSON` (rejects unknown fields) and run**

```go
// internal/core/httpserver/errors_test.go  (add)
func TestDecodeJSONRejectsUnknownFields(t *testing.T) {
	r := httptest.NewRequest("POST", "/", strings.NewReader(`{"nope":1}`))
	w := httptest.NewRecorder()
	var dst struct{ Name string `json:"name"` }
	if httpserver.DecodeJSON(w, r, &dst) {
		t.Fatal("want false for unknown field")
	}
	if w.Code != http.StatusBadRequest {
		t.Fatalf("want 400, got %d", w.Code)
	}
}
```

Run: `go test ./internal/core/httpserver/ -run TestDecodeJSON -v` → PASS.

- [ ] **Step 11: Commit**

```bash
gofmt -w ./internal/core && go vet ./internal/core/... && go test ./internal/core/...
git add internal/core
git commit -m "feat(backend): add DBTX/WithTx, jobs.EnqueueInTx, and http error helpers"
```

---

## Task 2: Schema & migrations (tables, enums, seed)

**Files:**
- Create: Atlas schema files for the new tables (follow the established Phase 1 schema layout, e.g. `db/schema/task.sql`, `db/schema/matching.sql`, `db/schema/judgement.sql`).
- Create/Modify: the config seed for `matching_config`.
- Test: `internal/matching/schema_test.go` (integration: tables/constraints exist, apply-to-empty).

**Interfaces:**
- Produces tables: `tasks`, `referee_requests`, `judgements`, `referee_available_time_slots`, `referee_blocked_dates`, `referee_availability`, `matching_config`; enums `task_status`, `matching_strategy`, `referee_request_status`, `judgement_status`, `evidence`/`point_source_type` as needed (only what 4a uses — `point_source_type` may already exist from a shared enum; if not, add `regular`/`trial`).

- [ ] **Step 1: Write the schema SQL** (declarative, table-only)

```sql
-- tasks
CREATE TYPE public.task_status AS ENUM ('draft', 'open', 'closed');
CREATE TABLE public.tasks (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tasker_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
    title text NOT NULL,
    description text,
    criteria text,
    due_date timestamptz,
    status public.task_status NOT NULL DEFAULT 'draft',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_tasks_tasker_status ON public.tasks (tasker_id, status);

-- referee_requests
CREATE TYPE public.matching_strategy AS ENUM ('standard');
CREATE TYPE public.referee_request_status AS ENUM
    ('pending', 'accepted', 'expired', 'cancelled', 'closed', 'payment_processing');
CREATE TYPE public.point_source_type AS ENUM ('regular', 'trial'); -- if not already present
CREATE TABLE public.referee_requests (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id uuid NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    matching_strategy public.matching_strategy NOT NULL DEFAULT 'standard',
    status public.referee_request_status NOT NULL DEFAULT 'pending',
    matched_referee_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
    responded_at timestamptz,
    point_source public.point_source_type NOT NULL DEFAULT 'regular',
    is_obligation boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_referee_requests_task ON public.referee_requests (task_id);
CREATE INDEX idx_referee_requests_status ON public.referee_requests (status);
CREATE INDEX idx_referee_requests_matched ON public.referee_requests (matched_referee_id);
-- Concurrency guard (P4a-D16): one referee cannot be accepted twice on a task.
CREATE UNIQUE INDEX uq_referee_requests_task_accepted_referee
    ON public.referee_requests (task_id, matched_referee_id)
    WHERE status = 'accepted' AND matched_referee_id IS NOT NULL;

-- judgements (row created by matching; lifecycle in 4c)
CREATE TYPE public.judgement_status AS ENUM
    ('awaiting_evidence', 'in_review', 'approved', 'rejected', 'review_timeout', 'evidence_timeout');
CREATE TABLE public.judgements (
    id uuid PRIMARY KEY REFERENCES public.referee_requests(id) ON DELETE CASCADE,
    status public.judgement_status NOT NULL DEFAULT 'awaiting_evidence',
    comment text,
    is_confirmed boolean NOT NULL DEFAULT false,
    is_auto_confirmed boolean NOT NULL DEFAULT false,
    reopen_count smallint NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- availability
CREATE TABLE public.referee_available_time_slots (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    dow smallint NOT NULL CHECK (dow BETWEEN 0 AND 6),
    start_min smallint NOT NULL CHECK (start_min BETWEEN 0 AND 1439),
    end_min smallint NOT NULL CHECK (end_min BETWEEN 1 AND 1440),
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT valid_time_range CHECK (start_min < end_min),
    UNIQUE (user_id, dow, start_min)
);
CREATE INDEX idx_ravts_user ON public.referee_available_time_slots (user_id);
CREATE INDEX idx_ravts_dow_time ON public.referee_available_time_slots (dow, start_min, end_min) WHERE is_active;

CREATE TABLE public.referee_blocked_dates (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    start_date date NOT NULL,
    end_date date NOT NULL,
    reason text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT valid_date_range CHECK (end_date >= start_date)
);
CREATE INDEX idx_rbd_user ON public.referee_blocked_dates (user_id);

-- per-referee availability knobs (forward-build; edit UI later)
CREATE TABLE public.referee_availability (
    user_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    is_accepting boolean NOT NULL DEFAULT true,
    max_concurrent_assignments int,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- typed matching config (singleton)
CREATE TABLE public.matching_config (
    id boolean PRIMARY KEY DEFAULT true CHECK (id = true),
    open_deadline_hours int NOT NULL,
    cancel_deadline_hours int NOT NULL CHECK (cancel_deadline_hours > 0),
    rematch_cutoff_hours int NOT NULL,
    max_referees_per_task int NOT NULL DEFAULT 2 CHECK (max_referees_per_task >= 1),
    point_cost_per_request int NOT NULL DEFAULT 1 CHECK (point_cost_per_request >= 0),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ordering_invariant CHECK (open_deadline_hours > rematch_cutoff_hours
        AND rematch_cutoff_hours > cancel_deadline_hours)
);
```

> **`updated_at` writes (P4a-D15):** every mutable Store `UPDATE` and
> `ON CONFLICT DO UPDATE` for the tables above explicitly sets
> `updated_at = now()`. Inserts rely on `DEFAULT now()`. Add focused Store
> integration coverage for update and upsert paths; do not add a function or
> trigger.

- [ ] **Step 2: Register the schema files in Atlas config and generate the migration**

Run the pinned Atlas migration-diff workflow (as in Phase 1). Review the generated migration. Add the seed as a DML line (not captured by schema diff):

```sql
-- DML, not detected by schema diff. Values are the current production
-- matching_time_config: open=24 > rematch=14 > cancel=12 (ordering invariant).
INSERT INTO public.matching_config (id, open_deadline_hours, cancel_deadline_hours, rematch_cutoff_hours)
VALUES (true, 24, 12, 14)
ON CONFLICT (id) DO NOTHING;
```

- [ ] **Step 3: Write the integration test (apply-to-empty + constraints)**

```go
// internal/matching/schema_test.go
package matching_test

import (
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
)

func TestMatchingConfigOrderingInvariant(t *testing.T) {
	db := testsupport.DB(t)
	// invalid ordering must be rejected
	_, err := db.Exec(`INSERT INTO public.matching_config
		(id, open_deadline_hours, cancel_deadline_hours, rematch_cutoff_hours)
		VALUES (true, 1, 2, 3)
		ON CONFLICT (id) DO UPDATE SET open_deadline_hours = 1, cancel_deadline_hours = 2, rematch_cutoff_hours = 3`)
	if err == nil {
		t.Fatal("expected ordering_invariant violation")
	}
}

func TestRefereeRequestsForeignKeys(t *testing.T) {
	db := testsupport.DB(t)
	_, err := db.Exec(`INSERT INTO public.referee_requests (task_id) VALUES (gen_random_uuid())`)
	if err == nil {
		t.Fatal("expected FK violation for missing task")
	}
}
```

- [ ] **Step 4: Run migrations against the test DB, then run the tests**

Run: `make migrate` (or the Phase 1 apply-to-empty target), then
`go test ./internal/matching/ -run 'TestMatchingConfig|TestRefereeRequests' -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add db/ internal/matching/schema_test.go
git commit -m "feat(backend): Phase 4a schema — tasks, referee_requests, judgements, availability, matching_config"
```

---

## Task 3: Phase 5 seams (`PointLocker`, `ObligationChecker`) + no-op stubs

**Files:**
- Create: `internal/matching/seams.go` (interfaces + no-op stubs)
- Test: `internal/matching/seams_test.go`

**Interfaces:**
- Produces:
  - `type PointLocker interface { LockInTx(ctx, tx database.DBTX, userID uuid.UUID, cost int, taskID uuid.UUID) error; RefundInTx(ctx, tx database.DBTX, requestID uuid.UUID, cost int, reason string) error }`
  - `type ObligationChecker interface { FilterObligated(ctx context.Context, candidateIDs []uuid.UUID) ([]uuid.UUID, error) }`
  - `func NewNoopPointLocker() PointLocker`
  - `func NewNoObligations() ObligationChecker`

- [ ] **Step 1: Write the failing test**

```go
// internal/matching/seams_test.go
package matching_test

import (
	"context"
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/matching"
	"github.com/google/uuid"
)

func TestNoopPointLockerSucceeds(t *testing.T) {
	pl := matching.NewNoopPointLocker()
	src, err := pl.LockForRequestInTx(context.Background(), nil, uuid.New(), uuid.New(), 1)
	if err != nil || src != "regular" {
		t.Fatalf("noop lock should return (\"regular\", nil), got (%q, %v)", src, err)
	}
}

func TestNoObligationsReturnsEmpty(t *testing.T) {
	oc := matching.NewNoObligations()
	got, err := oc.FilterObligated(context.Background(), []uuid.UUID{uuid.New()})
	if err != nil || len(got) != 0 {
		t.Fatalf("want empty, got %v err %v", got, err)
	}
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `go test ./internal/matching/ -run 'Noop|NoObligations' -v` → FAIL (undefined).

- [ ] **Step 3: Implement seams + stubs**

```go
// internal/matching/seams.go
package matching

import (
	"context"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
	"github.com/google/uuid"
)

// PointLocker reserves and refunds matching points PER REQUEST, returning a
// funding-source receipt (P4a-D17) so Phase 5 is a pure wiring swap. The real
// implementation arrives in Phase 5; 4a wires a no-op.
type PointLocker interface {
	// LockForRequestInTx reserves cost points for one request and returns the
	// funding source recorded on that request's point_source.
	LockForRequestInTx(ctx context.Context, tx database.Querier, taskerID, requestID uuid.UUID, cost int) (pointSource string, err error)
	// RefundForRequestInTx idempotently reverses the lock, keyed by requestID.
	RefundForRequestInTx(ctx context.Context, tx database.Querier, requestID uuid.UUID, reason string) error
}

// ObligationChecker returns which candidate referees have a pending obligation.
// Phase 5 supplies the real implementation; 4a returns none.
type ObligationChecker interface {
	FilterObligated(ctx context.Context, candidateIDs []uuid.UUID) ([]uuid.UUID, error)
}

type noopPointLocker struct{}

func NewNoopPointLocker() PointLocker { return noopPointLocker{} }
func (noopPointLocker) LockForRequestInTx(context.Context, database.Querier, uuid.UUID, uuid.UUID, int) (string, error) {
	return "regular", nil
}
func (noopPointLocker) RefundForRequestInTx(context.Context, database.Querier, uuid.UUID, string) error {
	return nil
}

type noObligations struct{}

func NewNoObligations() ObligationChecker { return noObligations{} }
func (noObligations) FilterObligated(_ context.Context, _ []uuid.UUID) ([]uuid.UUID, error) {
	return nil, nil
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `go test ./internal/matching/ -run 'Noop|NoObligations' -v` → PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/matching/seams.go internal/matching/seams_test.go
git commit -m "feat(backend): Phase 5 matching seams (PointLocker, ObligationChecker) with no-op stubs"
```

---

## Task 4: `judgement` minimal provisioner (create/delete awaiting_evidence)

**Files:**
- Create: `internal/judgement/domain.go`, `internal/judgement/store.go`
- Test: `internal/judgement/store_test.go`

**Interfaces:**
- Produces:
  - `type Provisioner struct{}` with `CreateAwaitingEvidenceInTx(ctx, tx database.DBTX, requestID uuid.UUID) error`
  - `DeleteIfAwaitingEvidenceInTx(ctx, tx database.DBTX, requestID uuid.UUID) (deleted bool, err error)`

- [ ] **Step 1: Write the failing integration test**

```go
// internal/judgement/store_test.go
package judgement_test

import (
	"context"
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
	"github.com/cloveclovedev/peppercheck/backend/internal/judgement"
	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
	"github.com/google/uuid"
)

func TestCreateAndDeleteAwaitingEvidence(t *testing.T) {
	db := testsupport.DB(t)
	p := judgement.NewProvisioner()
	reqID := seedRequest(t, db) // helper inserts a user, task, referee_request; returns request id

	ctx := context.Background()
	err := database.WithTx(ctx, db, func(tx database.DBTX) error {
		return p.CreateAwaitingEvidenceInTx(ctx, tx, reqID)
	})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	var status string
	if err := db.QueryRow(`SELECT status FROM public.judgements WHERE id=$1`, reqID).Scan(&status); err != nil {
		t.Fatalf("scan: %v", err)
	}
	if status != "awaiting_evidence" {
		t.Fatalf("want awaiting_evidence, got %s", status)
	}

	var deleted bool
	_ = database.WithTx(ctx, db, func(tx database.DBTX) error {
		var e error
		deleted, e = p.DeleteIfAwaitingEvidenceInTx(ctx, tx, reqID)
		return e
	})
	if !deleted {
		t.Fatal("want deleted=true")
	}
	_ = uuid.Nil
}
```

> Provide `seedRequest(t, db)` in a shared test helper: insert `users DEFAULT VALUES`, a `tasks` row (tasker = that user), and a `referee_requests` row for the task; return the request id.

- [ ] **Step 2: Run to verify it fails**

Run: `go test ./internal/judgement/ -v` → FAIL (undefined).

- [ ] **Step 3: Implement domain + provisioner**

```go
// internal/judgement/domain.go
package judgement

// StatusAwaitingEvidence is the only status 4a writes; the rest arrive in 4c.
const StatusAwaitingEvidence = "awaiting_evidence"
```

```go
// internal/judgement/store.go
package judgement

import (
	"context"
	"fmt"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
	"github.com/google/uuid"
)

// Provisioner creates and removes the awaiting_evidence judgement row keyed 1:1
// to a referee request. The full judgement lifecycle is Phase 4c.
type Provisioner struct{}

func NewProvisioner() *Provisioner { return &Provisioner{} }

// CreateAwaitingEvidenceInTx inserts the judgement row for a matched request.
// The PK = request id makes a duplicate insert a conflict (idempotent caller).
func (p *Provisioner) CreateAwaitingEvidenceInTx(ctx context.Context, tx database.DBTX, requestID uuid.UUID) error {
	_, err := tx.ExecContext(ctx,
		`INSERT INTO public.judgements (id, status) VALUES ($1, $2)
		 ON CONFLICT (id) DO NOTHING`,
		requestID, StatusAwaitingEvidence)
	if err != nil {
		return fmt.Errorf("insert judgement: %w", err)
	}
	return nil
}

// DeleteIfAwaitingEvidenceInTx removes the judgement only while it is still
// awaiting_evidence (used by cancel). Returns whether a row was deleted.
func (p *Provisioner) DeleteIfAwaitingEvidenceInTx(ctx context.Context, tx database.DBTX, requestID uuid.UUID) (bool, error) {
	res, err := tx.ExecContext(ctx,
		`DELETE FROM public.judgements WHERE id = $1 AND status = $2`,
		requestID, StatusAwaitingEvidence)
	if err != nil {
		return false, fmt.Errorf("delete judgement: %w", err)
	}
	n, _ := res.RowsAffected()
	return n > 0, nil
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `go test ./internal/judgement/ -v` → PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/judgement
git commit -m "feat(backend): judgement provisioner for awaiting_evidence (4a minimal)"
```

---

## Task 5: `platform/fcm` — Firebase messaging adapter

> **Consult the official Firebase Admin SDK Go docs first** (`firebase.google.com/go/v4/messaging`): confirm the current API for loc-key notifications (`AndroidNotification.TitleLocKey`/`BodyLocKey`/`TitleLocArgs`; APNS `aps.alert.title-loc-key`), multicast send (`SendEach`/`SendEachForMulticast`), and how invalid tokens are reported (`messaging.IsUnregistered`, `IsInvalidArgument` on per-message errors). Code the adapter against what the docs show, not memory.

> **Operator/infra requirement (P4a-D18) — 4a-owned, no 7a doc change.** FCM
> sending needs a Firebase service-account credential (unlike Phase 2 token
> verification, which uses `WithoutAuthentication`). **Assume** Phase 7a delivers
> secrets as Docker file-based secrets rendered from BWS to the `worker`
> container. **This phase must:** provision a worker-only, least-privilege
> service account (Firebase Cloud Messaging only), add it to BWS, deliver it
> through 7a's file-secret path, and set `GOOGLE_APPLICATION_CREDENTIALS` to that
> file for the worker so the Admin SDK uses Application Default Credentials. Do
> NOT edit the 7a design; 7a's §6.3 inventory predates this need. Ref:
> `firebase.google.com/docs/admin/setup`. The `api` container does not need this
> secret (it never sends FCM).

**Files:**
- Create: `internal/platform/fcm/fcm.go`
- Test: `internal/platform/fcm/fcm_test.go` (unit: message construction; the network send path is exercised via the `Sender` seam with a fake)

**Interfaces:**
- Produces:
  - `type Message struct { TitleLocKey, BodyLocKey string; LocArgs []string; Data map[string]string }`
  - `type SendResult struct { InvalidTokens []string }`
  - `type Client interface { Send(ctx context.Context, tokens []string, msg Message) (SendResult, error) }`
  - `func New(ctx context.Context, projectID string) (Client, error)`
  - Internally split so the message-building is a pure function unit-tested without Firebase.

- [ ] **Step 1: Write the failing unit test for message building**

```go
// internal/platform/fcm/fcm_test.go
package fcm

import "testing"

func TestBuildMulticastUsesLocKeys(t *testing.T) {
	msg := Message{TitleLocKey: "notification_task_assigned_referee_title",
		BodyLocKey: "notification_task_assigned_referee_body",
		LocArgs:    []string{"Wash the car"}, Data: map[string]string{"route": "/tasks/1"}}
	mm := buildMulticast([]string{"tok1", "tok2"}, msg)
	if len(mm.Tokens) != 2 {
		t.Fatalf("want 2 tokens, got %d", len(mm.Tokens))
	}
	if mm.Android.Notification.TitleLocKey != msg.TitleLocKey {
		t.Fatalf("android title loc key not set")
	}
	if mm.APNS == nil {
		t.Fatal("APNS payload missing")
	}
}
```

> `buildMulticast` returns the `*messaging.MulticastMessage` (unexported helper). The exact field paths (Android vs APNS loc keys) come from the SDK docs — adjust the assertion field names to the real API.

- [ ] **Step 2: Run to verify it fails**

Run: `go test ./internal/platform/fcm/ -run TestBuildMulticast -v` → FAIL.

- [ ] **Step 3: Implement the adapter** (message builder + Firebase-backed `Client`)

```go
// internal/platform/fcm/fcm.go
package fcm

import (
	"context"
	"fmt"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
)

type Message struct {
	TitleLocKey string
	BodyLocKey  string
	LocArgs     []string
	Data        map[string]string
}

type SendResult struct{ InvalidTokens []string }

type Client interface {
	Send(ctx context.Context, tokens []string, msg Message) (SendResult, error)
}

type client struct{ msg *messaging.Client }

// New builds an FCM client from application default credentials for projectID.
func New(ctx context.Context, projectID string) (Client, error) {
	app, err := firebase.NewApp(ctx, &firebase.Config{ProjectID: projectID})
	if err != nil {
		return nil, fmt.Errorf("firebase app: %w", err)
	}
	m, err := app.Messaging(ctx)
	if err != nil {
		return nil, fmt.Errorf("messaging client: %w", err)
	}
	return &client{msg: m}, nil
}

// buildMulticast builds a loc-key multicast message for Android and iOS.
// Verify the exact loc-key field paths against the SDK docs before relying on this.
func buildMulticast(tokens []string, m Message) *messaging.MulticastMessage {
	return &messaging.MulticastMessage{
		Tokens: tokens,
		Data:   m.Data,
		Android: &messaging.AndroidConfig{
			Notification: &messaging.AndroidNotification{
				TitleLocKey: m.TitleLocKey, TitleLocArgs: m.LocArgs,
				BodyLocKey: m.BodyLocKey, BodyLocArgs: m.LocArgs,
			},
		},
		APNS: &messaging.APNSConfig{
			Payload: &messaging.APNSPayload{Aps: &messaging.Aps{
				Alert: &messaging.ApsAlert{
					TitleLocKey: m.TitleLocKey, TitleLocArgs: m.LocArgs,
					LocKey: m.BodyLocKey, LocArgs: m.LocArgs,
				},
			}},
		},
	}
}

func (c *client) Send(ctx context.Context, tokens []string, m Message) (SendResult, error) {
	if len(tokens) == 0 {
		return SendResult{}, nil
	}
	resp, err := c.msg.SendEachForMulticast(ctx, buildMulticast(tokens, m))
	if err != nil {
		return SendResult{}, fmt.Errorf("fcm send: %w", err)
	}
	var invalid []string
	for i, r := range resp.Responses {
		if r.Error != nil && (messaging.IsUnregistered(r.Error) || messaging.IsInvalidArgument(r.Error)) {
			invalid = append(invalid, tokens[i])
		}
	}
	return SendResult{InvalidTokens: invalid}, nil
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `go test ./internal/platform/fcm/ -run TestBuildMulticast -v` → PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/platform/fcm
git commit -m "feat(backend): platform/fcm Firebase messaging adapter with loc-key multicast"
```

---

## Task 6: Notification send path (`Enqueue` outbox + `send_notification` worker)

**Files:**
- Create: `internal/notification/domain.go`, `internal/notification/service.go`, `internal/notification/store.go`, `internal/notification/worker.go` (extend the 3a `notification` package; if 3a already defines `store.go`, add methods there)
- Test: `internal/notification/worker_test.go`

**Interfaces:**
- Consumes: `fcm.Client`; `jobs.Store.EnqueueInTx`; `user_fcm_tokens` (3a).
- Produces:
  - `func (s *Service) EnqueueInTx(ctx, tx database.DBTX, userID uuid.UUID, keyBase string, args []string, data map[string]string) error`
  - `func (s *Service) HandleSend(ctx context.Context, j *jobs.Job) error` (worker handler for kind `send_notification`)
  - `const JobKindSendNotification = "send_notification"`
  - payload type `sendPayload{ UserID string; KeyBase string; Args []string; Data map[string]string }`

- [ ] **Step 1: Write the failing worker test with a fake FCM client**

```go
// internal/notification/worker_test.go
package notification_test

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/jobs"
	"github.com/cloveclovedev/peppercheck/backend/internal/notification"
	"github.com/cloveclovedev/peppercheck/backend/internal/platform/fcm"
	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
	"github.com/google/uuid"
)

type fakeFCM struct {
	gotTokens []string
	invalid   []string
}

func (f *fakeFCM) Send(_ context.Context, tokens []string, _ fcm.Message) (fcm.SendResult, error) {
	f.gotTokens = tokens
	return fcm.SendResult{InvalidTokens: f.invalid}, nil
}

func TestHandleSendDeliversAndCleansInvalidTokens(t *testing.T) {
	db := testsupport.DB(t)
	userID := seedUserWithTokens(t, db, "good-token", "bad-token") // helper
	fake := &fakeFCM{invalid: []string{"bad-token"}}
	svc := notification.NewService(notification.NewStore(db), fake)

	payload, _ := json.Marshal(map[string]any{
		"userId": userID.String(), "keyBase": "notification_task_assigned_referee",
		"args": []string{"Wash the car"}, "data": map[string]string{"route": "/tasks/1"},
	})
	if err := svc.HandleSend(context.Background(), &jobs.Job{Kind: notification.JobKindSendNotification, Payload: payload}); err != nil {
		t.Fatalf("HandleSend: %v", err)
	}
	if len(fake.gotTokens) != 2 {
		t.Fatalf("want 2 tokens sent, got %d", len(fake.gotTokens))
	}
	var remaining int
	_ = db.QueryRow(`SELECT count(*) FROM public.user_fcm_tokens WHERE user_id=$1`, userID).Scan(&remaining)
	if remaining != 1 {
		t.Fatalf("want invalid token pruned (1 left), got %d", remaining)
	}
	_ = uuid.Nil
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `go test ./internal/notification/ -run TestHandleSend -v` → FAIL.

- [ ] **Step 3: Implement service, store methods, worker handler**

```go
// internal/notification/service.go  (add; keep 3a's registration service intact)
package notification

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
	"github.com/cloveclovedev/peppercheck/backend/internal/core/jobs"
	"github.com/cloveclovedev/peppercheck/backend/internal/platform/fcm"
	"github.com/google/uuid"
)

const JobKindSendNotification = "send_notification"

type sendStore interface {
	TokensForUser(ctx context.Context, userID uuid.UUID) ([]string, error)
	DeleteTokens(ctx context.Context, userID uuid.UUID, tokens []string) error
	EnqueueSendInTx(ctx context.Context, tx database.DBTX, kind string, payload any) error
}

type Service struct {
	store sendStore
	fcm   fcm.Client
}

func NewService(store sendStore, client fcm.Client) *Service {
	return &Service{store: store, fcm: client}
}

type sendPayload struct {
	UserID  string            `json:"userId"`
	KeyBase string            `json:"keyBase"`
	Args    []string          `json:"args"`
	Data    map[string]string `json:"data"`
}

// EnqueueInTx writes a send_notification job into the caller's transaction
// (transactional outbox) so the notification rides the caller's commit.
func (s *Service) EnqueueInTx(ctx context.Context, tx database.DBTX, userID uuid.UUID, keyBase string, args []string, data map[string]string) error {
	return s.store.EnqueueSendInTx(ctx, tx, JobKindSendNotification, sendPayload{
		UserID: userID.String(), KeyBase: keyBase, Args: args, Data: data,
	})
}

// HandleSend is the worker handler: load tokens, send via FCM (loc keys), prune
// invalid tokens. At-least-once safe; a duplicate delivery is a duplicate push.
func (s *Service) HandleSend(ctx context.Context, j *jobs.Job) error {
	var p sendPayload
	if err := json.Unmarshal(j.Payload, &p); err != nil {
		return fmt.Errorf("unmarshal send payload: %w", err)
	}
	userID, err := uuid.Parse(p.UserID)
	if err != nil {
		return fmt.Errorf("parse user id: %w", err)
	}
	tokens, err := s.store.TokensForUser(ctx, userID)
	if err != nil {
		return err
	}
	res, err := s.fcm.Send(ctx, tokens, fcm.Message{
		TitleLocKey: p.KeyBase + "_title",
		BodyLocKey:  p.KeyBase + "_body",
		LocArgs:     p.Args,
		Data:        p.Data,
	})
	if err != nil {
		return err
	}
	if len(res.InvalidTokens) > 0 {
		if err := s.store.DeleteTokens(ctx, userID, res.InvalidTokens); err != nil {
			return err
		}
	}
	return nil
}
```

```go
// internal/notification/store.go  (add these methods to the 3a store)
func (s *Store) TokensForUser(ctx context.Context, userID uuid.UUID) ([]string, error) {
	rows, err := s.db.QueryContext(ctx,
		`SELECT token FROM public.user_fcm_tokens WHERE user_id = $1`, userID)
	if err != nil {
		return nil, fmt.Errorf("query tokens: %w", err)
	}
	defer rows.Close()
	var out []string
	for rows.Next() {
		var t string
		if err := rows.Scan(&t); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

func (s *Store) DeleteTokens(ctx context.Context, userID uuid.UUID, tokens []string) error {
	_, err := s.db.ExecContext(ctx,
		`DELETE FROM public.user_fcm_tokens WHERE user_id = $1 AND token = ANY($2)`,
		userID, pq.Array(tokens)) // or pgx array encoding; verify the driver's array support
	if err != nil {
		return fmt.Errorf("delete tokens: %w", err)
	}
	return nil
}

func (s *Store) EnqueueSendInTx(ctx context.Context, tx database.DBTX, kind string, payload any) error {
	_, err := jobs.NewStore(s.db).EnqueueInTx(ctx, tx, kind, payload, jobs.EnqueueOpts{})
	return err
}
```

> Use the pgx-native array binding for `token = ANY($2)` rather than `lib/pq`; confirm the array-encoding approach against the pgx stdlib driver docs. Adjust the import accordingly.

- [ ] **Step 4: Run to verify it passes**

Run: `go test ./internal/notification/ -run TestHandleSend -v` → PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/notification
git commit -m "feat(backend): notification send path — outbox enqueue + send_notification worker + invalid-token cleanup"
```

---

## Task 7: Matching store, domain, and candidate selection

**Files:**
- Create: `internal/matching/domain.go`, `internal/matching/store.go`
- Test: `internal/matching/store_test.go`

**Interfaces:**
- Produces:
  - `type RefereeRequest struct { ID, TaskID, MatchedRefereeID uuid.UUID/uuid.NullUUID; Status string; ... }`
  - `type Config struct { OpenDeadlineHours, CancelDeadlineHours, RematchCutoffHours, MaxRefereesPerTask, PointCostPerRequest int }`
  - `func (s *Store) LoadConfig(ctx) (Config, error)`
  - `func (s *Store) InsertRequestInTx(ctx, tx, taskID uuid.UUID) (uuid.UUID, error)`
  - `func (s *Store) CandidateReferees(ctx, tx database.DBTX, requestID uuid.UUID) ([]uuid.UUID, error)` — runs the full exclusion + least-workload query and returns the least-workload candidate set (obligation priority is applied by the service using `ObligationChecker`).
  - `func (s *Store) MarkAcceptedInTx(ctx, tx, requestID, refereeID uuid.UUID, isObligation bool) (accepted bool, err error)` — CAS on `status='pending'`.

- [ ] **Step 1: Write the failing candidate-selection integration test**

```go
// internal/matching/store_test.go
// Seeds: a task due at a known instant; referee A available at that dow/time
// (accepting, workload 0); referee B blocked on the due date; referee C
// not accepting. Expects CandidateReferees == [A].
func TestCandidateRefereesAppliesExclusions(t *testing.T) {
	db := testsupport.DB(t)
	s := matching.NewStore(db)
	reqID, wantA := seedMatchingScenario(t, db) // helper builds the scenario, returns request id + referee A id
	got, err := s.CandidateReferees(context.Background(), db, reqID)
	if err != nil {
		t.Fatalf("candidates: %v", err)
	}
	if len(got) != 1 || got[0] != wantA {
		t.Fatalf("want [A], got %v", got)
	}
}
```

> `seedMatchingScenario` must create: `users` for tasker + A/B/C; `profiles` with a timezone; `referee_available_time_slots` for A and C covering the due time; a `referee_blocked_dates` row for B over the due date; `referee_availability` with `is_accepting=false` for C; the task + a pending `referee_requests` row. Return `(requestID, refereeAID)`.

- [ ] **Step 2: Run to verify it fails**

Run: `go test ./internal/matching/ -run TestCandidateReferees -v` → FAIL.

- [ ] **Step 3: Implement domain + store, porting the candidate query**

```go
// internal/matching/store.go  (CandidateReferees — the ported algorithm, steps 1-2 of the spec)
func (s *Store) CandidateReferees(ctx context.Context, tx database.DBTX, requestID uuid.UUID) ([]uuid.UUID, error) {
	rows, err := tx.QueryContext(ctx, `
WITH req AS (
  SELECT rr.id, rr.task_id, t.tasker_id, t.due_date
  FROM public.referee_requests rr
  JOIN public.tasks t ON t.id = rr.task_id
  WHERE rr.id = $1
),
available AS (
  SELECT DISTINCT s.user_id AS referee_id
  FROM public.referee_available_time_slots s
  JOIN req ON true
  JOIN public.profiles p ON p.id = s.user_id
  LEFT JOIN public.referee_availability ra ON ra.user_id = s.user_id
  WHERE s.is_active
    AND s.user_id <> req.tasker_id
    AND COALESCE(ra.is_accepting, true)
    -- due date in the referee's timezone: matching dow + minute window
    AND EXTRACT(DOW FROM (req.due_date AT TIME ZONE COALESCE(p.timezone, 'UTC'))) = s.dow
    AND (EXTRACT(HOUR FROM (req.due_date AT TIME ZONE COALESCE(p.timezone, 'UTC'))) * 60
       + EXTRACT(MINUTE FROM (req.due_date AT TIME ZONE COALESCE(p.timezone, 'UTC')))) BETWEEN s.start_min AND s.end_min
    -- not blocked on the due date
    AND NOT EXISTS (
      SELECT 1 FROM public.referee_blocked_dates b
      WHERE b.user_id = s.user_id
        AND (req.due_date AT TIME ZONE COALESCE(p.timezone, 'UTC'))::date BETWEEN b.start_date AND b.end_date)
    -- did not previously cancel on this task
    AND NOT EXISTS (
      SELECT 1 FROM public.referee_requests c
      WHERE c.task_id = req.task_id AND c.status = 'cancelled' AND c.matched_referee_id = s.user_id)
    -- not already active on this task (multi-referee)
    AND NOT EXISTS (
      SELECT 1 FROM public.referee_requests a
      WHERE a.task_id = req.task_id AND a.status IN ('pending','accepted')
        AND a.matched_referee_id = s.user_id)
),
workloads AS (
  SELECT a.referee_id,
         COUNT(j.id) FILTER (WHERE j.status IN ('awaiting_evidence','in_review','rejected','review_timeout')) AS wl
  FROM available a
  LEFT JOIN public.referee_requests rr2 ON rr2.matched_referee_id = a.referee_id AND rr2.status IN ('accepted')
  LEFT JOIN public.judgements j ON j.id = rr2.id
  LEFT JOIN public.referee_availability ra ON ra.user_id = a.referee_id
  GROUP BY a.referee_id, ra.max_concurrent_assignments
  HAVING ra.max_concurrent_assignments IS NULL
      OR COUNT(j.id) FILTER (WHERE j.status IN ('awaiting_evidence','in_review','rejected','review_timeout')) < ra.max_concurrent_assignments
)
SELECT referee_id FROM workloads
WHERE wl = (SELECT MIN(wl) FROM workloads)`, requestID)
	if err != nil {
		return nil, fmt.Errorf("candidate query: %w", err)
	}
	defer rows.Close()
	var out []uuid.UUID
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		out = append(out, id)
	}
	return out, rows.Err()
}
```

```go
// internal/matching/store.go  (InsertRequestInTx, MarkAcceptedInTx, LoadConfig)
func (s *Store) InsertRequestInTx(ctx context.Context, tx database.DBTX, taskID uuid.UUID) (uuid.UUID, error) {
	var id uuid.UUID
	err := tx.QueryRowContext(ctx,
		`INSERT INTO public.referee_requests (task_id) VALUES ($1) RETURNING id`, taskID).Scan(&id)
	if err != nil {
		return uuid.Nil, fmt.Errorf("insert request: %w", err)
	}
	return id, nil
}

// MarkAcceptedInTx transitions a request pending->accepted only if it is still
// pending AND its task is still within the matching window (due_date is more
// than rematch_cutoff_hours away). The cutoff guard is in the UPDATE itself so a
// match job that runs late — e.g. after a worker outage crossed the cutoff —
// cannot assign a referee to a request the sweep should expire (re-review #1);
// when it affects 0 rows the caller leaves the request pending and the sweep
// expires + refunds it. This UPDATE also sets updated_at = now(). A
// same-task double-assignment (two requests, same referee) trips the partial
// unique index (P4a-D16); the caller distinguishes ErrRefereeTaken.
func (s *Store) MarkAcceptedInTx(ctx context.Context, tx database.Querier, requestID, refereeID uuid.UUID, isObligation bool) (bool, error) {
	res, err := tx.ExecContext(ctx, `
		UPDATE public.referee_requests r
		SET status = 'accepted', matched_referee_id = $2, is_obligation = $3,
		    responded_at = now(), updated_at = now()
		FROM public.tasks t, public.matching_config c
		WHERE r.id = $1 AND r.status = 'pending'
		  AND t.id = r.task_id AND c.id = true
		  AND t.due_date > now() + make_interval(hours => c.rematch_cutoff_hours)`,
		requestID, refereeID, isObligation)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" { // same-task unique index
			return false, ErrRefereeTaken
		}
		return false, fmt.Errorf("mark accepted: %w", err)
	}
	n, _ := res.RowsAffected()
	return n == 1, nil
}

func (s *Store) LoadConfig(ctx context.Context) (Config, error) {
	var c Config
	err := s.db.QueryRowContext(ctx, `
		SELECT open_deadline_hours, cancel_deadline_hours, rematch_cutoff_hours,
		       max_referees_per_task, point_cost_per_request
		FROM public.matching_config WHERE id = true`).
		Scan(&c.OpenDeadlineHours, &c.CancelDeadlineHours, &c.RematchCutoffHours,
			&c.MaxRefereesPerTask, &c.PointCostPerRequest)
	if err != nil {
		return Config{}, fmt.Errorf("load matching config: %w", err)
	}
	return c, nil
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `go test ./internal/matching/ -run TestCandidateReferees -v` → PASS.

- [ ] **Step 5: Add a workload-tiebreak test and a max_concurrent-exclusion test; run them**

Write `TestCandidateRefereesLeastWorkloadOnly` (two available referees, different workloads → only the lower is returned) and `TestCandidateRefereesRespectsMaxConcurrent` (a referee at their cap is excluded). Run → PASS.

- [ ] **Step 6: Commit**

```bash
git add internal/matching/domain.go internal/matching/store.go internal/matching/store_test.go
git commit -m "feat(backend): matching store + candidate selection (availability/workload/exclusions/max_concurrent)"
```

---

## Task 8: Matching service + `match_referee_request` worker

**Files:**
- Create/Modify: `internal/matching/service.go`, `internal/matching/worker.go`
- Test: `internal/matching/service_test.go`

**Interfaces:**
- Consumes: `Store`, `PointLocker`, `ObligationChecker`, `judgement.Provisioner`, `notification.Service` (via a `notifier` interface), `jobs.Store`.
- Produces:
  - `const JobKindMatch = "match_referee_request"`
  - `func (s *Service) HandleMatch(ctx context.Context, j *jobs.Job) error` — idempotent single-request match.
  - `type notifier interface { EnqueueInTx(ctx, tx database.DBTX, userID uuid.UUID, keyBase string, args []string, data map[string]string) error }`

- [ ] **Step 1: Write the failing test — match assigns exactly one referee and is idempotent**

```go
// internal/matching/service_test.go
// Seed a pending request with exactly one eligible referee A.
// Run HandleMatch twice; expect: request accepted to A, exactly one judgement row,
// notification jobs enqueued, and the second run a no-op (no error, no second judgement).
func TestHandleMatchAssignsAndIsIdempotent(t *testing.T) {
	db := testsupport.DB(t)
	svc := newTestMatchingService(t, db) // wires Store + noop seams + real judgement provisioner + fake notifier
	reqID, refA := seedSingleCandidate(t, db)

	job := matchJob(reqID)
	if err := svc.HandleMatch(context.Background(), job); err != nil {
		t.Fatalf("match #1: %v", err)
	}
	if err := svc.HandleMatch(context.Background(), job); err != nil {
		t.Fatalf("match #2 (idempotent): %v", err)
	}

	var status string
	var matched uuid.UUID
	_ = db.QueryRow(`SELECT status, matched_referee_id FROM public.referee_requests WHERE id=$1`, reqID).Scan(&status, &matched)
	if status != "accepted" || matched != refA {
		t.Fatalf("want accepted->A, got %s / %s", status, matched)
	}
	var jcount int
	_ = db.QueryRow(`SELECT count(*) FROM public.judgements WHERE id=$1`, reqID).Scan(&jcount)
	if jcount != 1 {
		t.Fatalf("want exactly 1 judgement, got %d", jcount)
	}
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `go test ./internal/matching/ -run TestHandleMatch -v` → FAIL.

- [ ] **Step 3: Implement the service match use case + worker handler**

```go
// internal/matching/service.go
func (s *Service) HandleMatch(ctx context.Context, j *jobs.Job) error {
	var p struct{ RequestID string `json:"requestId"` }
	if err := json.Unmarshal(j.Payload, &p); err != nil {
		return fmt.Errorf("unmarshal match payload: %w", err)
	}
	requestID, err := uuid.Parse(p.RequestID)
	if err != nil {
		return fmt.Errorf("parse request id: %w", err)
	}

	// A same-task unique violation (23505) aborts the transaction, so it MUST
	// propagate out of WithTx to force a rollback; treating it as success INSIDE
	// the callback would make Commit fail (P4a-D16 / re-review #2). The sentinel
	// is mapped to success OUTSIDE the tx.
	err = database.WithTx(ctx, s.db, func(tx database.Querier) error {
		candidates, err := s.store.CandidateReferees(ctx, tx, requestID)
		if err != nil {
			return err
		}
		if len(candidates) == 0 {
			// leave pending; the sweep retries. If cancel-originated, notify once (below).
			return s.maybeNotifyCancelledPending(ctx, tx, requestID)
		}
		// obligation priority (Phase 5 seam; 4a returns none)
		pick := candidates
		if obligated, err := s.obligations.FilterObligated(ctx, candidates); err != nil {
			return err
		} else if len(obligated) > 0 {
			pick = obligated
		}
		isObligation := len(pick) < len(candidates) // only when narrowed by obligation
		referee := pick[pickIndex(requestID, len(pick))] // deterministic index from request id (no rand in tx)

		won, err := s.store.MarkAcceptedInTx(ctx, tx, requestID, referee, isObligation)
		if err != nil {
			return err // ErrRefereeTaken (23505) propagates -> WithTx rolls back
		}
		if !won {
			return nil // another worker already matched this request
		}
		if err := s.judgements.CreateAwaitingEvidenceInTx(ctx, tx, requestID); err != nil {
			return err
		}
		return s.notifyMatch(ctx, tx, requestID, referee)
	})
	if errors.Is(err, ErrRefereeTaken) {
		return nil // concurrent match took this referee on the task; request stays pending, sweep retries
	}
	return err
}
```

> **`maybeNotifyCancelledPending` (P4a-D19):** if the request is cancel-originated
> (its task has a prior `cancelled` request), enqueue
> `notification_matching_cancelled_pending_tasker` via `s.jobs.EnqueueInTx` with
> `EnqueueOpts{IdempotencyKey: "cancelled_pending:" + requestID.String()}` so the
> tasker is told exactly once, even across sweep retries; otherwise it is a no-op.
> It runs inside the match tx (committed with the "still pending" outcome).

> `pickIndex` derives a stable index from the request UUID bytes (`binary.BigEndian.Uint64(id[:8]) % uint64(n)`), avoiding `math/rand` inside the transaction (and keeping the handler deterministic/idempotent). Document that faithful randomness is not required — any stable pick within the least-workload set preserves the "balanced" intent.

`notifyMatch` loads task title + tasker id, then enqueues (via `s.notifier.EnqueueInTx`) `notification_task_assigned_referee` to the referee and `notification_request_matched_tasker` (or `notification_matching_reassigned_tasker` when a prior cancelled request exists on the task) to the tasker.

```go
// internal/matching/worker.go
const JobKindMatch = "match_referee_request"

// EnqueueMatchInTx writes a match job into the caller's tx (used by publish/cancel).
func (s *Service) EnqueueMatchInTx(ctx context.Context, tx database.DBTX, requestID uuid.UUID) error {
	_, err := s.jobs.EnqueueInTx(ctx, tx, JobKindMatch, map[string]string{"requestId": requestID.String()}, jobs.EnqueueOpts{})
	return err
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `go test ./internal/matching/ -run TestHandleMatch -v` → PASS.

- [ ] **Step 5: Add concurrency + cutoff tests** — (a) two goroutines call `HandleMatch` on the **same request**; assert exactly one accepted + one judgement (CAS). (b) two `pending` requests **of the same task** whose only eligible referee is the same A; run `HandleMatch` for both concurrently; assert exactly one request is `accepted` to A and the other stays `pending` (the partial unique index trips `ErrRefereeTaken` → rollback → mapped to success, no error surfaced). (c) **delayed match past cutoff**: seed a pending request whose task `due_date` is already within `rematch_cutoff_hours` of now (past the cutoff) with an eligible referee; run `HandleMatch`; assert the request is **not** accepted (stays `pending`, no judgement) because the cutoff guard in the accept CAS matched 0 rows. Run → PASS.

- [ ] **Step 6: Commit**

```bash
git add internal/matching/service.go internal/matching/worker.go internal/matching/service_test.go
git commit -m "feat(backend): match_referee_request worker — idempotent assign + judgement + notifications"
```

---

## Task 9: `sweep_pending_requests` worker (expire + retry)

**Files:**
- Modify: `internal/matching/service.go`, `internal/matching/worker.go`
- Test: `internal/matching/sweep_test.go`

**Interfaces:**
- Produces:
  - `const JobKindSweep = "sweep_pending_requests"`
  - `func (s *Service) HandleSweep(ctx context.Context, j *jobs.Job) error` — expire past-cutoff pendings (refund seam + notify), re-enqueue a match for the rest.

- [ ] **Step 1: Write the failing test — a past-cutoff pending is expired, refunded, notified; a fresh pending is retried**

```go
// internal/matching/sweep_test.go
// Seed request X on a task whose due_date is within rematch_cutoff of now -> expired.
// Seed request Y on a task well before cutoff -> stays pending, a match job enqueued.
func TestHandleSweepExpiresPastCutoffAndRetriesRest(t *testing.T) {
	db := testsupport.DB(t)
	svc := newTestMatchingService(t, db)
	xID := seedPendingPastCutoff(t, db)
	yID := seedPendingWithinWindowNoCandidate(t, db)

	if err := svc.HandleSweep(context.Background(), &jobs.Job{Kind: matching.JobKindSweep}); err != nil {
		t.Fatalf("sweep: %v", err)
	}
	assertStatus(t, db, xID, "expired")
	assertStatus(t, db, yID, "pending")
	assertJobEnqueued(t, db, matching.JobKindMatch, yID)     // retry enqueued
	assertSweepScheduled(t, db)                              // next-bucket sweep enqueued (chain continues)
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `go test ./internal/matching/ -run TestHandleSweep -v` → FAIL.

- [ ] **Step 3: Implement `HandleSweep`**

```go
// internal/matching/service.go
func (s *Service) HandleSweep(ctx context.Context, _ *jobs.Job) error {
	// Schedule the NEXT occurrence first, before any processing, so a failure
	// mid-run (retried to exhaustion) cannot stop the recurring chain
	// (re-review #2). The bucketed idempotency key makes a duplicate schedule on
	// retry a no-op. If scheduling itself fails, return early (job retries) —
	// this run does no partial work.
	if err := s.scheduleNextSweep(ctx); err != nil {
		return err
	}
	cfg, err := s.store.LoadConfig(ctx)
	if err != nil {
		return err
	}
	// 1. Expire pendings past the rematch cutoff. The expire is a CAS inside the
	//    SAME tx as the refund + notify, so a request a concurrent match already
	//    accepted is NOT expired/refunded (re-review #3): the read below only
	//    lists candidates; ExpireIfPendingInTx is the guard.
	candidates, err := s.store.PastCutoffPendingIDs(ctx, cfg.RematchCutoffHours) // []expiredRequest{ID, TaskID, TaskerID, Title}
	if err != nil {
		return err
	}
	for _, e := range candidates {
		if err := database.WithTx(ctx, s.db, func(tx database.Querier) error {
			expired, err := s.store.ExpireIfPendingInTx(ctx, tx, e.ID) // UPDATE ... SET status='expired' WHERE id=$1 AND status='pending'
			if err != nil {
				return err
			}
			if !expired {
				return nil // a concurrent match accepted it; do NOT refund/notify
			}
			if err := s.points.RefundForRequestInTx(ctx, tx, e.ID, "matching expired — no referee found"); err != nil {
				return err
			}
			return s.notifier.EnqueueInTx(ctx, tx, e.TaskerID,
				"notification_matching_expired_refunded_tasker", []string{e.Title},
				map[string]string{"route": "/tasks/" + e.TaskID.String()})
		}); err != nil {
			return err
		}
	}
	// 2. Re-enqueue a match for remaining in-window pendings.
	remaining, err := s.store.PendingWithinWindow(ctx, cfg.RematchCutoffHours) // []uuid.UUID
	if err != nil {
		return err
	}
	for _, id := range remaining {
		if err := database.WithTx(ctx, s.db, func(tx database.Querier) error {
			return s.EnqueueMatchInTx(ctx, tx, id)
		}); err != nil {
			return err
		}
	}
	return nil
}
```

> Add the supporting store methods: `PastCutoffPendingIDs` (a plain `SELECT` of pendings whose task `due_date - rematch_cutoff_hours <= now()`), `ExpireIfPendingInTx` (the CAS `UPDATE ... SET status='expired' WHERE id=$1 AND status='pending'`, returning whether a row changed), `PendingWithinWindow`. No `FOR UPDATE SKIP LOCKED` cross-tx handle is needed — the per-request CAS is the concurrency guard, and it serializes against `MarkAcceptedInTx` (both row-lock on `WHERE status='pending'`).

- [ ] **Step 4: Run to verify it passes**

Run: `go test ./internal/matching/ -run TestHandleSweep -v` → PASS.

- [ ] **Step 5: Add the accept-vs-expire concurrency test** — a request past the cutoff; concurrently run `HandleMatch` (which now can NOT accept, because the accept CAS embeds the cutoff guard — T7) and the sweep's expire for that request. Assert the deterministic outcome: the request ends **`expired`** (never `accepted`), the refund and the `expired` notification fire **exactly once**, and **no** judgement row and **no** assignment/`request_matched` notification are enqueued. (Past cutoff, accept is impossible, so the only valid terminal state is expired.) Run → PASS.

- [ ] **Step 6: Commit**

```bash
git add internal/matching
git commit -m "feat(backend): sweep_pending_requests worker — expire (CAS) + refund + retry + self-reschedule"
```

---

## Task 10: Availability + referee handlers (availability CRUD, assignments, cancel)

**Files:**
- Create: `internal/matching/handler.go`, availability store methods in `internal/matching/store.go`
- Test: `internal/matching/handler_test.go`

**Interfaces:**
- Consumes: `identity.CurrentUserFrom(ctx)` (3a), `httpserver` helpers.
- Produces HTTP handlers:
  - `GET/POST/PUT/DELETE /me/availability/time-slots`
  - `GET/POST/PUT/DELETE /me/availability/blocked-dates`
  - `GET /me/assignments`
  - `POST /referee-requests/{id}/cancel`

- [ ] **Step 1: Write the failing handler test — cancel by a non-assigned user is 403; by the referee before cutoff creates a new pending**

```go
// internal/matching/handler_test.go
func TestCancelRejectsNonAssignedReferee(t *testing.T) {
	// build a request accepted to referee A; call cancel as user B -> 403 forbidden envelope
}
func TestCancelByRefereeReMatches(t *testing.T) {
	// accepted to A, before cancel cutoff; cancel as A -> 200, old request cancelled,
	// judgement deleted, a new pending request exists, a match job enqueued
}
func TestCancelPreservesPointSource(t *testing.T) {
	// original request has point_source='trial'; after cancel, the replacement
	// pending request also has point_source='trial' (P4a-D17: funding source is
	// inherited so Phase 5 refund/consume routing stays correct).
}
```

> Use the api integration harness (real Postgres + a stub CurrentUser that injects a chosen user id into context). Follow the Phase 2 API integration test pattern in `internal/api`.

- [ ] **Step 2: Run to verify it fails**

Run: `go test ./internal/matching/ -run TestCancel -v` → FAIL.

- [ ] **Step 3: Implement the cancel use case (service) + handler**

```go
// internal/matching/service.go
// Cancel sets the accepted request cancelled, deletes the awaiting_evidence
// judgement, inserts a new pending request, and enqueues a match — atomically.
// Only the assigned referee, before the cancel cutoff.
func (s *Service) Cancel(ctx context.Context, requestID, callerID uuid.UUID) error {
	cfg, err := s.store.LoadConfig(ctx)
	if err != nil {
		return err
	}
	return database.WithTx(ctx, s.db, func(tx database.Querier) error {
		req, err := s.store.GetRequestForCancelInTx(ctx, tx, requestID) // returns status, matched_referee_id, task_id, due_date, point_source
		if err != nil {
			return err
		}
		if req.MatchedRefereeID != callerID {
			return ErrForbidden
		}
		if req.Status != "accepted" {
			return ErrConflict
		}
		if req.DueDate.Add(-time.Duration(cfg.CancelDeadlineHours) * time.Hour).Before(time.Now()) {
			return ErrCancelDeadlinePassed
		}
		if err := s.store.SetStatusInTx(ctx, tx, requestID, "cancelled"); err != nil {
			return err
		}
		if deleted, err := s.judgements.DeleteIfAwaitingEvidenceInTx(ctx, tx, requestID); err != nil {
			return err
		} else if !deleted {
			return ErrConflict // judgement progressed; cannot cancel
		}
		newID, err := s.store.InsertRequestInTx(ctx, tx, req.TaskID)
		if err != nil {
			return err
		}
		// Carry the original funding source onto the replacement so Phase 5's
		// refund/consume routing stays correct (P4a-D17 / re-review #4). No new
		// point lock: the original lock is still held; the replacement inherits it.
		if err := s.store.SetPointSourceInTx(ctx, tx, newID, req.PointSource); err != nil {
			return err
		}
		return s.EnqueueMatchInTx(ctx, tx, newID)
	})
}
```

The handler maps `ErrForbidden`→403, `ErrConflict`/`ErrCancelDeadlinePassed`→409, unknown→500, using `httpserver.WriteError` with the codes from Task 1. Availability CRUD handlers scope every query to `CurrentUser`.

- [ ] **Step 4: Implement availability CRUD store methods + handlers** (time-slots, blocked-dates)

Provide `ListTimeSlots/CreateTimeSlot/UpdateTimeSlot/DeleteTimeSlot` and the blocked-dates equivalents, all `user_id`-scoped, plus `ActiveAssignments(ctx, refereeID)` for `/me/assignments`. Each handler: decode with `httpserver.DecodeJSON`, validate ranges (mirror the DB CHECKs), scope to `CurrentUser`, return JSON.

- [ ] **Step 5: Run the handler tests**

Run: `go test ./internal/matching/ -run 'TestCancel|TestAvailability|TestAssignments' -v` → PASS.

- [ ] **Step 6: Commit**

```bash
git add internal/matching
git commit -m "feat(backend): referee handlers — availability CRUD, assignments, cancel + re-match"
```

---

## Task 11: Task store, domain, and draft handlers

**Files:**
- Create: `internal/task/domain.go`, `internal/task/store.go`, `internal/task/service.go`, `internal/task/handler.go`
- Test: `internal/task/service_test.go`, `internal/task/handler_test.go`

**Interfaces:**
- Produces:
  - `type Task struct { ID, TaskerID uuid.UUID; Title string; Description, Criteria *string; DueDate *time.Time; Status string; ... }`
  - CRUD: `CreateDraft`, `UpdateDraft`, `DeleteDraft`, `GetOwned`, `ListOwned` — all `CurrentUser`-scoped.
  - `func ValidateOpenRequirements(t Task) error` (pure).

- [ ] **Step 1: Write the failing test for open-requirement validation (pure)**

```go
// internal/task/service_test.go
func TestValidateOpenRequirements(t *testing.T) {
	const minLead = 24
	crit := "did it"
	// missing due date / criteria
	if err := task.ValidateOpenRequirements(task.Task{Title: "x"}, minLead); err == nil {
		t.Fatal("want error: missing due_date/criteria")
	}
	// due date too soon (inside the min-lead window) must fail
	soon := time.Now().Add(1 * time.Hour)
	if err := task.ValidateOpenRequirements(task.Task{Title: "x", DueDate: &soon, Criteria: &crit}, minLead); err == nil {
		t.Fatalf("want error: due_date within %dh lead", minLead)
	}
	// due date beyond the lead window is valid
	future := time.Now().Add(48 * time.Hour)
	if err := task.ValidateOpenRequirements(task.Task{Title: "x", DueDate: &future, Criteria: &crit}, minLead); err != nil {
		t.Fatalf("want valid, got %v", err)
	}
}
```

- [ ] **Step 2: Run to verify it fails** → FAIL.

- [ ] **Step 3: Implement domain + validation + CRUD store/service/handler**

```go
// internal/task/service.go
// ValidateOpenRequirements enforces the rules for draft->open (porting
// validate_task_open_requirements, minus the point-balance check, which the
// PointLocker now owns): title present, criteria present, and due_date at least
// minLeadHours ahead of now (matching_config.open_deadline_hours).
func ValidateOpenRequirements(t Task, minLeadHours int) error {
	if strings.TrimSpace(t.Title) == "" {
		return fmt.Errorf("%w: title required", ErrValidation)
	}
	if t.Criteria == nil || strings.TrimSpace(*t.Criteria) == "" {
		return fmt.Errorf("%w: criteria required", ErrValidation)
	}
	minDue := time.Now().Add(time.Duration(minLeadHours) * time.Hour)
	if t.DueDate == nil || !t.DueDate.After(minDue) {
		return fmt.Errorf("%w: due_date must be at least %d hours from now", ErrValidation, minLeadHours)
	}
	return nil
}
```

CRUD handlers: `POST /tasks` (create draft), `PATCH /tasks/{id}` / `DELETE /tasks/{id}` (owner + draft-status guard), `GET /me/tasks` (list owned, status filter + paging), `GET /tasks/{id}` (owner or assigned referee may read). All `CurrentUser`-scoped; ownership violations → 403; not found → 404.

- [ ] **Step 4: Write + run handler tests** (create draft; edit others' task → 403; get missing → 404). Run → PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/task
git commit -m "feat(backend): task feature — draft CRUD + open-requirement validation"
```

---

## Task 12: Publish orchestration + composition root wiring

**Files:**
- Modify: `internal/task/service.go`, `internal/task/handler.go` (publish)
- Modify: `internal/api/api.go` (Deps + routes), `internal/worker/worker.go` (register handlers), `cmd/peppercheck/main.go` (wire everything)
- Test: `internal/task/publish_test.go`, an api integration test in `internal/api`

**Interfaces:**
- Consumes: `matching.RefereeRequestCreator` (consumer-declared in `task`):
  `type RefereeRequestCreator interface { CreateInTx(ctx, tx database.DBTX, taskID, taskerID uuid.UUID, count int) error }` — implemented by `matching.Service`.
- Produces: `POST /tasks/{id}/publish`.

- [ ] **Step 1: Write the failing publish test — atomic open + N requests + N match jobs; rollback on creator failure**

```go
// internal/task/publish_test.go
func TestPublishOpensTaskAndCreatesRequestsAtomically(t *testing.T) {
	db := testsupport.DB(t)
	svc := newTestTaskService(t, db) // wires task.Store + a real matching.Service creator (noop seams)
	taskID, taskerID := seedDraftReady(t, db)

	res, err := svc.Publish(context.Background(), taskerID, taskID, 2)
	if err != nil {
		t.Fatalf("publish: %v", err)
	}
	assertStatus(t, db, taskID, "open")
	if got := countRequests(t, db, taskID); got != 2 {
		t.Fatalf("want 2 requests, got %d", got)
	}
	if got := countJobs(t, db, "match_referee_request"); got < 2 {
		t.Fatalf("want >=2 match jobs, got %d", got)
	}
	_ = res
}

func TestPublishRollsBackWhenCreatorFails(t *testing.T) {
	// inject a creator whose CreateInTx returns an error; assert task stays 'draft'
	// and no referee_requests / jobs were created.
}
```

- [ ] **Step 2: Run to verify it fails** → FAIL.

- [ ] **Step 3: Implement `matching.Service.CreateInTx` + `task.Service.Publish`**

```go
// internal/matching/service.go
// CreateInTx locks points (seam), inserts N pending requests, and enqueues a
// match job per request — all in the caller's transaction (publish outbox).
func (s *Service) CreateInTx(ctx context.Context, tx database.DBTX, taskID, taskerID uuid.UUID, count int) error {
	cfg, err := s.store.LoadConfig(ctx)
	if err != nil {
		return err
	}
	if count < 1 || count > cfg.MaxRefereesPerTask {
		return fmt.Errorf("%w: refereeCount must be 1..%d", ErrValidation, cfg.MaxRefereesPerTask)
	}
	for i := 0; i < count; i++ {
		reqID, err := s.store.InsertRequestInTx(ctx, tx, taskID)
		if err != nil {
			return err
		}
		// Per-request lock returns the funding source; a failed lock (e.g. the
		// tasker can fund fewer than count) rolls back the whole publish (P4a-D17).
		source, err := s.points.LockForRequestInTx(ctx, tx, taskerID, reqID, cfg.PointCostPerRequest)
		if err != nil {
			return err
		}
		if err := s.store.SetPointSourceInTx(ctx, tx, reqID, source); err != nil {
			return err
		}
		if err := s.EnqueueMatchInTx(ctx, tx, reqID); err != nil {
			return err
		}
	}
	return nil
}
```

> Add `SetPointSourceInTx(ctx, tx, requestID uuid.UUID, source string) error`
> to the matching Store
> (`UPDATE public.referee_requests SET point_source = $2, updated_at = now()
> WHERE id = $1`). The no-op locker returns `"regular"`, so this is a no-op
> stamp in 4a.

```go
// internal/task/service.go
// Publish validates open requirements, flips the task to open, and creates the
// referee requests + match jobs in one transaction.
func (s *Service) Publish(ctx context.Context, callerID, taskID uuid.UUID, refereeCount int) (Task, error) {
	var out Task
	err := database.WithTx(ctx, s.db, func(tx database.DBTX) error {
		t, err := s.store.GetOwnedForUpdateInTx(ctx, tx, taskID, callerID) // 404/forbidden if not owner
		if err != nil {
			return err
		}
		if t.Status != "draft" {
			return ErrConflict
		}
		cfg, err := s.matching.LoadConfig(ctx) // matching config: open_deadline_hours (min lead)
		if err != nil {
			return err
		}
		if err := ValidateOpenRequirements(t, cfg.OpenDeadlineHours); err != nil {
			return err
		}
		if err := s.store.SetStatusInTx(ctx, tx, taskID, "open"); err != nil {
			return err
		}
		if err := s.requests.CreateInTx(ctx, tx, taskID, callerID, refereeCount); err != nil {
			return err
		}
		t.Status = "open"
		out = t
		return nil
	})
	return out, err
}
```

- [ ] **Step 4: Run publish tests** → PASS.

- [ ] **Step 5: Wire the composition root**

Extend `api.Deps` with the task, matching (referee/availability), and any read handlers; mount the new routes behind the auth + CurrentUser middleware chain. In `worker.Run`, register the three handlers and bootstrap the recurring sweep. In `main.go`, build: `fcm.New`, `notification.NewService`, `matching.NewStore/NewService` with `NewNoopPointLocker()` + `NewNoObligations()` + `judgement.NewProvisioner()` + the notifier, and `task.NewService` with the matching service as `RefereeRequestCreator`.

**Recurring sweep — self-rescheduling with a bucketed key (re-review #3).** A
fixed idempotency key (`"sweep-bootstrap"`) enqueues the sweep exactly *once ever*
(`ON CONFLICT DO NOTHING` blocks all future enqueues), so it must be
time-bucketed. `HandleSweep` re-schedules the next occurrence **at its start**,
before any processing (`scheduleNextSweep`, re-review #2), so a failure mid-run
cannot drop the next schedule; startup seeds the current bucket:

```go
// internal/matching/service.go
const sweepInterval = time.Hour

// sweepKey is a per-bucket idempotency key so exactly one sweep is scheduled per
// interval, no matter how many workers try to enqueue it.
func sweepKey(runAt time.Time) string {
	return "sweep_pending_requests:" + runAt.UTC().Truncate(sweepInterval).Format(time.RFC3339)
}

// scheduleNextSweep enqueues the next sweep at the next interval boundary. The
// bucketed key + ON CONFLICT DO NOTHING makes concurrent/duplicate schedules a
// no-op, so the chain never forks or dies.
func (s *Service) scheduleNextSweep(ctx context.Context) error {
	next := time.Now().Truncate(sweepInterval).Add(sweepInterval)
	_, err := s.jobs.Enqueue(ctx, JobKindSweep, struct{}{},
		jobs.EnqueueOpts{RunAt: next, IdempotencyKey: sweepKey(next)})
	return err
}

// BootstrapSweep seeds the current bucket on startup (idempotent across restarts
// and multiple workers).
func (s *Service) BootstrapSweep(ctx context.Context) error {
	now := time.Now().Truncate(sweepInterval)
	_, err := s.jobs.Enqueue(ctx, JobKindSweep, struct{}{},
		jobs.EnqueueOpts{RunAt: now, IdempotencyKey: sweepKey(now)})
	return err
}
```

```go
// internal/worker/worker.go  (in Run, replacing the noop-only registration)
w.Register(matching.JobKindMatch, matchingSvc.HandleMatch)
w.Register(matching.JobKindSweep, matchingSvc.HandleSweep)
w.Register(notification.JobKindSendNotification, notificationSvc.HandleSend)
if err := matchingSvc.BootstrapSweep(ctx); err != nil {
	logger.Error("bootstrap sweep failed", "error", err)
}
```

> `HandleSweep` calls `s.scheduleNextSweep(ctx)` **at its start** (Task 9,
> re-review #2), before any processing, so a failure mid-run cannot drop the next
> schedule; the bucketed key keeps retries from double-scheduling. If the worker
> is down over a boundary, the next startup's `BootstrapSweep` reseeds. The
> enqueue uses the non-tx `Enqueue` (scheduling is not part of any business tx).

- [ ] **Step 6: Wire the worker's FCM credentials into prod Compose** (`backend/compose.prod.yaml`, `scripts/assert-prod-config.sh`, deploy secret allowlist)

The `worker` service currently has `environment: {APP_ENV, LOG_LEVEL, DATABASE_URL_FILE}` and `secrets: [database_url]`; it needs the Firebase project id and the service-account file (P4a-D18). Add to the `worker` service:

```yaml
  worker:
    # ...existing...
    environment:
      APP_ENV: ${PC_ENV}
      LOG_LEVEL: ${LOG_LEVEL:-info}
      DATABASE_URL_FILE: /run/secrets/database_url
      FIREBASE_PROJECT_ID: ${FIREBASE_PROJECT_ID:?FIREBASE_PROJECT_ID is required (FCM sender)}
      GOOGLE_APPLICATION_CREDENTIALS: /run/secrets/firebase_service_account
    secrets:
      - database_url
      - firebase_service_account
```

Define the top-level secret (delivered by 7a's file-secret mechanism, same as `database_url`):

```yaml
secrets:
  # ...existing (database_url, ...)...
  firebase_service_account:
    file: ${FIREBASE_SERVICE_ACCOUNT_FILE:?path to the rendered Firebase SA json}
```

Then: add `firebase_service_account` to the deploy secret allowlist (the CI render/inject step that materializes BWS secrets to files), and extend `scripts/assert-prod-config.sh` to assert the `worker` service mounts `firebase_service_account` and sets `GOOGLE_APPLICATION_CREDENTIALS` + `FIREBASE_PROJECT_ID`. The `api` service does **not** get this secret (it never sends FCM). Do NOT edit the 7a design docs — this is 4a-owned config building on 7a's mechanism.

- [ ] **Step 7: Add an api integration test** covering `POST /tasks` → `POST /tasks/{id}/publish` → assert 200 + task open + requests pending, using the real middleware chain (Phase 2 `internal/api` test pattern). Run → PASS.

- [ ] **Step 8: Full build + test + commit**

```bash
gofmt -w . && go vet ./... && go test ./...
git add internal/ cmd/
git commit -m "feat(backend): publish orchestration + wire task/matching/notification into api and worker"
```

---

## Self-Review Notes (author)

- **Spec coverage:** task authoring (T11, T12), async matching (T7/T8), sweep/expire/refund (T9), availability incl. new `referee_availability` enforcement (T2/T7/T10), cancel + re-match + point_source carry-over (T10), notification foundation loc_key (T5/T6), Phase 5 seams (T3), judgement awaiting_evidence (T4), config collapse + drops (T2), publish cross-feature tx + open-deadline validation (T1/T11/T12), FCM worker credentials (T12 Step 6). Multi-referee cap (T2 config, T12 CreateInTx). Idempotency (#464) + concurrency covered in T6/T8/T9 tests.
- **Re-review round 1 fixes applied:** open-deadline validation now uses `matching_config.open_deadline_hours` and the real seed values (24/12/14) (T2/T11); the same-task 23505 propagates out of the tx and is mapped to success outside (T8) with a same-task concurrency test; the sweep expire is a CAS in the refund/notify tx with an accept-vs-expire test (T9); the recurring sweep self-reschedules with a bucketed idempotency key (T9/T12); cancel carries `point_source` with a trial-preservation test (T10); `judgements` mutations explicitly maintain `updated_at` (T2); the worker's `FIREBASE_PROJECT_ID` + SA secret land in prod Compose (T12 Step 6).
- **Re-review round 2 fixes applied:** the accept CAS embeds the cutoff guard (`due_date > now() + rematch_cutoff_hours`) so a delayed/stale match job cannot assign after cutoff (T7), with a past-cutoff test (T8 Step 5c); `HandleSweep` schedules the next occurrence **first** (before processing) so a failed run can't break the recurring chain, asserted in the sweep test (T9); Task 1's `EnqueueInTx` rollback test uses a real `countProbeJobs` helper (no `sqlRow` placeholder).
- **Known execution-time confirmations (not placeholders — verify against the implemented 3a code at execution):** 3a symbol names (`identity.CurrentUserFrom`, `database.Querier`, `notification` store shape) and Go-maintained `updated_at` mutation paths; FCM SDK loc-key field paths + pgx array binding (official docs). Each is flagged inline at its task.
- **Deferred by decision (not gaps):** all-requests-expired task terminal state / tasker withdrawal → follow-up, decide before 4c; `max_concurrent_assignments` concurrency enforcement → the availability-cap feature (no-op at 4a default).
- **Type consistency:** `database.DBTX` used uniformly across stores; `EnqueueInTx`/`EnqueueMatchInTx`/`EnqueueSendInTx` naming consistent; job-kind constants (`JobKindMatch`, `JobKindSweep`, `JobKindSendNotification`) referenced identically in worker registration.
