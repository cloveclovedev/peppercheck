package profile

import (
	"context"
	"errors"
	"regexp"
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
)

// seedUser inserts a bare users row and returns its id.
func seedUser(t *testing.T, s *Store) string {
	t.Helper()
	var id string
	if err := s.db.QueryRowContext(context.Background(),
		`INSERT INTO public.users DEFAULT VALUES RETURNING id`).Scan(&id); err != nil {
		t.Fatalf("seed user: %v", err)
	}
	return id
}

// provision runs ProvisionInTx inside a real transaction (as the identity
// fan-out does), since it uses SAVEPOINT and cannot run in autocommit.
func provision(t *testing.T, s *Store, userID string) {
	t.Helper()
	ctx := context.Background()
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		t.Fatalf("begin: %v", err)
	}
	defer func() { _ = tx.Rollback() }()
	if err := s.ProvisionInTx(ctx, tx, userID); err != nil {
		t.Fatalf("provision: %v", err)
	}
	if err := tx.Commit(); err != nil {
		t.Fatalf("commit: %v", err)
	}
}

func newStore(t *testing.T) *Store {
	t.Helper()
	db := testsupport.DB(t)
	if _, err := db.Exec("TRUNCATE public.users CASCADE"); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	return NewStore(db)
}

var usernamePattern = regexp.MustCompile(`^user_[0-9a-f]{8}$`)

func TestProvisionInTxGeneratesUsername(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()
	uid := seedUser(t, s)

	provision(t, s, uid)
	p, err := s.GetByUserID(ctx, uid)
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if !usernamePattern.MatchString(p.Username) {
		t.Fatalf("username = %q, want user_<8 hex>", p.Username)
	}
	if p.Timezone != "UTC" {
		t.Fatalf("timezone = %q, want UTC default", p.Timezone)
	}
}

func TestProvisionInTxDistinctUsernames(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()
	seen := map[string]bool{}
	for i := 0; i < 20; i++ {
		uid := seedUser(t, s)
		provision(t, s, uid)
		p, err := s.GetByUserID(ctx, uid)
		if err != nil {
			t.Fatalf("get %d: %v", i, err)
		}
		if seen[p.Username] {
			t.Fatalf("duplicate generated username %q", p.Username)
		}
		seen[p.Username] = true
	}
}

func TestGetByUserIDNotFound(t *testing.T) {
	s := newStore(t)
	if _, err := s.GetByUserID(context.Background(), seedUser(t, s)); !errors.Is(err, ErrNotFound) {
		t.Fatalf("err = %v, want ErrNotFound", err)
	}
}

func TestUpdateUsernameTaken(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()
	u1, u2 := seedUser(t, s), seedUser(t, s)
	provision(t, s, u1)
	provision(t, s, u2)
	p1, _ := s.GetByUserID(ctx, u1)

	// u2 tries to take u1's username.
	taken := p1.Username
	_, _, err := s.Update(ctx, u2, UpdateFields{Username: &taken})
	if !errors.Is(err, ErrUsernameTaken) {
		t.Fatalf("err = %v, want ErrUsernameTaken", err)
	}
}

func TestUpdateFieldsAndAvatarPrevious(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()
	uid := seedUser(t, s)
	provision(t, s, uid)

	// Set username + timezone in one partial update; avatar not provided.
	newName, tz := "alice", "Asia/Tokyo"
	p, prev, err := s.Update(ctx, uid, UpdateFields{Username: &newName, Timezone: &tz})
	if err != nil {
		t.Fatalf("update: %v", err)
	}
	if p.Username != "alice" || p.Timezone != "Asia/Tokyo" {
		t.Fatalf("updated profile = %+v", p)
	}
	if prev != nil {
		t.Fatalf("prevAvatar = %v, want nil when avatar not provided", *prev)
	}

	// First avatar set: previous is nil (was NULL).
	a1 := "https://cdn.example.com/avatar/" + uid + "/a.jpg"
	_, prev1, err := s.Update(ctx, uid, UpdateFields{AvatarURL: &a1})
	if err != nil {
		t.Fatalf("update avatar 1: %v", err)
	}
	if prev1 != nil {
		t.Fatalf("prev1 = %v, want nil for first avatar", *prev1)
	}

	// Second avatar set: previous is a1.
	a2 := "https://cdn.example.com/avatar/" + uid + "/b.jpg"
	got, prev2, err := s.Update(ctx, uid, UpdateFields{AvatarURL: &a2})
	if err != nil {
		t.Fatalf("update avatar 2: %v", err)
	}
	if prev2 == nil || *prev2 != a1 {
		t.Fatalf("prev2 = %v, want %q", prev2, a1)
	}
	if got.AvatarURL == nil || *got.AvatarURL != a2 {
		t.Fatalf("avatar = %v, want %q", got.AvatarURL, a2)
	}
}
