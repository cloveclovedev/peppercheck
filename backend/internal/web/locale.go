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
func hreflangAlternates(relPath string) []alt {
	out := make([]alt, 0, len(supportedLocales)+1)
	for _, l := range supportedLocales {
		out = append(out, alt{Lang: l, Href: "/" + l + relPath})
	}
	out = append(out, alt{Lang: "x-default", Href: "/" + defaultLocale + relPath})
	return out
}
