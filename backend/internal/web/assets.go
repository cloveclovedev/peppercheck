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

// assetServer serves the embedded static assets (CSS, fonts, images) with a
// content-based ETag so browsers get a cheap 304 on revalidation.
// embed.FS carries no mtime, so http.FileServer alone would emit no
// validators at all; computing an ETag once at startup gives correct
// revalidation without a build-time content-hash filename pipeline.
type assetServer struct {
	fileServer http.Handler
	etags      map[string]string // e.g. "styles.css" -> `"<hex>"`
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
	if r.Method != http.MethodGet && r.Method != http.MethodHead {
		w.Header().Set("Allow", "GET, HEAD")
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	name := strings.TrimPrefix(r.URL.Path, "/static/")
	if etag, ok := a.etags[name]; ok {
		// http.FileServer honors If-None-Match against this and answers 304.
		w.Header().Set("Etag", etag)
		w.Header().Set("Cache-Control", "public, max-age=3600")
	}
	a.fileServer.ServeHTTP(w, r)
}
