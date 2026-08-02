package identity

import (
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/httpserver"
	"github.com/cloveclovedev/peppercheck/backend/internal/platform/auth"
)

// discardLogger keeps middleware error logs out of test output.
func discardLogger() *slog.Logger { return slog.New(slog.NewTextHandler(io.Discard, nil)) }

// TestMiddlewareResolvesCurrentUser drives the real auth.Middleware (which seeds
// the verified Identity) followed by the resolve middleware, and asserts the
// downstream handler sees the provisioned internal user via CurrentUser.
func TestMiddlewareResolvesCurrentUser(t *testing.T) {
	f := &fakeStore{
		findResults:   []result{{err: ErrNotFound}},
		createResults: []result{{u: User{ID: "u-42", Status: "active"}}},
	}
	svc := NewService(f, nil)

	var seen User
	var sawUser bool
	probe := http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
		seen, sawUser = CurrentUser(r.Context())
	})
	verified := auth.Middleware(&auth.FakeVerifier{Identity: auth.Identity{Issuer: "iss", Subject: "sub"}}, discardLogger())
	h := verified(NewMiddleware(svc, discardLogger())(probe))

	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/x", nil)
	req.Header.Set("Authorization", "Bearer t")
	h.ServeHTTP(rec, req)

	if !sawUser || seen.ID != "u-42" {
		t.Fatalf("probe saw user=%v id=%q, want the resolved u-42", sawUser, seen.ID)
	}
}

// TestMiddlewareMissingIdentityReturns401 invokes the resolve middleware without
// the auth middleware (no Identity in context), exercising its own guard.
func TestMiddlewareMissingIdentityReturns401(t *testing.T) {
	svc := NewService(&fakeStore{}, nil)
	probe := http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		t.Fatal("handler must not run without an identity")
	})
	h := NewMiddleware(svc, discardLogger())(probe)

	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/x", nil))

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", rec.Code)
	}
	var body struct {
		Error struct{ Code string } `json:"error"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &body)
	if body.Error.Code != httpserver.CodeUnauthenticated {
		t.Fatalf("code = %q, want unauthenticated", body.Error.Code)
	}
}
