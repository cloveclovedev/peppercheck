package task

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
)

// RefereeRequestCreator creates a task's referee requests (and their match
// jobs) inside the publish transaction, and reports the publish bounds
// (minimum lead hours, maximum referee count). It is declared here
// (consumer-side) so the task feature stays independent of the matching
// feature; matching.Service implements it.
type RefereeRequestCreator interface {
	CreateInTx(ctx context.Context, tx database.Querier, taskID, taskerID string, count int) error
	PublishBounds(ctx context.Context) (minLeadHours, maxReferees int, err error)
}

// Service is the task use case: draft CRUD (owner-scoped) and the publish
// transition that opens a task and creates its referee requests atomically.
type Service struct {
	db       *database.Handle
	store    *Store
	requests RefereeRequestCreator
}

// NewService wires the task use case. requests is the matching-side creator used
// only by Publish; draft CRUD does not touch it.
func NewService(db *database.Handle, store *Store, requests RefereeRequestCreator) *Service {
	return &Service{db: db, store: store, requests: requests}
}

// DraftInput is the full editable field set for creating a draft.
// Description/Criteria/DueDate are optional at the draft stage; publishing
// enforces criteria + due date.
type DraftInput struct {
	Title       string
	Description *string
	Criteria    *string
	DueDate     *time.Time
}

// PatchInput is a presence-aware partial update: each Set* flag records whether
// the field appeared in the request body, so an omitted field is left unchanged
// while an explicit null clears a nullable field.
type PatchInput struct {
	SetTitle    bool
	Title       *string
	SetDesc     bool
	Description *string
	SetCriteria bool
	Criteria    *string
	SetDueDate  bool
	DueDate     *time.Time
}

// Page is a cursor page of tasks with the next opaque cursor ("" when exhausted).
type Page struct {
	Tasks      []Task
	NextCursor string
}

// CreateDraft creates a draft owned by taskerID and returns the full Task.
func (s *Service) CreateDraft(ctx context.Context, taskerID string, in DraftInput) (Task, error) {
	if err := validateTitle(in.Title); err != nil {
		return Task{}, err
	}
	created, err := s.store.InsertDraft(ctx, taskerID, strings.TrimSpace(in.Title), in.Description, in.Criteria, in.DueDate)
	if err != nil {
		return Task{}, err
	}
	return s.store.LoadAggregate(ctx, created.ID)
}

// GetOwned returns the bare row of a task the caller owns (ownership probe).
func (s *Service) GetOwned(ctx context.Context, taskerID, taskID string) (Task, error) {
	return s.store.GetOwned(ctx, taskID, taskerID)
}

// GetReadable returns the full Task a caller may read (owner or assigned referee).
func (s *Service) GetReadable(ctx context.Context, userID, taskID string) (Task, error) {
	return s.store.GetReadableAggregate(ctx, taskID, userID)
}

// ListOwned returns a cursor page of the caller's tasks.
func (s *Service) ListOwned(ctx context.Context, taskerID, status, cursor string, limit int) (Page, error) {
	tasks, next, err := s.store.ListOwnedPage(ctx, taskerID, status, cursor, limit)
	if err != nil {
		return Page{}, err
	}
	return Page{Tasks: tasks, NextCursor: next}, nil
}

// Assignments returns a cursor page of the tasks the caller currently referees.
func (s *Service) Assignments(ctx context.Context, refereeID, cursor string, limit int) (Page, error) {
	tasks, next, err := s.store.ListAssignmentsPage(ctx, refereeID, cursor, limit)
	if err != nil {
		return Page{}, err
	}
	return Page{Tasks: tasks, NextCursor: next}, nil
}

// UpdateDraft applies a presence-aware partial update to a draft the caller owns
// (omitted fields unchanged; explicit null clears nullable fields) and returns
// the full Task. A non-draft task is ErrConflict; a missing/foreign id is
// ErrNotFound.
func (s *Service) UpdateDraft(ctx context.Context, taskerID, taskID string, patch PatchInput) (Task, error) {
	err := database.WithTx(ctx, s.db, func(tx database.Querier) error {
		draft, err := s.store.GetOwnedForUpdateInTx(ctx, tx, taskID, taskerID)
		if err != nil {
			return err
		}
		if draft.Status != "draft" {
			return ErrConflict
		}
		title := draft.Title
		if patch.SetTitle {
			if patch.Title == nil || strings.TrimSpace(*patch.Title) == "" {
				return fmt.Errorf("%w: title cannot be empty", ErrValidation)
			}
			title = strings.TrimSpace(*patch.Title)
		}
		description := draft.Description
		if patch.SetDesc {
			description = patch.Description
		}
		criteria := draft.Criteria
		if patch.SetCriteria {
			criteria = patch.Criteria
		}
		due := draft.DueDate
		if patch.SetDueDate {
			due = patch.DueDate
		}
		return s.store.UpdateDraftFieldsInTx(ctx, tx, taskID, title, description, criteria, due)
	})
	if err != nil {
		return Task{}, err
	}
	return s.store.LoadAggregate(ctx, taskID)
}

// DeleteDraft removes a draft the caller owns. A non-draft task is ErrConflict;
// a missing/foreign id is ErrNotFound.
func (s *Service) DeleteDraft(ctx context.Context, taskerID, taskID string) error {
	return database.WithTx(ctx, s.db, func(tx database.Querier) error {
		t, err := s.store.GetOwnedForUpdateInTx(ctx, tx, taskID, taskerID)
		if err != nil {
			return err
		}
		if t.Status != "draft" {
			return ErrConflict
		}
		return s.store.DeleteInTx(ctx, tx, taskID)
	})
}

// Publish validates the open requirements, flips the draft to open, and creates
// its referee requests + match jobs in one transaction. Only the owner, only
// from draft, with a referee count within the matching-config bounds.
func (s *Service) Publish(ctx context.Context, callerID, taskID string, refereeCount int) (Task, error) {
	minLead, maxReferees, err := s.requests.PublishBounds(ctx)
	if err != nil {
		return Task{}, err
	}
	if refereeCount < 1 || refereeCount > maxReferees {
		return Task{}, fmt.Errorf("%w: refereeCount must be 1..%d", ErrValidation, maxReferees)
	}
	err = database.WithTx(ctx, s.db, func(tx database.Querier) error {
		t, err := s.store.GetOwnedForUpdateInTx(ctx, tx, taskID, callerID)
		if err != nil {
			return err
		}
		if t.Status != "draft" {
			return ErrConflict
		}
		if err := ValidateOpenRequirements(t, minLead); err != nil {
			return err
		}
		if err := s.store.SetStatusInTx(ctx, tx, taskID, "open"); err != nil {
			return err
		}
		return s.requests.CreateInTx(ctx, tx, taskID, callerID, refereeCount)
	})
	if err != nil {
		return Task{}, err
	}
	return s.store.LoadAggregate(ctx, taskID)
}

func validateTitle(title string) error {
	if strings.TrimSpace(title) == "" {
		return fmt.Errorf("%w: title required", ErrValidation)
	}
	return nil
}
