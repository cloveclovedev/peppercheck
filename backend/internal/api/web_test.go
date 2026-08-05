package api

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/identity"
	"github.com/cloveclovedev/peppercheck/backend/internal/platform/auth"
	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
	"github.com/cloveclovedev/peppercheck/backend/internal/web"
)

func TestWebCatchAllServesRootAndDoesNotShadowMountedAPIRoutes(t *testing.T) {
	db := testsupport.DB(t)
	if _, err := db.Exec("TRUNCATE public.users CASCADE"); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	svc := identity.NewService(identity.NewStore(db), nil)
	h := buildHandler(Deps{
		Verifier:    &auth.FakeVerifier{Identity: auth.Identity{Issuer: "iss", Subject: "sub-A"}},
		Identity:    identity.NewHandler(svc, nil),
		ResolveUser: identity.NewMiddleware(svc, nil),
		Web:         web.NewHandler(web.Deps{}),
	})

	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/", nil))
	if rec.Code != http.StatusMovedPermanently || rec.Header().Get("Location") != "/en" {
		t.Fatalf("GET / = %d %q, want 301 to /en", rec.Code, rec.Header().Get("Location"))
	}

	// The identity route is mounted (Verifier/Identity/ResolveUser are all
	// set), so it must win over the web catch-all's "/" pattern -- stdlib
	// ServeMux picks the more specific pattern, but this asserts the actual
	// wiring, not just the stdlib guarantee.
	rec = httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/api/v1/me", nil)
	req.Header.Set("Authorization", "Bearer t")
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /api/v1/me = %d, want 200 from the identity route; body=%s", rec.Code, rec.Body.String())
	}
	if ct := rec.Header().Get("Content-Type"); ct != "application/json" {
		t.Fatalf("GET /api/v1/me Content-Type = %q, want application/json (was it served by the web handler instead?)", ct)
	}
}

func TestAPIPrefixFallbackStaysJSONOnMethodMismatch(t *testing.T) {
	// Regression: stdlib ServeMux does NOT return 405 for a wrong-method
	// request against a registered path when a less-specific catch-all ("/")
	// also matches -- it silently dispatches to the catch-all instead. Without
	// the /api/ prefix fallback, POST /api/v1/me (only GET is registered)
	// would be served by the web handler as an HTML 404 page.
	h := buildHandler(Deps{Web: web.NewHandler(web.Deps{})})

	for _, tc := range []struct{ method, path string }{
		{http.MethodPost, "/api/v1/me"},            // registered path, wrong method
		{http.MethodGet, "/api/v1/does-not-exist"}, // unregistered path
	} {
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, httptest.NewRequest(tc.method, tc.path, nil))
		if rec.Code != http.StatusNotFound {
			t.Fatalf("%s %s = %d, want 404", tc.method, tc.path, rec.Code)
		}
		if ct := rec.Header().Get("Content-Type"); ct != "application/json" {
			t.Fatalf("%s %s Content-Type = %q, want application/json (leaked to the web handler?)", tc.method, tc.path, ct)
		}
	}
}

func TestBuildHandlerWithoutWebHasNoCatchAll(t *testing.T) {
	h := buildHandler(Deps{})
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/", nil))
	if rec.Code != http.StatusNotFound {
		t.Fatalf("GET / without Web = %d, want 404 (stdlib ServeMux default, no catch-all registered)", rec.Code)
	}
}
