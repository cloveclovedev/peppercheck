package identity

import (
	"context"
	"sync"
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
)

// fakeStore scripts FindByIdentity/CreateWithIdentity results per call.
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

func (f *fakeStore) CreateWithIdentity(_ context.Context, _, _ string) (User, error) {
	r := f.createResults[f.creates]
	f.creates++
	return r.u, r.err
}

func TestResolveExistingUser(t *testing.T) {
	f := &fakeStore{findResults: []result{{u: User{ID: "u1"}}}}
	got, err := NewService(f).ResolveOrProvision(context.Background(), "iss", "sub")
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
	got, err := NewService(f).ResolveOrProvision(context.Background(), "iss", "sub")
	if err != nil || got.ID != "u2" {
		t.Fatalf("got %+v err %v", got, err)
	}
}

func TestResolveRefindsWhenCreateLosesRace(t *testing.T) {
	f := &fakeStore{
		findResults:   []result{{err: ErrNotFound}, {u: User{ID: "u3"}}}, // 1st: absent, 2nd: winner's row
		createResults: []result{{err: ErrNotFound}},                      // create lost the unique race
	}
	got, err := NewService(f).ResolveOrProvision(context.Background(), "iss", "sub")
	if err != nil || got.ID != "u3" {
		t.Fatalf("got %+v err %v", got, err)
	}
}

func TestResolveOrProvisionConcurrentFirstSighting(t *testing.T) {
	db := testsupport.DB(t)
	if _, err := db.Exec("TRUNCATE public.users CASCADE"); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	svc := NewService(NewStore(db))

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
