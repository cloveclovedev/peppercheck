package identity

import (
	"encoding/json"
	"log/slog"
	"net/http"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/httpserver"
	"github.com/cloveclovedev/peppercheck/backend/internal/platform/auth"
)

// Handler serves the identity HTTP surface.
type Handler struct {
	svc    *Service
	logger *slog.Logger
}

// NewHandler builds a Handler over the identity service. A nil logger falls back
// to slog.Default().
func NewHandler(svc *Service, logger *slog.Logger) *Handler {
	if logger == nil {
		logger = slog.Default()
	}
	return &Handler{svc: svc, logger: logger}
}

type meResponse struct {
	User     meUser     `json:"user"`
	Identity meIdentity `json:"identity"`
}

type meUser struct {
	ID        string `json:"id"`
	Status    string `json:"status"`
	CreatedAt string `json:"createdAt"`
}

type meIdentity struct {
	Issuer string `json:"issuer"`
}

// Me resolves the verified identity to the internal user, provisioning on first
// sighting, and returns it. It assumes the auth middleware ran.
func (h *Handler) Me(w http.ResponseWriter, r *http.Request) {
	id, ok := auth.IdentityFrom(r.Context())
	if !ok {
		httpserver.WriteError(w, r, http.StatusUnauthorized, httpserver.CodeUnauthenticated, "missing identity")
		return
	}
	u, err := h.svc.ResolveOrProvision(r.Context(), id.Issuer, id.Subject)
	if err != nil {
		h.logger.LogAttrs(r.Context(), slog.LevelError, "me_resolve_failed",
			slog.String("request_id", httpserver.RequestIDFrom(r.Context())),
			slog.Any("error", err),
		)
		httpserver.WriteError(w, r, http.StatusInternalServerError, httpserver.CodeInternal, "could not resolve user")
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(meResponse{
		User: meUser{
			ID:        u.ID,
			Status:    u.Status,
			CreatedAt: u.CreatedAt.UTC().Format("2006-01-02T15:04:05Z07:00"),
		},
		Identity: meIdentity{Issuer: id.Issuer},
	})
}
