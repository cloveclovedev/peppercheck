package notification

import (
	"context"
	"testing"
	"time"

	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
)

func newStore(t *testing.T) *Store {
	t.Helper()
	db := testsupport.DB(t)
	if _, err := db.Exec("TRUNCATE public.users CASCADE"); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	return NewStore(db)
}

func seedUser(t *testing.T, s *Store) string {
	t.Helper()
	var id string
	if err := s.db.QueryRowContext(context.Background(),
		`INSERT INTO public.users DEFAULT VALUES RETURNING id`).Scan(&id); err != nil {
		t.Fatalf("seed user: %v", err)
	}
	return id
}

func TestProvisionSettingsInTx(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()
	uid := seedUser(t, s)
	if err := s.ProvisionSettingsInTx(ctx, s.db, uid); err != nil {
		t.Fatalf("provision settings: %v", err)
	}
	var evidence []byte
	if err := s.db.QueryRowContext(ctx,
		`SELECT evidence_reminder_minutes::text FROM public.notification_settings WHERE user_id = $1`, uid,
	).Scan(&evidence); err != nil {
		t.Fatalf("read settings: %v", err)
	}
	if string(evidence) != "{10}" {
		t.Fatalf("evidence_reminder_minutes = %s, want default {10}", evidence)
	}
}

func TestUpsertTokenRebinds(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()
	u1, u2 := seedUser(t, s), seedUser(t, s)

	if err := s.UpsertToken(ctx, u1, "tok", "android"); err != nil {
		t.Fatalf("insert: %v", err)
	}
	// Same token re-registered by a different user rebinds the row (ON CONFLICT token).
	if err := s.UpsertToken(ctx, u2, "tok", "ios"); err != nil {
		t.Fatalf("rebind: %v", err)
	}
	var owner, device string
	if err := s.db.QueryRowContext(ctx,
		`SELECT user_id, device_type FROM public.user_fcm_tokens WHERE token = $1`, "tok",
	).Scan(&owner, &device); err != nil {
		t.Fatalf("read token: %v", err)
	}
	if owner != u2 || device != "ios" {
		t.Fatalf("token owner=%s device=%s, want %s/ios", owner, device, u2)
	}
	var count int
	if err := s.db.QueryRowContext(ctx, `SELECT count(*) FROM public.user_fcm_tokens`).Scan(&count); err != nil {
		t.Fatalf("count: %v", err)
	}
	if count != 1 {
		t.Fatalf("token rows = %d, want 1 (rebind, not duplicate)", count)
	}
}

func TestUpsertTokenAdvancesUpdatedAt(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()
	uid := seedUser(t, s)
	if err := s.UpsertToken(ctx, uid, "tok", "android"); err != nil {
		t.Fatalf("insert: %v", err)
	}
	// Seed a past updated_at/last_active_at, then upsert the same token.
	past := time.Now().Add(-time.Hour)
	if _, err := s.db.ExecContext(ctx,
		`UPDATE public.user_fcm_tokens SET updated_at = $2, last_active_at = $2 WHERE token = $1`, "tok", past,
	); err != nil {
		t.Fatalf("seed past: %v", err)
	}
	if err := s.UpsertToken(ctx, uid, "tok", "android"); err != nil {
		t.Fatalf("conflict upsert: %v", err)
	}
	var updatedAt, lastActive time.Time
	if err := s.db.QueryRowContext(ctx,
		`SELECT updated_at, last_active_at FROM public.user_fcm_tokens WHERE token = $1`, "tok",
	).Scan(&updatedAt, &lastActive); err != nil {
		t.Fatalf("read timestamps: %v", err)
	}
	if !updatedAt.After(past) || !lastActive.After(past) {
		t.Fatalf("timestamps not advanced: updated_at=%v last_active=%v past=%v", updatedAt, lastActive, past)
	}
}

func TestDeleteTokenScoped(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()
	u1, u2 := seedUser(t, s), seedUser(t, s)
	if err := s.UpsertToken(ctx, u1, "tok-a", "android"); err != nil {
		t.Fatalf("insert a: %v", err)
	}
	if err := s.UpsertToken(ctx, u2, "tok-b", "ios"); err != nil {
		t.Fatalf("insert b: %v", err)
	}

	// u1 cannot delete u2's token (scoped to user_id + token): no-op.
	if err := s.DeleteToken(ctx, u1, "tok-b"); err != nil {
		t.Fatalf("scoped delete: %v", err)
	}
	var count int
	if err := s.db.QueryRowContext(ctx, `SELECT count(*) FROM public.user_fcm_tokens WHERE token = $1`, "tok-b").Scan(&count); err != nil {
		t.Fatalf("count b: %v", err)
	}
	if count != 1 {
		t.Fatalf("u1 must not delete u2's token; tok-b rows = %d", count)
	}

	// u1 deletes its own token.
	if err := s.DeleteToken(ctx, u1, "tok-a"); err != nil {
		t.Fatalf("own delete: %v", err)
	}
	if err := s.db.QueryRowContext(ctx, `SELECT count(*) FROM public.user_fcm_tokens WHERE token = $1`, "tok-a").Scan(&count); err != nil {
		t.Fatalf("count a: %v", err)
	}
	if count != 0 {
		t.Fatalf("u1's own token should be deleted; tok-a rows = %d", count)
	}
}
