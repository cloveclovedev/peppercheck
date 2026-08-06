package matching_test

import (
	"context"
	"database/sql"
	"sync"
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/jobs"
	"github.com/cloveclovedev/peppercheck/backend/internal/matching"
	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
)

func assertStatus(t *testing.T, db *sql.DB, reqID, want string) {
	t.Helper()
	status, _ := requestStatus(t, db, reqID)
	if status != want {
		t.Fatalf("request %s: want status %s, got %s", reqID, want, status)
	}
}

// matchJobEnqueued reports whether a match job exists for the request.
func matchJobEnqueued(t *testing.T, db *sql.DB, reqID string) bool {
	t.Helper()
	var n int
	if err := db.QueryRow(
		`SELECT count(*) FROM public.jobs WHERE kind=$1 AND payload->>'requestId'=$2`,
		matching.JobKindMatch, reqID).Scan(&n); err != nil {
		t.Fatalf("count match jobs: %v", err)
	}
	return n > 0
}

// sweepScheduled reports whether a future sweep job is queued (the chain lives on).
func sweepScheduled(t *testing.T, db *sql.DB) bool {
	t.Helper()
	var n int
	if err := db.QueryRow(
		`SELECT count(*) FROM public.jobs WHERE kind=$1 AND status='pending'`,
		matching.JobKindSweep).Scan(&n); err != nil {
		t.Fatalf("count sweep jobs: %v", err)
	}
	return n > 0
}

func TestHandleSweepExpiresPastCutoffAndRetriesRest(t *testing.T) {
	db := testsupport.DB(t)
	svc, fn := newTestMatchingService(t, db)
	ctx := context.Background()

	// X: past the cutoff -> expired + refunded + notified.
	taskerX := newUser(t, db)
	taskX := newTaskDueIn(t, db, taskerX, "5 hours")
	xID := newPendingRequest(t, db, taskX)

	// Y: well inside the window with no candidate -> stays pending, match retried.
	taskerY := newUser(t, db)
	taskY := newTask(t, db, taskerY)
	yID := newPendingRequest(t, db, taskY)

	if err := svc.HandleSweep(ctx, &jobs.Job{Kind: matching.JobKindSweep}); err != nil {
		t.Fatalf("sweep: %v", err)
	}

	assertStatus(t, db, xID, "expired")
	assertStatus(t, db, yID, "pending")
	if !matchJobEnqueued(t, db, yID) {
		t.Fatal("want a match retry enqueued for the in-window pending")
	}
	if !sweepScheduled(t, db) {
		t.Fatal("want the next sweep scheduled")
	}
	if keys := fn.keysFor(taskerX); len(keys) != 1 || keys[0] != "notification_matching_expired_refunded_tasker" {
		t.Fatalf("want tasker told of the expiry+refund once, got %v", keys)
	}
}

func TestHandleSweepExpireBeatsLateMatch(t *testing.T) {
	db := testsupport.DB(t)
	svc, fn := newTestMatchingService(t, db)
	ctx := context.Background()

	// A request past the cutoff with an otherwise-eligible referee. The late match
	// cannot accept (the accept CAS embeds the cutoff guard), so the only valid
	// terminal state is expired — with no judgement and no assignment notice.
	tasker := newUser(t, db)
	taskID := newTaskDueIn(t, db, tasker, "5 hours")
	a := newReferee(t, db)
	addAllDaySlot(t, db, a, taskID)
	reqID := newPendingRequest(t, db, taskID)

	var wg sync.WaitGroup
	wg.Add(2)
	go func() { defer wg.Done(); _ = svc.HandleMatch(ctx, matchJob(reqID)) }()
	go func() { defer wg.Done(); _ = svc.HandleSweep(ctx, &jobs.Job{Kind: matching.JobKindSweep}) }()
	wg.Wait()

	assertStatus(t, db, reqID, "expired")
	if n := judgementCount(t, db, reqID); n != 0 {
		t.Fatalf("want no judgement, got %d", n)
	}
	if keys := fn.keysFor(a); len(keys) != 0 {
		t.Fatalf("want no assignment notice to the referee, got %v", keys)
	}
	if keys := fn.keysFor(tasker); len(keys) != 1 || keys[0] != "notification_matching_expired_refunded_tasker" {
		t.Fatalf("want exactly the expiry notice to the tasker, got %v", keys)
	}
}
