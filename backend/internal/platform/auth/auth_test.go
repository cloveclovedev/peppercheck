package auth

import (
	"context"
	"errors"
	"testing"
	"time"

	fbauth "firebase.google.com/go/v4/auth"
)

func TestFakeVerifierReturnsIdentity(t *testing.T) {
	var v TokenVerifier = &FakeVerifier{Identity: Identity{Issuer: "iss", Subject: "sub", Email: "a@b.c", EmailVerified: true}}
	got, err := v.Verify(context.Background(), "any")
	if err != nil {
		t.Fatalf("Verify: %v", err)
	}
	if got.Issuer != "iss" || got.Subject != "sub" || !got.EmailVerified {
		t.Fatalf("identity = %+v", got)
	}
}

func TestFakeVerifierReturnsError(t *testing.T) {
	var v TokenVerifier = &FakeVerifier{Err: ErrInvalidToken}
	if _, err := v.Verify(context.Background(), "any"); !errors.Is(err, ErrInvalidToken) {
		t.Fatalf("err = %v, want ErrInvalidToken", err)
	}
}

func TestNewFirebaseVerifierRejectsEmptyProject(t *testing.T) {
	if _, err := NewFirebaseVerifier(context.Background(), ""); err == nil {
		t.Fatal("expected error for empty project ID")
	}
}

func TestFirebaseVerifierImplementsInterface(t *testing.T) {
	var _ TokenVerifier = (*FirebaseVerifier)(nil)
}

// hangingClient blocks until the context deadline, simulating a stuck key fetch.
type hangingClient struct{}

func (hangingClient) VerifyIDToken(ctx context.Context, _ string) (*fbauth.Token, error) {
	<-ctx.Done()
	return nil, ctx.Err()
}

func TestFirebaseVerifierTimesOutToInfraError(t *testing.T) {
	v := &FirebaseVerifier{client: hangingClient{}, timeout: 10 * time.Millisecond}
	_, err := v.Verify(context.Background(), "tok")
	if err == nil || errors.Is(err, ErrInvalidToken) {
		t.Fatalf("a timed-out verification must be a non-invalid (503) error, got %v", err)
	}
}
