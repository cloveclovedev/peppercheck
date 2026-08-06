// Package inbox is the webhook idempotency primitive. Inbound webhook events
// are recorded once per (source, event_id); duplicate at-least-once deliveries
// are detected and ignored. Phase 1 provides the store only; no endpoint yet.
package inbox

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
)

// Store issues the SQL backing the webhook inbox.
type Store struct{ db *sql.DB }

// NewStore builds a Store over an open database handle.
func NewStore(db *sql.DB) *Store { return &Store{db: db} }

// Insert records a webhook event. It returns isNew=false when this
// (source, event_id) was already recorded (a duplicate delivery).
func (s *Store) Insert(ctx context.Context, source, eventID string, payload any) (isNew bool, err error) {
	raw, err := json.Marshal(payload)
	if err != nil {
		return false, fmt.Errorf("marshal payload: %w", err)
	}
	var id string
	err = s.db.QueryRowContext(ctx, `
		INSERT INTO public.webhook_inbox (source, event_id, payload)
		VALUES ($1, $2, $3)
		ON CONFLICT (source, event_id) DO NOTHING
		RETURNING id`,
		source, eventID, raw,
	).Scan(&id)
	if errors.Is(err, sql.ErrNoRows) {
		return false, nil // duplicate delivery
	}
	if err != nil {
		return false, fmt.Errorf("insert inbox event: %w", err)
	}
	return true, nil
}
