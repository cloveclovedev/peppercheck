// Package worker runs Postgres-backed durable jobs. A ticker drives a claim
// loop; each due job is dispatched to a registered handler and marked
// succeeded, rescheduled with backoff, or failed. Phase 1 registers only a
// noop handler to exercise the machinery. Each RunDue cycle that drains the
// queue without error optionally POSTs to a Better Stack heartbeat URL
// (HEARTBEAT_URL_WORKER, Phase 7-A monitoring) so an external monitor can
// alert if the worker stops running entirely.
package worker

import (
	"context"
	"database/sql"
	"fmt"
	"log/slog"
	"net/http"
	"time"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/config"
	"github.com/cloveclovedev/peppercheck/backend/internal/core/jobs"
)

// Handler processes one job. Returning an error reschedules (or fails) the job.
type Handler func(ctx context.Context, j *jobs.Job) error

// Worker claims and dispatches durable jobs.
type Worker struct {
	store        *jobs.Store
	logger       *slog.Logger
	handlers     map[string]Handler
	interval     time.Duration
	heartbeatURL string
	httpClient   *http.Client
}

// New builds a Worker over an open database handle.
func New(db *sql.DB, logger *slog.Logger) *Worker {
	return &Worker{
		store:      jobs.NewStore(db),
		logger:     logger,
		handlers:   map[string]Handler{},
		interval:   time.Second,
		httpClient: &http.Client{Timeout: 5 * time.Second},
	}
}

// Register binds a handler to a job kind.
func (w *Worker) Register(kind string, h Handler) { w.handlers[kind] = h }

// SetHeartbeatURL configures the optional Better Stack heartbeat URL POSTed
// to after every RunDue cycle that drains the queue without error. Leaving
// it empty (the default) disables heartbeats entirely -- not every
// environment monitors the worker this way.
func (w *Worker) SetHeartbeatURL(url string) { w.heartbeatURL = url }

// RunDue drains every currently-due job, then returns. It stops early if ctx is
// cancelled or a claim errors.
func (w *Worker) RunDue(ctx context.Context) error {
	if _, err := w.store.FailExpired(ctx); err != nil {
		return err
	}
	for {
		if err := ctx.Err(); err != nil {
			return err
		}
		j, err := w.store.Claim(ctx)
		if err != nil {
			return err
		}
		if j == nil {
			w.sendHeartbeat(ctx)
			return nil
		}
		w.process(ctx, j)
	}
}

// sendHeartbeat POSTs to the configured Better Stack heartbeat URL, if any.
// It is deliberately best-effort: a heartbeat is a liveness signal for an
// external monitor, not part of job-processing correctness, so a failure
// here is logged at warn level and never propagated -- it must never break,
// delay, or retry job processing.
func (w *Worker) sendHeartbeat(ctx context.Context) {
	if w.heartbeatURL == "" {
		return
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, w.heartbeatURL, nil)
	if err != nil {
		// Do not log w.heartbeatURL itself -- Better Stack heartbeat URLs
		// carry an auth token in the path.
		w.logger.Warn("heartbeat request build failed", "error", err)
		return
	}
	resp, err := w.httpClient.Do(req)
	if err != nil {
		w.logger.Warn("heartbeat POST failed", "error", err)
		return
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		w.logger.Warn("heartbeat POST returned non-2xx", "status", resp.StatusCode)
	}
}

func (w *Worker) process(ctx context.Context, j *jobs.Job) {
	h, ok := w.handlers[j.Kind]
	if !ok {
		_ = w.store.Fail(ctx, j, fmt.Errorf("no handler registered for kind %q", j.Kind), 5*time.Minute)
		w.logger.Error("no handler for job kind", "kind", j.Kind, "job_id", j.ID)
		return
	}
	if err := w.runHandler(ctx, h, j); err != nil {
		backoff := time.Duration(j.Attempts) * 30 * time.Second
		if ferr := w.store.Fail(ctx, j, err, backoff); ferr != nil {
			w.logger.Error("failed to record job failure", "job_id", j.ID, "error", ferr)
		}
		w.logger.Error("job failed", "kind", j.Kind, "job_id", j.ID, "attempts", j.Attempts, "error", err)
		return
	}
	if err := w.store.Complete(ctx, j); err != nil {
		w.logger.Error("failed to mark job complete", "job_id", j.ID, "error", err)
	}
}

// runHandler runs h and converts a panic into an error so one bad job cannot
// crash the whole worker process.
func (w *Worker) runHandler(ctx context.Context, h Handler, j *jobs.Job) (err error) {
	defer func() {
		if r := recover(); r != nil {
			err = fmt.Errorf("handler panicked: %v", r)
		}
	}()
	return h(ctx, j)
}

// Loop runs RunDue on each tick until ctx is cancelled.
func (w *Worker) Loop(ctx context.Context) error {
	t := time.NewTicker(w.interval)
	defer t.Stop()
	w.logger.Info("worker started", "interval", w.interval.String())
	for {
		select {
		case <-ctx.Done():
			w.logger.Info("worker shutting down")
			return nil
		case <-t.C:
			if err := w.RunDue(ctx); err != nil && ctx.Err() == nil {
				w.logger.Error("run due failed", "error", err)
			}
		}
	}
}

// Run wires the built-in handlers and loops until ctx is cancelled.
func Run(ctx context.Context, cfg config.Config, logger *slog.Logger, db *sql.DB) error {
	w := New(db, logger)
	w.SetHeartbeatURL(cfg.HeartbeatURLWorker)
	w.Register("noop", func(context.Context, *jobs.Job) error { return nil })
	return w.Loop(ctx)
}
