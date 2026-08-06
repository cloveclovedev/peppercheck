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

// DraftInput is the editable field set of a draft. Description/Criteria/DueDate
// are optional at the draft stage; publishing enforces criteria + due date.
type DraftInput struct {
	Title       string
	Description *string
	Criteria    *string
	DueDate     *time.Time
}

// ListParams is the owner task listing filter + paging.
type ListParams struct {
	Status string // "" = any
	Limit  int
	Offset int
}

// CreateDraft creates a draft owned by taskerID.
func (s *Service) CreateDraft(ctx context.Context, taskerID string, in DraftInput) (Task, error) {
	if err := validateTitle(in.Title); err != nil {
		return Task{}, err
	}
	return s.store.InsertDraft(ctx, taskerID, strings.TrimSpace(in.Title), in.Description, in.Criteria, in.DueDate)
}

// GetOwned returns a task the caller owns.
func (s *Service) GetOwned(ctx context.Context, taskerID, taskID string) (Task, error) {
	return s.store.GetOwned(ctx, taskID, taskerID)
}

// GetReadable returns a task the caller may read (owner or assigned referee).
func (s *Service) GetReadable(ctx context.Context, userID, taskID string) (Task, error) {
	return s.store.GetReadable(ctx, taskID, userID)
}

// ListOwned returns the caller's tasks.
func (s *Service) ListOwned(ctx context.Context, taskerID string, p ListParams) ([]Task, error) {
	return s.store.ListOwned(ctx, taskerID, p.Status, p.Limit, p.Offset)
}

// UpdateDraft replaces the editable fields of a draft the caller owns. A
// non-draft task is ErrConflict; a missing/foreign id is ErrNotFound.
func (s *Service) UpdateDraft(ctx context.Context, taskerID, taskID string, in DraftInput) (Task, error) {
	if err := validateTitle(in.Title); err != nil {
		return Task{}, err
	}
	var out Task
	err := database.WithTx(ctx, s.db, func(tx database.Querier) error {
		t, err := s.store.GetOwnedForUpdateInTx(ctx, tx, taskID, taskerID)
		if err != nil {
			return err
		}
		if t.Status != "draft" {
			return ErrConflict
		}
		out, err = s.store.UpdateDraftFieldsInTx(ctx, tx, taskID,
			strings.TrimSpace(in.Title), in.Description, in.Criteria, in.DueDate)
		return err
	})
	return out, err
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
	var out Task
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
		opened, err := s.store.SetStatusInTx(ctx, tx, taskID, "open")
		if err != nil {
			return err
		}
		if err := s.requests.CreateInTx(ctx, tx, taskID, callerID, refereeCount); err != nil {
			return err
		}
		out = opened
		return nil
	})
	return out, err
}

func validateTitle(title string) error {
	if strings.TrimSpace(title) == "" {
		return fmt.Errorf("%w: title required", ErrValidation)
	}
	return nil
}
