package identity

import (
	"context"
	"database/sql"
	"errors"
	"sync"
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
)

// fakeStore scripts FindByIdentity/CreateWithIdentity results per call. On a
// scripted successful create it invokes the provision callback (with a nil tx,
// which the fake provisioner ignores) so provisioning wiring is exercised.
type fakeStore struct {
	findResults   []result
	createResults []result
	finds         int
	creates       int
}

type result struct {
	u   User
	err error
}

func (f *fakeStore) FindByIdentity(_ context.Context, _, _ string) (User, error) {
	r := f.findResults[f.finds]
	f.finds++
	return r.u, r.err
}

func (f *fakeStore) CreateWithIdentity(ctx context.Context, _, _ string,
	provision func(ctx context.Context, tx *sql.Tx, userID string) error) (User, error) {
	r := f.createResults[f.creates]
	f.creates++
	if r.err != nil {
		return User{}, r.err
	}
	if provision != nil {
		if err := provision(ctx, nil, r.u.ID); err != nil {
			return User{}, err
		}
	}
	return r.u, nil
}

// fakeProvisioner records the user ids it was asked to provision and can be
// scripted to fail.
type fakeProvisioner struct {
	calls []string
	err   error
}

func (f *fakeProvisioner) ProvisionInTx(_ context.Context, _ database.Querier, userID string) error {
	f.calls = append(f.calls, userID)
	return f.err
}

func TestResolveExistingUser(t *testing.T) {
	f := &fakeStore{findResults: []result{{u: User{ID: "u1"}}}}
	got, err := NewService(f, nil).ResolveOrProvision(context.Background(), "iss", "sub")
	if err != nil || got.ID != "u1" {
		t.Fatalf("got %+v err %v", got, err)
	}
	if f.creates != 0 {
		t.Fatalf("should not create when user exists")
	}
}

func TestResolveProvisionsNewUser(t *testing.T) {
	f := &fakeStore{
		findResults:   []result{{err: ErrNotFound}},
		createResults: []result{{u: User{ID: "u2"}}},
	}
	got, err := NewService(f, nil).ResolveOrProvision(context.Background(), "iss", "sub")
	if err != nil || got.ID != "u2" {
		t.Fatalf("got %+v err %v", got, err)
	}
}

func TestResolveOrProvisionRunsProvisioner(t *testing.T) {
	p := &fakeProvisioner{}
	f := &fakeStore{
		findResults:   []result{{err: ErrNotFound}},
		createResults: []result{{u: User{ID: "u2"}}},
	}
	got, err := NewService(f, p).ResolveOrProvision(context.Background(), "iss", "sub")
	if err != nil || got.ID != "u2" {
		t.Fatalf("got %+v err %v", got, err)
	}
	if len(p.calls) != 1 || p.calls[0] != "u2" {
		t.Fatalf("provisioner calls = %v, want exactly one for u2", p.calls)
	}

	// An already-known identity must not re-run the provisioner.
	p2 := &fakeProvisioner{}
	f2 := &fakeStore{findResults: []result{{u: User{ID: "u1"}}}}
	if _, err := NewService(f2, p2).ResolveOrProvision(context.Background(), "iss", "sub"); err != nil {
		t.Fatalf("resolve existing: %v", err)
	}
	if len(p2.calls) != 0 {
		t.Fatalf("provisioner ran %d times for an existing user, want 0", len(p2.calls))
	}
}

func TestResolveOrProvisionProvisionerErrorAborts(t *testing.T) {
	sentinel := errors.New("provision boom")
	p := &fakeProvisioner{err: sentinel}
	f := &fakeStore{
		findResults:   []result{{err: ErrNotFound}},
		createResults: []result{{u: User{ID: "u2"}}},
	}
	got, err := NewService(f, p).ResolveOrProvision(context.Background(), "iss", "sub")
	if err == nil || got.ID != "" {
		t.Fatalf("got %+v err %v, want a provisioning error and no user", got, err)
	}
}

func TestResolveRefindsWhenCreateLosesRace(t *testing.T) {
	f := &fakeStore{
		findResults:   []result{{err: ErrNotFound}, {u: User{ID: "u3"}}}, // 1st: absent, 2nd: winner's row
		createResults: []result{{err: ErrNotFound}},                      // create lost the unique race
	}
	got, err := NewService(f, nil).ResolveOrProvision(context.Background(), "iss", "sub")
	if err != nil || got.ID != "u3" {
		t.Fatalf("got %+v err %v", got, err)
	}
}

func TestResolveOrProvisionConcurrentFirstSighting(t *testing.T) {
	db := testsupport.DB(t)
	if _, err := db.Exec("TRUNCATE public.users CASCADE"); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	svc := NewService(NewStore(db), nil)

	const n = 8
	var wg sync.WaitGroup
	ids := make([]string, n)
	errs := make([]error, n)
	for i := 0; i < n; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			u, err := svc.ResolveOrProvision(context.Background(), "iss", "race")
			ids[i], errs[i] = u.ID, err
		}(i)
	}
	wg.Wait()

	for i, err := range errs {
		if err != nil {
			t.Fatalf("goroutine %d: %v", i, err)
		}
		if ids[i] == "" || ids[i] != ids[0] {
			t.Fatalf("goroutine %d resolved %q, want the single shared id %q", i, ids[i], ids[0])
		}
	}
	var count int
	if err := db.QueryRow("SELECT count(*) FROM public.users").Scan(&count); err != nil {
		t.Fatalf("count: %v", err)
	}
	if count != 1 {
		t.Fatalf("users count = %d after concurrent first sighting; want exactly 1", count)
	}
}
