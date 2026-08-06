package task_test

import (
	"context"
	"database/sql"
	"errors"
	"testing"
	"time"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
	"github.com/cloveclovedev/peppercheck/backend/internal/core/jobs"
	"github.com/cloveclovedev/peppercheck/backend/internal/judgement"
	"github.com/cloveclovedev/peppercheck/backend/internal/matching"
	"github.com/cloveclovedev/peppercheck/backend/internal/task"
	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
)

// noopNotifier satisfies matching's notifier interface; publish enqueues match
// jobs but sends no notifications, so it is never called here.
type noopNotifier struct{}

func (noopNotifier) EnqueueInTx(context.Context, database.Querier, string, string, []string, map[string]string) error {
	return nil
}
func (noopNotifier) EnqueueIdempotentInTx(context.Context, database.Querier, string, string, []string, map[string]string, string) error {
	return nil
}

// realMatchingCreator wires a matching.Service with no-op seams as the publish
// creator.
func realMatchingCreator(db *sql.DB) *matching.Service {
	return matching.NewService(
		db, matching.NewStore(db),
		matching.NewNoopPointLocker(), matching.NewNoObligations(),
		judgement.NewProvisioner(), noopNotifier{}, jobs.NewStore(db),
	)
}

// seedDraftReady creates a publish-ready draft (title, criteria, due 48h out)
// owned by a fresh user; returns task id and tasker id.
func seedDraftReady(t *testing.T, db *sql.DB, svc *task.Service) (taskID, taskerID string) {
	t.Helper()
	taskerID = newUser(t, db)
	due := time.Now().Add(48 * time.Hour)
	created, err := svc.CreateDraft(context.Background(), taskerID,
		task.DraftInput{Title: "Wash the car", Criteria: ptr("photo of a clean car"), DueDate: &due})
	if err != nil {
		t.Fatalf("seed draft: %v", err)
	}
	return created.ID, taskerID
}

func countRequests(t *testing.T, db *sql.DB, taskID string) int {
	t.Helper()
	var n int
	if err := db.QueryRow(`SELECT count(*) FROM public.referee_requests WHERE task_id=$1`, taskID).Scan(&n); err != nil {
		t.Fatalf("count requests: %v", err)
	}
	return n
}

func countMatchJobsForTask(t *testing.T, db *sql.DB, taskID string) int {
	t.Helper()
	var n int
	if err := db.QueryRow(
		`SELECT count(*) FROM public.jobs
		 WHERE kind='match_referee_request'
		   AND payload->>'requestId' IN (SELECT id::text FROM public.referee_requests WHERE task_id=$1)`,
		taskID).Scan(&n); err != nil {
		t.Fatalf("count match jobs: %v", err)
	}
	return n
}

func TestPublishOpensTaskAndCreatesRequestsAtomically(t *testing.T) {
	db := testsupport.DB(t)
	svc := task.NewService(db, task.NewStore(db), realMatchingCreator(db))
	taskID, taskerID := seedDraftReady(t, db, svc)

	out, err := svc.Publish(context.Background(), taskerID, taskID, 2)
	if err != nil {
		t.Fatalf("publish: %v", err)
	}
	if out.Status != "open" {
		t.Fatalf("want open, got %s", out.Status)
	}
	if got := countRequests(t, db, taskID); got != 2 {
		t.Fatalf("want 2 requests, got %d", got)
	}
	if got := countMatchJobsForTask(t, db, taskID); got != 2 {
		t.Fatalf("want 2 match jobs, got %d", got)
	}
}

func TestPublishRefreshesUpdatedAt(t *testing.T) {
	db := testsupport.DB(t)
	svc := task.NewService(db, task.NewStore(db), realMatchingCreator(db))
	taskID, taskerID := seedDraftReady(t, db, svc)

	var draftUpdated time.Time
	if err := db.QueryRow(`SELECT updated_at FROM public.tasks WHERE id=$1`, taskID).Scan(&draftUpdated); err != nil {
		t.Fatalf("read draft updated_at: %v", err)
	}
	out, err := svc.Publish(context.Background(), taskerID, taskID, 1)
	if err != nil {
		t.Fatalf("publish: %v", err)
	}
	if !out.UpdatedAt.After(draftUpdated) {
		t.Fatalf("publish response updatedAt %v not refreshed past draft's %v", out.UpdatedAt, draftUpdated)
	}
}

func TestPublishRollsBackWhenCreatorFails(t *testing.T) {
	db := testsupport.DB(t)
	// The service used to seed a ready draft uses the real creator; the service
	// under test uses a failing creator so publish rolls the open + requests back.
	seedSvc := task.NewService(db, task.NewStore(db), realMatchingCreator(db))
	taskID, taskerID := seedDraftReady(t, db, seedSvc)

	failing := task.NewService(db, task.NewStore(db), failingCreator{})
	if _, err := failing.Publish(context.Background(), taskerID, taskID, 2); err == nil {
		t.Fatal("want publish error from the creator")
	}
	// Task stays draft; no requests, no jobs.
	var status string
	_ = db.QueryRow(`SELECT status FROM public.tasks WHERE id=$1`, taskID).Scan(&status)
	if status != "draft" {
		t.Fatalf("want task rolled back to draft, got %s", status)
	}
	if got := countRequests(t, db, taskID); got != 0 {
		t.Fatalf("want no requests after rollback, got %d", got)
	}
}

type failingCreator struct{}

func (failingCreator) PublishBounds(context.Context) (int, int, error) { return 24, 2, nil }
func (failingCreator) CreateInTx(context.Context, database.Querier, string, string, int) error {
	return errors.New("creator boom")
}

func TestPublishRejectsInvalidCount(t *testing.T) {
	db := testsupport.DB(t)
	svc := task.NewService(db, task.NewStore(db), realMatchingCreator(db))
	taskID, taskerID := seedDraftReady(t, db, svc)

	if _, err := svc.Publish(context.Background(), taskerID, taskID, 0); !errors.Is(err, task.ErrValidation) {
		t.Fatalf("count 0: want ErrValidation, got %v", err)
	}
	if _, err := svc.Publish(context.Background(), taskerID, taskID, 99); !errors.Is(err, task.ErrValidation) {
		t.Fatalf("count over max: want ErrValidation, got %v", err)
	}
	assertDraft(t, db, taskID)
}

func TestPublishRejectsMissingCriteria(t *testing.T) {
	db := testsupport.DB(t)
	svc := task.NewService(db, task.NewStore(db), realMatchingCreator(db))
	taskerID := newUser(t, db)
	due := time.Now().Add(48 * time.Hour)
	created, _ := svc.CreateDraft(context.Background(), taskerID, task.DraftInput{Title: "no criteria", DueDate: &due})

	if _, err := svc.Publish(context.Background(), taskerID, created.ID, 1); !errors.Is(err, task.ErrValidation) {
		t.Fatalf("missing criteria: want ErrValidation, got %v", err)
	}
	assertDraft(t, db, created.ID)
}

func TestPublishRejectsNonOwnerAndNonDraft(t *testing.T) {
	db := testsupport.DB(t)
	svc := task.NewService(db, task.NewStore(db), realMatchingCreator(db))
	taskID, _ := seedDraftReady(t, db, svc)

	stranger := newUser(t, db)
	if _, err := svc.Publish(context.Background(), stranger, taskID, 1); !errors.Is(err, task.ErrNotFound) {
		t.Fatalf("non-owner: want ErrNotFound, got %v", err)
	}

	// Publish once, then a second publish conflicts (already open).
	owner := ownerOf(t, db, taskID)
	if _, err := svc.Publish(context.Background(), owner, taskID, 1); err != nil {
		t.Fatalf("first publish: %v", err)
	}
	if _, err := svc.Publish(context.Background(), owner, taskID, 1); !errors.Is(err, task.ErrConflict) {
		t.Fatalf("re-publish: want ErrConflict, got %v", err)
	}
}

func assertDraft(t *testing.T, db *sql.DB, taskID string) {
	t.Helper()
	var status string
	_ = db.QueryRow(`SELECT status FROM public.tasks WHERE id=$1`, taskID).Scan(&status)
	if status != "draft" {
		t.Fatalf("want task still draft, got %s", status)
	}
}

func ownerOf(t *testing.T, db *sql.DB, taskID string) string {
	t.Helper()
	var owner string
	if err := db.QueryRow(`SELECT tasker_id FROM public.tasks WHERE id=$1`, taskID).Scan(&owner); err != nil {
		t.Fatalf("owner of: %v", err)
	}
	return owner
}
