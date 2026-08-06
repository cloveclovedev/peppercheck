package accountdeletion

import (
	"context"
	"database/sql"
	"fmt"
)

// Store issues the SQL over account_deletion_requests.
type Store struct{ db *sql.DB }

// NewStore builds a Store over an open database handle.
func NewStore(db *sql.DB) *Store { return &Store{db: db} }

// Upsert records (or refreshes) a single web deletion request per user. It
// only ever creates or refreshes an 'unverified' row: the ON CONFLICT ...
// WHERE guard leaves a row that Phase 6 already advanced to 'verified' or
// 'processed' UNTOUCHED, so a third party who merely knows the email cannot
// revert a confirmed/executed request back to 'unverified'. State machine:
// unverified -> verified -> processed (only Phase 6 advances it); the public
// form only ever writes 'unverified'. updated_at is Go-maintained.
func (s *Store) Upsert(ctx context.Context, userID, claimedEmail string) error {
	_, err := s.db.ExecContext(ctx, `
		INSERT INTO public.account_deletion_requests (user_id, claimed_email, status, source)
		VALUES ($1, $2, 'unverified', 'web')
		ON CONFLICT (user_id) DO UPDATE
		SET claimed_email = EXCLUDED.claimed_email,
		    requested_at  = now(),
		    updated_at    = now()
		WHERE public.account_deletion_requests.status = 'unverified'`,
		userID, claimedEmail)
	if err != nil {
		return fmt.Errorf("upsert deletion request: %w", err)
	}
	return nil
}
