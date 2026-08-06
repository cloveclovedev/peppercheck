package matching

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5/pgconn"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
)

// Store issues the SQL backing referee matching: the typed config, request
// insertion, candidate selection, and the accept CAS. IDs are strings to match
// the codebase's internal identifier convention; the columns are uuid.
type Store struct {
	db *database.Handle
}

// NewStore builds a Store over an open database handle.
func NewStore(db *database.Handle) *Store { return &Store{db: db} }

// LoadConfig reads the singleton matching configuration on the pool.
func (s *Store) LoadConfig(ctx context.Context) (Config, error) {
	return s.loadConfig(ctx, s.db)
}

// LoadConfigInTx reads the config through the caller's transaction. Callers
// already inside a WithTx MUST use this, not LoadConfig: reading through the
// pool while holding a transaction's connection needs a second pooled
// connection, so enough concurrent in-transaction reads would deadlock the pool.
func (s *Store) LoadConfigInTx(ctx context.Context, q database.Querier) (Config, error) {
	return s.loadConfig(ctx, q)
}

func (s *Store) loadConfig(ctx context.Context, q database.Querier) (Config, error) {
	var c Config
	err := q.QueryRowContext(ctx, `
		SELECT open_deadline_hours, cancel_deadline_hours, rematch_cutoff_hours,
		       max_referees_per_task, point_cost_per_request
		FROM public.matching_config WHERE id = true`).
		Scan(&c.OpenDeadlineHours, &c.CancelDeadlineHours, &c.RematchCutoffHours,
			&c.MaxRefereesPerTask, &c.PointCostPerRequest)
	if err != nil {
		return Config{}, fmt.Errorf("load matching config: %w", err)
	}
	return c, nil
}

// InsertRequestInTx creates one pending referee_request seat on a task using the
// caller's transaction, returning its id. Publishing a task inserts N of these
// (N = the tasker's chosen referee count), each matched asynchronously.
func (s *Store) InsertRequestInTx(ctx context.Context, q database.Querier, taskID string) (string, error) {
	var id string
	err := q.QueryRowContext(ctx,
		`INSERT INTO public.referee_requests (task_id) VALUES ($1) RETURNING id`, taskID).Scan(&id)
	if err != nil {
		return "", fmt.Errorf("insert request: %w", err)
	}
	return id, nil
}

// CandidateReferees runs the full exclusion + least-workload query for a pending
// request and returns the least-workload candidate set (obligation priority is
// applied by the service using ObligationChecker). A referee qualifies when they
// have an active time slot covering the task's due instant in their local
// timezone, are accepting, are not the tasker, are not blocked on the due date,
// never previously cancelled on this task, are not already active on it, and are
// under their concurrent-assignment cap. The returned set is those qualifying
// referees whose current workload equals the minimum across all qualifying
// referees.
func (s *Store) CandidateReferees(ctx context.Context, q database.Querier, requestID string) ([]string, error) {
	rows, err := q.QueryContext(ctx, `
WITH req AS (
  SELECT rr.id, rr.task_id, t.tasker_id, t.due_date
  FROM public.referee_requests rr
  JOIN public.tasks t ON t.id = rr.task_id
  WHERE rr.id = $1
),
available AS (
  SELECT DISTINCT s.user_id AS referee_id
  FROM public.referee_available_time_slots s
  JOIN req ON true
  JOIN public.profiles p ON p.id = s.user_id
  LEFT JOIN public.referee_availability ra ON ra.user_id = s.user_id
  WHERE s.is_active
    AND s.user_id <> req.tasker_id
    AND COALESCE(ra.is_accepting, true)
    -- due instant in the referee's timezone: matching dow + minute window
    AND EXTRACT(DOW FROM (req.due_date AT TIME ZONE COALESCE(p.timezone, 'UTC'))) = s.dow
    AND (EXTRACT(HOUR FROM (req.due_date AT TIME ZONE COALESCE(p.timezone, 'UTC'))) * 60
       + EXTRACT(MINUTE FROM (req.due_date AT TIME ZONE COALESCE(p.timezone, 'UTC')))) BETWEEN s.start_min AND s.end_min
    -- not blocked on the due date
    AND NOT EXISTS (
      SELECT 1 FROM public.referee_blocked_dates b
      WHERE b.user_id = s.user_id
        AND (req.due_date AT TIME ZONE COALESCE(p.timezone, 'UTC'))::date BETWEEN b.start_date AND b.end_date)
    -- did not previously cancel on this task
    AND NOT EXISTS (
      SELECT 1 FROM public.referee_requests c
      WHERE c.task_id = req.task_id AND c.status = 'cancelled' AND c.matched_referee_id = s.user_id)
    -- not already active on this task (multi-referee)
    AND NOT EXISTS (
      SELECT 1 FROM public.referee_requests a
      WHERE a.task_id = req.task_id AND a.status IN ('pending','accepted')
        AND a.matched_referee_id = s.user_id)
),
workloads AS (
  SELECT a.referee_id,
         COUNT(j.id) FILTER (WHERE j.status IN ('awaiting_evidence','in_review','rejected','review_timeout')) AS wl
  FROM available a
  LEFT JOIN public.referee_requests rr2 ON rr2.matched_referee_id = a.referee_id AND rr2.status = 'accepted'
  LEFT JOIN public.judgements j ON j.id = rr2.id
  LEFT JOIN public.referee_availability ra ON ra.user_id = a.referee_id
  GROUP BY a.referee_id, ra.max_concurrent_assignments
  HAVING ra.max_concurrent_assignments IS NULL
      OR COUNT(j.id) FILTER (WHERE j.status IN ('awaiting_evidence','in_review','rejected','review_timeout')) < ra.max_concurrent_assignments
)
SELECT referee_id FROM workloads
WHERE wl = (SELECT MIN(wl) FROM workloads)`, requestID)
	if err != nil {
		return nil, fmt.Errorf("candidate query: %w", err)
	}
	defer rows.Close()
	var out []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		out = append(out, id)
	}
	return out, rows.Err()
}

// RequestContext loads the task facts the match handler notifies with: the task
// id/title, the tasker (NULL when the author was deleted), and whether the task
// already has a cancelled request (the re-match signal).
func (s *Store) RequestContext(ctx context.Context, q database.Querier, requestID string) (RequestContext, error) {
	var rc RequestContext
	var tasker sql.NullString
	err := q.QueryRowContext(ctx, `
		SELECT rr.task_id, t.tasker_id, t.title,
		       EXISTS (SELECT 1 FROM public.referee_requests c
		               WHERE c.task_id = rr.task_id AND c.status = 'cancelled') AS has_cancelled
		FROM public.referee_requests rr
		JOIN public.tasks t ON t.id = rr.task_id
		WHERE rr.id = $1`, requestID).
		Scan(&rc.TaskID, &tasker, &rc.Title, &rc.HasCancelledSibling)
	if err != nil {
		return RequestContext{}, fmt.Errorf("load request context: %w", err)
	}
	rc.TaskerID = tasker.String
	return rc, nil
}

// cancelRow is the request state the cancel use case guards on.
type cancelRow struct {
	Status           string
	MatchedRefereeID sql.NullString
	TaskID           string
	DueDate          sql.NullTime
	PointSource      string
}

// GetRequestForCancelInTx loads and row-locks a request (with its task's due
// date) so the cancel use case can validate the caller/status/deadline without a
// concurrent match or sweep changing it mid-transaction.
func (s *Store) GetRequestForCancelInTx(ctx context.Context, q database.Querier, requestID string) (cancelRow, error) {
	var c cancelRow
	err := q.QueryRowContext(ctx, `
		SELECT r.status, r.matched_referee_id, r.task_id, t.due_date, r.point_source
		FROM public.referee_requests r
		JOIN public.tasks t ON t.id = r.task_id
		WHERE r.id = $1
		FOR UPDATE OF r`, requestID).
		Scan(&c.Status, &c.MatchedRefereeID, &c.TaskID, &c.DueDate, &c.PointSource)
	if err != nil {
		return cancelRow{}, err // caller distinguishes sql.ErrNoRows
	}
	return c, nil
}

// SetStatusInTx sets a request's status unconditionally (the caller has already
// validated the transition under a row lock).
func (s *Store) SetStatusInTx(ctx context.Context, q database.Querier, requestID, status string) error {
	if _, err := q.ExecContext(ctx,
		`UPDATE public.referee_requests SET status = $2, updated_at = now() WHERE id = $1`,
		requestID, status); err != nil {
		return fmt.Errorf("set request status: %w", err)
	}
	return nil
}

// SetPointSourceInTx stamps the request's funding source (P4a-D17: a cancel's
// replacement inherits it, and publish records the locker's source). The no-op
// locker returns 'regular', so this is a no-op stamp in 4a.
func (s *Store) SetPointSourceInTx(ctx context.Context, q database.Querier, requestID, source string) error {
	if _, err := q.ExecContext(ctx,
		`UPDATE public.referee_requests SET point_source = $2::public.point_source_type, updated_at = now() WHERE id = $1`,
		requestID, source); err != nil {
		return fmt.Errorf("set point source: %w", err)
	}
	return nil
}

// --- referee availability CRUD (all user-scoped) --------------------------

// ListTimeSlots returns the referee's weekly availability slots.
func (s *Store) ListTimeSlots(ctx context.Context, userID string) ([]TimeSlot, error) {
	rows, err := s.db.QueryContext(ctx,
		`SELECT id, dow, start_min, end_min, is_active
		 FROM public.referee_available_time_slots WHERE user_id = $1
		 ORDER BY dow, start_min`, userID)
	if err != nil {
		return nil, fmt.Errorf("list time slots: %w", err)
	}
	defer rows.Close()
	var out []TimeSlot
	for rows.Next() {
		var t TimeSlot
		if err := rows.Scan(&t.ID, &t.DOW, &t.StartMin, &t.EndMin, &t.IsActive); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// CreateTimeSlot inserts a slot for the referee. A duplicate (user, dow, start)
// maps to ErrConflict.
func (s *Store) CreateTimeSlot(ctx context.Context, userID string, in TimeSlot) (TimeSlot, error) {
	out := in
	err := s.db.QueryRowContext(ctx,
		`INSERT INTO public.referee_available_time_slots (user_id, dow, start_min, end_min, is_active)
		 VALUES ($1, $2, $3, $4, $5) RETURNING id`,
		userID, in.DOW, in.StartMin, in.EndMin, in.IsActive).Scan(&out.ID)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return TimeSlot{}, ErrConflict
		}
		return TimeSlot{}, fmt.Errorf("create time slot: %w", err)
	}
	return out, nil
}

// UpdateTimeSlot updates a slot the referee owns; a missing/foreign id is
// ErrNotFound. A collision with another of the referee's slots is ErrConflict.
func (s *Store) UpdateTimeSlot(ctx context.Context, userID, id string, in TimeSlot) error {
	res, err := s.db.ExecContext(ctx,
		`UPDATE public.referee_available_time_slots
		 SET dow = $3, start_min = $4, end_min = $5, is_active = $6, updated_at = now()
		 WHERE id = $1 AND user_id = $2`,
		id, userID, in.DOW, in.StartMin, in.EndMin, in.IsActive)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return ErrConflict
		}
		return fmt.Errorf("update time slot: %w", err)
	}
	return rowsAffectedOrNotFound(res)
}

// DeleteTimeSlot removes a slot the referee owns; a missing/foreign id is ErrNotFound.
func (s *Store) DeleteTimeSlot(ctx context.Context, userID, id string) error {
	res, err := s.db.ExecContext(ctx,
		`DELETE FROM public.referee_available_time_slots WHERE id = $1 AND user_id = $2`, id, userID)
	if err != nil {
		return fmt.Errorf("delete time slot: %w", err)
	}
	return rowsAffectedOrNotFound(res)
}

// ListBlockedDates returns the referee's blocked date ranges.
func (s *Store) ListBlockedDates(ctx context.Context, userID string) ([]BlockedDate, error) {
	rows, err := s.db.QueryContext(ctx,
		`SELECT id, start_date, end_date, reason
		 FROM public.referee_blocked_dates WHERE user_id = $1
		 ORDER BY start_date`, userID)
	if err != nil {
		return nil, fmt.Errorf("list blocked dates: %w", err)
	}
	defer rows.Close()
	var out []BlockedDate
	for rows.Next() {
		var b BlockedDate
		var reason sql.NullString
		if err := rows.Scan(&b.ID, &b.StartDate, &b.EndDate, &reason); err != nil {
			return nil, err
		}
		if reason.Valid {
			b.Reason = &reason.String
		}
		out = append(out, b)
	}
	return out, rows.Err()
}

// CreateBlockedDate inserts a blocked range for the referee.
func (s *Store) CreateBlockedDate(ctx context.Context, userID string, in BlockedDate) (BlockedDate, error) {
	out := in
	err := s.db.QueryRowContext(ctx,
		`INSERT INTO public.referee_blocked_dates (user_id, start_date, end_date, reason)
		 VALUES ($1, $2, $3, $4) RETURNING id`,
		userID, in.StartDate, in.EndDate, in.Reason).Scan(&out.ID)
	if err != nil {
		return BlockedDate{}, fmt.Errorf("create blocked date: %w", err)
	}
	return out, nil
}

// UpdateBlockedDate updates a range the referee owns; a missing/foreign id is ErrNotFound.
func (s *Store) UpdateBlockedDate(ctx context.Context, userID, id string, in BlockedDate) error {
	res, err := s.db.ExecContext(ctx,
		`UPDATE public.referee_blocked_dates
		 SET start_date = $3, end_date = $4, reason = $5, updated_at = now()
		 WHERE id = $1 AND user_id = $2`,
		id, userID, in.StartDate, in.EndDate, in.Reason)
	if err != nil {
		return fmt.Errorf("update blocked date: %w", err)
	}
	return rowsAffectedOrNotFound(res)
}

// DeleteBlockedDate removes a range the referee owns; a missing/foreign id is ErrNotFound.
func (s *Store) DeleteBlockedDate(ctx context.Context, userID, id string) error {
	res, err := s.db.ExecContext(ctx,
		`DELETE FROM public.referee_blocked_dates WHERE id = $1 AND user_id = $2`, id, userID)
	if err != nil {
		return fmt.Errorf("delete blocked date: %w", err)
	}
	return rowsAffectedOrNotFound(res)
}

// rowsAffectedOrNotFound turns a zero-row write into ErrNotFound so a
// missing-or-foreign id reads as 404 without leaking whether it exists.
func rowsAffectedOrNotFound(res sql.Result) error {
	n, _ := res.RowsAffected()
	if n == 0 {
		return ErrNotFound
	}
	return nil
}

// PastCutoffPendingIDs lists pending requests whose task is within
// rematchCutoffHours of its due date (or already past it) — matching can no
// longer place them, so the sweep expires them. Rows carry the task facts the
// sweep refunds and notifies with. A NULL due date is skipped (an unpublished
// task has no requests; a defensively-NULL one can neither match nor expire).
func (s *Store) PastCutoffPendingIDs(ctx context.Context, rematchCutoffHours int) ([]ExpiredCandidate, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT rr.id, rr.task_id, t.tasker_id, t.title
		FROM public.referee_requests rr
		JOIN public.tasks t ON t.id = rr.task_id
		WHERE rr.status = 'pending'
		  AND t.due_date IS NOT NULL
		  AND t.due_date <= now() + make_interval(hours => $1)`, rematchCutoffHours)
	if err != nil {
		return nil, fmt.Errorf("past-cutoff pendings: %w", err)
	}
	defer rows.Close()
	var out []ExpiredCandidate
	for rows.Next() {
		var e ExpiredCandidate
		var tasker sql.NullString
		if err := rows.Scan(&e.ID, &e.TaskID, &tasker, &e.Title); err != nil {
			return nil, err
		}
		e.TaskerID = tasker.String
		out = append(out, e)
	}
	return out, rows.Err()
}

// ExpireIfPendingInTx flips a request pending->expired only while it is still
// pending, returning whether it changed. The CAS is the concurrency guard: a
// request a concurrent match already accepted is left untouched (0 rows), so the
// sweep never refunds/notifies a request that was in fact matched.
func (s *Store) ExpireIfPendingInTx(ctx context.Context, q database.Querier, requestID string) (bool, error) {
	res, err := q.ExecContext(ctx,
		`UPDATE public.referee_requests SET status = 'expired', updated_at = now()
		 WHERE id = $1 AND status = 'pending'`, requestID)
	if err != nil {
		return false, fmt.Errorf("expire request: %w", err)
	}
	n, _ := res.RowsAffected()
	return n > 0, nil
}

// PendingWithinWindow lists pending requests whose task is still more than
// rematchCutoffHours from its due date — matching can still place them, so the
// sweep re-enqueues a match.
func (s *Store) PendingWithinWindow(ctx context.Context, rematchCutoffHours int) ([]string, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT rr.id
		FROM public.referee_requests rr
		JOIN public.tasks t ON t.id = rr.task_id
		WHERE rr.status = 'pending'
		  AND t.due_date > now() + make_interval(hours => $1)`, rematchCutoffHours)
	if err != nil {
		return nil, fmt.Errorf("in-window pendings: %w", err)
	}
	defer rows.Close()
	var out []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		out = append(out, id)
	}
	return out, rows.Err()
}

// MarkAcceptedInTx transitions a request pending->accepted only if it is still
// pending AND its task is still within the matching window (due_date is more
// than rematch_cutoff_hours away). The cutoff guard is in the UPDATE itself so a
// match job that runs late — e.g. after a worker outage crossed the cutoff —
// cannot assign a referee to a request the sweep should expire; when it affects
// 0 rows the caller leaves the request pending and the sweep expires + refunds
// it. This UPDATE also sets updated_at = now(). A same-task double-assignment
// (two requests, same referee) trips the partial unique index (P4a-D16); the
// caller distinguishes ErrRefereeTaken.
func (s *Store) MarkAcceptedInTx(ctx context.Context, q database.Querier, requestID, refereeID string, isObligation bool) (bool, error) {
	res, err := q.ExecContext(ctx, `
		UPDATE public.referee_requests r
		SET status = 'accepted', matched_referee_id = $2, is_obligation = $3,
		    responded_at = now(), updated_at = now()
		FROM public.tasks t, public.matching_config c
		WHERE r.id = $1 AND r.status = 'pending'
		  AND t.id = r.task_id AND c.id = true
		  AND t.due_date > now() + make_interval(hours => c.rematch_cutoff_hours)`,
		requestID, refereeID, isObligation)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" { // same-task accepted unique index
			return false, ErrRefereeTaken
		}
		return false, fmt.Errorf("mark accepted: %w", err)
	}
	n, _ := res.RowsAffected()
	return n == 1, nil
}
