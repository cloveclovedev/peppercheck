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
const SweepInterval = time.Minute

// scheduleNextSweep enqueues the next sweep occurrence, keyed by the target
// bucket so repeated calls within one interval (a retried run) collapse to a
// single job. HandleSweep calls this first, before any processing, so a run that
// fails partway cannot break the recurring chain.
func (s *Service) scheduleNextSweep(ctx context.Context) error {
	next := time.Now().Add(SweepInterval).Truncate(SweepInterval).UTC()
	_, err := s.jobs.Enqueue(ctx, JobKindSweep, map[string]string{}, jobs.EnqueueOpts{
		RunAt:          next,
		IdempotencyKey: "sweep:" + next.Format(time.RFC3339),
	})
	return err
}

// EnqueueMatchInTx writes a match job into the caller's transaction (used by
// publish, referee cancel, and the sweep's retry), so the match is queued
// atomically with the state change that warrants it.
func (s *Service) EnqueueMatchInTx(ctx context.Context, tx database.Querier, requestID string) error {
	_, err := s.jobs.EnqueueInTx(ctx, tx, JobKindMatch, map[string]string{"requestId": requestID}, jobs.EnqueueOpts{})
	return err
}
