package web

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestStaticAssetsServed(t *testing.T) {
	rec := httptest.NewRecorder()
	newTestHandler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/static/styles.css", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("styles.css status = %d", rec.Code)
	}
	if ct := rec.Header().Get("Content-Type"); !strings.Contains(ct, "css") {
		t.Fatalf("styles.css content-type = %q", ct)
	}
	if cc := rec.Header().Get("Cache-Control"); !strings.Contains(cc, "max-age=3600") {
		t.Fatalf("styles.css Cache-Control = %q", cc)
	}
	etag := rec.Header().Get("Etag")
	if etag == "" {
		t.Fatal("styles.css missing Etag")
	}

	// A second request with a matching If-None-Match returns 304.
	rec2 := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/static/styles.css", nil)
	req.Header.Set("If-None-Match", etag)
	newTestHandler().ServeHTTP(rec2, req)
	if rec2.Code != http.StatusNotModified {
		t.Fatalf("conditional request status = %d, want 304", rec2.Code)
	}
}

func TestStaticFontsServed(t *testing.T) {
	for _, name := range []string{
		"inter-variable-latin.woff2",
		"noto-sans-jp-400.woff2",
		"noto-sans-jp-600.woff2",
		"noto-sans-jp-700.woff2",
		"noto-sans-jp-800.woff2",
	} {
		rec := httptest.NewRecorder()
		newTestHandler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/static/fonts/"+name, nil))
		if rec.Code != http.StatusOK {
			t.Fatalf("%s status = %d", name, rec.Code)
		}
		if rec.Body.Len() == 0 {
			t.Fatalf("%s served an empty body", name)
		}
	}
}

func TestStaticAssetsRejectsNonGet(t *testing.T) {
	rec := httptest.NewRecorder()
	newTestHandler().ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/static/styles.css", nil))
	if rec.Code != http.StatusMethodNotAllowed {
		t.Fatalf("status = %d, want 405", rec.Code)
	}
}

func TestHomePageLinksStylesheetAndPreloadsFonts(t *testing.T) {
	rec := httptest.NewRecorder()
	newTestHandler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/en", nil))
	body := rec.Body.String()
	if !strings.Contains(body, `<link rel="stylesheet" href="/static/styles.css">`) {
		t.Fatal("home page missing stylesheet link")
	}
	if !strings.Contains(body, `rel="preload" as="font"`) {
		t.Fatal("home page missing font preload")
	}
}
