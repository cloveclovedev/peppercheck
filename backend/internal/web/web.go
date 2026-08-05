// Package web serves the server-rendered public web (marketing home, legal
// pages, Stripe Connect landing pages, and the account-deletion request
// resource) same-origin alongside the JSON API. See
// docs/designs/2026-07-26-phase3b-go-web-design.md.
package web

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/ratelimit"
)

// deletionRequester is the account-deletion use case; accountdeletion.Service
// satisfies it. A consumer-declared interface (web depends on it, not the
// other way around) keeps internal/web free of an internal/accountdeletion
// import cycle concern and lets tests use a fake.
type deletionRequester interface {
	RequestDeletion(ctx context.Context, claimedEmail string) error
}

// Deps are the web handler's dependencies.
type Deps struct {
	Logger *slog.Logger
	// Deletion, FormToken, and RateLim back the account-deletion request
	// form. When any is nil (e.g. skeleton tests), the delete page renders
	// instructions only, with no form -- see accountDelete/deletePage.
	Deletion  deletionRequester
	FormToken *FormToken
	RateLim   *ratelimit.TokenBucket
}

// Handler serves the server-rendered public web on every path not owned by
// the JSON API. It is mounted as the ServeMux catch-all ("/").
type Handler struct {
	logger    *slog.Logger
	deletion  deletionRequester
	formToken *FormToken
	rateLim   *ratelimit.TokenBucket
	static    *assetServer
}

// NewHandler builds the web Handler. A nil logger falls back to slog.Default().
func NewHandler(d Deps) *Handler {
	l := d.Logger
	if l == nil {
		l = slog.Default()
	}
	return &Handler{
		logger: l, deletion: d.Deletion, formToken: d.FormToken, rateLim: d.RateLim,
		static: newAssetServer(),
	}
}

// contentSecurityPolicy locks the pages to their own self-contained origin.
// The site ships no JavaScript and no external hosts (CSS/fonts are embedded
// and served same-origin), so this is strict: no scripts, no framing, forms
// only to self. data: is allowed for images (favicons/inline SVG) only.
const contentSecurityPolicy = "default-src 'self'; script-src 'none'; style-src 'self'; font-src 'self'; img-src 'self' data:; form-action 'self'; base-uri 'self'; frame-ancestors 'none'; object-src 'none'"

// Reviewed IAP subscription prices (JPY/month) shown on the tokushoho page.
// These are Apple's confirmed subscription tiers (docs/designs/2026-05-09-ios-iap-design.md).
// Do NOT resurrect the `subscription_plan_prices` provider='stripe' seed
// rows (¥480/¥980/¥1,980) -- those are for the disabled web Stripe Checkout
// path and are not what subscribers actually pay.
//
// RELEASE GATE: Google Play's live Premium price is still ¥2,580 as of this
// commit (issue #411, blocked on #402) -- this constant anticipates the
// reconciled value. This page is safe to merge now because the whole
// refactor is big-bang on the integration branch and does not reach
// production until the Phase 7 cutover (see the design doc §5.1); #477
// Phase 5 already tracks resolving #411 as a pre-cutover requirement. Do
// NOT let this value reach production before Google Play is actually
// updated to match.
const (
	lightPriceJPY    = 650
	standardPriceJPY = 1280
	premiumPriceJPY  = 2480
)

// tokushohoPriceLines builds the localized, formatted price lines shown in
// the tokushoho price row, e.g. "Light Plan ¥650" / "ライトプラン ¥650".
func tokushohoPriceLines(locale string) []string {
	plans := []struct {
		key string
		jpy int
	}{
		{"light", lightPriceJPY},
		{"standard", standardPriceJPY},
		{"premium", premiumPriceJPY},
	}
	lines := make([]string, 0, len(plans))
	for _, p := range plans {
		name := cat.T(locale, "Tokushoho.plans."+p.key)
		lines = append(lines, fmt.Sprintf("%s ¥%s", name, formatJPY(p.jpy)))
	}
	return lines
}

// formatJPY adds thousands separators to a JPY yen amount, e.g. 2480 -> "2,480".
func formatJPY(n int) string {
	s := strconv.Itoa(n)
	if len(s) <= 3 {
		return s
	}
	var out strings.Builder
	first := len(s) % 3
	if first == 0 {
		first = 3
	}
	out.WriteString(s[:first])
	for i := first; i < len(s); i += 3 {
		out.WriteByte(',')
		out.WriteString(s[i : i+3])
	}
	return out.String()
}

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	// Security headers on every web response (set before any body/redirect write).
	w.Header().Set("Content-Security-Policy", contentSecurityPolicy)
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.Header().Set("Referrer-Policy", "strict-origin-when-cross-origin")

	p := r.URL.Path
	if strings.HasPrefix(p, "/static/") {
		h.static.ServeHTTP(w, r)
		return
	}
	if p == "/" {
		target := "/" + defaultLocale
		if r.URL.RawQuery != "" {
			// Preserve campaign/attribution query params (e.g. utm_source)
			// through the locale redirect instead of dropping them.
			target += "?" + r.URL.RawQuery
		}
		http.Redirect(w, r, target, http.StatusMovedPermanently)
		return
	}
	segs := strings.Split(strings.Trim(p, "/"), "/")
	if !isSupported(segs[0]) {
		// Bare (locale-less) path with no locale prefix. Stripe's Account
		// Links contract sends return_url/refresh_url as these exact bare
		// paths (payout-setup, ported in Phase 5), so they must keep
		// resolving; 301 to the default-locale page. The legacy
		// auth/subscription routes are dropped entirely (P3b-D15, no
		// redirect) -- everything else is a plain 404.
		bare := strings.Join(segs, "/")
		if bare == "stripe/connect/return" || bare == "stripe/connect/refresh" {
			http.Redirect(w, r, "/"+defaultLocale+"/"+bare, http.StatusMovedPermanently)
			return
		}
		h.renderNotFound(w, r, defaultLocale)
		return
	}
	locale := segs[0]
	rest := segs[1:]

	switch {
	case len(rest) == 0: // localized home
		h.render(w, http.StatusOK, "home", h.page(r, locale, "Meta.defaultTitle", ""))
	case len(rest) == 2 && rest[0] == "legal":
		h.serveLegal(w, r, locale, rest[1])
	case len(rest) == 3 && rest[0] == "stripe" && rest[1] == "connect":
		h.serveStripeConnect(w, r, locale, rest[2])
	case len(rest) == 2 && rest[0] == "account" && rest[1] == "delete":
		h.accountDelete(w, r, locale)
	default:
		h.renderNotFound(w, r, locale)
	}
}

func (h *Handler) serveStripeConnect(w http.ResponseWriter, r *http.Request, locale, page string) {
	switch page {
	case "return":
		h.render(w, http.StatusOK, "stripe_return", h.page(r, locale, "StripeConnect.return.title", "/stripe/connect/return"))
	case "refresh":
		h.render(w, http.StatusOK, "stripe_refresh", h.page(r, locale, "StripeConnect.refresh.title", "/stripe/connect/refresh"))
	default:
		h.renderNotFound(w, r, locale)
	}
}

func (h *Handler) serveLegal(w http.ResponseWriter, r *http.Request, locale, page string) {
	switch page {
	case "privacy":
		h.render(w, http.StatusOK, "legal_privacy", h.page(r, locale, "Privacy.title", "/legal/privacy"))
	case "terms":
		h.render(w, http.StatusOK, "legal_terms", h.page(r, locale, "Terms.title", "/legal/terms"))
	case "refund":
		h.render(w, http.StatusOK, "legal_refund", h.page(r, locale, "Refund.title", "/legal/refund"))
	case "tokushoho":
		data := h.page(r, locale, "Tokushoho.title", "/legal/tokushoho")
		data.PriceLines = tokushohoPriceLines(locale)
		h.render(w, http.StatusOK, "legal_tokushoho", data)
	default:
		h.renderNotFound(w, r, locale)
	}
}

// maxDeletionFormBytes bounds the public POST body -- this form is tiny.
const maxDeletionFormBytes = 4 << 10 // 4 KiB

// AccountDeletionRateLimit{Burst,PerHour,IdleEvict} parameterize the
// ratelimit.TokenBucket main.go constructs for the public deletion form: a
// low, deliberately tight per-IP volume. Unlike the authenticated
// avatar-upload limiter (burst 10 / 10 per hour), this endpoint has no auth
// to fall back on, so it favors blocking casual abuse over convenience.
// Escalate to Cloudflare Turnstile if real spam gets past this (recorded in
// the design doc's follow-ups).
const (
	AccountDeletionRateLimitBurst     = 5
	AccountDeletionRateLimitPerHour   = 5
	AccountDeletionRateLimitIdleEvict = time.Hour
)

func (h *Handler) accountDelete(w http.ResponseWriter, r *http.Request, locale string) {
	switch r.Method {
	case http.MethodGet:
		submitted := r.URL.Query().Get("submitted") == "1"
		h.render(w, http.StatusOK, "account_delete", h.deletePage(r, locale, submitted))
	case http.MethodPost:
		h.handleDeletePost(w, r, locale)
	default:
		w.Header().Set("Allow", "GET, POST")
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}

// deletePage builds pageData for the account-deletion page. ShowForm is only
// true when every dependency the form needs is actually wired.
func (h *Handler) deletePage(r *http.Request, locale string, submitted bool) pageData {
	data := h.page(r, locale, "AccountDelete.title", "/account/delete")
	data.Submitted = submitted
	if !submitted && h.deletion != nil && h.formToken != nil {
		data.ShowForm = true
		data.FormToken = h.formToken.Issue(time.Now())
	}
	return data
}

func (h *Handler) handleDeletePost(w http.ResponseWriter, r *http.Request, locale string) {
	redirect := "/" + locale + "/account/delete?submitted=1" // uniform response
	if h.deletion == nil || h.formToken == nil {
		// Dependencies not wired (shouldn't happen outside tests/skeleton) --
		// fail closed to the uniform redirect rather than a 500 that could
		// hint at server state.
		http.Redirect(w, r, redirect, http.StatusSeeOther)
		return
	}
	// Rate limit first, before touching the body.
	if h.rateLim != nil {
		if allowed, _ := h.rateLim.Allow(clientIP(r)); !allowed {
			http.Error(w, "too many requests", http.StatusTooManyRequests)
			return
		}
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
	if h.formToken.Verify(r.PostForm.Get("form_token"), time.Now()) != nil {
		http.Redirect(w, r, redirect, http.StatusSeeOther)
		return
	}
	email := r.PostForm.Get("email")
	if err := h.deletion.RequestDeletion(r.Context(), email); err != nil {
		// Infrastructure failure (e.g. DB down): the request was NOT saved, so
		// we must NOT tell the user it was received. Return a generic 503
		// retry page. This is independent of whether an account matched
		// (RequestDeletion returns nil for both match and no-match), so it
		// leaks no account existence. No PII in the log line.
		h.logger.Error("web_deletion_request_failed", slog.Any("error", err))
		h.renderError(w, r, locale, http.StatusServiceUnavailable)
		return
	}
	http.Redirect(w, r, redirect, http.StatusSeeOther)
}

// renderError renders the shared error page (used for the 503 on infra
// failure). Monitoring alerts fire off the logged web_deletion_request_failed
// / 5xx rate, not this page.
func (h *Handler) renderError(w http.ResponseWriter, r *http.Request, locale string, status int) {
	h.render(w, status, "error", h.page(r, locale, "Error.title", ""))
}

func (h *Handler) renderNotFound(w http.ResponseWriter, r *http.Request, locale string) {
	h.render(w, http.StatusNotFound, "notfound", h.page(r, locale, "NotFound.title", ""))
}

// requestOrigin returns the scheme+host the current request arrived on, for
// building fully-qualified URLs (Google requires hreflang alternates to be
// absolute). Caddy sets X-Forwarded-Proto when reverse-proxying; https is the
// correct default for every real deployment (this is a public site, never
// served over plain http in staging/production).
func requestOrigin(r *http.Request) string {
	scheme := "https"
	if proto := r.Header.Get("X-Forwarded-Proto"); proto != "" {
		scheme = proto
	}
	return scheme + "://" + r.Host
}

// page builds pageData for a locale, a title message key, and the
// locale-relative path (used for hreflang + the language switcher).
// Hreflang tags get absolute URLs (requestOrigin); the language switcher's
// nav links stay relative, matching every other in-page link. Every page's
// <title> is "<page title> | Peppercheck", matching the current site's
// title template -- except the home page itself, which passes
// "Meta.defaultTitle" as titleKey and gets just "Peppercheck" (no
// self-referential suffix), matching Next's `default: 'Peppercheck'`.
func (h *Handler) page(r *http.Request, locale, titleKey, relPath string) pageData {
	title := cat.T(locale, titleKey)
	if titleKey != "Meta.defaultTitle" {
		title += " | " + cat.T(locale, "Meta.defaultTitle")
	}
	return pageData{
		Locale:     locale,
		Title:      title,
		Hreflang:   hreflangAlternates(requestOrigin(r), relPath),
		LangSwitch: hreflangAlternates("", relPath)[:len(supportedLocales)],
	}
}
