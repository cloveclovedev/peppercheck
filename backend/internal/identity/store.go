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

// CreateWithIdentity inserts a users row and its user_identities row (with the
// verified email captured from the token) in one transaction, then runs the
// provision callback (the profile/notification fan-out) inside the same
// transaction before committing, so first-sighting setup is atomic. A
// (issuer, subject) unique violation (a concurrent first sighting won)
// returns ErrNotFound so the caller re-resolves. A nil provision callback
// creates the user and identity only.
func (s *Store) CreateWithIdentity(ctx context.Context, issuer, subject, email string, emailVerified bool,
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
		INSERT INTO public.user_identities (user_id, issuer, subject, email, email_verified)
		VALUES ($1, $2, $3, $4, $5)`,
		u.ID, issuer, subject, email, emailVerified,
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

// FindUserByEmail resolves a claimed email to the internal user, but ONLY via
// a VERIFIED email, and ONLY when unambiguous. It scans up to two DISTINCT
// users: none -> ErrNotFound; exactly one -> that user; more than one (the
// same verified email mapped to different accounts -- which identity linking
// should prevent, but is not DB-enforced because one user may legitimately
// hold two identities with the same verified email) -> ErrNotFound (fail
// safe: never resolve to an arbitrary user). Stale addresses are avoided
// because TouchIdentityEmail refreshes the stored email on every login.
func (s *Store) FindUserByEmail(ctx context.Context, email string) (User, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT DISTINCT u.id, u.status, u.created_at, u.updated_at
		FROM public.users u
		JOIN public.user_identities i ON i.user_id = u.id
		WHERE lower(i.email) = lower($1) AND i.email_verified
		LIMIT 2`, email)
	if err != nil {
		return User{}, fmt.Errorf("find user by email: %w", err)
	}
	defer rows.Close()

	var users []User
	for rows.Next() {
		var u User
		if err := rows.Scan(&u.ID, &u.Status, &u.CreatedAt, &u.UpdatedAt); err != nil {
			return User{}, fmt.Errorf("scan user by email: %w", err)
		}
		users = append(users, u)
	}
	if err := rows.Err(); err != nil {
		return User{}, fmt.Errorf("find user by email rows: %w", err)
	}
	if len(users) != 1 { // 0 = no match; >1 = ambiguous -> refuse
		return User{}, ErrNotFound
	}
	return users[0], nil
}

// TouchIdentityEmail refreshes the stored email only when it changed
// (updated_at is Go-maintained).
func (s *Store) TouchIdentityEmail(ctx context.Context, issuer, subject, email string, emailVerified bool) error {
	_, err := s.db.ExecContext(ctx, `
		UPDATE public.user_identities
		SET email = $3, email_verified = $4, updated_at = now()
		WHERE issuer = $1 AND subject = $2
		  AND (email IS DISTINCT FROM $3 OR email_verified IS DISTINCT FROM $4)`,
		issuer, subject, email, emailVerified)
	if err != nil {
		return fmt.Errorf("touch identity email: %w", err)
	}
	return nil
}
