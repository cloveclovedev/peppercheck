package worker

import (
	"context"
	"errors"
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/jobs"
	"github.com/cloveclovedev/peppercheck/backend/internal/core/logging"
	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
)

func TestRunDueProcessesRegisteredJob(t *testing.T) {
	db := testsupport.DB(t)
	if _, err := db.Exec("TRUNCATE public.jobs"); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	ctx := context.Background()
	store := jobs.NewStore(db)
	if _, err := store.Enqueue(ctx, "noop", nil, jobs.EnqueueOpts{}); err != nil {
		t.Fatalf("enqueue: %v", err)
	}

	w := New(db, logging.New("error"))
	ran := false
	w.Register("noop", func(context.Context, *jobs.Job) error { ran = true; return nil })

	if err := w.RunDue(ctx); err != nil {
		t.Fatalf("RunDue: %v", err)
	}
	if !ran {
		t.Fatal("handler was not invoked")
	}

	var status string
	if err := db.QueryRow("SELECT status FROM public.jobs LIMIT 1").Scan(&status); err != nil {
		t.Fatalf("scan status: %v", err)
	}
	if status != "succeeded" {
		t.Fatalf("job status = %q, want succeeded", status)
	}
}

func TestRunDueFailingHandlerReschedules(t *testing.T) {
	db := testsupport.DB(t)
	if _, err := db.Exec("TRUNCATE public.jobs"); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	ctx := context.Background()
	store := jobs.NewStore(db)
	if _, err := store.Enqueue(ctx, "boom", nil, jobs.EnqueueOpts{MaxAttempts: 5}); err != nil {
		t.Fatalf("enqueue: %v", err)
	}

	w := New(db, logging.New("error"))
	w.Register("boom", func(context.Context, *jobs.Job) error { return errors.New("nope") })

	if err := w.RunDue(ctx); err != nil {
		t.Fatalf("RunDue: %v", err)
	}
	var status string
	if err := db.QueryRow("SELECT status FROM public.jobs LIMIT 1").Scan(&status); err != nil {
		t.Fatalf("scan status: %v", err)
	}
	if status != "pending" {
		t.Fatalf("failed job with attempts left should be pending, got %q", status)
	}
}

func TestPanickingHandlerFailsJobNotWorker(t *testing.T) {
	db := testsupport.DB(t)
	if _, err := db.Exec("TRUNCATE public.jobs"); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	ctx := context.Background()
	store := jobs.NewStore(db)
	if _, err := store.Enqueue(ctx, "boom", nil, jobs.EnqueueOpts{MaxAttempts: 5}); err != nil {
		t.Fatalf("enqueue: %v", err)
	}
	w := New(db, logging.New("error"))
	w.Register("boom", func(context.Context, *jobs.Job) error { panic("kaboom") })
	// RunDue must NOT panic out (that would crash the worker) — it recovers and reschedules.
	if err := w.RunDue(ctx); err != nil {
		t.Fatalf("RunDue returned error: %v", err)
	}
	var status string
	if err := db.QueryRow("SELECT status FROM public.jobs LIMIT 1").Scan(&status); err != nil {
		t.Fatalf("scan: %v", err)
	}
	if status != "pending" {
		t.Fatalf("panicking handler should reschedule job to pending, got %q", status)
	}
}
