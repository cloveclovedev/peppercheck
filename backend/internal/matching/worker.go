package matching

import (
	"context"
	"time"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
	"github.com/cloveclovedev/peppercheck/backend/internal/core/jobs"
)

// JobKindMatch is the worker job kind for matching a single referee request.
const JobKindMatch = "match_referee_request"

// JobKindSweep is the worker job kind for the recurring pass that expires
// past-cutoff pending requests and re-matches the rest. It reschedules itself,
// so a single bootstrap enqueue keeps the chain alive.
const JobKindSweep = "sweep_pending_requests"

// SweepInterval is the cadence of the self-rescheduling sweep.
const SweepInterval = time.Hour

// sweepKey is a per-bucket idempotency key so at most one sweep is scheduled per
// interval, no matter how many workers (or retries) try to enqueue it.
func sweepKey(runAt time.Time) string {
	return JobKindSweep + ":" + runAt.UTC().Truncate(SweepInterval).Format(time.RFC3339)
}

// scheduleNextSweep enqueues the sweep at the next interval boundary. The
// bucketed key + ON CONFLICT DO NOTHING makes concurrent/duplicate schedules a
// no-op, so the chain never forks or dies. HandleSweep calls this first, before
// any processing, so a run that fails partway cannot break the recurring chain.
func (s *Service) scheduleNextSweep(ctx context.Context) error {
	next := time.Now().Truncate(SweepInterval).Add(SweepInterval)
	_, err := s.jobs.Enqueue(ctx, JobKindSweep, struct{}{},
		jobs.EnqueueOpts{RunAt: next, IdempotencyKey: sweepKey(next)})
	return err
}

// BootstrapSweep seeds the current interval's sweep on startup. It is idempotent
// across restarts and multiple workers (the bucketed key), so a worker that
// comes up mid-interval re-seeds the chain without duplicating it.
func (s *Service) BootstrapSweep(ctx context.Context) error {
	now := time.Now().Truncate(SweepInterval)
	_, err := s.jobs.Enqueue(ctx, JobKindSweep, struct{}{},
		jobs.EnqueueOpts{RunAt: now, IdempotencyKey: sweepKey(now)})
	return err
}

// EnqueueMatchInTx writes a match job into the caller's transaction (used by
// publish, referee cancel, and the sweep's retry), so the match is queued
// atomically with the state change that warrants it.
func (s *Service) EnqueueMatchInTx(ctx context.Context, tx database.Querier, requestID string) error {
	_, err := s.jobs.EnqueueInTx(ctx, tx, JobKindMatch, map[string]string{"requestId": requestID}, jobs.EnqueueOpts{})
	return err
}
