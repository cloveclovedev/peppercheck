package accountdeletion

import (
	"context"
	"errors"
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/identity"
)

type fakeUsers struct {
	user identity.User
	err  error
}

func (f fakeUsers) FindUserByEmail(context.Context, string) (identity.User, error) {
	return f.user, f.err
}

type fakeStore struct{ upserts int }

func (f *fakeStore) Upsert(context.Context, string, string) error { f.upserts++; return nil }

func TestRequestDeletion(t *testing.T) {
	ctx := context.Background()

	// match -> upsert
	fs := &fakeStore{}
	svc := NewService(fakeUsers{user: identity.User{ID: "u1"}}, fs)
	if err := svc.RequestDeletion(ctx, "a@b.com"); err != nil || fs.upserts != 1 {
		t.Fatalf("match: err=%v upserts=%d", err, fs.upserts)
	}

	// no match -> no upsert, no error (uniform)
	fs = &fakeStore{}
	svc = NewService(fakeUsers{err: identity.ErrNotFound}, fs)
	if err := svc.RequestDeletion(ctx, "a@b.com"); err != nil || fs.upserts != 0 {
		t.Fatalf("no-match: err=%v upserts=%d", err, fs.upserts)
	}

	// invalid email -> no lookup, no error
	fs = &fakeStore{}
	svc = NewService(fakeUsers{err: errors.New("should not be called")}, fs)
	if err := svc.RequestDeletion(ctx, "not-an-email"); err != nil || fs.upserts != 0 {
		t.Fatalf("invalid: err=%v upserts=%d", err, fs.upserts)
	}

	// infrastructure error -> propagated
	fs = &fakeStore{}
	svc = NewService(fakeUsers{err: errors.New("db down")}, fs)
	if err := svc.RequestDeletion(ctx, "a@b.com"); err == nil {
		t.Fatal("infra error: want a non-nil error")
	}

	// email is case/whitespace-normalized before lookup and upsert.
	fs = &fakeStore{}
	svc = NewService(fakeUsers{user: identity.User{ID: "u1"}}, fs)
	if err := svc.RequestDeletion(ctx, "  A@B.COM  "); err != nil || fs.upserts != 1 {
		t.Fatalf("normalize: err=%v upserts=%d", err, fs.upserts)
	}
}
