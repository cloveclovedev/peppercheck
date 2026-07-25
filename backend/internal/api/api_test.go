package api

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestBuildHandlerLivez(t *testing.T) {
	h := buildHandler(Deps{})
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/livez", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("/livez = %d, want 200", rec.Code)
	}
}

func TestBuildHandlerReadyzUsesProbe(t *testing.T) {
	h := buildHandler(Deps{Ready: func(context.Context) error { return errors.New("down") }})
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/readyz", nil))
	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("/readyz = %d, want 503 when probe fails", rec.Code)
	}
}

func TestBuildHandlerReadyzOKWhenNilProbe(t *testing.T) {
	h := buildHandler(Deps{})
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/readyz", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("/readyz = %d, want 200 when probe is nil", rec.Code)
	}
}
