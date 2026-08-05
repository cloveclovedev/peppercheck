package identity

import (
	"context"
	"database/sql"
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

	created, err := s.CreateWithIdentity(ctx, "iss", "sub-1", "sub-1@example.com", true, nil)
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

func TestStoreWorksWithRuntimeRole(t *testing.T) {
	db := testsupport.DBFromEnv(t, "APP_DATABASE_URL")
	const issuer = "runtime-role-test"
	const subject = "subject"
	clean := func() error {
		_, err := db.Exec(`
			DELETE FROM public.users u
			USING public.user_identities i
			WHERE u.id = i.user_id
			  AND i.issuer = $1
			  AND i.subject = $2`,
			issuer, subject,
		)
		return err
	}
	if err := clean(); err != nil {
		t.Fatalf("clean runtime-role fixtures: %v", err)
	}
	t.Cleanup(func() {
		if err := clean(); err != nil {
			t.Errorf("clean runtime-role fixtures: %v", err)
		}
	})

	s := NewStore(db)
	ctx := context.Background()
	created, err := s.CreateWithIdentity(ctx, issuer, subject, "runtime-role@example.com", true, nil)
	if err != nil {
		t.Fatalf("create with runtime role: %v", err)
	}
	found, err := s.FindByIdentity(ctx, issuer, subject)
	if err != nil {
		t.Fatalf("find with runtime role: %v", err)
	}
	if found.ID != created.ID {
		t.Fatalf("find returned %s, want %s", found.ID, created.ID)
	}
}

func TestCreateWithIdentityDuplicateSignalsNotFound(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()
	if _, err := s.CreateWithIdentity(ctx, "iss", "sub-dup", "sub-dup@example.com", true, nil); err != nil {
		t.Fatalf("first create: %v", err)
	}
	// Second create for the same (issuer, subject) hits the unique constraint
	// and reports ErrNotFound so the caller re-resolves.
	if _, err := s.CreateWithIdentity(ctx, "iss", "sub-dup", "sub-dup@example.com", true, nil); !errors.Is(err, ErrNotFound) {
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

func TestCreateWithIdentityProvisionErrorRollsBack(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()
	boom := errors.New("provision failed")

	_, err := s.CreateWithIdentity(ctx, "iss", "sub-prov", "sub-prov@example.com", true,
		func(context.Context, *sql.Tx, string) error { return boom })
	if !errors.Is(err, boom) {
		t.Fatalf("err = %v, want the provision error", err)
	}
	// The whole transaction rolled back: no orphan user or identity remains.
	var users, idents int
	if err := s.db.QueryRowContext(ctx, `SELECT count(*) FROM public.users`).Scan(&users); err != nil {
		t.Fatalf("count users: %v", err)
	}
	if err := s.db.QueryRowContext(ctx, `SELECT count(*) FROM public.user_identities`).Scan(&idents); err != nil {
		t.Fatalf("count identities: %v", err)
	}
	if users != 0 || idents != 0 {
		t.Fatalf("after a failed provision: users=%d identities=%d, want 0/0 (atomic rollback)", users, idents)
	}
}

func TestDeleteUserCascadesIdentities(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()
	u, err := s.CreateWithIdentity(ctx, "iss", "sub-fk", "sub-fk@example.com", true, nil)
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

func TestFindUserByEmail(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()

	u, err := s.CreateWithIdentity(ctx, "firebase", "sub-1", "User@Example.com", true, nil)
	if err != nil {
		t.Fatal(err)
	}
	got, err := s.FindUserByEmail(ctx, "user@example.com") // case-insensitive, verified
	if err != nil {
		t.Fatalf("FindUserByEmail: %v", err)
	}
	if got.ID != u.ID {
		t.Fatalf("got %s want %s", got.ID, u.ID)
	}
	if _, err := s.FindUserByEmail(ctx, "nobody@example.com"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("want ErrNotFound, got %v", err)
	}

	// UNVERIFIED email must NOT match.
	if _, err := s.CreateWithIdentity(ctx, "firebase", "sub-2", "unverified@example.com", false, nil); err != nil {
		t.Fatal(err)
	}
	if _, err := s.FindUserByEmail(ctx, "unverified@example.com"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("unverified email should not match, got %v", err)
	}

	// A second VERIFIED identity for the SAME user still resolves to that user.
	if _, err := s.db.ExecContext(ctx, `INSERT INTO public.user_identities (user_id, issuer, subject, email, email_verified)
		VALUES ($1, 'apple', 'sub-3', 'User@Example.com', true)`, u.ID); err != nil {
		t.Fatal(err)
	}
	if got, err := s.FindUserByEmail(ctx, "user@example.com"); err != nil || got.ID != u.ID {
		t.Fatalf("same-user duplicate should resolve: id=%s err=%v", got.ID, err)
	}

	// Two DIFFERENT verified users with the same email -> ambiguous -> ErrNotFound.
	if _, err := s.CreateWithIdentity(ctx, "firebase", "sub-4", "shared@example.com", true, nil); err != nil {
		t.Fatal(err)
	}
	if _, err := s.CreateWithIdentity(ctx, "firebase", "sub-5", "shared@example.com", true, nil); err != nil {
		t.Fatal(err)
	}
	if _, err := s.FindUserByEmail(ctx, "shared@example.com"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("ambiguous email should refuse (ErrNotFound), got %v", err)
	}
}

func TestTouchIdentityEmailRefreshesOnChange(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()

	if _, err := s.CreateWithIdentity(ctx, "iss", "sub-touch", "old@example.com", false, nil); err != nil {
		t.Fatal(err)
	}
	if err := s.TouchIdentityEmail(ctx, "iss", "sub-touch", "new@example.com", true); err != nil {
		t.Fatalf("touch: %v", err)
	}
	if _, err := s.FindUserByEmail(ctx, "old@example.com"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("old email should no longer match, got %v", err)
	}
	if _, err := s.FindUserByEmail(ctx, "new@example.com"); err != nil {
		t.Fatalf("new email should match after touch: %v", err)
	}
}
