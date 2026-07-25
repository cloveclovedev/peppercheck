package worker

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"

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

// --- Heartbeat (HEARTBEAT_URL_WORKER) ---------------------------------------

func TestHeartbeatPostedAfterSuccessfulCycle(t *testing.T) {
	db := testsupport.DB(t)
	if _, err := db.Exec("TRUNCATE public.jobs"); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	ctx := context.Background()
	store := jobs.NewStore(db)
	if _, err := store.Enqueue(ctx, "noop", nil, jobs.EnqueueOpts{}); err != nil {
		t.Fatalf("enqueue: %v", err)
	}

	var received int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			t.Errorf("method = %s, want POST", r.Method)
		}
		atomic.AddInt32(&received, 1)
		w.WriteHeader(http.StatusOK)
	}))
	defer srv.Close()

	w := New(db, logging.New("error"))
	w.SetHeartbeatURL(srv.URL)
	w.Register("noop", func(context.Context, *jobs.Job) error { return nil })

	if err := w.RunDue(ctx); err != nil {
		t.Fatalf("RunDue: %v", err)
	}
	if got := atomic.LoadInt32(&received); got != 1 {
		t.Fatalf("heartbeat POSTs received = %d, want 1", got)
	}
}

func TestHeartbeatThrottledWithinInterval(t *testing.T) {
	db := testsupport.DB(t)
	if _, err := db.Exec("TRUNCATE public.jobs"); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	ctx := context.Background()

	var received int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		atomic.AddInt32(&received, 1)
		w.WriteHeader(http.StatusOK)
	}))
	defer srv.Close()

	w := New(db, logging.New("error"))
	w.SetHeartbeatURL(srv.URL)
	// A long throttle window means the second (and any subsequent) clean
	// drain inside the window must NOT ping again.
	w.heartbeatInterval = time.Hour

	// Two back-to-back clean drains (empty queue drains immediately and
	// still pings on the first, throttled on the second).
	if err := w.RunDue(ctx); err != nil {
		t.Fatalf("RunDue #1: %v", err)
	}
	if err := w.RunDue(ctx); err != nil {
		t.Fatalf("RunDue #2: %v", err)
	}
	if got := atomic.LoadInt32(&received); got != 1 {
		t.Fatalf("heartbeat POSTs received = %d, want 1 (second drain must be throttled)", got)
	}
}

// failTransport fails the test the instant a request is attempted -- used to
// prove NO heartbeat request is ever sent when the URL is left unset, rather
// than relying on a flaky "wait and see if nothing arrives" assertion.
type failTransport struct{ t *testing.T }

func (f failTransport) RoundTrip(*http.Request) (*http.Response, error) {
	f.t.Fatal("heartbeat HTTP request must not be sent when HeartbeatURL is unset")
	return nil, nil
}

func TestHeartbeatSkippedWhenURLUnset(t *testing.T) {
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
	// heartbeatURL is deliberately left at its empty default.
	w.httpClient = &http.Client{Transport: failTransport{t}}
	w.Register("noop", func(context.Context, *jobs.Job) error { return nil })

	if err := w.RunDue(ctx); err != nil {
		t.Fatalf("RunDue: %v", err)
	}
}

func TestHeartbeatFailureDoesNotFailCycle(t *testing.T) {
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
	// Nothing is listening on this address -- the POST fails with a
	// connection error, which must be logged as a warning, never surfaced as
	// a RunDue error or allowed to skip job processing.
	w.SetHeartbeatURL("http://127.0.0.1:1/heartbeat")
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
		t.Fatalf("job status = %q, want succeeded despite heartbeat POST failure", status)
	}
}
