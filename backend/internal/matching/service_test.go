package matching_test

import (
	"context"
	"database/sql"
	"encoding/json"
	"sync"
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
	"github.com/cloveclovedev/peppercheck/backend/internal/core/jobs"
	"github.com/cloveclovedev/peppercheck/backend/internal/judgement"
	"github.com/cloveclovedev/peppercheck/backend/internal/matching"
	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
)

// fakeNotifier records the notifications the matching service enqueues so tests
// can assert on them without a device-token round-trip. It satisfies matching's
// unexported notifier interface structurally.
type fakeNotifier struct {
	mu    sync.Mutex
	calls []notifyCall
}

type notifyCall struct {
	userID  string
	keyBase string
}

func (f *fakeNotifier) EnqueueInTx(_ context.Context, _ database.Querier, userID, keyBase string, _ []string, _ map[string]string) error {
	f.record(userID, keyBase)
	return nil
}

func (f *fakeNotifier) EnqueueIdempotentInTx(_ context.Context, _ database.Querier, userID, keyBase string, _ []string, _ map[string]string, _ string) error {
	f.record(userID, keyBase)
	return nil
}

func (f *fakeNotifier) record(userID, keyBase string) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.calls = append(f.calls, notifyCall{userID, keyBase})
}

func (f *fakeNotifier) keysFor(userID string) []string {
	f.mu.Lock()
	defer f.mu.Unlock()
	var out []string
	for _, c := range f.calls {
		if c.userID == userID {
			out = append(out, c.keyBase)
		}
	}
	return out
}

func newTestMatchingService(t *testing.T, db *sql.DB) (*matching.Service, *fakeNotifier) {
	t.Helper()
	fn := &fakeNotifier{}
	svc := matching.NewService(
		db,
		matching.NewStore(db),
		matching.NewNoopPointLocker(),
		matching.NewNoObligations(),
		judgement.NewProvisioner(),
		fn,
		jobs.NewStore(db),
	)
	return svc, fn
}

// seedSingleCandidate creates a pending request whose only eligible referee is A.
func seedSingleCandidate(t *testing.T, db *sql.DB) (requestID, refereeA string) {
	t.Helper()
	tasker := newUser(t, db)
	taskID := newTask(t, db, tasker)
	a := newReferee(t, db)
	addAllDaySlot(t, db, a, taskID)
	return newPendingRequest(t, db, taskID), a
}

func matchJob(reqID string) *jobs.Job {
	payload, _ := json.Marshal(map[string]string{"requestId": reqID})
	return &jobs.Job{Kind: matching.JobKindMatch, Payload: payload}
}

func requestStatus(t *testing.T, db *sql.DB, reqID string) (status string, matched sql.NullString) {
	t.Helper()
	if err := db.QueryRow(`SELECT status, matched_referee_id FROM public.referee_requests WHERE id=$1`, reqID).
		Scan(&status, &matched); err != nil {
		t.Fatalf("read request %s: %v", reqID, err)
	}
	return status, matched
}

func judgementCount(t *testing.T, db *sql.DB, reqID string) int {
	t.Helper()
	var n int
	if err := db.QueryRow(`SELECT count(*) FROM public.judgements WHERE id=$1`, reqID).Scan(&n); err != nil {
		t.Fatalf("count judgements %s: %v", reqID, err)
	}
	return n
}

func TestHandleMatchAssignsAndIsIdempotent(t *testing.T) {
	db := testsupport.DB(t)
	svc, fn := newTestMatchingService(t, db)
	reqID, refA := seedSingleCandidate(t, db)
	ctx := context.Background()

	if err := svc.HandleMatch(ctx, matchJob(reqID)); err != nil {
		t.Fatalf("match #1: %v", err)
	}
	if err := svc.HandleMatch(ctx, matchJob(reqID)); err != nil {
		t.Fatalf("match #2 (idempotent): %v", err)
	}

	status, matched := requestStatus(t, db, reqID)
	if status != "accepted" || matched.String != refA {
		t.Fatalf("want accepted->A(%s), got %s/%s", refA, status, matched.String)
	}
	if n := judgementCount(t, db, reqID); n != 1 {
		t.Fatalf("want exactly 1 judgement, got %d", n)
	}
	if keys := fn.keysFor(refA); len(keys) != 1 || keys[0] != "notification_task_assigned_referee" {
		t.Fatalf("want referee assigned once, got %v", keys)
	}
}

func TestHandleMatchConcurrentSameRequestAcceptsOnce(t *testing.T) {
	db := testsupport.DB(t)
	svc, _ := newTestMatchingService(t, db)
	reqID, refA := seedSingleCandidate(t, db)
	ctx := context.Background()

	var wg sync.WaitGroup
	errs := make([]error, 2)
	for i := range errs {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			errs[i] = svc.HandleMatch(ctx, matchJob(reqID))
		}(i)
	}
	wg.Wait()
	for i, err := range errs {
		if err != nil {
			t.Fatalf("goroutine %d: %v", i, err)
		}
	}

	status, matched := requestStatus(t, db, reqID)
	if status != "accepted" || matched.String != refA {
		t.Fatalf("want accepted->A, got %s/%s", status, matched.String)
	}
	if n := judgementCount(t, db, reqID); n != 1 {
		t.Fatalf("want exactly 1 judgement after concurrent match, got %d", n)
	}
}

func TestHandleMatchConcurrentSameTaskAssignsOneSeat(t *testing.T) {
	db := testsupport.DB(t)
	svc, _ := newTestMatchingService(t, db)
	ctx := context.Background()

	// Two seats on one task whose only eligible referee is A: exactly one seat
	// can accept A (the partial unique index trips ErrRefereeTaken on the other,
	// which rolls back and leaves that seat pending).
	tasker := newUser(t, db)
	taskID := newTask(t, db, tasker)
	a := newReferee(t, db)
	addAllDaySlot(t, db, a, taskID)
	req1 := newPendingRequest(t, db, taskID)
	req2 := newPendingRequest(t, db, taskID)

	var wg sync.WaitGroup
	for _, r := range []string{req1, req2} {
		wg.Add(1)
		go func(r string) {
			defer wg.Done()
			if err := svc.HandleMatch(ctx, matchJob(r)); err != nil {
				t.Errorf("match %s: %v", r, err)
			}
		}(r)
	}
	wg.Wait()

	s1, m1 := requestStatus(t, db, req1)
	s2, m2 := requestStatus(t, db, req2)
	accepted := 0
	pending := 0
	for _, pair := range []struct {
		s string
		m sql.NullString
	}{{s1, m1}, {s2, m2}} {
		switch pair.s {
		case "accepted":
			accepted++
			if pair.m.String != a {
				t.Fatalf("accepted seat matched to %s, want A(%s)", pair.m.String, a)
			}
		case "pending":
			pending++
		default:
			t.Fatalf("unexpected status %s", pair.s)
		}
	}
	if accepted != 1 || pending != 1 {
		t.Fatalf("want exactly one accepted + one pending, got accepted=%d pending=%d", accepted, pending)
	}
}

// addCancelledSibling inserts a cancelled referee_request on the task so it
// reads as a re-match (a referee previously cancelled their assignment).
func addCancelledSibling(t *testing.T, db *sql.DB, taskID, refereeID string) {
	t.Helper()
	if _, err := db.Exec(
		`INSERT INTO public.referee_requests (task_id, status, matched_referee_id)
		 VALUES ($1, 'cancelled', $2)`, taskID, refereeID); err != nil {
		t.Fatalf("seed cancelled sibling: %v", err)
	}
}

func TestHandleMatchReassignNotifiesTasker(t *testing.T) {
	db := testsupport.DB(t)
	svc, fn := newTestMatchingService(t, db)
	ctx := context.Background()

	tasker := newUser(t, db)
	taskID := newTask(t, db, tasker)
	gone := newReferee(t, db)
	addCancelledSibling(t, db, taskID, gone) // prior referee cancelled -> re-match
	a := newReferee(t, db)
	addAllDaySlot(t, db, a, taskID)
	reqID := newPendingRequest(t, db, taskID)

	if err := svc.HandleMatch(ctx, matchJob(reqID)); err != nil {
		t.Fatalf("match: %v", err)
	}
	status, matched := requestStatus(t, db, reqID)
	if status != "accepted" || matched.String != a {
		t.Fatalf("want accepted->A, got %s/%s", status, matched.String)
	}
	if keys := fn.keysFor(tasker); len(keys) != 1 || keys[0] != "notification_matching_reassigned_tasker" {
		t.Fatalf("want tasker reassigned once, got %v", keys)
	}
}

func TestHandleMatchCancelOriginatedNoCandidateNotifiesTasker(t *testing.T) {
	db := testsupport.DB(t)
	svc, fn := newTestMatchingService(t, db)
	ctx := context.Background()

	tasker := newUser(t, db)
	taskID := newTask(t, db, tasker)
	gone := newReferee(t, db)
	addCancelledSibling(t, db, taskID, gone)
	reqID := newPendingRequest(t, db, taskID) // no eligible referee seeded

	if err := svc.HandleMatch(ctx, matchJob(reqID)); err != nil {
		t.Fatalf("match: %v", err)
	}
	if status, _ := requestStatus(t, db, reqID); status != "pending" {
		t.Fatalf("want request left pending, got %s", status)
	}
	if keys := fn.keysFor(tasker); len(keys) != 1 || keys[0] != "notification_matching_cancelled_pending_tasker" {
		t.Fatalf("want tasker told the re-match is searching, got %v", keys)
	}
}

func TestHandleMatchMissingRequestIsNoop(t *testing.T) {
	db := testsupport.DB(t)
	svc, _ := newTestMatchingService(t, db)
	// A well-formed uuid that maps to no request row (e.g. its task was deleted):
	// the handler must succeed as a no-op, not error and burn retries (#464).
	if err := svc.HandleMatch(context.Background(), matchJob("00000000-0000-0000-0000-000000000000")); err != nil {
		t.Fatalf("want no-op for a missing request, got %v", err)
	}
}

func TestHandleMatchPastCutoffLeavesPending(t *testing.T) {
	db := testsupport.DB(t)
	svc, _ := newTestMatchingService(t, db)
	ctx := context.Background()

	// Task due inside the 14h rematch cutoff, with an otherwise-eligible referee:
	// the accept CAS embeds the cutoff guard, so no referee is assigned.
	tasker := newUser(t, db)
	taskID := newTaskDueIn(t, db, tasker, "5 hours")
	a := newReferee(t, db)
	addAllDaySlot(t, db, a, taskID)
	reqID := newPendingRequest(t, db, taskID)

	if err := svc.HandleMatch(ctx, matchJob(reqID)); err != nil {
		t.Fatalf("match: %v", err)
	}
	status, _ := requestStatus(t, db, reqID)
	if status != "pending" {
		t.Fatalf("want request left pending past cutoff, got %s", status)
	}
	if n := judgementCount(t, db, reqID); n != 0 {
		t.Fatalf("want no judgement past cutoff, got %d", n)
	}
}
