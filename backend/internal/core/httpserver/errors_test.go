package httpserver

import (
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestWriteErrorEnvelope(t *testing.T) {
	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/x", nil)
	req.Header.Set(RequestIDHeader, "req-123")
	// RequestID middleware normally seeds the context; seed it directly here.
	req = req.WithContext(withRequestID(req.Context(), "req-123"))

	WriteError(rec, req, http.StatusUnauthorized, CodeUnauthenticated, "missing token")

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", rec.Code)
	}
	if ct := rec.Header().Get("Content-Type"); ct != "application/json" {
		t.Fatalf("content-type = %q", ct)
	}
	var body struct {
		Error struct {
			Code, Message, RequestID string
		} `json:"error"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("unmarshal: %v; body=%s", err, rec.Body.String())
	}
	if body.Error.Code != "unauthenticated" || body.Error.Message != "missing token" || body.Error.RequestID != "req-123" {
		t.Fatalf("envelope = %+v", body.Error)
	}
}

func TestNewErrorCodesAreStable(t *testing.T) {
	cases := map[string]string{
		CodeInvalidArgument: "invalid_argument",
		CodeUsernameTaken:   "username_taken",
		CodeInvalidTimezone: "invalid_timezone",
		CodeRateLimited:     "rate_limited",
		CodeNotFound:        "not_found",
		CodeForbidden:       "forbidden",
		CodeConflict:        "conflict",
	}
	for got, want := range cases {
		if got != want {
			t.Fatalf("code = %q, want %q", got, want)
		}
	}
}

func TestDecodeJSONRejectsUnknownFields(t *testing.T) {
	r := httptest.NewRequest("POST", "/", strings.NewReader(`{"nope":1}`))
	w := httptest.NewRecorder()
	var dst struct {
		Name string `json:"name"`
	}
	if DecodeJSON(w, r, &dst) {
		t.Fatal("want false for unknown field")
	}
	if w.Code != http.StatusBadRequest {
		t.Fatalf("want 400, got %d", w.Code)
	}
	var body struct {
		Error struct{ Code string } `json:"error"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("unmarshal: %v; body=%s", err, w.Body.String())
	}
	if body.Error.Code != CodeInvalidArgument {
		t.Fatalf("code = %q, want %q", body.Error.Code, CodeInvalidArgument)
	}
}

func TestDecodeJSONAcceptsKnownFields(t *testing.T) {
	r := httptest.NewRequest("POST", "/", strings.NewReader(`{"name":"ok"}`))
	w := httptest.NewRecorder()
	var dst struct {
		Name string `json:"name"`
	}
	if !DecodeJSON(w, r, &dst) {
		t.Fatalf("want true; body=%s", w.Body.String())
	}
	if dst.Name != "ok" {
		t.Fatalf("name = %q, want ok", dst.Name)
	}
}

func TestRecoverWritesEnvelope(t *testing.T) {
	panicky := http.HandlerFunc(func(http.ResponseWriter, *http.Request) { panic("boom") })
	h := Chain(panicky, RequestID, Recover(slog.New(slog.NewTextHandler(io.Discard, nil))))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/x", nil))
	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want 500", rec.Code)
	}
	var body struct {
		Error struct{ Code, RequestID string } `json:"error"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("unmarshal: %v; body=%s", err, rec.Body.String())
	}
	if body.Error.Code != "internal" || body.Error.RequestID == "" {
		t.Fatalf("envelope = %+v", body.Error)
	}
}
