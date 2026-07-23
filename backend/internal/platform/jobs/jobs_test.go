package jobs

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
)

func newStore(t *testing.T) *Store {
	t.Helper()
	db := testsupport.DB(t)
	if _, err := db.Exec("TRUNCATE public.jobs"); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	return NewStore(db)
}

func TestEnqueueClaimComplete(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()

	id, err := s.Enqueue(ctx, "noop", map[string]any{"x": 1}, EnqueueOpts{})
	if err != nil || id == "" {
		t.Fatalf("Enqueue: id=%q err=%v", id, err)
	}

	j, err := s.Claim(ctx)
	if err != nil || j == nil {
		t.Fatalf("Claim: job=%v err=%v", j, err)
	}
	if j.Kind != "noop" || j.Attempts != 1 {
		t.Fatalf("claimed job kind=%q attempts=%d", j.Kind, j.Attempts)
	}
	if j.LockedBy == "" {
		t.Fatal("claim must issue a lease token")
	}

	// No second claimable job.
	if j2, err := s.Claim(ctx); err != nil || j2 != nil {
		t.Fatalf("second Claim should be empty: job=%v err=%v", j2, err)
	}

	if err := s.Complete(ctx, j); err != nil {
		t.Fatalf("Complete: %v", err)
	}
}

func TestClaimReclaimsExpiredLease(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()
	if _, err := s.Enqueue(ctx, "noop", nil, EnqueueOpts{}); err != nil {
		t.Fatalf("enqueue: %v", err)
	}
	a, err := s.Claim(ctx)
	if err != nil || a == nil {
		t.Fatalf("first claim: %v %v", a, err)
	}
	// Simulate a crashed worker: force the lease to have already expired.
	if _, err := s.db.Exec(`UPDATE public.jobs SET lease_until = now() - interval '1 second' WHERE id = $1`, a.ID); err != nil {
		t.Fatalf("expire lease: %v", err)
	}
	b, err := s.Claim(ctx)
	if err != nil || b == nil {
		t.Fatalf("expired running job must be reclaimable: %v %v", b, err)
	}
	if b.ID != a.ID {
		t.Fatalf("reclaimed a different job: %s != %s", b.ID, a.ID)
	}
	if b.LockedBy == a.LockedBy {
		t.Fatal("reclaim must issue a new lease token")
	}
	if b.Attempts != 2 {
		t.Fatalf("reclaim should increment attempts, got %d", b.Attempts)
	}
}

func TestLostLeaseCompleteIsNoop(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()
	if _, err := s.Enqueue(ctx, "noop", nil, EnqueueOpts{}); err != nil {
		t.Fatalf("enqueue: %v", err)
	}
	a, err := s.Claim(ctx)
	if err != nil || a == nil {
		t.Fatalf("first claim: %v %v", a, err)
	}
	if _, err := s.db.Exec(`UPDATE public.jobs SET lease_until = now() - interval '1 second' WHERE id = $1`, a.ID); err != nil {
		t.Fatalf("expire lease: %v", err)
	}
	b, err := s.Claim(ctx)
	if err != nil || b == nil {
		t.Fatalf("reclaim: %v %v", b, err)
	}
	// The original holder lost the lease; its Complete must not take effect.
	if err := s.Complete(ctx, a); err != nil {
		t.Fatalf("stale Complete should be a no-op, not an error: %v", err)
	}
	var status string
	if err := s.db.QueryRow(`SELECT status FROM public.jobs WHERE id = $1`, a.ID).Scan(&status); err != nil {
		t.Fatalf("scan: %v", err)
	}
	if status != "running" {
		t.Fatalf("stale Complete changed status to %q; expected still running", status)
	}
	// The current holder can complete.
	if err := s.Complete(ctx, b); err != nil {
		t.Fatalf("current holder Complete: %v", err)
	}
	if err := s.db.QueryRow(`SELECT status FROM public.jobs WHERE id = $1`, a.ID).Scan(&status); err != nil {
		t.Fatalf("scan2: %v", err)
	}
	if status != "succeeded" {
		t.Fatalf("current holder Complete failed; status=%q", status)
	}
}

func TestEnqueueIdempotencyKeyDedupes(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()
	id1, err := s.Enqueue(ctx, "noop", nil, EnqueueOpts{IdempotencyKey: "k1"})
	if err != nil || id1 == "" {
		t.Fatalf("first enqueue: %q %v", id1, err)
	}
	id2, err := s.Enqueue(ctx, "noop", nil, EnqueueOpts{IdempotencyKey: "k1"})
	if err != nil {
		t.Fatalf("second enqueue err: %v", err)
	}
	if id2 != "" {
		t.Fatalf("duplicate idempotency key should return empty id, got %q", id2)
	}
}

func TestFailReschedulesUntilExhausted(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()
	if _, err := s.Enqueue(ctx, "noop", nil, EnqueueOpts{MaxAttempts: 1}); err != nil {
		t.Fatalf("enqueue: %v", err)
	}
	j, err := s.Claim(ctx)
	if err != nil || j == nil {
		t.Fatalf("claim: %v %v", j, err)
	}
	// attempts (1) >= max_attempts (1) => marked failed, not rescheduled.
	if err := s.Fail(ctx, j, errors.New("boom"), time.Second); err != nil {
		t.Fatalf("fail: %v", err)
	}
	if j2, err := s.Claim(ctx); err != nil || j2 != nil {
		t.Fatalf("exhausted job must not be reclaimable: %v %v", j2, err)
	}
}

func TestClaimIsExclusiveUnderConcurrency(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()
	if _, err := s.Enqueue(ctx, "noop", nil, EnqueueOpts{}); err != nil {
		t.Fatalf("enqueue: %v", err)
	}
	type res struct {
		j   *Job
		err error
	}
	ch := make(chan res, 2)
	for i := 0; i < 2; i++ {
		go func() {
			j, err := s.Claim(ctx)
			ch <- res{j, err}
		}()
	}
	got := 0
	for i := 0; i < 2; i++ {
		r := <-ch
		if r.err != nil {
			t.Fatalf("claim err: %v", r.err)
		}
		if r.j != nil {
			got++
		}
	}
	if got != 1 {
		t.Fatalf("exactly one goroutine should claim the job, got %d", got)
	}
}
