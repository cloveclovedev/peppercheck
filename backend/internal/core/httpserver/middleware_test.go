package httpserver

import (
	"bytes"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestRequestIDGeneratesAndEchoes(t *testing.T) {
	var seen string
	h := RequestID(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		seen = RequestIDFrom(r.Context())
	}))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/", nil))
	if seen == "" {
		t.Fatal("request id not present in context")
	}
	if rec.Header().Get(RequestIDHeader) != seen {
		t.Fatalf("response header %q != context id %q", rec.Header().Get(RequestIDHeader), seen)
	}
}

func TestRequestIDPreservesInbound(t *testing.T) {
	h := RequestID(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {}))
	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/", nil)
	req.Header.Set(RequestIDHeader, "abc123")
	h.ServeHTTP(rec, req)
	if rec.Header().Get(RequestIDHeader) != "abc123" {
		t.Fatalf("inbound request id not preserved: %q", rec.Header().Get(RequestIDHeader))
	}
}

// A panic (turned into a 500 by Recover) must still be access-logged. That only
// holds when AccessLog wraps Recover — the order used by api.Run.
func TestAccessLogRecordsPanicAsFiveHundred(t *testing.T) {
	var buf bytes.Buffer
	logger := slog.New(slog.NewJSONHandler(&buf, nil))
	panicking := http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		panic("boom")
	})
	h := Chain(panicking, AccessLog(logger), Recover(logger))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/x", nil))
	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want 500", rec.Code)
	}
	out := buf.String()
	if !strings.Contains(out, `"msg":"http_request"`) {
		t.Fatalf("panicking request was not access-logged: %s", out)
	}
	if !strings.Contains(out, `"status":500`) {
		t.Fatalf("access log did not record status 500: %s", out)
	}
}
