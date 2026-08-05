package matching

import (
	"context"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
	"github.com/cloveclovedev/peppercheck/backend/internal/core/jobs"
)

// JobKindMatch is the worker job kind for matching a single referee request.
const JobKindMatch = "match_referee_request"

// EnqueueMatchInTx writes a match job into the caller's transaction (used by
// publish, referee cancel, and the sweep's retry), so the match is queued
// atomically with the state change that warrants it.
func (s *Service) EnqueueMatchInTx(ctx context.Context, tx database.Querier, requestID string) error {
	_, err := s.jobs.EnqueueInTx(ctx, tx, JobKindMatch, map[string]string{"requestId": requestID}, jobs.EnqueueOpts{})
	return err
}
