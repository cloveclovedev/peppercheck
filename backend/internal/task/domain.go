// Package task owns tasker-authored tasks: draft CRUD and the draft->open
// publish transition. A task starts as a draft the tasker can edit or delete;
// publishing validates the open requirements, flips it to open, and (via the
// matching feature) creates its referee requests atomically. IDs are strings to
// match the codebase's internal identifier convention; the columns are uuid.
package task

import (
	"errors"
	"fmt"
	"strings"
	"time"
)

// Use-case errors the handler maps to HTTP status codes.
var (
	ErrNotFound   = errors.New("task: not found")
	ErrForbidden  = errors.New("task: not the owner")
	ErrConflict   = errors.New("task: state conflict")
	ErrValidation = errors.New("task: validation failed")
)

// PublicProfile is the minimal display projection of a user (username + avatar),
// embedded in Task responses for the tasker and each matched referee. It is the
// Phase-3a-deferred shared projection, not the owner's editable profile.
type PublicProfile struct {
	UserID    string
	Username  string
	AvatarURL *string
}

// RefereeRequest is one seat on a task, as carried in the Task wire object. The
// embedded Referee profile is set only once the seat is matched.
type RefereeRequest struct {
	ID               string
	TaskID           string
	Status           string
	MatchedRefereeID *string
	RespondedAt      *time.Time
	PointSource      *string
	IsObligation     bool
	CreatedAt        time.Time
	UpdatedAt        time.Time
	Referee          *PublicProfile
}

// Task is a tasker-authored task. Description/Criteria/DueDate are nil until the
// tasker fills them in; publishing requires Criteria and DueDate. Tasker is the
// embedded public profile of the author (nil if the author was deleted);
// RefereeRequests are the task's seats (empty for a draft).
type Task struct {
	ID              string
	TaskerID        string
	Title           string
	Description     *string
	Criteria        *string
	DueDate         *time.Time
	Status          string
	CreatedAt       time.Time
	UpdatedAt       time.Time
	Tasker          *PublicProfile
	RefereeRequests []RefereeRequest
}

// ValidateOpenRequirements enforces the rules for the draft->open transition
// (porting the legacy validate_task_open_requirements minus the point-balance
// check, which the PointLocker now owns): a non-empty title and criteria, and a
// due date at least minLeadHours ahead of now (matching_config.open_deadline_hours).
func ValidateOpenRequirements(t Task, minLeadHours int) error {
	if strings.TrimSpace(t.Title) == "" {
		return fmt.Errorf("%w: title required", ErrValidation)
	}
	if t.Criteria == nil || strings.TrimSpace(*t.Criteria) == "" {
		return fmt.Errorf("%w: criteria required", ErrValidation)
	}
	minDue := time.Now().Add(time.Duration(minLeadHours) * time.Hour)
	if t.DueDate == nil || !t.DueDate.After(minDue) {
		return fmt.Errorf("%w: due_date must be at least %d hours from now", ErrValidation, minLeadHours)
	}
	return nil
}
