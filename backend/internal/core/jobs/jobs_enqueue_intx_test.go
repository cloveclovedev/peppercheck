package jobs_test

import (
	"context"
	"database/sql"
	"errors"
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
	"github.com/cloveclovedev/peppercheck/backend/internal/core/jobs"
	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
)

func TestEnqueueInTxRollsBackWithTransaction(t *testing.T) {
	db := testsupport.DB(t)
	store := jobs.NewStore(db)
	before := countProbeJobs(t, db)

	_ = database.WithTx(context.Background(), db, func(tx database.Querier) error {
		if _, err := store.EnqueueInTx(context.Background(), tx, "probe_kind", map[string]any{"x": 1}, jobs.EnqueueOpts{}); err != nil {
			t.Fatalf("EnqueueInTx: %v", err)
		}
		return errors.New("force rollback")
	})

	if got := countProbeJobs(t, db); got != before {
		t.Fatalf("job survived rollback: before=%d after=%d", before, got)
	}
}

func TestEnqueueInTxCommitsWithTransaction(t *testing.T) {
	db := testsupport.DB(t)
	store := jobs.NewStore(db)
	before := countProbeJobs(t, db)

	err := database.WithTx(context.Background(), db, func(tx database.Querier) error {
		_, err := store.EnqueueInTx(context.Background(), tx, "probe_kind", map[string]any{"x": 1}, jobs.EnqueueOpts{})
		return err
	})
	if err != nil {
		t.Fatalf("WithTx: %v", err)
	}
	if got := countProbeJobs(t, db); got != before+1 {
		t.Fatalf("job not committed: before=%d after=%d", before, got)
	}
	t.Cleanup(func() { _, _ = db.Exec(`DELETE FROM public.jobs WHERE kind = 'probe_kind'`) })
}

// countProbeJobs returns the number of probe_kind jobs currently in the queue.
func countProbeJobs(t *testing.T, db *sql.DB) int {
	t.Helper()
	var n int
	if err := db.QueryRow(`SELECT count(*) FROM public.jobs WHERE kind = 'probe_kind'`).Scan(&n); err != nil {
		t.Fatalf("count probe jobs: %v", err)
	}
	return n
}
