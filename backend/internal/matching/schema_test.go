package matching_test

import (
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
)

// TestMatchingConfigSeeded asserts the singleton row shipped by the migration's
// seed DML is present with the production ordering (open > rematch > cancel).
func TestMatchingConfigSeeded(t *testing.T) {
	db := testsupport.DB(t)
	var open, cancel, rematch int
	err := db.QueryRow(`SELECT open_deadline_hours, cancel_deadline_hours, rematch_cutoff_hours
		FROM public.matching_config WHERE id = true`).Scan(&open, &cancel, &rematch)
	if err != nil {
		t.Fatalf("seeded matching_config row missing: %v", err)
	}
	if !(open > rematch && rematch > cancel) {
		t.Fatalf("ordering invariant not seeded: open=%d rematch=%d cancel=%d", open, rematch, cancel)
	}
}

// TestMatchingConfigOrderingInvariant asserts the CHECK rejects an ordering that
// breaks open > rematch > cancel, exercised by upserting the singleton.
func TestMatchingConfigOrderingInvariant(t *testing.T) {
	db := testsupport.DB(t)
	_, err := db.Exec(`INSERT INTO public.matching_config
		(id, open_deadline_hours, cancel_deadline_hours, rematch_cutoff_hours)
		VALUES (true, 1, 2, 3)
		ON CONFLICT (id) DO UPDATE SET open_deadline_hours = 1, cancel_deadline_hours = 2, rematch_cutoff_hours = 3`)
	if err == nil {
		t.Fatal("expected ordering_invariant violation")
	}
}

// TestRefereeRequestsForeignKeys asserts the task_id FK rejects an orphan request.
func TestRefereeRequestsForeignKeys(t *testing.T) {
	db := testsupport.DB(t)
	_, err := db.Exec(`INSERT INTO public.referee_requests (task_id) VALUES (gen_random_uuid())`)
	if err == nil {
		t.Fatal("expected FK violation for missing task")
	}
}
