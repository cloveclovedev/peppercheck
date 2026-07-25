package auth

import (
	"context"
	"fmt"
	"time"

	firebase "firebase.google.com/go/v4"
	fbauth "firebase.google.com/go/v4/auth"
	"google.golang.org/api/option"
)

// defaultVerifyTimeout bounds a single verification, including the SDK's
// public-key fetch, so a hung fetch surfaces as a 503 instead of hanging the
// request.
const defaultVerifyTimeout = 5 * time.Second

// idTokenClient is the slice of the Firebase auth client this package needs;
// *fbauth.Client satisfies it, and tests substitute a fake.
type idTokenClient interface {
	VerifyIDToken(ctx context.Context, idToken string) (*fbauth.Token, error)
}

// FirebaseVerifier verifies Firebase ID tokens. Plain VerifyIDToken needs only
// the project ID and Google's public keys (fetched over a public endpoint), so
// the app is initialized without a service-account credential. A later phase
// that needs privileged calls (delete user / revoke tokens) swaps
// option.WithoutAuthentication() for a real credential.
type FirebaseVerifier struct {
	client  idTokenClient
	timeout time.Duration
}

// NewFirebaseVerifier builds a verifier for the given Firebase project.
func NewFirebaseVerifier(ctx context.Context, projectID string) (*FirebaseVerifier, error) {
	if projectID == "" {
		return nil, fmt.Errorf("firebase: empty project ID")
	}
	app, err := firebase.NewApp(ctx, &firebase.Config{ProjectID: projectID}, option.WithoutAuthentication())
	if err != nil {
		return nil, fmt.Errorf("firebase: new app: %w", err)
	}
	client, err := app.Auth(ctx)
	if err != nil {
		return nil, fmt.Errorf("firebase: auth client: %w", err)
	}
	return &FirebaseVerifier{client: client, timeout: defaultVerifyTimeout}, nil
}

// Verify checks the token's signature, aud (=project ID), iss, sub and expiry,
// and returns the external Identity. It bounds the whole call (incl. the SDK's
// public-key fetch) with its own timeout. An invalid/expired token returns
// ErrInvalidToken (the caller maps it to 401); any other failure — a public-key
// fetch, network error, or timeout — is wrapped and returned as-is so the caller
// can treat it as 503 and log the cause. It is NOT the user's fault.
func (v *FirebaseVerifier) Verify(ctx context.Context, rawToken string) (Identity, error) {
	ctx, cancel := context.WithTimeout(ctx, v.timeout)
	defer cancel()
	tok, err := v.client.VerifyIDToken(ctx, rawToken)
	if err != nil {
		if fbauth.IsIDTokenInvalid(err) || fbauth.IsIDTokenExpired(err) {
			return Identity{}, ErrInvalidToken
		}
		return Identity{}, fmt.Errorf("firebase verify id token: %w", err)
	}
	email, _ := tok.Claims["email"].(string)
	emailVerified, _ := tok.Claims["email_verified"].(bool)
	return Identity{
		Issuer:        tok.Issuer,
		Subject:       tok.Subject,
		Email:         email,
		EmailVerified: emailVerified,
	}, nil
}
