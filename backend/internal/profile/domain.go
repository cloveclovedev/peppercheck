// Package profile owns the app-facing user profile (username, avatar, timezone)
// behind the Go API. The profiles table is 1:1 with the identity anchor
// (profiles.id = users.id); the API/DTO is idless and carries no Stripe field.
package profile

import (
	"errors"
	"time"
)

// Profile is the app-owned presentation data for a user. It has no ID — the
// owner is always the authenticated caller (identity.CurrentUser).
type Profile struct {
	Username  string
	AvatarURL *string
	Timezone  string
	CreatedAt time.Time
	UpdatedAt time.Time
}

// UpdateFields is a partial profile update: a nil pointer leaves the column
// unchanged. AvatarURL is applied only after the caller has validated the URL
// and confirmed the object (finalize backstop, see service).
type UpdateFields struct {
	Username  *string
	Timezone  *string
	AvatarURL *string
}

var (
	// ErrNotFound means no profile row exists for the user id.
	ErrNotFound = errors.New("profile not found")
	// ErrUsernameTaken means the requested username is already in use.
	ErrUsernameTaken = errors.New("username taken")
)
