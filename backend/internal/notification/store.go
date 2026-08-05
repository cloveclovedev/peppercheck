package notification

import (
	"context"
	"database/sql"
	"fmt"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
	"github.com/cloveclovedev/peppercheck/backend/internal/core/jobs"
)

// Store issues the SQL over notification_settings and device_push_tokens.
type Store struct {
	db   *sql.DB
	jobs *jobs.Store
}

// NewStore builds a Store over an open database handle.
func NewStore(db *sql.DB) *Store { return &Store{db: db, jobs: jobs.NewStore(db)} }

// ProvisionSettingsInTx creates the user's notification_settings row (defaults
// fill every column) inside the caller's transaction (the identity fan-out).
func (s *Store) ProvisionSettingsInTx(ctx context.Context, q database.Querier, userID string) error {
	if _, err := q.ExecContext(ctx,
		`INSERT INTO public.notification_settings (user_id) VALUES ($1)`, userID); err != nil {
		return fmt.Errorf("insert notification_settings: %w", err)
	}
	return nil
}

// UpsertToken binds a device push token to the user, rebinding on conflict (a
// device re-logging-in). updated_at and last_active_at are Go-maintained on the
// conflict path. An empty deviceType is stored as NULL.
func (s *Store) UpsertToken(ctx context.Context, userID, token, deviceType string) error {
	device := sql.NullString{String: deviceType, Valid: deviceType != ""}
	if _, err := s.db.ExecContext(ctx, `
		INSERT INTO public.device_push_tokens (user_id, token, device_type)
		VALUES ($1, $2, $3)
		ON CONFLICT (token) DO UPDATE
		SET user_id = EXCLUDED.user_id,
		    device_type = EXCLUDED.device_type,
		    last_active_at = now(),
		    updated_at = now()`,
		userID, token, device); err != nil {
		return fmt.Errorf("upsert push token: %w", err)
	}
	return nil
}

// DeleteToken removes a token binding scoped to (user_id, token) so a user can
// only delete their own binding. Deleting a non-existent binding is a no-op.
func (s *Store) DeleteToken(ctx context.Context, userID, token string) error {
	if _, err := s.db.ExecContext(ctx,
		`DELETE FROM public.device_push_tokens WHERE user_id = $1 AND token = $2`,
		userID, token); err != nil {
		return fmt.Errorf("delete push token: %w", err)
	}
	return nil
}

// TokensForUser returns every device push token bound to the user (used by the
// send path to fan a notification out to all of a user's devices).
func (s *Store) TokensForUser(ctx context.Context, userID string) ([]string, error) {
	rows, err := s.db.QueryContext(ctx,
		`SELECT token FROM public.device_push_tokens WHERE user_id = $1`, userID)
	if err != nil {
		return nil, fmt.Errorf("query tokens: %w", err)
	}
	defer rows.Close()
	var out []string
	for rows.Next() {
		var t string
		if err := rows.Scan(&t); err != nil {
			return nil, fmt.Errorf("scan token: %w", err)
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// DeleteTokens prunes the given tokens for a user (the ones FCM reported as
// permanently invalid). The []string binds to text[] for `= ANY($2)` via the
// pgx driver; an empty list is a no-op.
func (s *Store) DeleteTokens(ctx context.Context, userID string, tokens []string) error {
	if len(tokens) == 0 {
		return nil
	}
	if _, err := s.db.ExecContext(ctx,
		`DELETE FROM public.device_push_tokens WHERE user_id = $1 AND token = ANY($2)`,
		userID, tokens); err != nil {
		return fmt.Errorf("delete tokens: %w", err)
	}
	return nil
}

// EnqueueSendInTx writes a job into the caller's transaction (transactional
// outbox), so a notification is enqueued atomically with the domain write that
// triggers it and never fires if that write rolls back.
func (s *Store) EnqueueSendInTx(ctx context.Context, tx database.Querier, kind string, payload any) error {
	_, err := s.jobs.EnqueueInTx(ctx, tx, kind, payload, jobs.EnqueueOpts{})
	return err
}
