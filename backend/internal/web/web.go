// Package web serves the server-rendered public web (marketing home, legal
// pages, Stripe Connect landing pages, and the account-deletion request
// resource) same-origin alongside the JSON API. See
// docs/designs/2026-07-26-phase3b-go-web-design.md.
package web

import (
	"log/slog"
	"net/http"
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
		// Bare (locale-less) path with no locale prefix: the legacy
		// auth/subscription routes are dropped entirely (P3b-D15, no
		// redirect); everything else is a plain 404 too. Stripe Connect's
		// bare-path handling is added when that page lands.
		h.renderNotFound(w, defaultLocale)
		return
	}
	locale := segs[0]
	rest := segs[1:]

	switch {
	case len(rest) == 0: // localized home
		h.render(w, http.StatusOK, "home", h.page(locale, "Meta.defaultTitle", ""))
	default:
		h.renderNotFound(w, locale)
	}
}

func (h *Handler) renderNotFound(w http.ResponseWriter, locale string) {
	h.render(w, http.StatusNotFound, "notfound", h.page(locale, "NotFound.title", ""))
}

// page builds pageData for a locale, a title message key, and the
// locale-relative path (used for hreflang + the language switcher).
func (h *Handler) page(locale, titleKey, relPath string) pageData {
	alts := hreflangAlternates(relPath)
	return pageData{
		Locale:     locale,
		Title:      cat.T(locale, titleKey),
		Hreflang:   alts,
		LangSwitch: alts[:len(supportedLocales)],
	}
}
