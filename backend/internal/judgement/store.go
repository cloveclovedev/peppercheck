package judgement

import (
	"context"
	"fmt"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
)

// Provisioner creates and removes the awaiting_evidence judgement row keyed 1:1
// to a referee request. The full judgement lifecycle is Phase 4c. IDs are
// strings to match the codebase's internal identifier convention; they map to
// UUID columns.
type Provisioner struct{}

// NewProvisioner builds a Provisioner. It holds no state; the tx is passed per
// call so the write joins the matching worker's transaction.
func NewProvisioner() *Provisioner { return &Provisioner{} }

// CreateAwaitingEvidenceInTx inserts the judgement row for a matched request.
// The PK = request id makes a duplicate insert a no-op conflict, so an
// at-least-once matching worker (#464) stays idempotent.
func (p *Provisioner) CreateAwaitingEvidenceInTx(ctx context.Context, tx database.Querier, requestID string) error {
	_, err := tx.ExecContext(ctx,
		`INSERT INTO public.judgements (id, status) VALUES ($1, $2)
		 ON CONFLICT (id) DO NOTHING`,
		requestID, StatusAwaitingEvidence)
	if err != nil {
		return fmt.Errorf("insert judgement: %w", err)
	}
	return nil
}

// DeleteIfAwaitingEvidenceInTx removes the judgement only while it is still
// awaiting_evidence (used by referee cancel before any evidence is submitted).
// Returns whether a row was deleted.
func (p *Provisioner) DeleteIfAwaitingEvidenceInTx(ctx context.Context, tx database.Querier, requestID string) (bool, error) {
	res, err := tx.ExecContext(ctx,
		`DELETE FROM public.judgements WHERE id = $1 AND status = $2`,
		requestID, StatusAwaitingEvidence)
	if err != nil {
		return false, fmt.Errorf("delete judgement: %w", err)
	}
	n, _ := res.RowsAffected()
	return n > 0, nil
}
