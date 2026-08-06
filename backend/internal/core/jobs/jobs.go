// Package jobs is the durable-job primitive backing the worker. Jobs live in a
// Postgres table and are claimed with FOR UPDATE SKIP LOCKED so multiple worker
// processes never run the same job. Each claim takes a lease (a random token +
// expiry); a running job whose lease expires — e.g. its worker crashed — is
// reclaimable, and Complete/Fail are conditional on the lease token so a stale
// worker cannot clobber a reclaimed job. It is a primitive only; no feature
// enqueues real work in Phase 1.
package jobs

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
)

// DefaultLease is how long a claimed job stays leased before another worker may
// reclaim it. It must exceed the longest expected job runtime; long-running
// jobs must renew their lease (not needed in Phase 1 — noop jobs are instant).
const DefaultLease = 5 * time.Minute

// Job is a claimed unit of work handed to a worker handler. LockedBy is the
// lease token issued at claim time.
type Job struct {
	ID          string
	Kind        string
	Payload     json.RawMessage
	Attempts    int
	MaxAttempts int
	LockedBy    string
}

// Store issues the SQL that backs the job queue.
type Store struct {
	db    *sql.DB
	lease time.Duration
}

// NewStore builds a Store over an open database handle.
func NewStore(db *sql.DB) *Store { return &Store{db: db, lease: DefaultLease} }

// EnqueueOpts tunes a single enqueue. Zero values mean: run now, 20 attempts,
// no idempotency key.
type EnqueueOpts struct {
	RunAt          time.Time
	MaxAttempts    int
	IdempotencyKey string
}

// Enqueue inserts a job on the store's pool. When IdempotencyKey collides with
// an existing row it returns ("", nil) — the duplicate is a no-op, not an error.
func (s *Store) Enqueue(ctx context.Context, kind string, payload any, opts EnqueueOpts) (string, error) {
	return s.EnqueueInTx(ctx, s.db, kind, payload, opts)
}

// EnqueueInTx inserts a job using the caller's transaction (any database.Querier,
// which *sql.Tx satisfies), so the enqueue commits or rolls back atomically with
// the caller's other writes — the transactional-outbox pattern. Like Enqueue, a
// colliding IdempotencyKey returns ("", nil).
func (s *Store) EnqueueInTx(ctx context.Context, q database.Querier, kind string, payload any, opts EnqueueOpts) (string, error) {
	raw, err := json.Marshal(payload)
	if err != nil {
		return "", fmt.Errorf("marshal payload: %w", err)
	}
	if opts.MaxAttempts == 0 {
		opts.MaxAttempts = 20
	}
	var runAt any
	if !opts.RunAt.IsZero() {
		runAt = opts.RunAt
	}
	var key any
	if opts.IdempotencyKey != "" {
		key = opts.IdempotencyKey
	}
	var id string
	err = q.QueryRowContext(ctx, `
		INSERT INTO public.jobs (kind, payload, run_at, max_attempts, idempotency_key)
		VALUES ($1, $2, COALESCE($3, now()), $4, $5)
		ON CONFLICT (idempotency_key) DO NOTHING
		RETURNING id`,
		kind, raw, runAt, opts.MaxAttempts, key,
	).Scan(&id)
	if errors.Is(err, sql.ErrNoRows) {
		return "", nil // duplicate idempotency key
	}
	if err != nil {
		return "", fmt.Errorf("insert job: %w", err)
	}
	return id, nil
}

// Claim atomically picks the oldest claimable job — either due-and-pending, or
// running with an expired lease (its worker crashed) — takes a fresh lease, and
// returns it. Returns (nil, nil) when nothing is claimable.
func (s *Store) Claim(ctx context.Context) (*Job, error) {
	token, err := newToken()
	if err != nil {
		return nil, err
	}
	var j Job
	var payload []byte
	err = s.db.QueryRowContext(ctx, `
		UPDATE public.jobs
		SET status = 'running',
		    locked_at = now(),
		    lease_until = now() + make_interval(secs => $1),
		    locked_by = $2,
		    attempts = attempts + 1,
		    updated_at = now()
		WHERE id = (
			SELECT id FROM public.jobs
			WHERE (status = 'pending' AND run_at <= now())
			   OR (status = 'running' AND lease_until < now() AND attempts < max_attempts)
			ORDER BY run_at
			FOR UPDATE SKIP LOCKED
			LIMIT 1
		)
		RETURNING id, kind, payload, attempts, max_attempts, locked_by`,
		s.lease.Seconds(), token,
	).Scan(&j.ID, &j.Kind, &payload, &j.Attempts, &j.MaxAttempts, &j.LockedBy)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("claim job: %w", err)
	}
	j.Payload = payload
	return &j, nil
}

// Complete marks the job succeeded, but only while this worker still holds the
// lease (locked_by matches). A lost lease affects 0 rows and is a safe no-op —
// another worker reclaimed the job and owns its outcome.
func (s *Store) Complete(ctx context.Context, j *Job) error {
	_, err := s.db.ExecContext(ctx,
		`UPDATE public.jobs SET status = 'succeeded', updated_at = now()
		 WHERE id = $1 AND locked_by = $2`,
		j.ID, j.LockedBy)
	return err
}

// Fail reschedules the job after backoff, or marks it failed once attempts are
// exhausted — only while this worker still holds the lease.
func (s *Store) Fail(ctx context.Context, j *Job, cause error, backoff time.Duration) error {
	if j.Attempts >= j.MaxAttempts {
		_, err := s.db.ExecContext(ctx,
			`UPDATE public.jobs SET status = 'failed', last_error = $2, updated_at = now()
			 WHERE id = $1 AND locked_by = $3`,
			j.ID, cause.Error(), j.LockedBy)
		return err
	}
	_, err := s.db.ExecContext(ctx,
		`UPDATE public.jobs
		 SET status = 'pending', run_at = now() + make_interval(secs => $2),
		     last_error = $3, locked_by = NULL, lease_until = NULL, updated_at = now()
		 WHERE id = $1 AND locked_by = $4`,
		j.ID, backoff.Seconds(), cause.Error(), j.LockedBy)
	return err
}

// FailExpired marks running jobs whose lease has expired and whose attempts are
// exhausted as failed, so a repeatedly-crashing job (its worker dies before
// Fail runs) doesn't stay leased forever. Returns the number of jobs failed.
func (s *Store) FailExpired(ctx context.Context) (int64, error) {
	res, err := s.db.ExecContext(ctx,
		`UPDATE public.jobs
		 SET status = 'failed', last_error = 'lease expired after max attempts', updated_at = now()
		 WHERE status = 'running' AND lease_until < now() AND attempts >= max_attempts`)
	if err != nil {
		return 0, fmt.Errorf("fail expired jobs: %w", err)
	}
	n, _ := res.RowsAffected()
	return n, nil
}

// newToken returns a random lease token.
func newToken() (string, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "", fmt.Errorf("generate lease token: %w", err)
	}
	return hex.EncodeToString(b), nil
}
