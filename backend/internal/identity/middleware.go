package identity

import (
	"context"
	"log/slog"
	"net/http"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/httpserver"
	"github.com/cloveclovedev/peppercheck/backend/internal/platform/auth"
)

type ctxKey int

const userKey ctxKey = 0

// CurrentUser returns the internal user resolved by NewMiddleware. Authenticated
// handlers read the internal UUID from here instead of resolving it themselves.
func CurrentUser(ctx context.Context) (User, bool) {
	u, ok := ctx.Value(userKey).(User)
	return u, ok
}

// NewMiddleware resolves the verified Identity (placed by auth.Middleware) to the
// internal user, provisioning on first sighting, and stores it in the context. It
// runs after auth.Middleware. A missing Identity is a 401; a resolve failure is a
// 500 (logged server-side). A nil logger falls back to slog.Default().
func NewMiddleware(svc *Service, logger *slog.Logger) func(http.Handler) http.Handler {
	if logger == nil {
		logger = slog.Default()
	}
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			id, ok := auth.IdentityFrom(r.Context())
			if !ok {
				httpserver.WriteError(w, r, http.StatusUnauthorized, httpserver.CodeUnauthenticated, "missing identity")
				return
			}
			u, err := svc.ResolveOrProvision(r.Context(), id.Issuer, id.Subject, id.Email, id.EmailVerified)
			if err != nil {
				logger.LogAttrs(r.Context(), slog.LevelError, "resolve_user_failed",
					slog.String("request_id", httpserver.RequestIDFrom(r.Context())),
					slog.Any("error", err),
				)
				httpserver.WriteError(w, r, http.StatusInternalServerError, httpserver.CodeInternal, "could not resolve user")
				return
			}
			next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), userKey, u)))
		})
	}
}
