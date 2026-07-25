package identity

import (
	"context"
	"errors"
	"testing"

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

func TestFindByIdentityNotFound(t *testing.T) {
	s := newStore(t)
	if _, err := s.FindByIdentity(context.Background(), "iss", "missing"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("err = %v, want ErrNotFound", err)
	}
}

func TestCreateWithIdentityThenFind(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()

	created, err := s.CreateWithIdentity(ctx, "iss", "sub-1")
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if created.ID == "" || created.Status != "active" {
		t.Fatalf("created = %+v", created)
	}

	found, err := s.FindByIdentity(ctx, "iss", "sub-1")
	if err != nil {
		t.Fatalf("find: %v", err)
	}
	if found.ID != created.ID {
		t.Fatalf("find returned %s, want %s", found.ID, created.ID)
	}
}

func TestCreateWithIdentityDuplicateSignalsNotFound(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()
	if _, err := s.CreateWithIdentity(ctx, "iss", "sub-dup"); err != nil {
		t.Fatalf("first create: %v", err)
	}
	// Second create for the same (issuer, subject) hits the unique constraint
	// and reports ErrNotFound so the caller re-resolves.
	if _, err := s.CreateWithIdentity(ctx, "iss", "sub-dup"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("duplicate create err = %v, want ErrNotFound", err)
	}
	// The rolled-back second insert must leave NO orphan users row: the users
	// INSERT and the user_identities INSERT share one transaction.
	var n int
	if err := s.db.QueryRowContext(ctx, `SELECT count(*) FROM public.users`).Scan(&n); err != nil {
		t.Fatalf("count users: %v", err)
	}
	if n != 1 {
		t.Fatalf("users count = %d after duplicate; want 1 (no orphan)", n)
	}
}

func TestDeleteUserCascadesIdentities(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()
	u, err := s.CreateWithIdentity(ctx, "iss", "sub-fk")
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if _, err := s.db.ExecContext(ctx, `DELETE FROM public.users WHERE id = $1`, u.ID); err != nil {
		t.Fatalf("delete user: %v", err)
	}
	var n int
	if err := s.db.QueryRowContext(ctx, `SELECT count(*) FROM public.user_identities WHERE user_id = $1`, u.ID).Scan(&n); err != nil {
		t.Fatalf("count identities: %v", err)
	}
	if n != 0 {
		t.Fatalf("identities remaining = %d after user delete; want 0 (FK cascade)", n)
	}
}
