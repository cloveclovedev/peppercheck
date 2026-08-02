package notification

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/httpserver"
	"github.com/cloveclovedev/peppercheck/backend/internal/identity"
)

// Handler serves the device push-token registration surface, scoped to the caller.
type Handler struct {
	svc *Service
}

// NewHandler builds a Handler over the notification service.
func NewHandler(svc *Service) *Handler { return &Handler{svc: svc} }

type putTokenRequest struct {
	Token      string `json:"token"`
	DeviceType string `json:"deviceType"`
}

// PutToken registers (upserts) the caller's device push token.
func (h *Handler) PutToken(w http.ResponseWriter, r *http.Request) {
	u, ok := identity.CurrentUser(r.Context())
	if !ok {
		httpserver.WriteError(w, r, http.StatusUnauthorized, httpserver.CodeUnauthenticated, "missing user")
		return
	}
	var req putTokenRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpserver.WriteError(w, r, http.StatusBadRequest, httpserver.CodeInvalidArgument, "invalid JSON body")
		return
	}
	if err := h.svc.RegisterToken(r.Context(), u.ID, req.Token, req.DeviceType); err != nil {
		writeTokenError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

type deleteTokenRequest struct {
	Token string `json:"token"`
}

// DeleteToken removes the caller's device push-token binding.
func (h *Handler) DeleteToken(w http.ResponseWriter, r *http.Request) {
	u, ok := identity.CurrentUser(r.Context())
	if !ok {
		httpserver.WriteError(w, r, http.StatusUnauthorized, httpserver.CodeUnauthenticated, "missing user")
		return
	}
	var req deleteTokenRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpserver.WriteError(w, r, http.StatusBadRequest, httpserver.CodeInvalidArgument, "invalid JSON body")
		return
	}
	if err := h.svc.DeleteToken(r.Context(), u.ID, req.Token); err != nil {
		writeTokenError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func writeTokenError(w http.ResponseWriter, r *http.Request, err error) {
	if errors.Is(err, ErrInvalidArgument) {
		httpserver.WriteError(w, r, http.StatusBadRequest, httpserver.CodeInvalidArgument, "token is required")
		return
	}
	httpserver.WriteError(w, r, http.StatusInternalServerError, httpserver.CodeInternal, "could not update token")
}
