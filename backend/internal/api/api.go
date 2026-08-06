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
	"github.com/cloveclovedev/peppercheck/backend/internal/matching"
	"github.com/cloveclovedev/peppercheck/backend/internal/notification"
	"github.com/cloveclovedev/peppercheck/backend/internal/platform/auth"
	"github.com/cloveclovedev/peppercheck/backend/internal/profile"
	"github.com/cloveclovedev/peppercheck/backend/internal/task"
)

// Deps are the runtime dependencies the api handler wires into routes.
type Deps struct {
	Ready        func(context.Context) error
	Verifier     auth.TokenVerifier
	Identity     *identity.Handler
	Profile      *profile.Handler
	Notification *notification.Handler
	Task         *task.Handler                   // task authoring (draft CRUD + publish)
	Referee      *matching.Handler               // referee availability, assignments, cancel
	ResolveUser  func(http.Handler) http.Handler // identity.NewMiddleware: verified Identity -> internal User in ctx
	Logger       *slog.Logger                    // used by the auth middleware; Run injects the run logger when nil
	Web          http.Handler                    // server-rendered public web (internal/web); mounted as the catch-all
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
		chain := func(h http.HandlerFunc) http.Handler { return authed(deps.ResolveUser(h)) }
		mux.Handle("GET /api/v1/me", chain(deps.Identity.Me))

		if deps.Profile != nil {
			mux.Handle("GET /api/v1/me/profile", chain(deps.Profile.GetMe))
			mux.Handle("PATCH /api/v1/me/profile", chain(deps.Profile.PatchMe))
			mux.Handle("POST /api/v1/me/avatar/request-upload-url", chain(deps.Profile.PostAvatarUploadURL))
		}
		if deps.Notification != nil {
			mux.Handle("PUT /api/v1/me/device-push-tokens", chain(deps.Notification.PutToken))
			mux.Handle("DELETE /api/v1/me/device-push-tokens", chain(deps.Notification.DeleteToken))
		}
		if deps.Task != nil {
			mux.Handle("POST /api/v1/tasks", chain(deps.Task.PostTask))
			mux.Handle("GET /api/v1/tasks/{id}", chain(deps.Task.GetTask))
			mux.Handle("PATCH /api/v1/tasks/{id}", chain(deps.Task.PatchTask))
			mux.Handle("DELETE /api/v1/tasks/{id}", chain(deps.Task.DeleteTask))
			mux.Handle("POST /api/v1/tasks/{id}/publish", chain(deps.Task.PostPublish))
			mux.Handle("GET /api/v1/me/tasks", chain(deps.Task.GetMyTasks))
			// Assignments return Task envelopes, so the task handler owns them.
			mux.Handle("GET /api/v1/me/assignments", chain(deps.Task.GetAssignments))
		}
		if deps.Referee != nil {
			mux.Handle("GET /api/v1/me/availability/time-slots", chain(deps.Referee.GetTimeSlots))
			mux.Handle("POST /api/v1/me/availability/time-slots", chain(deps.Referee.PostTimeSlot))
			mux.Handle("PUT /api/v1/me/availability/time-slots/{id}", chain(deps.Referee.PutTimeSlot))
			mux.Handle("DELETE /api/v1/me/availability/time-slots/{id}", chain(deps.Referee.DeleteTimeSlot))
			mux.Handle("GET /api/v1/me/availability/blocked-dates", chain(deps.Referee.GetBlockedDates))
			mux.Handle("POST /api/v1/me/availability/blocked-dates", chain(deps.Referee.PostBlockedDate))
			mux.Handle("PUT /api/v1/me/availability/blocked-dates/{id}", chain(deps.Referee.PutBlockedDate))
			mux.Handle("DELETE /api/v1/me/availability/blocked-dates/{id}", chain(deps.Referee.DeleteBlockedDate))
			mux.Handle("POST /api/v1/referee-requests/{id}/cancel", chain(deps.Referee.PostCancel))
		}
	}

	// Public (no auth): the matching configuration the client needs before
	// authenticating a publish/withdraw flow.
	if deps.Referee != nil {
		mux.Handle("GET /api/v1/matching/config", http.HandlerFunc(deps.Referee.GetConfig))
	}

	// Methodless /api/ fallback: without this, a request that hits a
	// registered path with the wrong method (e.g. POST /api/v1/me, which only
	// registers GET) is NOT rejected by the specific pattern -- ServeMux falls
	// through to the least-specific matching pattern instead, which would be
	// the web catch-all below, silently serving an HTML page for an API path.
	// Registering this JSON fallback for the whole /api/ prefix keeps every
	// /api/* response API-shaped regardless of Web being mounted.
	mux.Handle("/api/", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		httpserver.WriteError(w, r, http.StatusNotFound, httpserver.CodeNotFound, "not found")
	}))

	if deps.Web != nil {
		// Catch-all for everything else not matched by a more specific
		// pattern above (/api/ never reaches here; see the fallback registered
		// just above).
		mux.Handle("/", deps.Web)
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
