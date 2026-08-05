// Package web serves the server-rendered public web (marketing home, legal
// pages, Stripe Connect landing pages, and the account-deletion request
// resource) same-origin alongside the JSON API. See
// docs/designs/2026-07-26-phase3b-go-web-design.md.
package web

import (
	"fmt"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
)

// Deps are the web handler's dependencies. Later Phase 3b sub-issues add
// fields (e.g. the account-deletion service).
type Deps struct {
	Logger *slog.Logger
}

// Handler serves the server-rendered public web on every path not owned by
// the JSON API. It is mounted as the ServeMux catch-all ("/").
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

// contentSecurityPolicy locks the pages to their own self-contained origin.
// The site ships no JavaScript and no external hosts (CSS/fonts are embedded
// and served same-origin), so this is strict: no scripts, no framing, forms
// only to self. data: is allowed for images (favicons/inline SVG) only.
const contentSecurityPolicy = "default-src 'self'; script-src 'none'; style-src 'self'; font-src 'self'; img-src 'self' data:; form-action 'self'; base-uri 'self'; frame-ancestors 'none'; object-src 'none'"

// Reviewed IAP subscription prices (JPY/month) shown on the tokushoho page.
// These are Apple's confirmed subscription tiers (docs/designs/2026-05-09-ios-iap-design.md);
// Google Play is pending reconciliation to the same values via issue #411.
// Do NOT resurrect the `subscription_plan_prices` provider='stripe' seed
// rows (¥480/¥980/¥1,980) -- those are for the disabled web Stripe Checkout
// path and are not what subscribers actually pay.
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
		// Bare (locale-less) path with no locale prefix: the legacy
		// auth/subscription routes are dropped entirely (P3b-D15, no
		// redirect); everything else is a plain 404 too. Stripe Connect's
		// bare-path handling is added when that page lands.
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
// nav links stay relative, matching every other in-page link.
func (h *Handler) page(r *http.Request, locale, titleKey, relPath string) pageData {
	return pageData{
		Locale:     locale,
		Title:      cat.T(locale, titleKey),
		Hreflang:   hreflangAlternates(requestOrigin(r), relPath),
		LangSwitch: hreflangAlternates("", relPath)[:len(supportedLocales)],
	}
}
