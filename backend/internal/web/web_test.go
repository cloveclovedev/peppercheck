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

func TestRootRedirectPreservesQueryString(t *testing.T) {
	// Campaign/attribution params (utm_source, etc.) must survive the locale
	// redirect instead of being dropped at the root.
	rec := httptest.NewRecorder()
	newTestHandler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/?utm_source=ad&utm_campaign=x", nil))
	if rec.Code != http.StatusMovedPermanently {
		t.Fatalf("status = %d", rec.Code)
	}
	if loc := rec.Header().Get("Location"); loc != "/en?utm_source=ad&utm_campaign=x" {
		t.Fatalf("Location = %q, want query string preserved", loc)
	}
}

func TestLocalizedHomeRenders(t *testing.T) {
	for _, tc := range []struct{ loc, want string }{
		{"en", "Peer Referee Platform<br>for Tasks"},
		{"ja", "タスクのための<br>ピア・レフリー"},
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
		// Google requires hreflang alternates to be fully qualified (scheme +
		// host), not relative paths.
		if !strings.Contains(body, `hreflang="en" href="https://example.com/en"`) {
			t.Fatalf("%s home hreflang href is not absolute; body=%s", tc.loc, body)
		}
		// The language switcher's visible nav links stay relative, unlike the
		// hreflang tags -- distinct hrefs to the same locale in the same page.
		if !strings.Contains(body, `<a href="/en">EN</a>`) {
			t.Fatalf("%s home language switcher missing relative EN link", tc.loc)
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

func TestStripeConnectPagesRender(t *testing.T) {
	for _, kind := range []string{"return", "refresh"} {
		for _, loc := range []string{"en", "ja"} {
			rec := httptest.NewRecorder()
			newTestHandler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/"+loc+"/stripe/connect/"+kind, nil))
			if rec.Code != http.StatusOK {
				t.Fatalf("%s/stripe/connect/%s status = %d", loc, kind, rec.Code)
			}
			if !strings.Contains(rec.Body.String(), "hi@cloveclove.dev") {
				t.Fatalf("%s/stripe/connect/%s missing interpolated contact email; body=%s", loc, kind, rec.Body.String())
			}
		}
	}
}

func TestStripeConnectBarePathsRedirectToDefaultLocale(t *testing.T) {
	// payout-setup (Phase 5) sends return_url/refresh_url as these exact
	// bare, locale-less paths; they must keep resolving.
	for _, kind := range []string{"return", "refresh"} {
		rec := httptest.NewRecorder()
		newTestHandler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/stripe/connect/"+kind, nil))
		if rec.Code != http.StatusMovedPermanently {
			t.Fatalf("bare %s status = %d", kind, rec.Code)
		}
		if loc := rec.Header().Get("Location"); loc != "/en/stripe/connect/"+kind {
			t.Fatalf("bare %s Location = %q", kind, loc)
		}
	}
}

func TestUnknownStripeConnectPageIs404(t *testing.T) {
	rec := httptest.NewRecorder()
	newTestHandler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/en/stripe/connect/nope", nil))
	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d", rec.Code)
	}
}

func TestLegalPagesRender(t *testing.T) {
	for _, page := range []string{"privacy", "terms", "refund", "tokushoho"} {
		for _, loc := range []string{"en", "ja"} {
			rec := httptest.NewRecorder()
			newTestHandler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/"+loc+"/legal/"+page, nil))
			if rec.Code != http.StatusOK {
				t.Fatalf("%s/%s status = %d", loc, page, rec.Code)
			}
			if !strings.Contains(rec.Body.String(), `hreflang="ja"`) {
				t.Fatalf("%s/%s missing hreflang", loc, page)
			}
		}
	}
}

func TestUnknownLegalPageIs404(t *testing.T) {
	rec := httptest.NewRecorder()
	newTestHandler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/en/legal/nope", nil))
	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d", rec.Code)
	}
}

func TestTokushohoShowsAllThreePlanPrices(t *testing.T) {
	// The current page only shows the dead Stripe Web Checkout prices
	// (subscription is IAP-only); this asserts the real, reviewed IAP price
	// points for all three plans, not just Premium.
	rec := httptest.NewRecorder()
	newTestHandler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/ja/legal/tokushoho", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d", rec.Code)
	}
	body := rec.Body.String()
	for _, want := range []string{"650", "1,280", "2,480"} {
		if !strings.Contains(body, want) {
			t.Fatalf("tokushoho page missing formatted price %q; body=%s", want, body)
		}
	}
}

func TestFormatJPY(t *testing.T) {
	for _, tc := range []struct {
		in   int
		want string
	}{
		{0, "0"},
		{650, "650"},
		{1280, "1,280"},
		{2480, "2,480"},
		{1000000, "1,000,000"},
	} {
		if got := formatJPY(tc.in); got != tc.want {
			t.Fatalf("formatJPY(%d) = %q, want %q", tc.in, got, tc.want)
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
