package httpserver

import (
	"net/http"
	"net/http/httptest"
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
