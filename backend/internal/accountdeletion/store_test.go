package accountdeletion

import (
	"context"
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
)

func newTestStore(t *testing.T) (*Store, string) {
	t.Helper()
	db := testsupport.DB(t)
	if _, err := db.Exec("TRUNCATE public.users CASCADE"); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	var userID string
	if err := db.QueryRow(`INSERT INTO public.users DEFAULT VALUES RETURNING id`).Scan(&userID); err != nil {
		t.Fatalf("insert user: %v", err)
	}
	return NewStore(db), userID
}

func TestUpsertInsertsOneRow(t *testing.T) {
	s, userID := newTestStore(t)
	ctx := context.Background()

	if err := s.Upsert(ctx, userID, "first@example.com"); err != nil {
		t.Fatalf("upsert: %v", err)
	}

	var count int
	var email, status string
	if err := s.db.QueryRow(
		`SELECT count(*) FROM public.account_deletion_requests WHERE user_id = $1`, userID,
	).Scan(&count); err != nil {
		t.Fatalf("count: %v", err)
	}
	if count != 1 {
		t.Fatalf("count = %d, want 1", count)
	}
	if err := s.db.QueryRow(
		`SELECT claimed_email, status FROM public.account_deletion_requests WHERE user_id = $1`, userID,
	).Scan(&email, &status); err != nil {
		t.Fatalf("select: %v", err)
	}
	if email != "first@example.com" || status != "unverified" {
		t.Fatalf("email=%q status=%q", email, status)
	}
}

func TestUpsertRefreshesClaimedEmailForSameUser(t *testing.T) {
	s, userID := newTestStore(t)
	ctx := context.Background()

	if err := s.Upsert(ctx, userID, "first@example.com"); err != nil {
		t.Fatalf("first upsert: %v", err)
	}
	if err := s.Upsert(ctx, userID, "second@example.com"); err != nil {
		t.Fatalf("second upsert: %v", err)
	}

	var count int
	var email string
	if err := s.db.QueryRow(
		`SELECT count(*) FROM public.account_deletion_requests WHERE user_id = $1`, userID,
	).Scan(&count); err != nil {
		t.Fatalf("count: %v", err)
	}
	if count != 1 {
		t.Fatalf("count = %d, want 1 (repeated requests collapse to one row)", count)
	}
	if err := s.db.QueryRow(
		`SELECT claimed_email FROM public.account_deletion_requests WHERE user_id = $1`, userID,
	).Scan(&email); err != nil {
		t.Fatalf("select: %v", err)
	}
	if email != "second@example.com" {
		t.Fatalf("email = %q, want the refreshed value", email)
	}
}

func TestUpsertDoesNotRevertAVerifiedRequest(t *testing.T) {
	s, userID := newTestStore(t)
	ctx := context.Background()

	if err := s.Upsert(ctx, userID, "original@example.com"); err != nil {
		t.Fatalf("upsert: %v", err)
	}
	if _, err := s.db.Exec(
		`UPDATE public.account_deletion_requests SET status = 'verified' WHERE user_id = $1`, userID,
	); err != nil {
		t.Fatalf("mark verified: %v", err)
	}

	if err := s.Upsert(ctx, userID, "attacker-supplied@example.com"); err != nil {
		t.Fatalf("second upsert: %v", err)
	}

	var email, status string
	if err := s.db.QueryRow(
		`SELECT claimed_email, status FROM public.account_deletion_requests WHERE user_id = $1`, userID,
	).Scan(&email, &status); err != nil {
		t.Fatalf("select: %v", err)
	}
	if status != "verified" {
		t.Fatalf("status = %q, want it to stay verified (not reverted)", status)
	}
	if email != "original@example.com" {
		t.Fatalf("claimed_email = %q, want it unchanged", email)
	}
}
