package task

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
)

// Store issues the SQL over the tasks table. All read/write helpers are
// caller-scoped by tasker_id (ownership) except GetReadable, which also admits
// the assigned referee.
type Store struct {
	db *database.Handle
}

// NewStore builds a Store over an open database handle.
func NewStore(db *database.Handle) *Store { return &Store{db: db} }

const taskColumns = `id, tasker_id, title, description, criteria, due_date, status, created_at, updated_at`

func scanTask(s interface {
	Scan(...any) error
}) (Task, error) {
	var t Task
	var tasker sql.NullString
	var desc, crit sql.NullString
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

// InsertDraft creates a draft owned by taskerID.
func (s *Store) InsertDraft(ctx context.Context, taskerID, title string, description, criteria *string, due *time.Time) (Task, error) {
	row := s.db.QueryRowContext(ctx,
		`INSERT INTO public.tasks (tasker_id, title, description, criteria, due_date, status)
		 VALUES ($1, $2, $3, $4, $5, 'draft')
		 RETURNING `+taskColumns,
		taskerID, title, description, criteria, due)
	return scanTask(row)
}

// GetOwned loads a task the caller owns; a missing/foreign id is ErrNotFound.
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

// GetReadable loads a task the caller may read: its owner or a referee assigned
// to it (any non-terminal request). A missing/unauthorized id is ErrNotFound.
func (s *Store) GetReadable(ctx context.Context, taskID, userID string) (Task, error) {
	row := s.db.QueryRowContext(ctx,
		`SELECT `+taskColumns+` FROM public.tasks t
		 WHERE t.id = $1 AND (
		     t.tasker_id = $2
		     OR EXISTS (SELECT 1 FROM public.referee_requests r
		                WHERE r.task_id = t.id AND r.matched_referee_id = $2
		                  AND r.status IN ('accepted', 'closed')))`, taskID, userID)
	t, err := scanTask(row)
	if err == sql.ErrNoRows {
		return Task{}, ErrNotFound
	}
	if err != nil {
		return Task{}, fmt.Errorf("get readable task: %w", err)
	}
	return t, nil
}

// ListOwned returns the caller's tasks, optionally filtered by status, newest
// first, with limit/offset paging.
func (s *Store) ListOwned(ctx context.Context, taskerID string, status string, limit, offset int) ([]Task, error) {
	rows, err := s.db.QueryContext(ctx,
		`SELECT `+taskColumns+` FROM public.tasks
		 WHERE tasker_id = $1 AND ($2 = '' OR status::text = $2)
		 ORDER BY created_at DESC
		 LIMIT $3 OFFSET $4`, taskerID, status, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("list owned tasks: %w", err)
	}
	defer rows.Close()
	var out []Task
	for rows.Next() {
		t, err := scanTask(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
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
func (s *Store) UpdateDraftFieldsInTx(ctx context.Context, q database.Querier, taskID, title string, description, criteria *string, due *time.Time) (Task, error) {
	row := q.QueryRowContext(ctx,
		`UPDATE public.tasks
		 SET title = $2, description = $3, criteria = $4, due_date = $5, updated_at = now()
		 WHERE id = $1
		 RETURNING `+taskColumns,
		taskID, title, description, criteria, due)
	t, err := scanTask(row)
	if err != nil {
		return Task{}, fmt.Errorf("update draft: %w", err)
	}
	return t, nil
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
