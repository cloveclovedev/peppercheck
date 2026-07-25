package auth

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"strings"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/httpserver"
)

type ctxKey int

const identityKey ctxKey = 0

// IdentityFrom returns the verified Identity stored by Middleware.
func IdentityFrom(ctx context.Context) (Identity, bool) {
	id, ok := ctx.Value(identityKey).(Identity)
	return id, ok
}

// Middleware verifies the bearer token and stores the Identity in the context.
// A missing/malformed header or an invalid/expired token returns 401; any other
// verifier failure (infrastructure, e.g. a public-key fetch) returns 503 with
// the cause logged server-side. A nil logger falls back to slog.Default().
func Middleware(v TokenVerifier, logger *slog.Logger) func(http.Handler) http.Handler {
	if logger == nil {
		logger = slog.Default()
	}
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			raw, ok := bearerToken(r)
			if !ok {
				httpserver.WriteError(w, r, http.StatusUnauthorized, httpserver.CodeUnauthenticated, "missing bearer token")
				return
			}
			id, err := v.Verify(r.Context(), raw)
			if err != nil {
				if errors.Is(err, ErrInvalidToken) {
					httpserver.WriteError(w, r, http.StatusUnauthorized, httpserver.CodeUnauthenticated, "invalid or expired token")
					return
				}
				logger.LogAttrs(r.Context(), slog.LevelError, "token_verify_failed",
					slog.String("request_id", httpserver.RequestIDFrom(r.Context())),
					slog.Any("error", err),
				)
				httpserver.WriteError(w, r, http.StatusServiceUnavailable, httpserver.CodeUnavailable, "authentication temporarily unavailable")
				return
			}
			ctx := context.WithValue(r.Context(), identityKey, id)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// bearerToken extracts a non-empty token from an "Authorization: Bearer <t>"
// header, case-insensitive on the scheme.
func bearerToken(r *http.Request) (string, bool) {
	h := r.Header.Get("Authorization")
	const prefix = "bearer "
	if len(h) <= len(prefix) || !strings.EqualFold(h[:len(prefix)], prefix) {
		return "", false
	}
	tok := strings.TrimSpace(h[len(prefix):])
	return tok, tok != ""
}
