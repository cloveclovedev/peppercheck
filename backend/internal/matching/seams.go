package matching

import (
	"context"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
)

// PointLocker reserves and refunds matching points PER REQUEST, returning a
// funding-source receipt (P4a-D17) so Phase 5 is a pure wiring swap. The real
// implementation arrives in Phase 5; Phase 4a wires a no-op.
//
// IDs are strings to match the codebase's internal-user identifier convention
// (identity.User.ID); the columns they map to are UUIDs.
type PointLocker interface {
	// LockForRequestInTx reserves cost points for one request and returns the
	// funding source recorded on that request's point_source.
	LockForRequestInTx(ctx context.Context, tx database.Querier, taskerID, requestID string, cost int) (pointSource string, err error)
	// RefundForRequestInTx idempotently reverses the lock, keyed by requestID.
	RefundForRequestInTx(ctx context.Context, tx database.Querier, requestID, reason string) error
}

// ObligationChecker returns which candidate referees have a pending obligation
// that excludes them from new matches. Phase 5 supplies the real
// implementation; Phase 4a returns none.
type ObligationChecker interface {
	FilterObligated(ctx context.Context, candidateIDs []string) ([]string, error)
}

type noopPointLocker struct{}

// NewNoopPointLocker returns a PointLocker that reserves nothing and always
// funds from the regular source — the Phase 4a wiring until Phase 5 lands.
func NewNoopPointLocker() PointLocker { return noopPointLocker{} }

func (noopPointLocker) LockForRequestInTx(context.Context, database.Querier, string, string, int) (string, error) {
	return "regular", nil
}

func (noopPointLocker) RefundForRequestInTx(context.Context, database.Querier, string, string) error {
	return nil
}

type noObligations struct{}

// NewNoObligations returns an ObligationChecker that never excludes a candidate
// — the Phase 4a wiring until Phase 5 lands.
func NewNoObligations() ObligationChecker { return noObligations{} }

func (noObligations) FilterObligated(context.Context, []string) ([]string, error) {
	return nil, nil
}
