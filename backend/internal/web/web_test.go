package web

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func newTestHandler() *Handler { return NewHandler(Deps{}) }

func TestRootRedirectsToDefaultLocale(t *testing.T) {
	rec := httptest.NewRecorder()
	newTestHandler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/", nil))
	if rec.Code != http.StatusMovedPermanently {
		t.Fatalf("status = %d", rec.Code)
	}
	if loc := rec.Header().Get("Location"); loc != "/en" {
		t.Fatalf("Location = %q", loc)
	}
}

func TestLocalizedHomeRenders(t *testing.T) {
	for _, tc := range []struct{ loc, want string }{
		{"en", "Peer Referee Platform for Tasks"},
		{"ja", "ピア・レフリー"},
	} {
		rec := httptest.NewRecorder()
		newTestHandler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/"+tc.loc, nil))
		if rec.Code != http.StatusOK {
			t.Fatalf("%s home status = %d", tc.loc, rec.Code)
		}
		body := rec.Body.String()
		if !strings.Contains(body, tc.want) {
			t.Fatalf("%s home missing %q in body", tc.loc, tc.want)
		}
		if !strings.Contains(body, `<title>Peppercheck</title>`) {
			t.Fatalf("%s home missing expected <title>", tc.loc)
		}
		if !strings.Contains(body, `hreflang="ja"`) || !strings.Contains(body, `hreflang="x-default"`) {
			t.Fatalf("%s home missing hreflang tags", tc.loc)
		}
		if !strings.Contains(body, `lang="`+tc.loc+`"`) {
			t.Fatalf("%s home missing <html lang>", tc.loc)
		}
	}
}

func TestUnknownPathIs404(t *testing.T) {
	rec := httptest.NewRecorder()
	newTestHandler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/en/nope", nil))
	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d", rec.Code)
	}
}

func TestLegacyRoutesAre404NotRedirect(t *testing.T) {
	// P3b-D15: the public web has never gone to production, so the legacy
	// auth/subscription routes carry no external indexing/backlinks to
	// preserve. No route is registered for them; they 404 like any other
	// unknown path, with no redirect.
	for _, p := range []string{"/auth/callback", "/login", "/dashboard", "/pricing", "/en/login", "/ja/pricing"} {
		rec := httptest.NewRecorder()
		newTestHandler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, p, nil))
		if rec.Code != http.StatusNotFound {
			t.Fatalf("%s status = %d, want 404", p, rec.Code)
		}
		if loc := rec.Header().Get("Location"); loc != "" {
			t.Fatalf("%s unexpectedly redirected to %q", p, loc)
		}
	}
}

func TestSecurityHeadersOnEveryResponse(t *testing.T) {
	rec := httptest.NewRecorder()
	newTestHandler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/en", nil))
	csp := rec.Header().Get("Content-Security-Policy")
	if csp == "" {
		t.Fatal("missing Content-Security-Policy header")
	}
	if !strings.Contains(csp, "default-src 'self'") || !strings.Contains(csp, "frame-ancestors 'none'") {
		t.Fatalf("unexpected CSP: %q", csp)
	}
	if rec.Header().Get("X-Content-Type-Options") != "nosniff" {
		t.Fatal("missing X-Content-Type-Options: nosniff")
	}
	if rec.Header().Get("Referrer-Policy") == "" {
		t.Fatal("missing Referrer-Policy")
	}
}
