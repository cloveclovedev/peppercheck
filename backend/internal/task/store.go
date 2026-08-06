package task

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
)

// Store issues the SQL over the tasks table and assembles the Task read-model
// (§7.1): the task row plus the tasker's embedded public profile and the task's
// referee requests (each with the matched referee's public profile). Reading
// referee_requests + profiles here is the one cross-feature read the task
// handlers perform, pinned by the wire contract.
type Store struct {
	db *database.Handle
}

// NewStore builds a Store over an open database handle.
func NewStore(db *database.Handle) *Store { return &Store{db: db} }

const taskColumns = `id, tasker_id, title, description, criteria, due_date, status, created_at, updated_at`

func scanTask(s interface{ Scan(...any) error }) (Task, error) {
	var t Task
	var tasker, desc, crit sql.NullString
	var due sql.NullTime
	if err := s.Scan(&t.ID, &tasker, &t.Title, &desc, &crit, &due, &t.Status, &t.CreatedAt, &t.UpdatedAt); err != nil {
		return Task{}, err
	}
	t.TaskerID = tasker.String
	if desc.Valid {
		t.Description = &desc.String
	}
	if crit.Valid {
		t.Criteria = &crit.String
	}
	if due.Valid {
		t.DueDate = &due.Time
	}
	return t, nil
}

// --- mutations (bare rows; the caller loads the aggregate for the response) ---

// InsertDraft creates a draft owned by taskerID, returning its bare row.
func (s *Store) InsertDraft(ctx context.Context, taskerID, title string, description, criteria *string, due *time.Time) (Task, error) {
	row := s.db.QueryRowContext(ctx,
		`INSERT INTO public.tasks (tasker_id, title, description, criteria, due_date, status)
		 VALUES ($1, $2, $3, $4, $5, 'draft')
		 RETURNING `+taskColumns,
		taskerID, title, description, criteria, due)
	return scanTask(row)
}

// GetOwned loads the bare row of a task the caller owns; a missing/foreign id is
// ErrNotFound.
func (s *Store) GetOwned(ctx context.Context, taskID, taskerID string) (Task, error) {
	row := s.db.QueryRowContext(ctx,
		`SELECT `+taskColumns+` FROM public.tasks WHERE id = $1 AND tasker_id = $2`, taskID, taskerID)
	t, err := scanTask(row)
	if err == sql.ErrNoRows {
		return Task{}, ErrNotFound
	}
	if err != nil {
		return Task{}, fmt.Errorf("get owned task: %w", err)
	}
	return t, nil
}

// GetOwnedForUpdateInTx row-locks a task the caller owns so an edit/delete/
// publish validates and mutates it atomically. A missing/foreign id is ErrNotFound.
func (s *Store) GetOwnedForUpdateInTx(ctx context.Context, q database.Querier, taskID, taskerID string) (Task, error) {
	row := q.QueryRowContext(ctx,
		`SELECT `+taskColumns+` FROM public.tasks WHERE id = $1 AND tasker_id = $2 FOR UPDATE`, taskID, taskerID)
	t, err := scanTask(row)
	if err == sql.ErrNoRows {
		return Task{}, ErrNotFound
	}
	if err != nil {
		return Task{}, fmt.Errorf("lock owned task: %w", err)
	}
	return t, nil
}

// UpdateDraftFieldsInTx replaces the editable fields of a draft the caller has
// already validated (owned + still draft, under the row lock).
func (s *Store) UpdateDraftFieldsInTx(ctx context.Context, q database.Querier, taskID, title string, description, criteria *string, due *time.Time) error {
	if _, err := q.ExecContext(ctx,
		`UPDATE public.tasks
		 SET title = $2, description = $3, criteria = $4, due_date = $5, updated_at = now()
		 WHERE id = $1`,
		taskID, title, description, criteria, due); err != nil {
		return fmt.Errorf("update draft: %w", err)
	}
	return nil
}

// DeleteInTx removes a task (the caller has validated ownership + draft status).
func (s *Store) DeleteInTx(ctx context.Context, q database.Querier, taskID string) error {
	if _, err := q.ExecContext(ctx, `DELETE FROM public.tasks WHERE id = $1`, taskID); err != nil {
		return fmt.Errorf("delete task: %w", err)
	}
	return nil
}

// SetStatusInTx sets a task's status (the caller has validated the transition
// under the row lock).
func (s *Store) SetStatusInTx(ctx context.Context, q database.Querier, taskID, status string) error {
	if _, err := q.ExecContext(ctx,
		`UPDATE public.tasks SET status = $2, updated_at = now() WHERE id = $1`, taskID, status); err != nil {
		return fmt.Errorf("set task status: %w", err)
	}
	return nil
}

// --- aggregate reads (the §7.1 Task read-model) ---------------------------

// LoadAggregate loads the full Task read-model by id with no authorization check
// — for building the response to an action the caller just performed (publish,
// cancel). A missing id is ErrNotFound.
func (s *Store) LoadAggregate(ctx context.Context, taskID string) (Task, error) {
	row := s.db.QueryRowContext(ctx, `SELECT `+taskColumns+` FROM public.tasks WHERE id = $1`, taskID)
	t, err := scanTask(row)
	if err == sql.ErrNoRows {
		return Task{}, ErrNotFound
	}
	if err != nil {
		return Task{}, fmt.Errorf("load task: %w", err)
	}
	if err := s.attachAll(ctx, []*Task{&t}); err != nil {
		return Task{}, err
	}
	return t, nil
}

// GetReadableAggregate loads the full Task read-model for a task the caller may
// read (its owner, or a referee assigned to it). A missing/unauthorized id is
// ErrNotFound.
func (s *Store) GetReadableAggregate(ctx context.Context, taskID, viewerID string) (Task, error) {
	row := s.db.QueryRowContext(ctx,
		`SELECT `+taskColumns+` FROM public.tasks t
		 WHERE t.id = $1 AND (
		     t.tasker_id = $2
		     OR EXISTS (SELECT 1 FROM public.referee_requests r
		                WHERE r.task_id = t.id AND r.matched_referee_id = $2
		                  AND r.status IN ('accepted', 'closed')))`, taskID, viewerID)
	t, err := scanTask(row)
	if err == sql.ErrNoRows {
		return Task{}, ErrNotFound
	}
	if err != nil {
		return Task{}, fmt.Errorf("get readable task: %w", err)
	}
	if err := s.attachAll(ctx, []*Task{&t}); err != nil {
		return Task{}, err
	}
	return t, nil
}

// ListOwnedPage returns a cursor page of the caller's tasks (newest first),
// optionally filtered by status, and the next cursor ("" when exhausted).
func (s *Store) ListOwnedPage(ctx context.Context, taskerID, status, cursorTok string, limit int) ([]Task, string, error) {
	c, hasCursor, err := decodeCursor(cursorTok)
	if err != nil {
		return nil, "", err
	}
	q := `SELECT ` + taskColumns + ` FROM public.tasks
	      WHERE tasker_id = $1 AND ($2 = '' OR status::text = $2)`
	args := []any{taskerID, status}
	if hasCursor {
		q += ` AND (created_at, id) < ($3, $4)`
		args = append(args, c.CreatedAt, c.ID)
	}
	q += fmt.Sprintf(` ORDER BY created_at DESC, id DESC LIMIT %d`, limit+1)
	return s.queryPage(ctx, q, args, limit)
}

// ListAssignmentsPage returns a cursor page of the tasks the caller currently
// referees (an accepted/closed request), newest task first.
func (s *Store) ListAssignmentsPage(ctx context.Context, refereeID, cursorTok string, limit int) ([]Task, string, error) {
	c, hasCursor, err := decodeCursor(cursorTok)
	if err != nil {
		return nil, "", err
	}
	q := `SELECT DISTINCT ` + taskColumnsPrefixed("t") + ` FROM public.tasks t
	      JOIN public.referee_requests r ON r.task_id = t.id
	      WHERE r.matched_referee_id = $1 AND r.status IN ('accepted', 'closed')`
	args := []any{refereeID}
	if hasCursor {
		q += ` AND (t.created_at, t.id) < ($2, $3)`
		args = append(args, c.CreatedAt, c.ID)
	}
	q += fmt.Sprintf(` ORDER BY t.created_at DESC, t.id DESC LIMIT %d`, limit+1)
	return s.queryPage(ctx, q, args, limit)
}

func taskColumnsPrefixed(alias string) string {
	return alias + ".id, " + alias + ".tasker_id, " + alias + ".title, " + alias + ".description, " +
		alias + ".criteria, " + alias + ".due_date, " + alias + ".status, " + alias + ".created_at, " + alias + ".updated_at"
}

// queryPage runs a limit+1 page query, attaches the aggregate to each row, and
// derives the next cursor (empty when the page is the last).
func (s *Store) queryPage(ctx context.Context, query string, args []any, limit int) ([]Task, string, error) {
	rows, err := s.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, "", fmt.Errorf("list tasks: %w", err)
	}
	defer rows.Close()
	var tasks []Task
	for rows.Next() {
		t, err := scanTask(rows)
		if err != nil {
			return nil, "", err
		}
		tasks = append(tasks, t)
	}
	if err := rows.Err(); err != nil {
		return nil, "", err
	}
	next := ""
	if len(tasks) > limit {
		last := tasks[limit-1]
		next = encodeCursor(cursor{CreatedAt: last.CreatedAt, ID: last.ID})
		tasks = tasks[:limit]
	}
	ptrs := make([]*Task, len(tasks))
	for i := range tasks {
		ptrs[i] = &tasks[i]
	}
	if err := s.attachAll(ctx, ptrs); err != nil {
		return nil, "", err
	}
	return tasks, next, nil
}

// attachAll batch-loads each task's tasker profile and referee requests (with
// referee profiles), avoiding N+1: one query for all tasker profiles and one for
// all referee requests across the given tasks.
func (s *Store) attachAll(ctx context.Context, tasks []*Task) error {
	if len(tasks) == 0 {
		return nil
	}
	taskIDs := make([]string, 0, len(tasks))
	taskerIDs := make([]string, 0, len(tasks))
	for _, t := range tasks {
		taskIDs = append(taskIDs, t.ID)
		if t.TaskerID != "" {
			taskerIDs = append(taskerIDs, t.TaskerID)
		}
	}
	profiles, err := s.publicProfiles(ctx, taskerIDs)
	if err != nil {
		return err
	}
	reqs, err := s.refereeRequestsByTask(ctx, taskIDs)
	if err != nil {
		return err
	}
	for _, t := range tasks {
		t.Tasker = profiles[t.TaskerID]
		if rr, ok := reqs[t.ID]; ok {
			t.RefereeRequests = rr
		} else {
			t.RefereeRequests = []RefereeRequest{}
		}
	}
	return nil
}

// publicProfiles reads the minimal public projection (username + avatar) for the
// given user ids.
func (s *Store) publicProfiles(ctx context.Context, ids []string) (map[string]*PublicProfile, error) {
	out := map[string]*PublicProfile{}
	if len(ids) == 0 {
		return out, nil
	}
	rows, err := s.db.QueryContext(ctx,
		`SELECT id, username, avatar_url FROM public.profiles WHERE id = ANY($1)`, ids)
	if err != nil {
		return nil, fmt.Errorf("load public profiles: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var p PublicProfile
		var avatar sql.NullString
		if err := rows.Scan(&p.UserID, &p.Username, &avatar); err != nil {
			return nil, err
		}
		if avatar.Valid {
			p.AvatarURL = &avatar.String
		}
		pp := p
		out[p.UserID] = &pp
	}
	return out, rows.Err()
}

// refereeRequestsByTask loads all referee requests for the given tasks, grouped
// by task id, each with the matched referee's public profile (nil while pending).
func (s *Store) refereeRequestsByTask(ctx context.Context, taskIDs []string) (map[string][]RefereeRequest, error) {
	out := map[string][]RefereeRequest{}
	if len(taskIDs) == 0 {
		return out, nil
	}
	rows, err := s.db.QueryContext(ctx, `
		SELECT r.id, r.task_id, r.status, r.matched_referee_id, r.responded_at,
		       r.point_source, r.is_obligation, r.created_at, r.updated_at,
		       p.id, p.username, p.avatar_url
		FROM public.referee_requests r
		LEFT JOIN public.profiles p ON p.id = r.matched_referee_id
		WHERE r.task_id = ANY($1)
		ORDER BY r.created_at`, taskIDs)
	if err != nil {
		return nil, fmt.Errorf("load referee requests: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var rr RefereeRequest
		var matched, pointSource, pid, puser, pavatar sql.NullString
		var responded sql.NullTime
		if err := rows.Scan(&rr.ID, &rr.TaskID, &rr.Status, &matched, &responded,
			&pointSource, &rr.IsObligation, &rr.CreatedAt, &rr.UpdatedAt,
			&pid, &puser, &pavatar); err != nil {
			return nil, err
		}
		if matched.Valid {
			rr.MatchedRefereeID = &matched.String
		}
		if responded.Valid {
			rr.RespondedAt = &responded.Time
		}
		if pointSource.Valid {
			rr.PointSource = &pointSource.String
		}
		if pid.Valid {
			prof := PublicProfile{UserID: pid.String, Username: puser.String}
			if pavatar.Valid {
				prof.AvatarURL = &pavatar.String
			}
			rr.Referee = &prof
		}
		out[rr.TaskID] = append(out[rr.TaskID], rr)
	}
	return out, rows.Err()
}
