package identity

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5/pgconn"
)

// ErrNotFound means no user maps to the given (issuer, subject). CreateWithIdentity
// also returns it when a concurrent insert won the unique constraint, signalling
// the caller to re-resolve.
var ErrNotFound = errors.New("identity not found")

// Store issues the SQL over users / user_identities.
type Store struct {
	db *sql.DB
}

// NewStore builds a Store over an open database handle.
func NewStore(db *sql.DB) *Store { return &Store{db: db} }

// FindByIdentity returns the internal user for a verified (issuer, subject).
func (s *Store) FindByIdentity(ctx context.Context, issuer, subject string) (User, error) {
	var u User
	err := s.db.QueryRowContext(ctx, `
		SELECT u.id, u.status, u.created_at, u.updated_at
		FROM public.users u
		JOIN public.user_identities i ON i.user_id = u.id
		WHERE i.issuer = $1 AND i.subject = $2`,
		issuer, subject,
	).Scan(&u.ID, &u.Status, &u.CreatedAt, &u.UpdatedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return User{}, ErrNotFound
	}
	if err != nil {
		return User{}, fmt.Errorf("find by identity: %w", err)
	}
	return u, nil
}

// CreateWithIdentity inserts a users row and its user_identities row in one
// transaction, then runs the provision callback (the profile/notification
// fan-out) inside the same transaction before committing, so first-sighting
// setup is atomic. A (issuer, subject) unique violation (a concurrent first
// sighting won) returns ErrNotFound so the caller re-resolves. A nil provision
// callback creates the user and identity only.
func (s *Store) CreateWithIdentity(ctx context.Context, issuer, subject string,
	provision func(ctx context.Context, tx *sql.Tx, userID string) error) (User, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return User{}, fmt.Errorf("begin: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	var u User
	if err := tx.QueryRowContext(ctx, `
		INSERT INTO public.users DEFAULT VALUES
		RETURNING id, status, created_at, updated_at`,
	).Scan(&u.ID, &u.Status, &u.CreatedAt, &u.UpdatedAt); err != nil {
		return User{}, fmt.Errorf("insert user: %w", err)
	}

	if _, err := tx.ExecContext(ctx, `
		INSERT INTO public.user_identities (user_id, issuer, subject)
		VALUES ($1, $2, $3)`,
		u.ID, issuer, subject,
	); err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" { // unique_violation
			return User{}, ErrNotFound
		}
		return User{}, fmt.Errorf("insert identity: %w", err)
	}

	if provision != nil {
		if err := provision(ctx, tx, u.ID); err != nil {
			return User{}, fmt.Errorf("provision: %w", err)
		}
	}

	if err := tx.Commit(); err != nil {
		return User{}, fmt.Errorf("commit: %w", err)
	}
	return u, nil
}
