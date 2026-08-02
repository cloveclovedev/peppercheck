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

// Me returns the internal user resolved by the identity middleware (which
// provisions on first sighting) together with the verified issuer. It assumes
// both the auth and resolve middlewares ran; the Phase 2 contract is unchanged.
func (h *Handler) Me(w http.ResponseWriter, r *http.Request) {
	u, ok := CurrentUser(r.Context())
	if !ok {
		httpserver.WriteError(w, r, http.StatusUnauthorized, httpserver.CodeUnauthenticated, "missing user")
		return
	}
	id, _ := auth.IdentityFrom(r.Context())
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
