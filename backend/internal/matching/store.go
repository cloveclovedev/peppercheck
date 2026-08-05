package matching

import (
	"context"
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

// LoadConfig reads the singleton matching configuration.
func (s *Store) LoadConfig(ctx context.Context) (Config, error) {
	var c Config
	err := s.db.QueryRowContext(ctx, `
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
