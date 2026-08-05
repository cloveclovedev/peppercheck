package matching

import (
	"errors"
	"fmt"
	"time"
)

// ErrRefereeTaken signals that a referee already holds an accepted seat on the
// task: the partial unique index uq_referee_requests_task_accepted_referee
// tripped (P4a-D16). The match handler maps it to success OUTSIDE the
// transaction — the request stays pending and the sweep retries it.
var ErrRefereeTaken = errors.New("matching: referee already accepted on this task")

// Use-case errors the handler maps to HTTP status codes.
var (
	// ErrNotFound: the referee request does not exist.
	ErrNotFound = errors.New("matching: request not found")
	// ErrForbidden: the caller is not the referee assigned to the request.
	ErrForbidden = errors.New("matching: not the assigned referee")
	// ErrConflict: the request is not in a state that allows the action.
	ErrConflict = errors.New("matching: request state conflict")
	// ErrCancelDeadlinePassed: too close to the task due date to cancel.
	ErrCancelDeadlinePassed = errors.New("matching: cancel deadline passed")
	// ErrValidation: a request field failed validation (e.g. referee count).
	ErrValidation = errors.New("matching: validation failed")
)

// Config is the typed matching configuration singleton (matching_config, one
// row id = true). The ordering invariant open > rematch > cancel is enforced in
// the schema; the service only reads these values.
type Config struct {
	OpenDeadlineHours   int
	CancelDeadlineHours int
	RematchCutoffHours  int
	MaxRefereesPerTask  int
	PointCostPerRequest int
}

// RequestContext carries the task facts the match handler needs to notify: the
// task id/title, the tasker (empty when the task's author was deleted), and
// whether the task already has a cancelled request. HasCancelledSibling marks a
// re-match after a referee cancelled, which selects the reassigned/
// cancelled-pending notification variants over the first-match ones.
type RequestContext struct {
	TaskID              string
	TaskerID            string // "" when the task's tasker was deleted
	Title               string
	HasCancelledSibling bool
}

// ExpiredCandidate is a pending request that has passed the rematch cutoff and
// is a candidate for expiry by the sweep. TaskerID/Title come from the joined
// task so the sweep can refund and notify without a second round-trip; both may
// be zero-valued for a task whose tasker was deleted (ON DELETE SET NULL).
type ExpiredCandidate struct {
	ID       string
	TaskID   string
	TaskerID string // "" when the task's tasker was deleted
	Title    string
}

// TimeSlot is a weekly recurring availability window in the referee's local
// timezone. DOW is 0=Sunday..6=Saturday; StartMin/EndMin are minutes past
// midnight.
type TimeSlot struct {
	ID       string
	DOW      int
	StartMin int
	EndMin   int
	IsActive bool
}

// Validate mirrors the referee_available_time_slots CHECKs so a bad slot is
// rejected as a 400 before it reaches the DB.
func (s TimeSlot) Validate() error {
	if s.DOW < 0 || s.DOW > 6 {
		return fmt.Errorf("%w: dow must be 0..6", ErrValidation)
	}
	if s.StartMin < 0 || s.StartMin > 1439 {
		return fmt.Errorf("%w: startMin must be 0..1439", ErrValidation)
	}
	if s.EndMin < 1 || s.EndMin > 1440 {
		return fmt.Errorf("%w: endMin must be 1..1440", ErrValidation)
	}
	if s.StartMin >= s.EndMin {
		return fmt.Errorf("%w: startMin must be before endMin", ErrValidation)
	}
	return nil
}

// BlockedDate is an inclusive date range the referee is unavailable.
type BlockedDate struct {
	ID        string
	StartDate time.Time
	EndDate   time.Time
	Reason    *string
}

// Validate mirrors the referee_blocked_dates CHECK (end >= start).
func (b BlockedDate) Validate() error {
	if b.EndDate.Before(b.StartDate) {
		return fmt.Errorf("%w: endDate must be on or after startDate", ErrValidation)
	}
	return nil
}

// Assignment is one active seat a referee currently holds: the accepted request,
// its task, and the judgement's status.
type Assignment struct {
	RequestID       string
	TaskID          string
	Title           string
	DueDate         *time.Time
	JudgementStatus string
}
