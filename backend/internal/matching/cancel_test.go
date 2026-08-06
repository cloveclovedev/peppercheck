package matching_test

import (
	"context"
	"database/sql"
	"errors"
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/matching"
	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
)

// seedAccepted inserts a task (due dueInterval from now) with an accepted request
// matched to a fresh referee, an awaiting_evidence judgement, and the given
// point source. Returns the request id, task id, and referee id.
func seedAccepted(t *testing.T, db *sql.DB, dueInterval, pointSource string) (requestID, taskID, refereeID string) {
	t.Helper()
	tasker := newUser(t, db)
	taskID = newTaskDueIn(t, db, tasker, dueInterval)
	refereeID = newReferee(t, db)
	if err := db.QueryRow(
		`INSERT INTO public.referee_requests (task_id, status, matched_referee_id, point_source, responded_at)
		 VALUES ($1, 'accepted', $2, $3::public.point_source_type, now()) RETURNING id`,
		taskID, refereeID, pointSource).Scan(&requestID); err != nil {
		t.Fatalf("seed accepted request: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO public.judgements (id, status) VALUES ($1, 'awaiting_evidence')`, requestID); err != nil {
		t.Fatalf("seed judgement: %v", err)
	}
	return requestID, taskID, refereeID
}

func replacementPending(t *testing.T, db *sql.DB, taskID, cancelledID string) (id, pointSource string) {
	t.Helper()
	if err := db.QueryRow(
		`SELECT id, point_source FROM public.referee_requests
		 WHERE task_id=$1 AND status='pending' AND id<>$2`, taskID, cancelledID).
		Scan(&id, &pointSource); err != nil {
		t.Fatalf("load replacement pending: %v", err)
	}
	return id, pointSource
}

func TestCancelByRefereeReMatches(t *testing.T) {
	db := testsupport.DB(t)
	svc, _ := newTestMatchingService(t, db)
	reqID, taskID, ref := seedAccepted(t, db, "30 days", "regular")

	gotTaskID, err := svc.Cancel(context.Background(), reqID, ref)
	if err != nil {
		t.Fatalf("cancel: %v", err)
	}
	if gotTaskID != taskID {
		t.Fatalf("cancel returned task %s, want %s", gotTaskID, taskID)
	}
	assertStatus(t, db, reqID, "cancelled")
	if n := judgementCount(t, db, reqID); n != 0 {
		t.Fatalf("want judgement deleted, got %d", n)
	}
	newID, _ := replacementPending(t, db, taskID, reqID)
	if !matchJobEnqueued(t, db, newID) {
		t.Fatal("want a match job enqueued for the replacement request")
	}
}

func TestCancelRejectsNonAssignedReferee(t *testing.T) {
	db := testsupport.DB(t)
	svc, _ := newTestMatchingService(t, db)
	reqID, _, _ := seedAccepted(t, db, "30 days", "regular")
	other := newUser(t, db)

	if _, err := svc.Cancel(context.Background(), reqID, other); !errors.Is(err, matching.ErrForbidden) {
		t.Fatalf("want ErrForbidden, got %v", err)
	}
	assertStatus(t, db, reqID, "accepted") // unchanged
}

func TestCancelPreservesPointSource(t *testing.T) {
	db := testsupport.DB(t)
	svc, _ := newTestMatchingService(t, db)
	reqID, taskID, ref := seedAccepted(t, db, "30 days", "trial")

	if _, err := svc.Cancel(context.Background(), reqID, ref); err != nil {
		t.Fatalf("cancel: %v", err)
	}
	if _, src := replacementPending(t, db, taskID, reqID); src != "trial" {
		t.Fatalf("want replacement point_source=trial (P4a-D17), got %q", src)
	}
}

func TestCancelPastDeadline(t *testing.T) {
	db := testsupport.DB(t)
	svc, _ := newTestMatchingService(t, db)
	// Due in 5h is inside the 12h cancel deadline.
	reqID, _, ref := seedAccepted(t, db, "5 hours", "regular")

	if _, err := svc.Cancel(context.Background(), reqID, ref); !errors.Is(err, matching.ErrCancelDeadlinePassed) {
		t.Fatalf("want ErrCancelDeadlinePassed, got %v", err)
	}
	assertStatus(t, db, reqID, "accepted") // unchanged
}
