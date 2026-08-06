package web

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/ratelimit"
)

// recordingDeleter fakes deletionRequester, recording each call.
type recordingDeleter struct {
	calls     int
	lastEmail string
	err       error
}

func (f *recordingDeleter) RequestDeletion(_ context.Context, claimedEmail string) error {
	f.calls++
	f.lastEmail = claimedEmail
	return f.err
}

// newDeletionHandler builds a Handler with a fixed non-empty FormToken key and
// a rate limiter generous enough not to trip within one test.
func newDeletionHandler(d deletionRequester) *Handler {
	return NewHandler(Deps{
		Deletion:  d,
		FormToken: NewFormToken([]byte("test-form-signing-key")),
		RateLim:   ratelimit.NewTokenBucket(1000, 1000, time.Hour, nil),
	})
}

func TestAccountDeleteFormRenders(t *testing.T) {
	h := newDeletionHandler(&recordingDeleter{})
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/en/account/delete", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d", rec.Code)
	}
	body := rec.Body.String()
	if !strings.Contains(body, `name="email"`) || !strings.Contains(body, `name="form_token"`) {
		t.Fatal("form missing email/token fields")
	}
	if !strings.Contains(body, `name="website"`) { // honeypot
		t.Fatal("form missing honeypot field")
	}
	if !strings.Contains(body, `name="consent"`) {
		t.Fatal("form missing consent checkbox")
	}
}

func TestAccountDeleteWithoutDepsRendersInstructionsOnlyNoForm(t *testing.T) {
	h := newTestHandler() // no Deletion/FormToken/RateLim wired
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/en/account/delete", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d", rec.Code)
	}
	if strings.Contains(rec.Body.String(), `name="email"`) {
		t.Fatal("form should not render when dependencies are missing")
	}
}

func TestAccountDeleteSubmittedShowsUniformConfirmation(t *testing.T) {
	h := newDeletionHandler(&recordingDeleter{})
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/en/account/delete?submitted=1", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d", rec.Code)
	}
	body := rec.Body.String()
	if strings.Contains(body, `name="email"`) {
		t.Fatal("submitted page must not still show the form")
	}
}

func postDeleteForm(h *Handler, form string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(http.MethodPost, "/en/account/delete", strings.NewReader(form))
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec
}

func TestAccountDeletePostUniformAndCallsService(t *testing.T) {
	rd := &recordingDeleter{}
	h := newDeletionHandler(rd)
	tok := h.formToken.Issue(time.Now().Add(-2 * time.Second))
	rec := postDeleteForm(h, "email=a%40b.com&form_token="+tok+"&consent=on&website=")
	if rec.Code != http.StatusSeeOther {
		t.Fatalf("status = %d", rec.Code)
	}
	if loc := rec.Header().Get("Location"); loc != "/en/account/delete?submitted=1" {
		t.Fatalf("Location = %q", loc)
	}
	if rd.calls != 1 || rd.lastEmail != "a@b.com" {
		t.Fatalf("service calls=%d email=%q", rd.calls, rd.lastEmail)
	}
}

func TestAccountDeletePostHoneypotSilentlyDropped(t *testing.T) {
	rd := &recordingDeleter{}
	h := newDeletionHandler(rd)
	tok := h.formToken.Issue(time.Now().Add(-2 * time.Second))
	rec := postDeleteForm(h, "email=a%40b.com&form_token="+tok+"&consent=on&website=iamabot")
	if rec.Code != http.StatusSeeOther { // same uniform response
		t.Fatalf("status = %d", rec.Code)
	}
	if rd.calls != 0 {
		t.Fatalf("honeypot should skip the service, calls=%d", rd.calls)
	}
}

func TestAccountDeletePostRequiresConsent(t *testing.T) {
	rd := &recordingDeleter{}
	h := newDeletionHandler(rd)
	tok := h.formToken.Issue(time.Now().Add(-2 * time.Second))
	rec := postDeleteForm(h, "email=a%40b.com&form_token="+tok+"&website=") // no consent
	if rec.Code != http.StatusSeeOther {
		t.Fatalf("status = %d", rec.Code)
	}
	if rd.calls != 0 {
		t.Fatalf("missing consent must not record, calls=%d", rd.calls)
	}
}

func TestAccountDeletePostRejectsBadFormToken(t *testing.T) {
	rd := &recordingDeleter{}
	h := newDeletionHandler(rd)
	rec := postDeleteForm(h, "email=a%40b.com&form_token=garbage&consent=on&website=")
	if rec.Code != http.StatusSeeOther { // same uniform response, no leak
		t.Fatalf("status = %d", rec.Code)
	}
	if rd.calls != 0 {
		t.Fatalf("bad token must not record, calls=%d", rd.calls)
	}
}

func TestAccountDeletePostInfraErrorReturns503(t *testing.T) {
	rd := &recordingDeleter{err: errors.New("db down")}
	h := newDeletionHandler(rd)
	tok := h.formToken.Issue(time.Now().Add(-2 * time.Second))
	rec := postDeleteForm(h, "email=a%40b.com&form_token="+tok+"&consent=on&website=")
	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("infra error must return 503 (not a 303 'submitted'), got %d", rec.Code)
	}
}

func TestAccountDeletePostRateLimited(t *testing.T) {
	rd := &recordingDeleter{}
	h := NewHandler(Deps{
		Deletion:  rd,
		FormToken: NewFormToken([]byte("test-form-signing-key")),
		RateLim:   ratelimit.NewTokenBucket(1, 1, time.Hour, nil), // burst of exactly 1
	})
	tok := h.formToken.Issue(time.Now().Add(-2 * time.Second))
	form := "email=a%40b.com&form_token=" + tok + "&consent=on&website="

	first := postDeleteForm(h, form)
	if first.Code != http.StatusSeeOther {
		t.Fatalf("first request status = %d", first.Code)
	}
	second := postDeleteForm(h, form)
	if second.Code != http.StatusTooManyRequests {
		t.Fatalf("second request status = %d, want 429", second.Code)
	}
	if rd.calls != 1 {
		t.Fatalf("rate-limited request must not reach the service, calls=%d", rd.calls)
	}
}

func TestAccountDeleteMethodNotAllowed(t *testing.T) {
	h := newDeletionHandler(&recordingDeleter{})
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodDelete, "/en/account/delete", nil))
	if rec.Code != http.StatusMethodNotAllowed {
		t.Fatalf("status = %d", rec.Code)
	}
}
