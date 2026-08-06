package matching_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/cloveclovedev/peppercheck/backend/internal/matching"
	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
)

func mustDate(t *testing.T, s string) time.Time {
	t.Helper()
	d, err := time.Parse("2006-01-02", s)
	if err != nil {
		t.Fatalf("parse date %q: %v", s, err)
	}
	return d
}

func TestTimeSlotCRUD(t *testing.T) {
	db := testsupport.DB(t)
	s := matching.NewStore(db)
	ctx := context.Background()
	user := newUser(t, db)

	created, err := s.CreateTimeSlot(ctx, user, matching.TimeSlot{DOW: 1, StartMin: 540, EndMin: 1020, IsActive: true})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if created.ID == "" {
		t.Fatal("want created id")
	}

	slots, err := s.ListTimeSlots(ctx, user)
	if err != nil || len(slots) != 1 {
		t.Fatalf("list: %v len=%d", err, len(slots))
	}

	if err := s.UpdateTimeSlot(ctx, user, created.ID, matching.TimeSlot{DOW: 2, StartMin: 600, EndMin: 700, IsActive: false}); err != nil {
		t.Fatalf("update: %v", err)
	}

	// A different user cannot update or delete this slot.
	other := newUser(t, db)
	if err := s.UpdateTimeSlot(ctx, other, created.ID, matching.TimeSlot{DOW: 0, StartMin: 0, EndMin: 1}); !errors.Is(err, matching.ErrNotFound) {
		t.Fatalf("cross-user update: want ErrNotFound, got %v", err)
	}
	if err := s.DeleteTimeSlot(ctx, other, created.ID); !errors.Is(err, matching.ErrNotFound) {
		t.Fatalf("cross-user delete: want ErrNotFound, got %v", err)
	}

	if err := s.DeleteTimeSlot(ctx, user, created.ID); err != nil {
		t.Fatalf("delete: %v", err)
	}
	if err := s.DeleteTimeSlot(ctx, user, created.ID); !errors.Is(err, matching.ErrNotFound) {
		t.Fatalf("delete again: want ErrNotFound, got %v", err)
	}
}

func TestTimeSlotDuplicateIsConflict(t *testing.T) {
	db := testsupport.DB(t)
	s := matching.NewStore(db)
	ctx := context.Background()
	user := newUser(t, db)
	slot := matching.TimeSlot{DOW: 3, StartMin: 480, EndMin: 600, IsActive: true}
	if _, err := s.CreateTimeSlot(ctx, user, slot); err != nil {
		t.Fatalf("first create: %v", err)
	}
	if _, err := s.CreateTimeSlot(ctx, user, slot); !errors.Is(err, matching.ErrConflict) {
		t.Fatalf("duplicate (user,dow,start): want ErrConflict, got %v", err)
	}
}

func TestBlockedDateCRUD(t *testing.T) {
	db := testsupport.DB(t)
	s := matching.NewStore(db)
	ctx := context.Background()
	user := newUser(t, db)

	start := mustDate(t, "2027-01-10")
	end := mustDate(t, "2027-01-12")
	created, err := s.CreateBlockedDate(ctx, user, matching.BlockedDate{StartDate: start, EndDate: end})
	if err != nil {
		t.Fatalf("create: %v", err)
	}

	dates, err := s.ListBlockedDates(ctx, user)
	if err != nil || len(dates) != 1 {
		t.Fatalf("list: %v len=%d", err, len(dates))
	}

	reason := "holiday"
	if err := s.UpdateBlockedDate(ctx, user, created.ID, matching.BlockedDate{StartDate: start, EndDate: end, Reason: &reason}); err != nil {
		t.Fatalf("update: %v", err)
	}
	other := newUser(t, db)
	if err := s.DeleteBlockedDate(ctx, other, created.ID); !errors.Is(err, matching.ErrNotFound) {
		t.Fatalf("cross-user delete: want ErrNotFound, got %v", err)
	}
	if err := s.DeleteBlockedDate(ctx, user, created.ID); err != nil {
		t.Fatalf("delete: %v", err)
	}
}
