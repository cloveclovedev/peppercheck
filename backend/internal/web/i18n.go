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

// T resolves a dotted key (e.g. "HomePage.title"); a missing key echoes the
// key so gaps are visible in tests and dev instead of rendering blank.
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
