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

// pageData is the data every template receives. Later Phase 3b sub-issues
// (account-deletion form) extend this struct as they add pages that need it.
type pageData struct {
	Locale     string
	Title      string
	Hreflang   []alt
	LangSwitch []alt
	// PriceLines is only set for the tokushoho page: formatted
	// "<plan name> ¥<amount>" strings, one per subscription plan.
	PriceLines []string
}

// langLabel is the language-switcher display label for a locale code, e.g.
// "ja" -> "JP" (matches the current site's EN/JP switcher; ISO code and
// display label differ for Japanese).
func langLabel(locale string) string {
	switch locale {
	case "ja":
		return "JP"
	default:
		return strings.ToUpper(locale)
	}
}

// pages holds one parsed template set per page: layout + that page's content
// block. Every templates/<name>.gohtml auto-registers as page <name>.
var pages = parsePages()

// list lets a template build an ordered string slice inline (e.g. an item
// key list for a {{range}}) without a Go-side helper per page.
func list(items ...string) []string { return items }

func parsePages() map[string]*template.Template {
	fm := template.FuncMap{"t": cat.T, "langLabel": langLabel, "list": list}
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

// render executes the named page to a buffer first, so a template error
// yields a clean 500 instead of a half-written body.
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
