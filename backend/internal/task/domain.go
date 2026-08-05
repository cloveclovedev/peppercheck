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

// Task is a tasker-authored task. Description/Criteria/DueDate are nil until the
// tasker fills them in; publishing requires Criteria and DueDate.
type Task struct {
	ID          string
	TaskerID    string
	Title       string
	Description *string
	Criteria    *string
	DueDate     *time.Time
	Status      string
	CreatedAt   time.Time
	UpdatedAt   time.Time
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
