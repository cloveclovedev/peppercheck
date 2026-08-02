package notification

import (
	"context"
	"database/sql"
	"fmt"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
)

// Store issues the SQL over notification_settings and device_push_tokens.
type Store struct {
	db *sql.DB
}

// NewStore builds a Store over an open database handle.
func NewStore(db *sql.DB) *Store { return &Store{db: db} }

// ProvisionSettingsInTx creates the user's notification_settings row (defaults
// fill every column) inside the caller's transaction (the identity fan-out).
func (s *Store) ProvisionSettingsInTx(ctx context.Context, q database.Querier, userID string) error {
	if _, err := q.ExecContext(ctx,
		`INSERT INTO public.notification_settings (user_id) VALUES ($1)`, userID); err != nil {
		return fmt.Errorf("insert notification_settings: %w", err)
	}
	return nil
}

// UpsertToken binds an FCM token to the user, rebinding on conflict (a device
// re-logging-in). updated_at and last_active_at are Go-maintained on the
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
		return fmt.Errorf("upsert fcm token: %w", err)
	}
	return nil
}

// DeleteToken removes a token binding scoped to (user_id, token) so a user can
// only delete their own binding. Deleting a non-existent binding is a no-op.
func (s *Store) DeleteToken(ctx context.Context, userID, token string) error {
	if _, err := s.db.ExecContext(ctx,
		`DELETE FROM public.device_push_tokens WHERE user_id = $1 AND token = $2`,
		userID, token); err != nil {
		return fmt.Errorf("delete fcm token: %w", err)
	}
	return nil
}
