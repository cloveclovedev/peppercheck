package profile

import (
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/httpserver"
	"github.com/cloveclovedev/peppercheck/backend/internal/identity"
)

// Handler serves the profile HTTP surface, scoped to the authenticated caller.
type Handler struct {
	svc *Service
}

// NewHandler builds a Handler over the profile service.
func NewHandler(svc *Service) *Handler { return &Handler{svc: svc} }

// profileResponse is the idless profile DTO (the owner is always the caller).
type profileResponse struct {
	Username  string  `json:"username"`
	AvatarURL *string `json:"avatarUrl"`
	Timezone  string  `json:"timezone"`
	CreatedAt string  `json:"createdAt"`
	UpdatedAt string  `json:"updatedAt"`
}

func toResponse(p Profile) profileResponse {
	return profileResponse{
		Username:  p.Username,
		AvatarURL: p.AvatarURL,
		Timezone:  p.Timezone,
		CreatedAt: p.CreatedAt.UTC().Format(time.RFC3339),
		UpdatedAt: p.UpdatedAt.UTC().Format(time.RFC3339),
	}
}

// GetMe returns the caller's profile.
func (h *Handler) GetMe(w http.ResponseWriter, r *http.Request) {
	u, ok := identity.CurrentUser(r.Context())
	if !ok {
		httpserver.WriteError(w, r, http.StatusUnauthorized, httpserver.CodeUnauthenticated, "missing user")
		return
	}
	p, err := h.svc.GetOwn(r.Context(), u.ID)
	if err != nil {
		httpserver.WriteError(w, r, http.StatusInternalServerError, httpserver.CodeInternal, "could not load profile")
		return
	}
	writeJSON(w, http.StatusOK, toResponse(p))
}

type patchProfileRequest struct {
	Username  *string `json:"username"`
	Timezone  *string `json:"timezone"`
	AvatarURL *string `json:"avatarUrl"`
}

// PatchMe applies a partial update to the caller's profile.
func (h *Handler) PatchMe(w http.ResponseWriter, r *http.Request) {
	u, ok := identity.CurrentUser(r.Context())
	if !ok {
		httpserver.WriteError(w, r, http.StatusUnauthorized, httpserver.CodeUnauthenticated, "missing user")
		return
	}
	var req patchProfileRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpserver.WriteError(w, r, http.StatusBadRequest, httpserver.CodeInvalidArgument, "invalid JSON body")
		return
	}
	p, err := h.svc.UpdateOwn(r.Context(), u.ID, UpdateInput{
		Username:  req.Username,
		Timezone:  req.Timezone,
		AvatarURL: req.AvatarURL,
	})
	if err != nil {
		writeUpdateError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, toResponse(p))
}

// writeUpdateError maps service errors to the stable envelope.
func writeUpdateError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, ErrUsernameTaken):
		httpserver.WriteError(w, r, http.StatusConflict, httpserver.CodeUsernameTaken, "username already in use")
	case errors.Is(err, ErrInvalidTimezone):
		httpserver.WriteError(w, r, http.StatusBadRequest, httpserver.CodeInvalidTimezone, "invalid timezone")
	case errors.Is(err, ErrInvalidArgument):
		httpserver.WriteError(w, r, http.StatusBadRequest, httpserver.CodeInvalidArgument, "invalid argument")
	default:
		httpserver.WriteError(w, r, http.StatusInternalServerError, httpserver.CodeInternal, "could not update profile")
	}
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}
