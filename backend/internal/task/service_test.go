package task_test

import (
	"context"
	"database/sql"
	"errors"
	"testing"
	"time"

	"github.com/cloveclovedev/peppercheck/backend/internal/task"
	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
)

func newUser(t *testing.T, db *sql.DB) string {
	t.Helper()
	var id string
	if err := db.QueryRow(`INSERT INTO public.users DEFAULT VALUES RETURNING id`).Scan(&id); err != nil {
		t.Fatalf("seed user: %v", err)
	}
	return id
}

func newService(t *testing.T, db *sql.DB) *task.Service {
	t.Helper()
	return task.NewService(db, task.NewStore(db), nil) // nil creator: draft CRUD does not use it
}

func ptr(s string) *string { return &s }

func TestValidateOpenRequirements(t *testing.T) {
	const minLead = 24
	crit := "did it"

	if err := task.ValidateOpenRequirements(task.Task{Title: "x"}, minLead); err == nil {
		t.Fatal("want error: missing due_date/criteria")
	}
	soon := time.Now().Add(1 * time.Hour)
	if err := task.ValidateOpenRequirements(task.Task{Title: "x", DueDate: &soon, Criteria: &crit}, minLead); err == nil {
		t.Fatalf("want error: due_date within %dh lead", minLead)
	}
	blank := "   "
	future := time.Now().Add(48 * time.Hour)
	if err := task.ValidateOpenRequirements(task.Task{Title: "x", DueDate: &future, Criteria: &blank}, minLead); err == nil {
		t.Fatal("want error: blank criteria")
	}
	if err := task.ValidateOpenRequirements(task.Task{Title: "x", DueDate: &future, Criteria: &crit}, minLead); err != nil {
		t.Fatalf("want valid, got %v", err)
	}
}

func TestCreateAndGetDraft(t *testing.T) {
	db := testsupport.DB(t)
	svc := newService(t, db)
	ctx := context.Background()
	owner := newUser(t, db)

	created, err := svc.CreateDraft(ctx, owner, task.DraftInput{Title: " Wash the car ", Criteria: ptr("shiny")})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if created.Title != "Wash the car" || created.Status != "draft" {
		t.Fatalf("unexpected draft %+v", created)
	}

	got, err := svc.GetOwned(ctx, owner, created.ID)
	if err != nil || got.ID != created.ID {
		t.Fatalf("get owned: %v %+v", err, got)
	}

	// A different user cannot fetch it as owner.
	other := newUser(t, db)
	if _, err := svc.GetOwned(ctx, other, created.ID); !errors.Is(err, task.ErrNotFound) {
		t.Fatalf("cross-user get: want ErrNotFound, got %v", err)
	}
}

func TestCreateRejectsEmptyTitle(t *testing.T) {
	db := testsupport.DB(t)
	svc := newService(t, db)
	owner := newUser(t, db)
	if _, err := svc.CreateDraft(context.Background(), owner, task.DraftInput{Title: "   "}); !errors.Is(err, task.ErrValidation) {
		t.Fatalf("want ErrValidation, got %v", err)
	}
}

func TestUpdateDraft(t *testing.T) {
	db := testsupport.DB(t)
	svc := newService(t, db)
	ctx := context.Background()
	owner := newUser(t, db)
	created, _ := svc.CreateDraft(ctx, owner, task.DraftInput{Title: "draft"})

	updated, err := svc.UpdateDraft(ctx, owner, created.ID, task.PatchInput{
		SetTitle: true, Title: ptr("edited"), SetCriteria: true, Criteria: ptr("done"),
	})
	if err != nil {
		t.Fatalf("update: %v", err)
	}
	if updated.Title != "edited" || updated.Criteria == nil || *updated.Criteria != "done" {
		t.Fatalf("unexpected update %+v", updated)
	}

	// A patch that omits title leaves it unchanged (presence-aware).
	patched, err := svc.UpdateDraft(ctx, owner, created.ID, task.PatchInput{SetDesc: true, Description: ptr("note")})
	if err != nil {
		t.Fatalf("partial update: %v", err)
	}
	if patched.Title != "edited" || patched.Description == nil || *patched.Description != "note" {
		t.Fatalf("partial update did not preserve title / set description: %+v", patched)
	}

	// Non-owner update is not found.
	other := newUser(t, db)
	if _, err := svc.UpdateDraft(ctx, other, created.ID, task.PatchInput{SetTitle: true, Title: ptr("x")}); !errors.Is(err, task.ErrNotFound) {
		t.Fatalf("cross-user update: want ErrNotFound, got %v", err)
	}

	// An opened task cannot be edited as a draft.
	if _, err := db.Exec(`UPDATE public.tasks SET status='open' WHERE id=$1`, created.ID); err != nil {
		t.Fatalf("open task: %v", err)
	}
	if _, err := svc.UpdateDraft(ctx, owner, created.ID, task.PatchInput{SetTitle: true, Title: ptr("x")}); !errors.Is(err, task.ErrConflict) {
		t.Fatalf("update opened: want ErrConflict, got %v", err)
	}
}

func TestDeleteDraft(t *testing.T) {
	db := testsupport.DB(t)
	svc := newService(t, db)
	ctx := context.Background()
	owner := newUser(t, db)
	created, _ := svc.CreateDraft(ctx, owner, task.DraftInput{Title: "draft"})

	if err := svc.DeleteDraft(ctx, owner, created.ID); err != nil {
		t.Fatalf("delete: %v", err)
	}
	if _, err := svc.GetOwned(ctx, owner, created.ID); !errors.Is(err, task.ErrNotFound) {
		t.Fatalf("after delete: want ErrNotFound, got %v", err)
	}

	// A non-draft task cannot be deleted through the draft path.
	other, _ := svc.CreateDraft(ctx, owner, task.DraftInput{Title: "d2"})
	if _, err := db.Exec(`UPDATE public.tasks SET status='open' WHERE id=$1`, other.ID); err != nil {
		t.Fatalf("open: %v", err)
	}
	if err := svc.DeleteDraft(ctx, owner, other.ID); !errors.Is(err, task.ErrConflict) {
		t.Fatalf("delete opened: want ErrConflict, got %v", err)
	}
}

func TestListOwnedFiltersByStatus(t *testing.T) {
	db := testsupport.DB(t)
	svc := newService(t, db)
	ctx := context.Background()
	owner := newUser(t, db)
	d1, _ := svc.CreateDraft(ctx, owner, task.DraftInput{Title: "a"})
	_, _ = svc.CreateDraft(ctx, owner, task.DraftInput{Title: "b"})
	if _, err := db.Exec(`UPDATE public.tasks SET status='open' WHERE id=$1`, d1.ID); err != nil {
		t.Fatalf("open: %v", err)
	}

	all, err := svc.ListOwned(ctx, owner, "", "", 50)
	if err != nil || len(all.Tasks) != 2 {
		t.Fatalf("list all: %v len=%d", err, len(all.Tasks))
	}
	drafts, err := svc.ListOwned(ctx, owner, "draft", "", 50)
	if err != nil || len(drafts.Tasks) != 1 || drafts.Tasks[0].Status != "draft" {
		t.Fatalf("list drafts: %v %+v", err, drafts.Tasks)
	}
}

func TestGetReadableByAssignedReferee(t *testing.T) {
	db := testsupport.DB(t)
	svc := newService(t, db)
	ctx := context.Background()
	owner := newUser(t, db)
	created, _ := svc.CreateDraft(ctx, owner, task.DraftInput{Title: "assigned"})

	referee := newUser(t, db)
	if _, err := db.Exec(
		`INSERT INTO public.referee_requests (task_id, status, matched_referee_id) VALUES ($1,'accepted',$2)`,
		created.ID, referee); err != nil {
		t.Fatalf("seed accepted request: %v", err)
	}

	if got, err := svc.GetReadable(ctx, referee, created.ID); err != nil || got.ID != created.ID {
		t.Fatalf("referee read: %v %+v", err, got)
	}
	stranger := newUser(t, db)
	if _, err := svc.GetReadable(ctx, stranger, created.ID); !errors.Is(err, task.ErrNotFound) {
		t.Fatalf("stranger read: want ErrNotFound, got %v", err)
	}
}
