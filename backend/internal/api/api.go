// Package api assembles and runs the HTTP api command. Phase 1 exposed only
// liveness and readiness; Phase 2 adds the authenticated identity route.
package api

import (
	"context"
	"log/slog"
	"net/http"
	"time"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/config"
	"github.com/cloveclovedev/peppercheck/backend/internal/core/httpserver"
	"github.com/cloveclovedev/peppercheck/backend/internal/identity"
	"github.com/cloveclovedev/peppercheck/backend/internal/platform/auth"
)

// Deps are the runtime dependencies the api handler wires into routes.
type Deps struct {
	Ready       func(context.Context) error
	Verifier    auth.TokenVerifier
	Identity    *identity.Handler
	ResolveUser func(http.Handler) http.Handler // identity.NewMiddleware: verified Identity -> internal User in ctx
	Logger      *slog.Logger                    // used by the auth middleware; Run injects the run logger when nil
}

// buildHandler wires routes and middleware. deps.Ready is the readiness probe;
// a nil probe means the process reports ready unconditionally. The identity
// route is mounted only when both deps.Identity and deps.Verifier are set.
func buildHandler(deps Deps) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /livez", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})
	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, r *http.Request) {
		if deps.Ready != nil {
			ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
			defer cancel()
			if err := deps.Ready(ctx); err != nil {
				w.WriteHeader(http.StatusServiceUnavailable)
				_, _ = w.Write([]byte("not ready"))
				return
			}
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ready"))
	})

	if deps.Identity != nil && deps.Verifier != nil && deps.ResolveUser != nil {
		authed := auth.Middleware(deps.Verifier, deps.Logger)
		// authed verifies the token (Identity in ctx); ResolveUser turns it into
		// the internal User (CurrentUser in ctx) before the handler runs.
		chain := func(h http.Handler) http.Handler { return authed(deps.ResolveUser(h)) }
		mux.Handle("GET /api/v1/me", chain(http.HandlerFunc(deps.Identity.Me)))
	}
	return mux
}

// rootHandler wraps the route mux in the full middleware chain. Run and the API
// integration tests both call it, so the tests exercise the exact chain
// production runs (RequestID → AccessLog → Recover), not a subset.
func rootHandler(deps Deps, logger *slog.Logger) http.Handler {
	if deps.Logger == nil {
		deps.Logger = logger
	}
	return httpserver.Chain(buildHandler(deps),
		httpserver.RequestID,
		httpserver.AccessLog(logger),
		httpserver.Recover(logger),
	)
}

// Run builds the handler and serves until ctx is cancelled. Middleware order
// (outermost first) is RequestID -> AccessLog -> Recover -> handler: AccessLog
// wraps Recover so a panic (which Recover turns into a 500) is still logged as
// an http_request. Putting Recover outside AccessLog would drop the access-log
// line for panicking requests.
func Run(ctx context.Context, cfg config.Config, logger *slog.Logger, deps Deps) error {
	srv := httpserver.New(cfg.Port, rootHandler(deps, logger))
	return httpserver.Run(ctx, logger, srv, time.Duration(cfg.ShutdownTimeout)*time.Second)
}
