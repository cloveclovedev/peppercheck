package profile

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"errors"
	"fmt"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
	"github.com/jackc/pgx/v5/pgconn"
)

// Store issues the SQL over the profiles table.
type Store struct {
	db *sql.DB
}

// NewStore builds a Store over an open database handle.
func NewStore(db *sql.DB) *Store { return &Store{db: db} }

const maxUsernameAttempts = 5

// ProvisionInTx creates the user's profile row inside the caller's transaction
// (the identity fan-out), generating a username and retrying on the unique
// constraint with an explicit savepoint, bounded to maxUsernameAttempts. It runs
// against the shared Querier so it commits atomically with the user/identity.
func (s *Store) ProvisionInTx(ctx context.Context, q database.Querier, userID string) error {
	for attempt := 0; attempt < maxUsernameAttempts; attempt++ {
		if _, err := q.ExecContext(ctx, `SAVEPOINT sp_username`); err != nil {
			return fmt.Errorf("savepoint: %w", err)
		}
		username, err := genUsername()
		if err != nil {
			return err
		}
		_, err = q.ExecContext(ctx,
			`INSERT INTO public.profiles (id, username) VALUES ($1, $2)`, userID, username)
		if err == nil {
			if _, err := q.ExecContext(ctx, `RELEASE SAVEPOINT sp_username`); err != nil {
				return fmt.Errorf("release savepoint: %w", err)
			}
			return nil
		}
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" { // unique_violation on username
			if _, rbErr := q.ExecContext(ctx, `ROLLBACK TO SAVEPOINT sp_username`); rbErr != nil {
				return fmt.Errorf("rollback savepoint: %w", rbErr)
			}
			continue
		}
		return fmt.Errorf("insert profile: %w", err)
	}
	return fmt.Errorf("username generation exhausted after %d attempts", maxUsernameAttempts)
}

// GetByUserID returns the caller's profile, or ErrNotFound.
func (s *Store) GetByUserID(ctx context.Context, userID string) (Profile, error) {
	var p Profile
	var avatar sql.NullString
	err := s.db.QueryRowContext(ctx, `
		SELECT username, avatar_url, timezone, created_at, updated_at
		FROM public.profiles WHERE id = $1`, userID,
	).Scan(&p.Username, &avatar, &p.Timezone, &p.CreatedAt, &p.UpdatedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return Profile{}, ErrNotFound
	}
	if err != nil {
		return Profile{}, fmt.Errorf("get profile: %w", err)
	}
	if avatar.Valid {
		p.AvatarURL = &avatar.String
	}
	return p, nil
}

// Update applies a partial change (only the set fields) in one statement and
// returns the updated profile plus the previous avatar_url (for inline
// delete-previous). A username unique violation maps to ErrUsernameTaken; a
// missing profile maps to ErrNotFound. updated_at is set to now(). The FOR UPDATE
// on the current row makes read-old + write-new atomic.
func (s *Store) Update(ctx context.Context, userID string, in UpdateFields) (Profile, *string, error) {
	avatarProvided := in.AvatarURL != nil
	var avatarValue any
	if avatarProvided {
		avatarValue = *in.AvatarURL
	}

	var p Profile
	var newAvatar, prevAvatar sql.NullString
	err := s.db.QueryRowContext(ctx, `
		WITH prev AS (
			SELECT avatar_url FROM public.profiles WHERE id = $1 FOR UPDATE
		)
		UPDATE public.profiles p SET
			username   = COALESCE($2, p.username),
			timezone   = COALESCE($3, p.timezone),
			avatar_url = CASE WHEN $4 THEN $5 ELSE p.avatar_url END,
			updated_at = now()
		FROM prev
		WHERE p.id = $1
		RETURNING p.username, p.avatar_url, p.timezone, p.created_at, p.updated_at, prev.avatar_url`,
		userID, in.Username, in.Timezone, avatarProvided, avatarValue,
	).Scan(&p.Username, &newAvatar, &p.Timezone, &p.CreatedAt, &p.UpdatedAt, &prevAvatar)
	if errors.Is(err, sql.ErrNoRows) {
		return Profile{}, nil, ErrNotFound
	}
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return Profile{}, nil, ErrUsernameTaken
		}
		return Profile{}, nil, fmt.Errorf("update profile: %w", err)
	}
	if newAvatar.Valid {
		p.AvatarURL = &newAvatar.String
	}
	var prev *string
	if prevAvatar.Valid {
		prev = &prevAvatar.String
	}
	return p, prev, nil
}

// genUsername mints "user_" + 4 random bytes hex (13 chars, within the 2..20
// length check). crypto/rand keeps it unpredictable.
func genUsername() (string, error) {
	var b [4]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "", fmt.Errorf("random username: %w", err)
	}
	return "user_" + hex.EncodeToString(b[:]), nil
}
