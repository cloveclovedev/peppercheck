// Package api assembles and runs the HTTP api command. In Phase 1 it exposes
// only liveness and readiness; feature routes arrive in later phases.
package api

import (
	"context"
	"log/slog"
	"net/http"
	"time"

	"github.com/cloveclovedev/peppercheck/backend/internal/platform/config"
	"github.com/cloveclovedev/peppercheck/backend/internal/platform/httpserver"
)

// buildHandler wires routes and middleware. ready is the readiness probe; a nil
// probe means the process reports ready unconditionally.
func buildHandler(ready func(context.Context) error) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /livez", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})
	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, r *http.Request) {
		if ready != nil {
			ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
			defer cancel()
			if err := ready(ctx); err != nil {
				w.WriteHeader(http.StatusServiceUnavailable)
				_, _ = w.Write([]byte("not ready"))
				return
			}
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ready"))
	})
	return mux
}

// Run builds the handler and serves until ctx is cancelled. Middleware order
// (outermost first) is RequestID -> AccessLog -> Recover -> handler: AccessLog
// wraps Recover so a panic (which Recover turns into a 500) is still logged as
// an http_request. Putting Recover outside AccessLog would drop the access-log
// line for panicking requests.
func Run(ctx context.Context, cfg config.Config, logger *slog.Logger, ready func(context.Context) error) error {
	handler := httpserver.Chain(buildHandler(ready),
		httpserver.RequestID,
		httpserver.AccessLog(logger),
		httpserver.Recover(logger),
	)
	srv := httpserver.New(cfg.Port, handler)
	return httpserver.Run(ctx, logger, srv, time.Duration(cfg.ShutdownTimeout)*time.Second)
}
