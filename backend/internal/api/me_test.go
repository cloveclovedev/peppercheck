package api

import (
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/identity"
	"github.com/cloveclovedev/peppercheck/backend/internal/platform/auth"
	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
)

func meHandler(t *testing.T, v auth.TokenVerifier) http.Handler {
	t.Helper()
	db := testsupport.DB(t)
	if _, err := db.Exec("TRUNCATE public.users CASCADE"); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	svc := identity.NewService(identity.NewStore(db))
	// Use the SAME chain builder as Run() so the tests exercise the real
	// middleware stack; RequestID seeds the id the error envelope carries.
	return rootHandler(
		Deps{
			Verifier:    v,
			Identity:    identity.NewHandler(svc, nil),
			ResolveUser: identity.NewMiddleware(svc, nil),
		},
		slog.New(slog.NewTextHandler(io.Discard, nil)),
	)
}

// envelope decodes {"error":{code,message,requestId}} from a response body.
func envelope(t *testing.T, rec *httptest.ResponseRecorder) (code, requestID string) {
	t.Helper()
	var body struct {
		Error struct{ Code, Message, RequestID string } `json:"error"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("unmarshal envelope: %v; body=%s", err, rec.Body.String())
	}
	return body.Error.Code, body.Error.RequestID
}

func TestMeRejectsMissingToken(t *testing.T) {
	h := meHandler(t, &auth.FakeVerifier{})
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/api/v1/me", nil))
	code, reqID := envelope(t, rec)
	if rec.Code != http.StatusUnauthorized || code != "unauthenticated" || reqID == "" {
		t.Fatalf("status=%d code=%q requestId=%q, want 401 unauthenticated with a request id", rec.Code, code, reqID)
	}
}

func TestMeRejectsInvalidToken(t *testing.T) {
	h := meHandler(t, &auth.FakeVerifier{Err: auth.ErrInvalidToken})
	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/api/v1/me", nil)
	req.Header.Set("Authorization", "Bearer bad")
	h.ServeHTTP(rec, req)
	code, _ := envelope(t, rec)
	if rec.Code != http.StatusUnauthorized || code != "unauthenticated" {
		t.Fatalf("status=%d code=%q, want 401 unauthenticated", rec.Code, code)
	}
}

func TestMeInfraErrorReturns503(t *testing.T) {
	// A non-token verifier failure (e.g. public-key fetch) is infrastructure,
	// not the caller's fault: 503 unavailable, with a request id.
	h := meHandler(t, &auth.FakeVerifier{Err: errors.New("key fetch failed")})
	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/api/v1/me", nil)
	req.Header.Set("Authorization", "Bearer whatever")
	h.ServeHTTP(rec, req)
	code, reqID := envelope(t, rec)
	if rec.Code != http.StatusServiceUnavailable || code != "unavailable" || reqID == "" {
		t.Fatalf("status=%d code=%q requestId=%q, want 503 unavailable with a request id", rec.Code, code, reqID)
	}
}

func TestMeProvisionsAndReturnsSameUser(t *testing.T) {
	h := meHandler(t, &auth.FakeVerifier{Identity: auth.Identity{Issuer: "iss", Subject: "sub-A"}})

	call := func() string {
		rec := httptest.NewRecorder()
		req := httptest.NewRequest("GET", "/api/v1/me", nil)
		req.Header.Set("Authorization", "Bearer t")
		h.ServeHTTP(rec, req)
		if rec.Code != http.StatusOK {
			t.Fatalf("status = %d, want 200; body=%s", rec.Code, rec.Body.String())
		}
		var body struct {
			User struct{ ID, Status string } `json:"user"`
		}
		if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
			t.Fatalf("unmarshal: %v", err)
		}
		if body.User.ID == "" || body.User.Status != "active" {
			t.Fatalf("user = %+v", body.User)
		}
		return body.User.ID
	}

	first := call()
	second := call() // same identity -> same internal user, no duplicate
	if first != second {
		t.Fatalf("me returned different ids for the same identity: %s != %s", first, second)
	}
}

func TestMeIsolatesUsers(t *testing.T) {
	db := testsupport.DB(t)
	if _, err := db.Exec("TRUNCATE public.users CASCADE"); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	svc := identity.NewService(identity.NewStore(db))

	me := func(subject string) string {
		h := buildHandler(Deps{
			Verifier:    &auth.FakeVerifier{Identity: auth.Identity{Issuer: "iss", Subject: subject}},
			Identity:    identity.NewHandler(svc, nil),
			ResolveUser: identity.NewMiddleware(svc, nil),
		})
		rec := httptest.NewRecorder()
		req := httptest.NewRequest("GET", "/api/v1/me", nil)
		req.Header.Set("Authorization", "Bearer t")
		h.ServeHTTP(rec, req)
		var body struct {
			User struct{ ID string } `json:"user"`
		}
		_ = json.Unmarshal(rec.Body.Bytes(), &body)
		return body.User.ID
	}

	if a, b := me("sub-A"), me("sub-B"); a == b || a == "" || b == "" {
		t.Fatalf("distinct identities must resolve to distinct users: a=%q b=%q", a, b)
	}
}
