package web

// alt is one hreflang (or language-switcher) alternate.
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
// "/legal/privacy", or "" for home), one per supported locale plus x-default.
// origin is prepended to every href ("" for relative links, e.g. the
// language switcher; a scheme+host for <link rel="alternate" hreflang>
// tags, which Google requires to be fully qualified -- see
// https://developers.google.com/search/docs/specialty/international/localized-versions#all-method-guidelines).
func hreflangAlternates(origin, relPath string) []alt {
	out := make([]alt, 0, len(supportedLocales)+1)
	for _, l := range supportedLocales {
		out = append(out, alt{Lang: l, Href: origin + "/" + l + relPath})
	}
	out = append(out, alt{Lang: "x-default", Href: origin + "/" + defaultLocale + relPath})
	return out
}
