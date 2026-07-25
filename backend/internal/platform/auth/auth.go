// Package auth is the third-party authentication boundary: it verifies a client
// ID token and hands the rest of the app a provider-neutral Identity. Only this
// package imports the Firebase SDK; domain and service code never do.
package auth

import (
	"context"
	"errors"
)

// ErrInvalidToken is returned by Verify only for an invalid or expired token;
// the caller maps it to 401. Any other failure (infrastructure — e.g. a
// public-key fetch or a timeout) is returned wrapped so the caller can treat it
// as 503 and log the cause.
var ErrInvalidToken = errors.New("invalid token")

// Identity is a verified external identity. Issuer + Subject uniquely identify
// the external account; today Subject holds the Firebase UID.
type Identity struct {
	Issuer        string
	Subject       string
	Email         string
	EmailVerified bool
}

// TokenVerifier verifies a raw bearer token and returns the external Identity.
type TokenVerifier interface {
	Verify(ctx context.Context, rawToken string) (Identity, error)
}

// FakeVerifier is a test double: Verify returns Identity, or Err if set.
type FakeVerifier struct {
	Identity Identity
	Err      error
}

// Verify implements TokenVerifier.
func (f *FakeVerifier) Verify(ctx context.Context, rawToken string) (Identity, error) {
	if f.Err != nil {
		return Identity{}, f.Err
	}
	return f.Identity, nil
}
