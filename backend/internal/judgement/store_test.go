package judgement_test

import (
	"context"
	"database/sql"
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
	"github.com/cloveclovedev/peppercheck/backend/internal/judgement"
	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
)

// seedRequest inserts a user, a task authored by that user, and a pending
// referee_request for the task, returning the request id.
func seedRequest(t *testing.T, db *sql.DB) string {
	t.Helper()
	ctx := context.Background()
	var userID string
	if err := db.QueryRowContext(ctx, `INSERT INTO public.users DEFAULT VALUES RETURNING id`).Scan(&userID); err != nil {
		t.Fatalf("seed user: %v", err)
	}
	var taskID string
	if err := db.QueryRowContext(ctx,
		`INSERT INTO public.tasks (tasker_id, title) VALUES ($1, 'seed') RETURNING id`, userID,
	).Scan(&taskID); err != nil {
		t.Fatalf("seed task: %v", err)
	}
	var reqID string
	if err := db.QueryRowContext(ctx,
		`INSERT INTO public.referee_requests (task_id) VALUES ($1) RETURNING id`, taskID,
	).Scan(&reqID); err != nil {
		t.Fatalf("seed referee_request: %v", err)
	}
	return reqID
}

func TestCreateAndDeleteAwaitingEvidence(t *testing.T) {
	db := testsupport.DB(t)
	p := judgement.NewProvisioner()
	reqID := seedRequest(t, db)
	ctx := context.Background()

	if err := database.WithTx(ctx, db, func(tx database.Querier) error {
		return p.CreateAwaitingEvidenceInTx(ctx, tx, reqID)
	}); err != nil {
		t.Fatalf("create: %v", err)
	}

	var status string
	if err := db.QueryRow(`SELECT status FROM public.judgements WHERE id=$1`, reqID).Scan(&status); err != nil {
		t.Fatalf("scan: %v", err)
	}
	if status != judgement.StatusAwaitingEvidence {
		t.Fatalf("want awaiting_evidence, got %s", status)
	}

	// A second create is idempotent (PK conflict, no error).
	if err := database.WithTx(ctx, db, func(tx database.Querier) error {
		return p.CreateAwaitingEvidenceInTx(ctx, tx, reqID)
	}); err != nil {
		t.Fatalf("idempotent create: %v", err)
	}

	var deleted bool
	if err := database.WithTx(ctx, db, func(tx database.Querier) error {
		var e error
		deleted, e = p.DeleteIfAwaitingEvidenceInTx(ctx, tx, reqID)
		return e
	}); err != nil {
		t.Fatalf("delete: %v", err)
	}
	if !deleted {
		t.Fatal("want deleted=true")
	}

	// Deleting again reports no row deleted.
	if err := database.WithTx(ctx, db, func(tx database.Querier) error {
		var e error
		deleted, e = p.DeleteIfAwaitingEvidenceInTx(ctx, tx, reqID)
		return e
	}); err != nil {
		t.Fatalf("second delete: %v", err)
	}
	if deleted {
		t.Fatal("want deleted=false on the second delete")
	}
}
