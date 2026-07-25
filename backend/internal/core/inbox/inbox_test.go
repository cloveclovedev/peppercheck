package inbox

import (
	"context"
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
)

func newStore(t *testing.T) *Store {
	t.Helper()
	db := testsupport.DB(t)
	if _, err := db.Exec("TRUNCATE public.webhook_inbox"); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	return NewStore(db)
}

func TestInsertDedupes(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()

	isNew, err := s.Insert(ctx, "revenuecat", "evt_1", map[string]any{"type": "INITIAL_PURCHASE"})
	if err != nil {
		t.Fatalf("first insert: %v", err)
	}
	if !isNew {
		t.Fatal("first insert should be new")
	}

	isNew, err = s.Insert(ctx, "revenuecat", "evt_1", map[string]any{"type": "INITIAL_PURCHASE"})
	if err != nil {
		t.Fatalf("second insert: %v", err)
	}
	if isNew {
		t.Fatal("duplicate (source,event_id) must not be new")
	}
}

func TestInsertDistinctSourcesAreIndependent(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()
	if isNew, err := s.Insert(ctx, "revenuecat", "evt_1", nil); err != nil || !isNew {
		t.Fatalf("rc insert: new=%v err=%v", isNew, err)
	}
	if isNew, err := s.Insert(ctx, "stripe", "evt_1", nil); err != nil || !isNew {
		t.Fatalf("stripe insert should be new despite same event_id: new=%v err=%v", isNew, err)
	}
}
