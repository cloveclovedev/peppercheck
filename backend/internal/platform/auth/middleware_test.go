package auth

import (
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"
)

func discardLogger() *slog.Logger { return slog.New(slog.NewTextHandler(io.Discard, nil)) }

func protected(t *testing.T) http.Handler {
	t.Helper()
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id, ok := IdentityFrom(r.Context())
		if !ok {
			t.Fatal("handler reached without an identity in context")
		}
		_, _ = w.Write([]byte(id.Subject))
	})
}

func codeOf(rec *httptest.ResponseRecorder) string {
	var body struct {
		Error struct{ Code string } `json:"error"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &body)
	return body.Error.Code
}

func TestMiddlewareRejectsMissingHeader(t *testing.T) {
	h := Middleware(&FakeVerifier{}, discardLogger())(protected(t))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/x", nil))
	if rec.Code != http.StatusUnauthorized || codeOf(rec) != "unauthenticated" {
		t.Fatalf("status=%d code=%q, want 401 unauthenticated", rec.Code, codeOf(rec))
	}
}

func TestMiddlewareRejectsInvalidToken(t *testing.T) {
	h := Middleware(&FakeVerifier{Err: ErrInvalidToken}, discardLogger())(protected(t))
	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/x", nil)
	req.Header.Set("Authorization", "Bearer bad")
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusUnauthorized || codeOf(rec) != "unauthenticated" {
		t.Fatalf("status=%d code=%q, want 401 unauthenticated", rec.Code, codeOf(rec))
	}
}

func TestMiddlewareInfraErrorReturns503(t *testing.T) {
	// A non-token error (e.g. public-key fetch failure) is infrastructure, not
	// the caller's fault: 503, not 401.
	h := Middleware(&FakeVerifier{Err: errors.New("key fetch failed")}, discardLogger())(protected(t))
	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/x", nil)
	req.Header.Set("Authorization", "Bearer whatever")
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusServiceUnavailable || codeOf(rec) != "unavailable" {
		t.Fatalf("status=%d code=%q, want 503 unavailable", rec.Code, codeOf(rec))
	}
}

func TestMiddlewarePassesIdentity(t *testing.T) {
	h := Middleware(&FakeVerifier{Identity: Identity{Subject: "sub-1"}}, discardLogger())(protected(t))
	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/x", nil)
	req.Header.Set("Authorization", "Bearer good")
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK || rec.Body.String() != "sub-1" {
		t.Fatalf("status=%d body=%q", rec.Code, rec.Body.String())
	}
}
