package matching

import "errors"

// ErrRefereeTaken signals that a referee already holds an accepted seat on the
// task: the partial unique index uq_referee_requests_task_accepted_referee
// tripped (P4a-D16). The match handler maps it to success OUTSIDE the
// transaction — the request stays pending and the sweep retries it.
var ErrRefereeTaken = errors.New("matching: referee already accepted on this task")

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
