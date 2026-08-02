# Phase 3b — Go Server-Rendered Public Web Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Next.js/Cloudflare public web with Go `html/template` pages served same-origin from the existing `api` binary — marketing home, legal pages, Stripe Connect landing pages, redirects for removed routes, and an unauthenticated account-deletion **request** resource — and delete the old web app.

**Architecture:** A new inbound feature `internal/web` owns all page rendering (embedded templates + CSS + fonts + i18n catalog), locale routing, and transport-level anti-abuse (HMAC form token, honeypot, per-IP rate limit). A new domain feature `internal/accountdeletion` owns the deletion-request domain/application/data (match a claimed email to a real account, upsert an unverified request). `internal/identity` is extended to persist and look up the provider email. Everything is wired into the existing stdlib `http.ServeMux` in `internal/api`; the web handler is the catch-all for anything not under `/api/v1`.

**Tech Stack:** Go 1.26 stdlib (`net/http`, `html/template`, `embed`, `crypto/hmac`, `log/slog`), Postgres 17 via `database/sql` + pgx driver, Atlas v1.2.0 for schema/migrations.

## Global Constraints

- Module path `github.com/cloveclovedev/peppercheck/backend`; Go 1.26; **stdlib-first** (`http.ServeMux` with `"METHOD /path"` patterns); only external DB dep is pgx as a `database/sql` driver.
- **No `Querier` interface and no tx/UoW helper exist.** Stores hold `*sql.DB` directly (`type Store struct { db *sql.DB }`, `NewStore(db *sql.DB)`); transactions are inline via `db.BeginTx`.
- **`updated_at` is maintained by Go** (`updated_at = now()` inside each `UPDATE`), NOT by a DB trigger. There is no `set_updated_at()` trigger in this codebase; do not add one.
- **DB tests are plain transactional assert-SQL** in `backend/db/tests/*.sql` (`BEGIN; … DO $$ … ASSERT … $$; ROLLBACK;`), run via `psql -v ON_ERROR_STOP=1 -f`. **Not pgTAP.**
- Atlas is **pinned v1.2.0**. A new schema directory MUST be added to `backend/atlas.hcl`'s `env "local"` `src` list, and a migration generated with `atlas migrate diff <name> --env local`, or the CI drift check (`atlas migrate diff ci_drift_check`) fails.
- **Config is environment-variable only (no TOML).** Read secrets via `config.lookupEnvOrFile("KEY")` (reads `KEY_FILE` if set, fail-closed; else `KEY`).
- Test gate (from `make test` / `ci-backend.yml`): `go test -race -p 1 -count=1 ./...`, plus `gofmt -l .` empty, `go vet ./...` clean, and a clean `atlas migrate diff` drift check. Run via `make test`, `make fmt`, `make vet` from `backend/`.
- Web is served **same-origin** through the existing Caddy `reverse_proxy api:{$API_PORT}` — **no Caddy change**.
- **URL structure is frozen:** `/{locale}/` subdirectory with locales exactly `en` and `ja`, default `en`; every kept path is preserved byte-for-byte. `/stripe/connect/return` and `/stripe/connect/refresh` (locale-less bare paths) MUST resolve.
- **English only** for committed content (code, comments, templates' non-localized text, commit messages). Localized copy is data: ja strings live in `internal/web/messages/ja.json`.
- Fonts: self-host **Inter + Noto Sans JP** as embedded `woff2` (both SIL OFL); Noto Sans JP via `unicode-range` split subsets; `font-display: swap` + `preload`.
- tokushoho price is a single reviewed **constant**; it MUST be the reconciled value (a Premium price discrepancy — **2,580 vs 2,480** — is an open launch-blocker; resolve before shipping) and carry a comment referencing that blocker.
- Implementation targets the refactor **integration branch `refactor/go-api-vps`** (big-bang model), not any single-phase branch. Commit messages follow Conventional Commits with scope, e.g. `feat(backend): …`.
- Delegated file-reading agents must be told: do not read `.env`, `.env.*`, `*.jks`, `*.keystore`, `key.properties`, or any gitignored file that may contain secrets; review only git-tracked files.

---

## File Structure

**New — `internal/web/` (inbound presentation feature):**
- `web.go` — `Handler` (implements `http.Handler`), `NewHandler(deps Deps) *Handler`, `Deps` struct, path dispatch (locale resolution, bare-path redirect, page/redirect routing).
- `render.go` — `//go:embed templates/*.gohtml`, parsed `*template.Template`, `render(w, locale, name string, data pageData)`.
- `i18n.go` — `//go:embed messages/en.json messages/ja.json`, `catalog` type, `T(locale, key) string`, `supportedLocales`, `defaultLocale`.
- `locale.go` — locale helpers: `isSupported`, `hreflangAlternates(path) []alt`.
- `formtoken.go` — `FormToken` (HMAC issue/verify + timing window).
- `ratelimit.go` — `RateLimiter` (per-IP fixed window) + `clientIP(r)`.
- `assets.go` — `//go:embed static/*` + a `GET`-only static file server for `/static/`.
- `templates/` — `layout.gohtml`, `home.gohtml`, `legal_privacy.gohtml`, `legal_terms.gohtml`, `legal_refund.gohtml`, `legal_tokushoho.gohtml`, `stripe_return.gohtml`, `stripe_refresh.gohtml`, `account_delete.gohtml`, `notfound.gohtml`.
- `static/` — `styles.css`, `fonts/*.woff2`.
- `messages/` — `en.json`, `ja.json`.
- Test files: `web_test.go`, `formtoken_test.go`, `ratelimit_test.go`, `i18n_test.go`.

**New — `internal/accountdeletion/` (domain feature):**
- `domain.go` — `DeletionRequest`.
- `store.go` — `Store{db}`, `NewStore`, `Upsert(ctx, userID, claimedEmail)`.
- `service.go` — `Service`, `NewService(users userLookup, store requestStore)`, `RequestDeletion(ctx, claimedEmail)`.
- Test files: `store_test.go`, `service_test.go`.

**New — schema/migration:**
- `backend/schema/web/01_account_deletion_requests.sql`.
- `backend/db/tests/test_account_deletion_requests.sql`.
- A generated file under `backend/migrations/`.

**Modified:**
- `backend/schema/identity/02_user_identities.sql` — add `email`, `email_verified`, `lower(email)` index.
- `backend/internal/identity/store.go` — email in `CreateWithIdentity`; add `TouchIdentityEmail`, `FindUserByEmail`.
- `backend/internal/identity/service.go` — `ResolveOrProvision` gains `email`, `emailVerified`.
- `backend/internal/identity/handler.go` — `Me` passes `id.Email`, `id.EmailVerified`.
- `backend/internal/core/config/config.go` — add `WebFormSigningKey` via `lookupEnvOrFile`.
- `backend/internal/api/api.go` — add `Web http.Handler` to `Deps`; mount as catch-all.
- `backend/cmd/peppercheck/main.go` — construct identity email lookup + accountdeletion + web handler; pass to `api.Run`.
- `backend/atlas.hcl` — add `file://schema/web` to `src`.
- `backend/db/tests/test_identity_constraints.sql` — add email-column assertions.

**Deleted:**
- `peppercheck-webapp/` (whole directory).
- `.github/workflows/ci-webapp.yml`.

---

## Task 1: Web feature skeleton (embed, i18n, locale dispatch, home page, wiring)

**Files:**
- Create: `internal/web/web.go`, `internal/web/render.go`, `internal/web/i18n.go`, `internal/web/locale.go`
- Create: `internal/web/templates/layout.gohtml`, `internal/web/templates/home.gohtml`, `internal/web/templates/notfound.gohtml`
- Create: `internal/web/messages/en.json`, `internal/web/messages/ja.json`
- Create: `internal/web/web_test.go`, `internal/web/i18n_test.go`
- Modify: `internal/api/api.go`, `cmd/peppercheck/main.go`

**Interfaces:**
- Produces: `web.NewHandler(web.Deps{Logger *slog.Logger}) *web.Handler` (implements `http.Handler`); the handler serves `GET /` (→301 `/en`), `GET /{locale}` and `/{locale}/` (localized home), and renders a 404 for unknown paths. Later tasks add pages/redirects/deletion into the same dispatch.
- Consumes: nothing from other tasks.

- [ ] **Step 1: Write the i18n catalog + failing test**

Create `internal/web/messages/en.json`. This starts minimal for the skeleton
test; **Step 5 of this task ports the full `HomePage`, `Header`, and `Footer`
namespaces verbatim from `peppercheck-webapp/messages/{en,ja}.json`** (later
tasks add `Privacy`/`Terms`/`Refund`/`Tokushoho`/`StripeConnect`/`AccountDelete`).
```json
{
  "Meta": { "siteName": "PepperCheck" },
  "Home": { "title": "PepperCheck", "tagline": "Get things done, verified." },
  "NotFound": { "title": "Page not found" }
}
```
Create `internal/web/messages/ja.json`:
```json
{
  "Meta": { "siteName": "PepperCheck" },
  "Home": { "title": "PepperCheck", "tagline": "やると決めたことを、やり切る。" },
  "NotFound": { "title": "ページが見つかりません" }
}
```
Create `internal/web/i18n_test.go`:
```go
package web

import "testing"

func TestCatalogT(t *testing.T) {
	if got := cat.T("en", "Home.title"); got != "PepperCheck" {
		t.Fatalf("en Home.title = %q", got)
	}
	if got := cat.T("ja", "Home.tagline"); got != "やると決めたことを、やり切る。" {
		t.Fatalf("ja Home.tagline = %q", got)
	}
	if got := cat.T("en", "Missing.key"); got != "Missing.key" {
		t.Fatalf("missing key should echo the key, got %q", got)
	}
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd backend && go test ./internal/web/ -run TestCatalogT`
Expected: FAIL (package/`cat` undefined).

- [ ] **Step 3: Implement i18n.go**

Create `internal/web/i18n.go`:
```go
package web

import (
	"embed"
	"encoding/json"
	"strings"
)

//go:embed messages/en.json messages/ja.json
var messagesFS embed.FS

const defaultLocale = "en"

var supportedLocales = []string{"en", "ja"}

// catalog maps locale -> nested message tree.
type catalog map[string]map[string]any

var cat = loadCatalog()

func loadCatalog() catalog {
	c := catalog{}
	for _, loc := range supportedLocales {
		b, err := messagesFS.ReadFile("messages/" + loc + ".json")
		if err != nil {
			panic("web: missing messages for " + loc + ": " + err.Error())
		}
		var tree map[string]any
		if err := json.Unmarshal(b, &tree); err != nil {
			panic("web: bad messages json for " + loc + ": " + err.Error())
		}
		c[loc] = tree
	}
	return c
}

// T resolves a dotted key (e.g. "Home.title"); a missing key echoes the key so
// gaps are visible in tests and dev.
func (c catalog) T(locale, key string) string {
	tree, ok := c[locale]
	if !ok {
		return key
	}
	var cur any = map[string]any(tree)
	for _, seg := range strings.Split(key, ".") {
		m, ok := cur.(map[string]any)
		if !ok {
			return key
		}
		cur, ok = m[seg]
		if !ok {
			return key
		}
	}
	if s, ok := cur.(string); ok {
		return s
	}
	return key
}
```

- [ ] **Step 4: Run it to verify it passes**

Run: `cd backend && go test ./internal/web/ -run TestCatalogT`
Expected: PASS.

- [ ] **Step 5: Write templates + render.go + locale.go**

Create `internal/web/templates/layout.gohtml`:
```gotemplate
{{define "layout"}}<!doctype html>
<html lang="{{.Locale}}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{{.Title}}</title>
<link rel="stylesheet" href="/static/styles.css">
{{range .Hreflang}}<link rel="alternate" hreflang="{{.Lang}}" href="{{.Href}}">
{{end}}</head>
<body>
<header><a href="/{{.Locale}}">{{t .Locale "Meta.siteName"}}</a>
<nav>{{range .LangSwitch}}<a href="{{.Href}}">{{.Lang}}</a> {{end}}</nav></header>
<main>{{template "content" .}}</main>
<footer>
  <a href="/{{.Locale}}/legal/privacy">{{t .Locale "Footer.privacy"}}</a> ·
  <a href="/{{.Locale}}/legal/terms">{{t .Locale "Footer.terms"}}</a> ·
  <a href="/{{.Locale}}/legal/refund">{{t .Locale "Footer.refund"}}</a> ·
  <a href="/{{.Locale}}/legal/tokushoho">{{t .Locale "Footer.tokushoho"}}</a>
  <p>{{t .Locale "Footer.copyright"}}</p>
</footer>
</body></html>{{end}}
```
> Port the full `Header`/`Footer` structure and copy from the current webapp
> (`peppercheck-webapp/src/components/Header.tsx`, `Footer.tsx`, and their
> `Header`/`Footer` message namespaces) into `layout.gohtml` and the catalogs —
> nav links, the EN/JP switcher, contact (`hi@cloveclove.dev`), X link, and
> copyright — so the shared chrome matches the current design, not just the two
> links sketched above.

Create `internal/web/templates/home.gohtml` — port the real marketing structure
(hero, feature sections, CTA) from `peppercheck-webapp/src/app/[locale]/page.tsx`
and its `HomePage` message namespace; do not ship a bare heading:
```gotemplate
{{define "content"}}
<section class="hero">
  <h1>{{t .Locale "HomePage.heroTitle"}}</h1>
  <p>{{t .Locale "HomePage.heroSubtitle"}}</p>
  <a class="cta" href="/{{.Locale}}#features">{{t .Locale "HomePage.ctaLabel"}}</a>
</section>
<section id="features" class="features">
  {{/* Port each feature card from HomePage.features.* preserving order/structure */}}
  <h2>{{t .Locale "HomePage.featuresTitle"}}</h2>
</section>
{{end}}
```
(Use the exact `HomePage.*` keys present in the ported catalog; mirror the section
order and markup of the current page so Task 6's visual comparison can match it.)
Create `internal/web/templates/notfound.gohtml`:
```gotemplate
{{define "content"}}<h1>{{t .Locale "NotFound.title"}}</h1>{{end}}
```
Create `internal/web/locale.go`:
```go
package web

// alt is one hreflang alternate.
type alt struct {
	Lang string
	Href string
}

func isSupported(loc string) bool {
	for _, l := range supportedLocales {
		if l == loc {
			return true
		}
	}
	return false
}

// hreflangAlternates returns alternates for a locale-relative path (e.g.
// "/legal/privacy" or "" for home), one per supported locale plus x-default.
func hreflangAlternates(relPath string) []alt {
	out := make([]alt, 0, len(supportedLocales)+1)
	for _, l := range supportedLocales {
		out = append(out, alt{Lang: l, Href: "/" + l + relPath})
	}
	out = append(out, alt{Lang: "x-default", Href: "/" + defaultLocale + relPath})
	return out
}
```
Create `internal/web/render.go`. **Single canonical rendering method:** each page
file defines `{{define "content"}}…{{end}}` and is parsed **together with**
`layout.gohtml` into its own `*template.Template`, held in a `map[string]*template.Template`
keyed by page name. No runtime cloning, no "content" aliasing, no ambiguity —
adding a `templates/<name>.gohtml` auto-registers `<name>`.
```go
package web

import (
	"bytes"
	"embed"
	"html/template"
	"io/fs"
	"log/slog"
	"net/http"
	"path"
	"strings"
)

//go:embed templates/*.gohtml
var templatesFS embed.FS

// pageData is the data every template receives. Page-specific fields are zero
// for pages that don't use them.
type pageData struct {
	Locale     string
	Title      string
	Hreflang   []alt
	LangSwitch []alt
	// tokushoho (Task 3)
	PremiumPrice string
	// account-deletion page (Task 12)
	ShowForm  bool
	Submitted bool
	FormToken string
}

// pages holds one parsed set per page: layout + that page's content block.
var pages = parsePages()

func parsePages() map[string]*template.Template {
	fm := template.FuncMap{"t": cat.T}
	entries, err := fs.Glob(templatesFS, "templates/*.gohtml")
	if err != nil {
		panic("web: glob templates: " + err.Error())
	}
	m := map[string]*template.Template{}
	for _, e := range entries {
		base := strings.TrimSuffix(path.Base(e), ".gohtml")
		if base == "layout" {
			continue
		}
		m[base] = template.Must(
			template.New("layout").Funcs(fm).ParseFS(templatesFS, "templates/layout.gohtml", e),
		)
	}
	return m
}

// render executes the named page to a buffer first, so a template error yields a
// clean 500 instead of a half-written body.
func (h *Handler) render(w http.ResponseWriter, status int, name string, data pageData) {
	t, ok := pages[name]
	if !ok {
		h.logger.Error("web_render_unknown_template", slog.String("template", name))
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	var buf bytes.Buffer
	if err := t.ExecuteTemplate(&buf, "layout", data); err != nil {
		h.logger.Error("web_render_exec_failed", slog.String("template", name), slog.Any("error", err))
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(status)
	_, _ = buf.WriteTo(w)
}
```

> Every page template (`home`, `notfound`, `legal_*`, `stripe_*`, `account_delete`)
> defines exactly one `{{define "content"}}` block. `pageData` already carries the
> page-specific fields later tasks need (tokushoho price, deletion form), so no
> task re-edits the struct.

- [ ] **Step 6: Write web.go (Handler + dispatch) + failing test**

Create `internal/web/web.go`:
```go
package web

import (
	"log/slog"
	"net/http"
	"strings"
)

// Deps are the web handler's dependencies. Later tasks add fields.
type Deps struct {
	Logger *slog.Logger
}

// Handler serves the server-rendered public web on every path not owned by the
// JSON API. It is mounted as the ServeMux catch-all ("/").
type Handler struct {
	logger *slog.Logger
}

// NewHandler builds the web Handler. A nil logger falls back to slog.Default().
func NewHandler(d Deps) *Handler {
	l := d.Logger
	if l == nil {
		l = slog.Default()
	}
	return &Handler{logger: l}
}

// contentSecurityPolicy locks the pages to their own self-contained origin. The
// site ships no JavaScript and no external hosts (CSS/fonts are embedded and
// served same-origin), so this is strict: no scripts, no framing, forms only to
// self. data: is allowed for images (favicons/inline SVG) only.
const contentSecurityPolicy = "default-src 'self'; script-src 'none'; style-src 'self'; font-src 'self'; img-src 'self' data:; form-action 'self'; base-uri 'self'; frame-ancestors 'none'; object-src 'none'"

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	// Security headers on every web response (set before any body/redirect write).
	w.Header().Set("Content-Security-Policy", contentSecurityPolicy)
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.Header().Set("Referrer-Policy", "strict-origin-when-cross-origin")

	p := r.URL.Path
	if p == "/" {
		http.Redirect(w, r, "/"+defaultLocale, http.StatusMovedPermanently)
		return
	}
	segs := strings.Split(strings.Trim(p, "/"), "/")
	if !isSupported(segs[0]) {
		// Bare (locale-less) path: redirect known ones to the default locale;
		// otherwise 404. Bare-path routing is completed in later tasks.
		h.renderNotFound(w, defaultLocale)
		return
	}
	locale := segs[0]
	rest := segs[1:]

	switch {
	case len(rest) == 0: // localized home
		h.render(w, http.StatusOK, "home", h.page(locale, "Home.title", ""))
	default:
		h.renderNotFound(w, locale)
	}
}

func (h *Handler) renderNotFound(w http.ResponseWriter, locale string) {
	h.render(w, http.StatusNotFound, "notfound", h.page(locale, "NotFound.title", ""))
}

// page builds pageData for a locale, a title message key, and the locale-relative
// path (used for hreflang + the language switcher).
func (h *Handler) page(locale, titleKey, relPath string) pageData {
	return pageData{
		Locale:     locale,
		Title:      cat.T(locale, titleKey),
		Hreflang:   hreflangAlternates(relPath),
		LangSwitch: hreflangAlternates(relPath)[:len(supportedLocales)],
	}
}
```
Create `internal/web/web_test.go`:
```go
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
		{"en", "Get things done"},
		{"ja", "やると決めたことを"},
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
}
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `cd backend && go test ./internal/web/`
Expected: PASS. (Adjust the render mechanism per the Step 5 note until home renders the tagline.)

- [ ] **Step 8: Wire the web handler into the API mux + main**

Modify `internal/api/api.go`: add `Web http.Handler` to `Deps` and mount it as the catch-all in `buildHandler` (after the existing routes):
```go
if deps.Web != nil {
	mux.Handle("/", deps.Web)
}
```
Modify `cmd/peppercheck/main.go` (the `api` subcommand wiring): construct and pass the web handler:
```go
webHandler := web.NewHandler(web.Deps{Logger: logger})
// ...
err = api.Run(ctx, cfg, logger, api.Deps{
	Ready:    db.PingContext,
	Verifier: verifier,
	Identity: idHandler,
	Web:      webHandler,
})
```
Add the import `"github.com/cloveclovedev/peppercheck/backend/internal/web"`.

- [ ] **Step 9: Verify the mux integration**

Add to `internal/api/` a test (or extend `me_test.go` style) that builds `rootHandler(Deps{Web: web.NewHandler(web.Deps{})}, logger)` and asserts `GET /` → 301 `/en` and `GET /api/v1/me` is still handled by the identity route (not the web catch-all). Run: `cd backend && go test ./internal/api/`
Expected: PASS.

- [ ] **Step 10: Format, vet, commit**

Run: `cd backend && make fmt && make vet && go test ./internal/web/ ./internal/api/`
```bash
git add backend/internal/web backend/internal/api/api.go backend/cmd/peppercheck/main.go
git commit -m "feat(backend): web feature skeleton (embed templates, i18n, locale dispatch, home)"
```

---

## Task 2: Legal pages (privacy, terms, refund)

**Files:**
- Create: `internal/web/templates/legal_privacy.gohtml`, `legal_terms.gohtml`, `legal_refund.gohtml`
- Modify: `internal/web/messages/en.json`, `internal/web/messages/ja.json` (add `Privacy`, `Terms`, `Refund` namespaces — port the copy from `peppercheck-webapp/messages/{en,ja}.json`)
- Modify: `internal/web/web.go` (route the three paths)
- Test: `internal/web/web_test.go`

**Interfaces:**
- Consumes: `Handler.render`, `Handler.page`, `cat.T` (Task 1).
- Produces: routes `GET /{locale}/legal/{privacy,terms,refund}`.

- [ ] **Step 1: Port the legal copy into the message catalogs**

Copy the `Privacy`, `Terms`, `Refund` namespaces from `peppercheck-webapp/messages/en.json` and `messages/ja.json` verbatim into `internal/web/messages/en.json` and `ja.json`. Preserve keys so template references match. (Read those files; they are git-tracked and contain no secrets.)

- [ ] **Step 2: Write a failing route test**

Add to `internal/web/web_test.go`:
```go
func TestLegalPagesRender(t *testing.T) {
	for _, page := range []string{"privacy", "terms", "refund"} {
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
```

- [ ] **Step 3: Run it to verify it fails**

Run: `cd backend && go test ./internal/web/ -run TestLegalPagesRender`
Expected: FAIL (routes 404).

- [ ] **Step 4: Add templates + routing**

Create each template, e.g. `internal/web/templates/legal_privacy.gohtml`:
```gotemplate
{{define "content"}}<article><h1>{{t .Locale "Privacy.title"}}</h1>
{{/* render the ported Privacy.* sections here, mirroring the webapp page structure */}}
</article>{{end}}
```
(Do the same for `legal_terms.gohtml` → `Terms.*` and `legal_refund.gohtml` → `Refund.*`.)
In `internal/web/web.go` dispatch, extend the `switch` with a legal branch:
```go
case len(rest) == 2 && rest[0] == "legal":
	switch rest[1] {
	case "privacy":
		h.render(w, http.StatusOK, "legal_privacy", h.page(locale, "Privacy.title", "/legal/privacy"))
	case "terms":
		h.render(w, http.StatusOK, "legal_terms", h.page(locale, "Terms.title", "/legal/terms"))
	case "refund":
		h.render(w, http.StatusOK, "legal_refund", h.page(locale, "Refund.title", "/legal/refund"))
	default:
		h.renderNotFound(w, locale)
	}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd backend && go test ./internal/web/ -run 'TestLegalPagesRender|TestLocalizedHomeRenders'`
Expected: PASS.

- [ ] **Step 6: Format, vet, commit**

Run: `cd backend && make fmt && make vet`
```bash
git add backend/internal/web
git commit -m "feat(backend): port privacy/terms/refund legal pages to Go templates"
```

---

## Task 3: tokushoho page (hardcoded reviewed price)

**Files:**
- Create: `internal/web/templates/legal_tokushoho.gohtml`
- Modify: `internal/web/web.go` (constant + route), `internal/web/messages/{en,ja}.json` (`Tokushoho` namespace)
- Test: `internal/web/web_test.go`

**Interfaces:**
- Consumes: `Handler.render`, `Handler.page`.
- Produces: route `GET /{locale}/legal/tokushoho`; the page shows a hardcoded price.

- [ ] **Step 1: Add the price constant + failing test**

In `internal/web/web.go` add:
```go
// premiumPriceJPY is the reviewed Premium subscription price shown on the
// 特定商取引法 page. LAUNCH-BLOCKER: a Premium price discrepancy (2,580 vs 2,480)
// is unresolved in the Phase 0 baseline; this constant MUST be the reconciled
// value before shipping. Phase 5 replaces this with a read from the Go
// subscription endpoint (see the Phase 3b follow-ups doc).
const premiumPriceJPY = 2480
```
Add to `internal/web/web_test.go`:
```go
func TestTokushohoShowsPrice(t *testing.T) {
	rec := httptest.NewRecorder()
	newTestHandler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/ja/legal/tokushoho", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d", rec.Code)
	}
	if !strings.Contains(rec.Body.String(), "2,480") {
		t.Fatalf("tokushoho page missing formatted price; body=%s", rec.Body.String())
	}
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd backend && go test ./internal/web/ -run TestTokushohoShowsPrice`
Expected: FAIL (route 404 / no price).

- [ ] **Step 3: Port the tokushoho copy + template + route + price formatting**

Copy the `Tokushoho` namespace from the webapp catalogs (seller/contact info etc.), keeping the solo-operator wording rule (no "employee"/team claims). Add a template `legal_tokushoho.gohtml` rendering the copy and a `.PremiumPrice` value. Extend `page` (or add a variant) to include the formatted price, and add the route branch `case "tokushoho":`. Format the integer with thousands separators (write a tiny helper `formatJPY(n int) string` returning e.g. `"2,480"`).

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd backend && go test ./internal/web/ -run TestTokushohoShowsPrice`
Expected: PASS.

- [ ] **Step 5: Format, vet, commit**

Run: `cd backend && make fmt && make vet`
```bash
git add backend/internal/web
git commit -m "feat(backend): port tokushoho page with reviewed price constant"
```

---

## Task 4: Stripe Connect landing pages (return / refresh) + bare-path handling

**Files:**
- Create: `internal/web/templates/stripe_return.gohtml`, `stripe_refresh.gohtml`
- Modify: `internal/web/web.go` (routes + bare-path redirect), `internal/web/messages/{en,ja}.json` (`StripeConnect` namespace)
- Test: `internal/web/web_test.go`

**Interfaces:**
- Consumes: `Handler.render`, `Handler.page`.
- Produces: routes `GET /{locale}/stripe/connect/{return,refresh}` AND locale-less `GET /stripe/connect/{return,refresh}` (301 → default locale).

- [ ] **Step 1: Failing tests (localized + bare)**

Add to `internal/web/web_test.go`:
```go
func TestStripeConnectPages(t *testing.T) {
	for _, kind := range []string{"return", "refresh"} {
		rec := httptest.NewRecorder()
		newTestHandler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/en/stripe/connect/"+kind, nil))
		if rec.Code != http.StatusOK {
			t.Fatalf("localized %s status = %d", kind, rec.Code)
		}
	}
}

func TestStripeConnectBarePathRedirects(t *testing.T) {
	rec := httptest.NewRecorder()
	newTestHandler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/stripe/connect/return", nil))
	if rec.Code != http.StatusMovedPermanently {
		t.Fatalf("bare status = %d", rec.Code)
	}
	if loc := rec.Header().Get("Location"); loc != "/en/stripe/connect/return" {
		t.Fatalf("Location = %q", loc)
	}
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `cd backend && go test ./internal/web/ -run TestStripeConnect`
Expected: FAIL.

- [ ] **Step 3: Templates + localized routes + bare-path redirect**

Add `stripe_return.gohtml` / `stripe_refresh.gohtml` (static info from `StripeConnect.return.*` / `StripeConnect.refresh.*`, contact from the catalog). Add localized routes:

> **Known limitation — `refresh` is a static page in 3b (faithful port of current
> prod).** Stripe's Account Links contract says the `refresh_url` should
> *generate a new Account Link and redirect the user back into onboarding*
> (https://docs.stripe.com/api/account_links/create). Doing that requires
> identifying the Connect account and calling `accountLinks.create`, which lives
> in the `payout-setup` integration — **ported to Go in Phase 5**. The current
> Next.js prod behaves the same (static "please restart" page), so 3b preserves
> it and records a **Phase 5 follow-up (§Task 13)**: make `refresh` regenerate the
> link via a short-lived signed `state` query param that safely identifies the
> Connect account, then 302 to the new link. The frozen path is preserved either
> way. `return` is correctly a static completion page.
```go
case len(rest) == 3 && rest[0] == "stripe" && rest[1] == "connect":
	switch rest[2] {
	case "return":
		h.render(w, http.StatusOK, "stripe_return", h.page(locale, "StripeConnect.return.title", "/stripe/connect/return"))
	case "refresh":
		h.render(w, http.StatusOK, "stripe_refresh", h.page(locale, "StripeConnect.refresh.title", "/stripe/connect/refresh"))
	default:
		h.renderNotFound(w, locale)
	}
```
In the bare-path branch (where `!isSupported(segs[0])`), add a known-bare redirect map so `stripe/connect/return` and `stripe/connect/refresh` 301 to `/`+defaultLocale+"/"+path:
```go
barePath := strings.Join(segs, "/")
if barePath == "stripe/connect/return" || barePath == "stripe/connect/refresh" {
	http.Redirect(w, r, "/"+defaultLocale+"/"+barePath, http.StatusMovedPermanently)
	return
}
```

- [ ] **Step 4: Run to verify they pass**

Run: `cd backend && go test ./internal/web/ -run TestStripeConnect`
Expected: PASS.

- [ ] **Step 5: Format, vet, commit**

```bash
cd backend && make fmt && make vet
git add backend/internal/web
git commit -m "feat(backend): Stripe Connect return/refresh landing pages (path-fixed)"
```

---

## Task 5: Redirects for removed routes (auth/callback, login, dashboard, pricing)

**Files:**
- Modify: `internal/web/web.go`
- Test: `internal/web/web_test.go`

**Interfaces:**
- Produces: `GET /{locale}/{auth/callback,login,dashboard,pricing}` → 301 `/{locale}`; locale-less equivalents → 301 `/{defaultLocale}`.

- [ ] **Step 1: Failing tests**

```go
func TestRemovedRoutesRedirect(t *testing.T) {
	cases := []struct{ path, want string }{
		{"/en/login", "/en"},
		{"/ja/dashboard", "/ja"},
		{"/en/pricing", "/en"},
		{"/ja/auth/callback", "/ja"},
		{"/login", "/en"},
		{"/pricing", "/en"},
	}
	for _, tc := range cases {
		rec := httptest.NewRecorder()
		newTestHandler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, tc.path, nil))
		if rec.Code != http.StatusMovedPermanently {
			t.Fatalf("%s status = %d", tc.path, rec.Code)
		}
		if loc := rec.Header().Get("Location"); loc != tc.want {
			t.Fatalf("%s -> %q, want %q", tc.path, loc, tc.want)
		}
	}
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `cd backend && go test ./internal/web/ -run TestRemovedRoutesRedirect`
Expected: FAIL.

- [ ] **Step 3: Implement redirects**

Add a helper and branches. Define the removed relative paths:
```go
var removedRoutes = map[string]bool{
	"login": true, "dashboard": true, "pricing": true, "auth/callback": true,
}
```
In the localized dispatch, before the 404 fallback:
```go
if removedRoutes[strings.Join(rest, "/")] {
	http.Redirect(w, r, "/"+locale, http.StatusMovedPermanently)
	return
}
```
In the bare-path branch, before its 404:
```go
if removedRoutes[strings.Join(segs, "/")] {
	http.Redirect(w, r, "/"+defaultLocale, http.StatusMovedPermanently)
	return
}
```

- [ ] **Step 4: Run to verify they pass**

Run: `cd backend && go test ./internal/web/ -run TestRemovedRoutesRedirect`
Expected: PASS.

- [ ] **Step 5: Format, vet, commit**

```bash
cd backend && make fmt && make vet
git add backend/internal/web
git commit -m "feat(backend): 301 removed web routes to localized home"
```

---

## Task 6: Self-hosted fonts + CSS (embedded, design-preserving)

**Files:**
- Create: `internal/web/assets.go`, `internal/web/static/styles.css`, `internal/web/static/fonts/*.woff2`
- Modify: `internal/web/templates/layout.gohtml` (preload + font-face via CSS), `internal/web/web.go` (mount `/static/`)
- Test: `internal/web/web_test.go`

**Interfaces:**
- Produces: `GET /static/...` serves embedded assets; `styles.css` declares `@font-face` for Inter + Noto Sans JP.

- [ ] **Step 1: Obtain the font files**

Download the current fonts as `woff2` from their OFL sources and place under `internal/web/static/fonts/`: **Inter** (the weights the webapp uses) and **Noto Sans JP** as `unicode-range` split subsets. Do not fetch at runtime. (Both are SIL OFL; committing the `woff2` is license-clean.) Record the source + version in a comment at the top of `styles.css`.

- [ ] **Step 2: Failing asset test**

```go
func TestStaticAssetsServed(t *testing.T) {
	rec := httptest.NewRecorder()
	newTestHandler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/static/styles.css", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("styles.css status = %d", rec.Code)
	}
	if ct := rec.Header().Get("Content-Type"); !strings.Contains(ct, "css") {
		t.Fatalf("styles.css content-type = %q", ct)
	}
}
```

- [ ] **Step 3: Run to verify it fails**

Run: `cd backend && go test ./internal/web/ -run TestStaticAssetsServed`
Expected: FAIL.

- [ ] **Step 4: Implement assets.go + CSS + preload, mount /static/**

Create `internal/web/assets.go`. Serve embedded assets with a **content-based
`ETag`** (sha256 of each file, computed once at startup) and
`Cache-Control: public, max-age=3600` — the design's "cache with revalidation"
option: browsers revalidate hourly with `If-None-Match` and get a cheap `304`
when unchanged. (This is chosen over content-hash filenames because `embed.FS`
has zero mtime, so `http.FileServer` alone would emit no validators; ETag gives
correct revalidation for both `styles.css` and the CSS-referenced fonts without a
build-time fingerprint pipeline.)
```go
package web

import (
	"crypto/sha256"
	"embed"
	"encoding/hex"
	"io/fs"
	"net/http"
	"strings"
)

//go:embed static
var staticFS embed.FS

type assetServer struct {
	fileServer http.Handler
	etags      map[string]string // "styles.css" -> `"<hex>"`
}

func newAssetServer() *assetServer {
	sub, err := fs.Sub(staticFS, "static")
	if err != nil {
		panic("web: static sub: " + err.Error())
	}
	etags := map[string]string{}
	_ = fs.WalkDir(sub, ".", func(p string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		b, err := fs.ReadFile(sub, p)
		if err != nil {
			return err
		}
		sum := sha256.Sum256(b)
		etags[p] = `"` + hex.EncodeToString(sum[:16]) + `"`
		return nil
	})
	return &assetServer{
		fileServer: http.StripPrefix("/static/", http.FileServer(http.FS(sub))),
		etags:      etags,
	}
}

func (a *assetServer) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	name := strings.TrimPrefix(r.URL.Path, "/static/")
	if etag, ok := a.etags[name]; ok {
		w.Header().Set("Etag", etag) // http.ServeContent honors this for If-None-Match -> 304
		w.Header().Set("Cache-Control", "public, max-age=3600")
	}
	a.fileServer.ServeHTTP(w, r)
}
```
In `web.go` `ServeHTTP`, before locale dispatch:
```go
if strings.HasPrefix(p, "/static/") {
	h.static.ServeHTTP(w, r)
	return
}
```
Add `static http.Handler` to `Handler`, set in `NewHandler` via `newAssetServer()`. Write `styles.css` with `@font-face` (`font-display: swap`, `src: url(/static/fonts/...woff2) format('woff2')` with `unicode-range` for the Noto subsets) that reproduces the current design; add `<link rel="preload" as="font" type="font/woff2" crossorigin href="/static/fonts/...woff2">` for the primary weight(s) into `layout.gohtml`'s `<head>`.

- [ ] **Step 5: Run to verify it passes (incl. caching headers + 304)**

Extend `TestStaticAssetsServed` to assert `Cache-Control` contains `max-age=3600`
and an `Etag` is present, and add a case: a second request with
`If-None-Match: <that etag>` returns `304 Not Modified`. Run:
`cd backend && go test ./internal/web/ -run TestStaticAssets`
Expected: PASS.

- [ ] **Step 6: Visual fidelity check (manual, one-time) — the design-parity baseline**

Run the stack locally (`make up`) and run the current webapp side by side. Compare
each kept page across the full matrix — **{home, privacy, terms, refund, tokushoho,
stripe return, stripe refresh, account/delete} × {en, ja} × {mobile viewport,
desktop viewport}** — against the current design. Check: hero/feature/CTA layout
and copy on home, header/footer chrome (nav, EN/JP switcher, contact, copyright),
typography (Inter / Noto Sans JP with no layout shift or fallback flash), spacing,
and responsive breakpoints. Adjust the templates + `styles.css` until each cell
matches. This is the concrete evidence for the design-doc "preserve the current
design" Done criterion.

- [ ] **Step 7: Format, vet, commit**

```bash
cd backend && make fmt && make vet
git add backend/internal/web
git commit -m "feat(backend): self-host Inter + Noto Sans JP fonts and site CSS"
```

---

## Task 7: Identity email capture (schema + provisioning + lookup)

**Files:**
- Modify: `backend/schema/identity/02_user_identities.sql`
- Modify: `backend/internal/identity/store.go`, `service.go`, `handler.go`
- Modify: `backend/db/tests/test_identity_constraints.sql`
- Create: a migration under `backend/migrations/`
- Test: `backend/internal/identity/*_test.go`

**Interfaces:**
- Produces:
  - `identity.Store.CreateWithIdentity(ctx, issuer, subject, email string, emailVerified bool) (User, error)`
  - `identity.Store.TouchIdentityEmail(ctx, issuer, subject, email string, emailVerified bool) error`
  - `identity.Store.FindUserByEmail(ctx, email string) (User, error)` (returns `identity.ErrNotFound` when no match)
  - `identity.Service.ResolveOrProvision(ctx, issuer, subject, email string, emailVerified bool) (User, error)`
- Consumes: existing `identity` package, `auth.Identity{Email, EmailVerified}`.

- [ ] **Step 1: Add the schema columns + index**

Edit `backend/schema/identity/02_user_identities.sql` to add columns and a case-insensitive lookup index (keep the Go-maintained `updated_at` comment convention):
```sql
    email          text,
    email_verified boolean NOT NULL DEFAULT false,
```
and after the table:
```sql
CREATE INDEX user_identities_email_lower_idx
    ON public.user_identities (lower(email));
```

- [ ] **Step 2: Generate the migration**

Run: `cd backend && atlas migrate diff add_user_identities_email --env local`
Review the generated SQL under `backend/migrations/` (should `ALTER TABLE ... ADD COLUMN` + `CREATE INDEX`). Ensure `atlas.sum` is updated.

- [ ] **Step 3: Write failing Go tests**

Add to `backend/internal/identity/store_test.go` (integration, uses `testsupport.DB`):
```go
func TestFindUserByEmail(t *testing.T) {
	db := testsupport.DB(t)
	_, _ = db.Exec("TRUNCATE public.users CASCADE")
	s := NewStore(db)
	ctx := context.Background()
	u, err := s.CreateWithIdentity(ctx, "firebase", "sub-1", "User@Example.com", true)
	if err != nil {
		t.Fatal(err)
	}
	got, err := s.FindUserByEmail(ctx, "user@example.com") // case-insensitive, verified
	if err != nil {
		t.Fatalf("FindUserByEmail: %v", err)
	}
	if got.ID != u.ID {
		t.Fatalf("got %s want %s", got.ID, u.ID)
	}
	if _, err := s.FindUserByEmail(ctx, "nobody@example.com"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("want ErrNotFound, got %v", err)
	}

	// UNVERIFIED email must NOT match.
	if _, err := s.CreateWithIdentity(ctx, "firebase", "sub-2", "unverified@example.com", false); err != nil {
		t.Fatal(err)
	}
	if _, err := s.FindUserByEmail(ctx, "unverified@example.com"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("unverified email should not match, got %v", err)
	}

	// A second VERIFIED identity for the SAME user still resolves to that user.
	if _, err := db.Exec(`INSERT INTO public.user_identities (user_id, issuer, subject, email, email_verified)
		VALUES ($1, 'apple', 'sub-3', 'User@Example.com', true)`, u.ID); err != nil {
		t.Fatal(err)
	}
	if got, err := s.FindUserByEmail(ctx, "user@example.com"); err != nil || got.ID != u.ID {
		t.Fatalf("same-user duplicate should resolve: id=%s err=%v", got.ID, err)
	}

	// Two DIFFERENT verified users with the same email -> ambiguous -> ErrNotFound.
	if _, err := s.CreateWithIdentity(ctx, "firebase", "sub-4", "shared@example.com", true); err != nil {
		t.Fatal(err)
	}
	if _, err := s.CreateWithIdentity(ctx, "firebase", "sub-5", "shared@example.com", true); err != nil {
		t.Fatal(err)
	}
	if _, err := s.FindUserByEmail(ctx, "shared@example.com"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("ambiguous email should refuse (ErrNotFound), got %v", err)
	}
}
```

- [ ] **Step 4: Run to verify it fails**

Run: `cd backend && make test` (or `go test ./internal/identity/ -run TestFindUserByEmail` against a migrated test DB)
Expected: FAIL (compile error / method missing).

- [ ] **Step 5: Implement store methods + service/handler plumbing**

In `store.go`: extend `CreateWithIdentity` to insert `email, email_verified`; add:
```go
// FindUserByEmail resolves a claimed email to the internal user, but ONLY via a
// VERIFIED email, and ONLY when unambiguous. It scans up to two DISTINCT users:
// none -> ErrNotFound; exactly one -> that user; more than one (the same verified
// email mapped to different accounts — which identity linking should prevent, but
// is not DB-enforced because one user may legitimately hold two identities with
// the same verified email) -> ErrNotFound (fail safe: never resolve to an
// arbitrary user). Stale addresses are avoided because TouchIdentityEmail
// refreshes the stored email on every login.
func (s *Store) FindUserByEmail(ctx context.Context, email string) (User, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT DISTINCT u.id, u.status, u.created_at, u.updated_at
		FROM public.users u
		JOIN public.user_identities i ON i.user_id = u.id
		WHERE lower(i.email) = lower($1) AND i.email_verified
		LIMIT 2`, email)
	if err != nil {
		return User{}, fmt.Errorf("find user by email: %w", err)
	}
	defer rows.Close()

	var users []User
	for rows.Next() {
		var u User
		if err := rows.Scan(&u.ID, &u.Status, &u.CreatedAt, &u.UpdatedAt); err != nil {
			return User{}, fmt.Errorf("scan user by email: %w", err)
		}
		users = append(users, u)
	}
	if err := rows.Err(); err != nil {
		return User{}, fmt.Errorf("find user by email rows: %w", err)
	}
	if len(users) != 1 { // 0 = no match; >1 = ambiguous -> refuse
		return User{}, ErrNotFound
	}
	return users[0], nil
}

// TouchIdentityEmail refreshes the stored email only when it changed
// (updated_at is Go-maintained).
func (s *Store) TouchIdentityEmail(ctx context.Context, issuer, subject, email string, emailVerified bool) error {
	_, err := s.db.ExecContext(ctx, `
		UPDATE public.user_identities
		SET email = $3, email_verified = $4, updated_at = now()
		WHERE issuer = $1 AND subject = $2
		  AND (email IS DISTINCT FROM $3 OR email_verified IS DISTINCT FROM $4)`,
		issuer, subject, email, emailVerified)
	if err != nil {
		return fmt.Errorf("touch identity email: %w", err)
	}
	return nil
}
```
In `service.go`: update the private `store` interface to match the new signatures, add `TouchIdentityEmail`, and thread email through `ResolveOrProvision` (refresh on found, store on create):
```go
func (s *Service) ResolveOrProvision(ctx context.Context, issuer, subject, email string, emailVerified bool) (User, error) {
	u, err := s.store.FindByIdentity(ctx, issuer, subject)
	if err == nil {
		_ = s.store.TouchIdentityEmail(ctx, issuer, subject, email, emailVerified) // best-effort refresh
		return u, nil
	}
	if !errors.Is(err, ErrNotFound) {
		return User{}, err
	}
	u, err = s.store.CreateWithIdentity(ctx, issuer, subject, email, emailVerified)
	if err == nil {
		return u, nil
	}
	if !errors.Is(err, ErrNotFound) {
		return User{}, err
	}
	u, err = s.store.FindByIdentity(ctx, issuer, subject)
	if err != nil {
		return User{}, fmt.Errorf("resolve after create race: %w", err)
	}
	_ = s.store.TouchIdentityEmail(ctx, issuer, subject, email, emailVerified)
	return u, nil
}
```
In `handler.go` `Me`: pass `id.Email, id.EmailVerified` to `ResolveOrProvision`.

- [ ] **Step 6: Update the assert-SQL DB test**

Add to `backend/db/tests/test_identity_constraints.sql` an assertion that `email`/`email_verified` columns exist and the `lower(email)` index is present (mirror the existing assertion style).

- [ ] **Step 7: Run all identity tests + DB test**

Run: `cd backend && make test`
Also run the assert-SQL test: `psql "$TEST_DSN" -v ON_ERROR_STOP=1 -f db/tests/test_identity_constraints.sql`
Expected: PASS.

- [ ] **Step 8: Format, vet, commit**

```bash
cd backend && make fmt && make vet
git add backend/schema/identity backend/migrations backend/internal/identity backend/db/tests/test_identity_constraints.sql
git commit -m "feat(backend): persist and look up provider email on user_identities"
```

---

## Task 8: account_deletion_requests schema

**Files:**
- Create: `backend/schema/web/01_account_deletion_requests.sql`
- Create: `backend/db/tests/test_account_deletion_requests.sql`
- Modify: `backend/atlas.hcl`
- Create: a migration under `backend/migrations/`

**Interfaces:**
- Produces: table `public.account_deletion_requests` with `user_id` UNIQUE + FK CASCADE, for Task 9's upsert.

- [ ] **Step 1: Write the schema file**

Create `backend/schema/web/01_account_deletion_requests.sql`:
```sql
-- Unverified account-deletion requests captured by the public (unauthenticated)
-- web resource. A row exists only when the claimed email matched a real account.
-- Phase 6 consumes these: email round-trip verification then the deletion saga.
-- updated_at is Go-maintained (updated_at = now() on UPDATE), not a DB trigger.
CREATE TABLE public.account_deletion_requests (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       uuid NOT NULL UNIQUE REFERENCES public.users (id) ON DELETE CASCADE,
    claimed_email text NOT NULL,
    status        text NOT NULL DEFAULT 'unverified',
    source        text NOT NULL DEFAULT 'web',
    requested_at  timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);
```

- [ ] **Step 2: Register the schema dir in atlas.hcl**

Edit `backend/atlas.hcl` `env "local"` `src` to append `"file://schema/web"`.

- [ ] **Step 3: Generate the migration**

Run: `cd backend && atlas migrate diff add_account_deletion_requests --env local`
Review the generated SQL (creates the table); confirm `atlas.sum` updated.

- [ ] **Step 4: Write the assert-SQL DB test**

Create `backend/db/tests/test_account_deletion_requests.sql` (mirror `test_identity_constraints.sql` structure): in a `BEGIN … ROLLBACK` block, insert a `users` row, insert an `account_deletion_requests` row, `ASSERT` a second plain insert with the same `user_id` raises `unique_violation`, `ASSERT` deleting the user cascades (the request row disappears), and — for the status guard — set the row's `status = 'verified'`, run the guarded upsert SQL (the `INSERT … ON CONFLICT (user_id) DO UPDATE … WHERE status = 'unverified'` from Task 9) with a different `claimed_email`, and `ASSERT` the row's `status` is still `'verified'` and `claimed_email` is unchanged.

- [ ] **Step 5: Run the DB test + drift check**

Run:
```bash
cd backend && atlas migrate apply --env local   # against the test DB
psql "$TEST_DSN" -v ON_ERROR_STOP=1 -f db/tests/test_account_deletion_requests.sql
atlas migrate diff ci_drift_check --env local   # expect: "no changes"
```
Expected: DB test PASS; drift check reports no changes.

- [ ] **Step 6: Commit**

```bash
git add backend/schema/web backend/atlas.hcl backend/migrations backend/db/tests/test_account_deletion_requests.sql
git commit -m "feat(backend): account_deletion_requests table (web schema)"
```

---

## Task 9: accountdeletion domain + store + service

**Files:**
- Create: `internal/accountdeletion/domain.go`, `store.go`, `service.go`
- Test: `internal/accountdeletion/store_test.go`, `service_test.go`

**Interfaces:**
- Consumes: Task 7 (`identity.User`, `identity.ErrNotFound`, `identity.Store.FindUserByEmail`); Task 8 (the table).
- Produces:
  - `accountdeletion.NewStore(db *sql.DB) *Store`; `Store.Upsert(ctx, userID, claimedEmail string) error`
  - `accountdeletion.NewService(users userLookup, store requestStore) *Service`; `Service.RequestDeletion(ctx, claimedEmail string) error` (nil on no-match; non-nil only on infrastructure error).

- [ ] **Step 1: Domain + store + failing store test**

Create `internal/accountdeletion/domain.go`:
```go
// Package accountdeletion captures unauthenticated web account-deletion
// requests. It resolves a claimed email to a real user and records an
// unverified request. Verification and the deletion saga are Phase 6.
package accountdeletion

import "time"

type DeletionRequest struct {
	ID           string
	UserID       string
	ClaimedEmail string
	Status       string
	Source       string
	RequestedAt  time.Time
	UpdatedAt    time.Time
}
```
Create `internal/accountdeletion/store.go`:
```go
package accountdeletion

import (
	"context"
	"database/sql"
	"fmt"
)

type Store struct{ db *sql.DB }

func NewStore(db *sql.DB) *Store { return &Store{db: db} }

// Upsert records (or refreshes) a single web deletion request per user. It only
// ever creates or refreshes an 'unverified' row: the ON CONFLICT ... WHERE guard
// leaves a row that Phase 6 already advanced to 'verified' or 'processed'
// UNTOUCHED, so a third party who merely knows the email cannot revert a
// confirmed/executed request back to 'unverified'. State machine:
// unverified -> verified -> processed (only Phase 6 advances it); the public
// form only ever writes 'unverified'. updated_at is Go-maintained.
func (s *Store) Upsert(ctx context.Context, userID, claimedEmail string) error {
	_, err := s.db.ExecContext(ctx, `
		INSERT INTO public.account_deletion_requests (user_id, claimed_email, status, source)
		VALUES ($1, $2, 'unverified', 'web')
		ON CONFLICT (user_id) DO UPDATE
		SET claimed_email = EXCLUDED.claimed_email,
		    requested_at  = now(),
		    updated_at    = now()
		WHERE public.account_deletion_requests.status = 'unverified'`,
		userID, claimedEmail)
	if err != nil {
		return fmt.Errorf("upsert deletion request: %w", err)
	}
	return nil
}
```
Create `internal/accountdeletion/store_test.go` — integration test asserting:
(a) a first `Upsert` inserts one row; (b) a second `Upsert` for the same `userID`
keeps a single row with the refreshed `claimed_email` (query `count(*)` +
`claimed_email`); **(c) after manually setting a row's `status = 'verified'`, a
further `Upsert` does NOT change its `status`, `claimed_email`, or `requested_at`
(the confirmed request is not reverted).**

- [ ] **Step 2: Run to verify it fails**

Run: `cd backend && go test ./internal/accountdeletion/`
Expected: FAIL (package/methods missing until implemented — implement store as above, then the test compiles).

- [ ] **Step 3: Service + failing unit test**

Create `internal/accountdeletion/service.go`:
```go
package accountdeletion

import (
	"context"
	"errors"
	"strings"

	"github.com/cloveclovedev/peppercheck/backend/internal/identity"
)

// userLookup resolves a claimed email to a user (identity.Store satisfies it).
type userLookup interface {
	FindUserByEmail(ctx context.Context, email string) (identity.User, error)
}

type requestStore interface {
	Upsert(ctx context.Context, userID, claimedEmail string) error
}

type Service struct {
	users userLookup
	store requestStore
}

func NewService(users userLookup, store requestStore) *Service {
	return &Service{users: users, store: store}
}

// RequestDeletion records an unverified deletion request IFF the claimed email
// matches a real account. No match (or an empty/invalid email) is a silent
// no-op — the caller always returns the same uniform response. A non-nil error
// means an infrastructure failure only.
func (s *Service) RequestDeletion(ctx context.Context, claimedEmail string) error {
	email := strings.TrimSpace(strings.ToLower(claimedEmail))
	if email == "" || !strings.Contains(email, "@") {
		return nil
	}
	u, err := s.users.FindUserByEmail(ctx, email)
	if errors.Is(err, identity.ErrNotFound) {
		return nil
	}
	if err != nil {
		return err
	}
	return s.store.Upsert(ctx, u.ID, email)
}
```
Create `internal/accountdeletion/service_test.go` with fakes for `userLookup` and `requestStore`:
```go
package accountdeletion

import (
	"context"
	"errors"
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/identity"
)

type fakeUsers struct {
	user identity.User
	err  error
}

func (f fakeUsers) FindUserByEmail(context.Context, string) (identity.User, error) {
	return f.user, f.err
}

type fakeStore struct{ upserts int }

func (f *fakeStore) Upsert(context.Context, string, string) error { f.upserts++; return nil }

func TestRequestDeletion(t *testing.T) {
	ctx := context.Background()

	// match -> upsert
	fs := &fakeStore{}
	svc := NewService(fakeUsers{user: identity.User{ID: "u1"}}, fs)
	if err := svc.RequestDeletion(ctx, "a@b.com"); err != nil || fs.upserts != 1 {
		t.Fatalf("match: err=%v upserts=%d", err, fs.upserts)
	}

	// no match -> no upsert, no error (uniform)
	fs = &fakeStore{}
	svc = NewService(fakeUsers{err: identity.ErrNotFound}, fs)
	if err := svc.RequestDeletion(ctx, "a@b.com"); err != nil || fs.upserts != 0 {
		t.Fatalf("no-match: err=%v upserts=%d", err, fs.upserts)
	}

	// invalid email -> no lookup, no error
	fs = &fakeStore{}
	svc = NewService(fakeUsers{err: errors.New("should not be called")}, fs)
	if err := svc.RequestDeletion(ctx, "not-an-email"); err != nil || fs.upserts != 0 {
		t.Fatalf("invalid: err=%v upserts=%d", err, fs.upserts)
	}
}
```

- [ ] **Step 4: Run to verify pass**

Run: `cd backend && go test ./internal/accountdeletion/`
Expected: PASS.

- [ ] **Step 5: Format, vet, commit**

```bash
cd backend && make fmt && make vet
git add backend/internal/accountdeletion
git commit -m "feat(backend): accountdeletion domain/store/service (match email, upsert request)"
```

---

## Task 10: HMAC form token

**Files:**
- Create: `internal/web/formtoken.go`, `internal/web/formtoken_test.go`
- Modify: `internal/core/config/config.go`

**Interfaces:**
- Produces:
  - `web.NewFormToken(key []byte) *FormToken`
  - `FormToken.Issue(now time.Time) string`
  - `FormToken.Verify(token string, now time.Time) error` (rejects bad signature, expired > maxAge, or submitted faster than minElapsed)
  - `config.Config.WebFormSigningKey string`

- [ ] **Step 1: Failing test**

Create `internal/web/formtoken_test.go`:
```go
package web

import (
	"testing"
	"time"
)

func TestFormTokenRoundTrip(t *testing.T) {
	ft := NewFormToken([]byte("test-key"))
	now := time.Unix(1_800_000_000, 0)
	tok := ft.Issue(now)

	// submitted after a human-plausible delay -> OK
	if err := ft.Verify(tok, now.Add(5*time.Second)); err != nil {
		t.Fatalf("valid token rejected: %v", err)
	}
	// too fast -> rejected
	if err := ft.Verify(tok, now.Add(200*time.Millisecond)); err == nil {
		t.Fatal("expected too-fast rejection")
	}
	// expired -> rejected
	if err := ft.Verify(tok, now.Add(2*time.Hour)); err == nil {
		t.Fatal("expected expiry rejection")
	}
	// tampered -> rejected
	if err := ft.Verify(tok+"x", now.Add(5*time.Second)); err == nil {
		t.Fatal("expected signature rejection")
	}
	// wrong key -> rejected
	if err := NewFormToken([]byte("other")).Verify(tok, now.Add(5*time.Second)); err == nil {
		t.Fatal("expected wrong-key rejection")
	}
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd backend && go test ./internal/web/ -run TestFormTokenRoundTrip`
Expected: FAIL.

- [ ] **Step 3: Implement formtoken.go**

```go
package web

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"
)

const (
	formTokenMinElapsed = 1 * time.Second
	formTokenMaxAge     = 30 * time.Minute
)

var errBadFormToken = errors.New("invalid form token")

// FormToken signs {issuedAtUnix, nonce} so a POST proves it came from a
// server-rendered form within a plausible time window. Stateless.
type FormToken struct{ key []byte }

func NewFormToken(key []byte) *FormToken { return &FormToken{key: key} }

func (ft *FormToken) Issue(now time.Time) string {
	nonce := make([]byte, 8)
	_, _ = rand.Read(nonce)
	payload := strconv.FormatInt(now.Unix(), 10) + "." + base64.RawURLEncoding.EncodeToString(nonce)
	return payload + "." + ft.sign(payload)
}

func (ft *FormToken) Verify(token string, now time.Time) error {
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return errBadFormToken
	}
	payload := parts[0] + "." + parts[1]
	if !hmac.Equal([]byte(ft.sign(payload)), []byte(parts[2])) {
		return errBadFormToken
	}
	issued, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil {
		return errBadFormToken
	}
	age := now.Sub(time.Unix(issued, 0))
	if age < formTokenMinElapsed {
		return fmt.Errorf("%w: too fast", errBadFormToken)
	}
	if age > formTokenMaxAge {
		return fmt.Errorf("%w: expired", errBadFormToken)
	}
	return nil
}

func (ft *FormToken) sign(payload string) string {
	m := hmac.New(sha256.New, ft.key)
	m.Write([]byte(payload))
	return base64.RawURLEncoding.EncodeToString(m.Sum(nil))
}
```
In `internal/core/config/config.go`: add `WebFormSigningKey string` to `Config` and load it in `Load()` **fail-closed** (empty key is a configuration error — an empty HMAC key would let anyone forge form tokens):
```go
webKey, _, err := lookupEnvOrFile("WEB_FORM_SIGNING_KEY")
if err != nil {
	return Config{}, err
}
if webKey == "" {
	return Config{}, errors.New("config: WEB_FORM_SIGNING_KEY (or _FILE) is required")
}
cfg.WebFormSigningKey = webKey
```
(Match the exact `lookupEnvOrFile` return signature used for `DATABASE_URL`; add the `errors` import if absent.)

- [ ] **Step 3b: Config fail-closed test**

Add a config test asserting `Load()` returns an error when `WEB_FORM_SIGNING_KEY` and `WEB_FORM_SIGNING_KEY_FILE` are both unset/empty (set the other required env vars so only this one is missing). Run: `cd backend && go test ./internal/core/config/`
Expected: PASS (the error is returned).

- [ ] **Step 4: Run to verify pass**

Run: `cd backend && go test ./internal/web/ -run TestFormTokenRoundTrip && go test ./internal/core/config/`
Expected: PASS.

- [ ] **Step 5: Format, vet, commit**

```bash
cd backend && make fmt && make vet
git add backend/internal/web/formtoken.go backend/internal/web/formtoken_test.go backend/internal/core/config/config.go
git commit -m "feat(backend): HMAC form token + web form signing key config"
```

> **Operator note (record in follow-ups, Task 13):** `WEB_FORM_SIGNING_KEY` is a
> new secret. It must be added to the Phase 7a secret delivery (BWS → Docker
> file-based secret rendered at deploy, consumed via `WEB_FORM_SIGNING_KEY_FILE`),
> scoped to the `api` service. This is a 3b-side addition, not a change to 7a's docs.

---

## Task 11: Per-IP rate-limit middleware

**Files:**
- Create: `internal/web/ratelimit.go`, `internal/web/ratelimit_test.go`

**Interfaces:**
- Produces:
  - `web.NewRateLimiter(limit int, window time.Duration) *RateLimiter`
  - `RateLimiter.Allow(key string, now time.Time) bool`
  - `web.clientIP(r *http.Request) string`

- [ ] **Step 1: Failing test**

Create `internal/web/ratelimit_test.go`:
```go
package web

import (
	"net/http/httptest"
	"testing"
	"time"
)

func TestRateLimiterAllow(t *testing.T) {
	rl := NewRateLimiter(2, time.Minute)
	now := time.Unix(1_800_000_000, 0)
	if !rl.Allow("ip1", now) || !rl.Allow("ip1", now) {
		t.Fatal("first two should be allowed")
	}
	if rl.Allow("ip1", now) {
		t.Fatal("third within window should be blocked")
	}
	if !rl.Allow("ip2", now) {
		t.Fatal("a different key is independent")
	}
	if !rl.Allow("ip1", now.Add(time.Minute+time.Second)) {
		t.Fatal("window should have reset")
	}
}

func TestClientIPPrefersForwardedFor(t *testing.T) {
	r := httptest.NewRequest("GET", "/", nil)
	r.RemoteAddr = "10.0.0.1:5555"
	r.Header.Set("X-Forwarded-For", "203.0.113.9, 10.0.0.1")
	if got := clientIP(r); got != "203.0.113.9" {
		t.Fatalf("clientIP = %q", got)
	}
}

func TestRateLimiterCleanupEvictsExpired(t *testing.T) {
	rl := NewRateLimiter(2, time.Minute)
	now := time.Unix(1_800_000_000, 0)
	rl.Allow("ip1", now)
	rl.Allow("ip2", now)
	if rl.Len() != 2 {
		t.Fatalf("expected 2 tracked keys, got %d", rl.Len())
	}
	rl.Cleanup(now.Add(2 * time.Minute)) // both windows expired
	if rl.Len() != 0 {
		t.Fatalf("expected cleanup to evict expired keys, got %d", rl.Len())
	}
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd backend && go test ./internal/web/ -run 'TestRateLimiter|TestClientIP'`
Expected: FAIL.

- [ ] **Step 3: Implement ratelimit.go**

```go
package web

import (
	"net"
	"net/http"
	"strings"
	"sync"
	"time"
)

// maxRateLimiterKeys hard-bounds the in-memory map so a public endpoint can't be
// turned into a memory-exhaustion vector (e.g. many distinct/spoofed client IPs).
const maxRateLimiterKeys = 10000

// RateLimiter is a bounded in-memory fixed-window limiter keyed by client IP.
// Memory is bounded two ways: Cleanup (called on a background ticker) evicts
// expired windows, and Allow refuses NEW keys once the map is full (after an
// inline prune), so the map never grows past maxRateLimiterKeys.
type RateLimiter struct {
	limit   int
	window  time.Duration
	maxKeys int
	mu      sync.Mutex
	counts  map[string]*window
}

type window struct {
	start time.Time
	n     int
}

func NewRateLimiter(limit int, w time.Duration) *RateLimiter {
	return &RateLimiter{limit: limit, window: w, maxKeys: maxRateLimiterKeys, counts: map[string]*window{}}
}

func (rl *RateLimiter) Allow(key string, now time.Time) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()
	if w := rl.counts[key]; w != nil {
		if now.Sub(w.start) >= rl.window {
			rl.counts[key] = &window{start: now, n: 1}
			return true
		}
		if w.n >= rl.limit {
			return false
		}
		w.n++
		return true
	}
	// New key: enforce the hard cap (prune first; if still full, refuse).
	if len(rl.counts) >= rl.maxKeys {
		rl.pruneLocked(now)
		if len(rl.counts) >= rl.maxKeys {
			return false
		}
	}
	rl.counts[key] = &window{start: now, n: 1}
	return true
}

// Cleanup evicts expired windows. Call it periodically from a background ticker
// (wired in main) so idle keys don't accumulate.
func (rl *RateLimiter) Cleanup(now time.Time) {
	rl.mu.Lock()
	defer rl.mu.Unlock()
	rl.pruneLocked(now)
}

func (rl *RateLimiter) pruneLocked(now time.Time) {
	for k, w := range rl.counts {
		if now.Sub(w.start) >= rl.window {
			delete(rl.counts, k)
		}
	}
}

// Len reports the number of tracked keys (for tests/observability).
func (rl *RateLimiter) Len() int {
	rl.mu.Lock()
	defer rl.mu.Unlock()
	return len(rl.counts)
}

// clientIP returns the leftmost X-Forwarded-For entry (the original client as
// seen by Caddy), falling back to RemoteAddr. NOTE: X-Forwarded-For is
// client-spoofable; this bounds casual abuse, not a determined attacker —
// escalate to Cloudflare Turnstile if real spam gets through (see follow-ups).
func clientIP(r *http.Request) string {
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		return strings.TrimSpace(strings.Split(xff, ",")[0])
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}
```

- [ ] **Step 4: Run to verify pass**

Run: `cd backend && go test ./internal/web/ -run 'TestRateLimiter|TestClientIP'`
Expected: PASS.

- [ ] **Step 5: Format, vet, commit**

```bash
cd backend && make fmt && make vet
git add backend/internal/web/ratelimit.go backend/internal/web/ratelimit_test.go
git commit -m "feat(backend): per-IP rate-limit middleware for the web"
```

---

## Task 12: Account-deletion web handler (GET form + POST) and wiring

**Files:**
- Create: `internal/web/templates/account_delete.gohtml`
- Modify: `internal/web/web.go` (Deps + routes + POST handler), `internal/web/messages/{en,ja}.json` (`AccountDelete` namespace)
- Modify: `cmd/peppercheck/main.go` (wire accountdeletion service + form token + rate limiter into web)
- Test: `internal/web/web_test.go`

**Interfaces:**
- Consumes: `accountdeletion.Service.RequestDeletion` (Task 9), `FormToken` (Task 10), `RateLimiter`/`clientIP` (Task 11), `config.WebFormSigningKey`.
- Produces: `GET /{locale}/account/delete` (form) and `POST /{locale}/account/delete` (PRG → `?submitted=1`, uniform response).

- [ ] **Step 1: Extend web.Deps + a deleter interface**

In `web.go`, add to `Deps`:
```go
type deletionRequester interface {
	RequestDeletion(ctx context.Context, claimedEmail string) error
}

type Deps struct {
	Logger    *slog.Logger
	Deletion  deletionRequester
	FormToken *FormToken
	RateLim   *RateLimiter
}
```
Store them on `Handler`. Guard: if `Deletion`/`FormToken`/`RateLim` are nil (e.g. skeleton tests), the delete route renders a static instructions page without the form.

- [ ] **Step 2: Failing tests (form render + POST behaviors)**

Add to `internal/web/web_test.go` a helper building a handler with a fake deleter, a real `FormToken`, and a real `RateLimiter`, then:
```go
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
}

func TestAccountDeletePostUniformAndCallsService(t *testing.T) {
	rd := &recordingDeleter{}
	h := newDeletionHandler(rd)
	// obtain a valid token by rendering the form first, or mint one via the handler's FormToken
	tok := h.formToken.Issue(time.Now().Add(-2 * time.Second))
	form := "email=a%40b.com&form_token=" + tok + "&consent=on&website="
	req := httptest.NewRequest(http.MethodPost, "/en/account/delete", strings.NewReader(form))
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusSeeOther {
		t.Fatalf("status = %d", rec.Code)
	}
	if rd.calls != 1 || rd.lastEmail != "a@b.com" {
		t.Fatalf("service calls=%d email=%q", rd.calls, rd.lastEmail)
	}
}

func TestAccountDeletePostHoneypotSilentlyDropped(t *testing.T) {
	rd := &recordingDeleter{}
	h := newDeletionHandler(rd)
	tok := h.formToken.Issue(time.Now().Add(-2 * time.Second))
	form := "email=a%40b.com&form_token=" + tok + "&consent=on&website=iamabot"
	req := httptest.NewRequest(http.MethodPost, "/en/account/delete", strings.NewReader(form))
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
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
	form := "email=a%40b.com&form_token=" + tok + "&website=" // no consent
	req := httptest.NewRequest(http.MethodPost, "/en/account/delete", strings.NewReader(form))
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusSeeOther {
		t.Fatalf("status = %d", rec.Code)
	}
	if rd.calls != 0 {
		t.Fatalf("missing consent must not record, calls=%d", rd.calls)
	}
}

func TestAccountDeletePostInfraErrorReturns503(t *testing.T) {
	rd := &recordingDeleter{err: errors.New("db down")}
	h := newDeletionHandler(rd)
	tok := h.formToken.Issue(time.Now().Add(-2 * time.Second))
	form := "email=a%40b.com&form_token=" + tok + "&consent=on&website="
	req := httptest.NewRequest(http.MethodPost, "/en/account/delete", strings.NewReader(form))
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("infra error must return 503 (not a 303 'submitted'), got %d", rec.Code)
	}
}
```
(Write `recordingDeleter` with `calls int; lastEmail string; err error`; its
`RequestDeletion` records the call and returns `f.err`. `newDeletionHandler`
builds `NewHandler(Deps{...})` with a fixed **non-empty** `FormToken` key and a
`RateLimiter` generous enough not to trip.)

- [ ] **Step 3: Run to verify they fail**

Run: `cd backend && go test ./internal/web/ -run TestAccountDelete`
Expected: FAIL.

- [ ] **Step 4: Template + GET/POST handling**

Create `account_delete.gohtml`: instructions (in-app deletion is the reliable path), then, when `.ShowForm`, a `<form method="post">` with `email` (required), a consent checkbox `consent`, a hidden `form_token` = `.FormToken`, and a visually-hidden honeypot `website` field; when `.Submitted`, render the uniform confirmation (`AccountDelete.submitted`).
In `web.go` dispatch, add:
```go
case len(rest) == 2 && rest[0] == "account" && rest[1] == "delete":
	h.accountDelete(w, r, locale)
```
Implement `accountDelete`:
```go
func (h *Handler) accountDelete(w http.ResponseWriter, r *http.Request, locale string) {
	switch r.Method {
	case http.MethodGet:
		data := h.deletePage(locale, r.URL.Query().Get("submitted") == "1")
		h.render(w, http.StatusOK, "account_delete", data)
	case http.MethodPost:
		h.handleDeletePost(w, r, locale)
	default:
		w.Header().Set("Allow", "GET, POST")
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}

// maxDeletionFormBytes bounds the public POST body — this form is tiny.
const maxDeletionFormBytes = 4 << 10 // 4 KiB

func (h *Handler) handleDeletePost(w http.ResponseWriter, r *http.Request, locale string) {
	redirect := "/" + locale + "/account/delete?submitted=1" // uniform response
	// Rate limit first.
	if h.rateLim != nil && !h.rateLim.Allow(clientIP(r), time.Now()) {
		http.Error(w, "too many requests", http.StatusTooManyRequests)
		return
	}
	// Bound the body BEFORE parsing (defends the public, unauthenticated form).
	r.Body = http.MaxBytesReader(w, r.Body, maxDeletionFormBytes)
	if err := r.ParseForm(); err != nil {
		http.Redirect(w, r, redirect, http.StatusSeeOther)
		return
	}
	// Honeypot: any value means bot -> silently accept, do nothing.
	if r.PostForm.Get("website") != "" {
		http.Redirect(w, r, redirect, http.StatusSeeOther)
		return
	}
	// Consent is mandatory: without the checkbox, record nothing.
	if r.PostForm.Get("consent") != "on" {
		http.Redirect(w, r, redirect, http.StatusSeeOther)
		return
	}
	// Form token: invalid/expired/too-fast -> silently accept, do nothing.
	if h.formToken == nil || h.formToken.Verify(r.PostForm.Get("form_token"), time.Now()) != nil {
		http.Redirect(w, r, redirect, http.StatusSeeOther)
		return
	}
	email := r.PostForm.Get("email")
	if err := h.deletion.RequestDeletion(r.Context(), email); err != nil {
		// Infrastructure failure (e.g. DB down): the request was NOT saved, so we
		// must NOT tell the user it was received. Return a generic 503 retry page.
		// This is independent of whether an account matched (RequestDeletion
		// returns nil for both match and no-match), so it leaks no account
		// existence. The error is logged for monitoring/alerting (no PII).
		h.logger.Error("web_deletion_request_failed", slog.Any("error", err))
		h.renderError(w, locale, http.StatusServiceUnavailable)
		return
	}
	http.Redirect(w, r, redirect, http.StatusSeeOther)
}

// renderError renders the shared error page (used for 503 on infra failure). It
// carries a "please try again later" message; monitoring alerts fire off the
// logged web_deletion_request_failed / 5xx rate, not this page.
func (h *Handler) renderError(w http.ResponseWriter, locale string, status int) {
	h.render(w, status, "error", h.page(locale, "Error.title", ""))
}
```
Create `internal/web/templates/error.gohtml` rendering `Error.title` + `Error.retry`
(a generic "something went wrong, please try again later" message; add the
`Error` namespace to both catalogs). Add `deletePage(locale, submitted)` building
`pageData` with `ShowForm`, `Submitted`, and `FormToken` (from
`h.formToken.Issue(time.Now())`). (`pageData` already carries these fields — see
Task 1's `render.go`.)

> **Observability:** the 503 path logs `web_deletion_request_failed`; the
> deployment's existing 5xx-rate / error-log alerting (per the observability
> policy) covers it. No new dashboard is required for 3b, but the follow-ups doc
> notes that a spike here means the deletion request queue is not being written.

- [ ] **Step 5: Wire into main**

In `cmd/peppercheck/main.go`, construct and inject, and start the rate-limiter's
background cleanup so its map is bounded over the process lifetime:
```go
delSvc := accountdeletion.NewService(identity.NewStore(db), accountdeletion.NewStore(db))
rl := web.NewRateLimiter(5, time.Minute)
go func() {
	t := time.NewTicker(5 * time.Minute)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case now := <-t.C:
			rl.Cleanup(now)
		}
	}
}()
webHandler := web.NewHandler(web.Deps{
	Logger:    logger,
	Deletion:  delSvc,
	FormToken: web.NewFormToken([]byte(cfg.WebFormSigningKey)),
	RateLim:   rl,
})
```
(`identity.NewStore(db)` satisfies `accountdeletion`'s `userLookup` via `FindUserByEmail`.) Add imports for `accountdeletion` and `time`. The goroutine exits on `ctx.Done()` (graceful shutdown), so it does not leak.

- [ ] **Step 6: Run tests to verify pass**

Run: `cd backend && go test ./internal/web/ ./internal/api/`
Expected: PASS.

- [ ] **Step 7: Format, vet, commit**

```bash
cd backend && make fmt && make vet
git add backend/internal/web backend/cmd/peppercheck/main.go
git commit -m "feat(backend): unauthenticated account-deletion request form (match, upsert, anti-abuse)"
```

---

## Task 13: Delete the Next.js web app, follow-ups doc, full verification

**Files:**
- Delete: `peppercheck-webapp/` (whole directory), `.github/workflows/ci-webapp.yml`
- Create: `docs/superpowers/specs/2026-07-26-phase3b-follow-ups.md`

**Interfaces:** none (cleanup + verification).

- [ ] **Step 1: Confirm route parity, then delete the web app**

Verify every kept route renders and every removed route 301s (Tasks 1–6, 12 tests all green). Then:
```bash
git rm -r peppercheck-webapp
git rm .github/workflows/ci-webapp.yml
```
Grep for lingering references to the deleted app (build scripts, READMEs, deploy workflows) and remove/adjust them. (Do not grep secret files.)

- [ ] **Step 2: Write the follow-ups doc**

Create `docs/superpowers/specs/2026-07-26-phase3b-follow-ups.md` recording, at minimum:
- Phase 5: replace the tokushoho hardcoded `premiumPriceJPY` with a read from the Go subscription endpoint; add a price-consistency check then. Resolve the 2,580 vs 2,480 Premium discrepancy before shipping.
- Phase 5 (**production-cutover release criterion**, not a 3b blocker): make the Stripe Connect **`refresh`** path regenerate a new Account Link (`accountLinks.create`) and 302 into onboarding, identifying the Connect account via a short-lived signed `state` query param — per Stripe's Account Links contract (https://docs.stripe.com/api/account_links/create). 3b ships it as a static page (faithful port of current prod); the re-issue belongs with the Go `payout-setup` port and MUST be done before the production cutover so Connect onboarding can recover from an expired link.
- Phase 6: consume `account_deletion_requests` — email round-trip verification (`unverified` → `verified`), run the deletion saga, per-account verification-email rate limiting. Note the state machine is enforced at write time (the public form's upsert never touches non-`unverified` rows).
- Operator/7a: `WEB_FORM_SIGNING_KEY` new secret via BWS → Docker file-based secret (`WEB_FORM_SIGNING_KEY_FILE`), scoped to `api`.
- Optional: Cloudflare Turnstile on the deletion form if real spam gets through; default locale `ja` vs `en` (product decision).
- Web CI: the html/template pages are covered by `ci-backend.yml` (Go tests); `ci-webapp.yml` removed.

- [ ] **Step 3: Full backend verification**

Run:
```bash
cd backend && make fmt && make vet && make test
atlas migrate diff ci_drift_check --env local   # expect: no changes
```
Expected: all green; drift check reports no changes. Confirm `gofmt -l .` prints nothing.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore(backend): remove Next.js web app; add Phase 3b follow-ups"
```

---

## Self-Review

**Spec coverage** (design doc §§1–9):
- 8 keep routes → Tasks 1 (home), 2 (privacy/terms/refund), 3 (tokushoho), 4 (stripe return/refresh), 12 (account/delete). ✓
- 4 redirects → Task 5. ✓
- Frozen `/{locale}/` + hreflang → Task 1 (locale dispatch, hreflang) applied per page. ✓
- Subdirectory (not subdomain) → inherent in routing (Task 1). ✓
- Deletion request model (request ≠ execution, match-on-real-account, uniform response, no email sent) → Tasks 7 (email), 8 (table), 9 (service), 12 (handler). ✓
- Match safety (verified-only, unambiguous, current) → Task 7 `FindUserByEmail` (DISTINCT + `email_verified` + LIMIT 2 → ambiguous refused) + login-time refresh. ✓
- Deletion state machine not revertible by the public form → Task 9 guarded upsert (`WHERE status = 'unverified'`) + Task 8 assert-SQL guard test. ✓
- Anti-abuse (honeypot, signed token, timing, per-IP rate limit, upsert dedup, consent required, body size cap, fail-closed signing key) → Tasks 9 (upsert), 10 (token+timing+fail-closed key), 11 (rate limit), 12 (honeypot+consent+MaxBytesReader+wiring). ✓
- Marketing home + shared chrome content port + design-parity baseline → Task 1 (HomePage/Header/Footer port) + Task 6 (page × locale × viewport comparison). ✓
- Stripe `refresh` re-issue is a documented Phase 5 follow-up (static in 3b, faithful port) → Task 4 note + Task 13 follow-ups (marked a cutover release criterion). ✓
- Infra failure does not silently drop a request → Task 12 returns a generic **503** retry page on `RequestDeletion` error (independent of account match, so no disclosure), logged for alerting. ✓
- Rate-limiter memory is bounded → Task 11 `Cleanup` (background ticker in main) + hard `maxKeys` cap that refuses new keys when full + `Len` for tests. ✓
- Asset caching matches the spec → Task 6 content-`ETag` + `Cache-Control: public, max-age=3600` with `304` on `If-None-Match`; spec §3.6 aligned to this revalidation policy. ✓
- CSP is actually enforced → Task 1 emits `Content-Security-Policy` (strict, no-JS) + `X-Content-Type-Options`/`Referrer-Policy` on every web response, with a header test; spec §6.3 aligned. ✓
- Response contract consistent across docs → spec §6.2 now states "normally 303, generic 503 on save-infra failure," matching Task 12. ✓
- i18n single source of truth in Go → Tasks 1–4, 12 (catalog). ✓
- Fonts self-hosted, design preserved → Task 6. ✓
- tokushoho hardcoded price + blocker linkage; Phase 5 follow-up → Task 3, Task 13. ✓
- Delete web app + no Supabase web imports → Task 13. ✓
- New `WEB_FORM_SIGNING_KEY` secret to 7a delivery → Task 10 note + Task 13. ✓
- DB tests as assert-SQL, Atlas migration + drift, `make test` gate → Tasks 7, 8, 13. ✓
- Phase 6 boundary (consume `account_deletion_requests`) → Task 13 follow-ups. ✓

**Placeholder scan:** Template *content* for legal pages is intentionally "port the ported namespace" because the copy is verbatim data from the existing catalogs (not inventable); every code mechanism (routing, token, rate limit, store, service, email) has concrete code. No "TODO/TBD/add error handling" left in code steps.

**Type consistency:** `RequestDeletion(ctx, claimedEmail string) error`, `FindUserByEmail(ctx, email) (identity.User, error)`, `Store.Upsert(ctx, userID, claimedEmail string) error`, `FormToken.Issue(now)/Verify(token, now)`, `RateLimiter.Allow(key, now)`, `ResolveOrProvision(ctx, issuer, subject, email, emailVerified)` are used identically across the tasks that define and consume them. ✓
