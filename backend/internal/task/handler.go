package task

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"time"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/httpserver"
	"github.com/cloveclovedev/peppercheck/backend/internal/identity"
)

// Handler serves the task HTTP surface, scoped to the authenticated caller.
type Handler struct {
	svc *Service
}

// NewHandler builds a Handler over the task service.
func NewHandler(svc *Service) *Handler { return &Handler{svc: svc} }

// --- DTOs -----------------------------------------------------------------

type taskDTO struct {
	ID          string  `json:"id"`
	Title       string  `json:"title"`
	Description *string `json:"description"`
	Criteria    *string `json:"criteria"`
	DueDate     *string `json:"dueDate"`
	Status      string  `json:"status"`
	CreatedAt   string  `json:"createdAt"`
	UpdatedAt   string  `json:"updatedAt"`
}

func toDTO(t Task) taskDTO {
	dto := taskDTO{
		ID:          t.ID,
		Title:       t.Title,
		Description: t.Description,
		Criteria:    t.Criteria,
		Status:      t.Status,
		CreatedAt:   t.CreatedAt.UTC().Format(time.RFC3339),
		UpdatedAt:   t.UpdatedAt.UTC().Format(time.RFC3339),
	}
	if t.DueDate != nil {
		s := t.DueDate.UTC().Format(time.RFC3339)
		dto.DueDate = &s
	}
	return dto
}

type taskRequest struct {
	Title       string  `json:"title"`
	Description *string `json:"description"`
	Criteria    *string `json:"criteria"`
	DueDate     *string `json:"dueDate"`
}

func (req taskRequest) toInput() (DraftInput, error) {
	in := DraftInput{Title: req.Title, Description: req.Description, Criteria: req.Criteria}
	if req.DueDate != nil {
		due, err := time.Parse(time.RFC3339, *req.DueDate)
		if err != nil {
			return DraftInput{}, errors.Join(ErrValidation, err)
		}
		in.DueDate = &due
	}
	return in, nil
}

// --- handlers -------------------------------------------------------------

// PostTask creates a draft owned by the caller.
func (h *Handler) PostTask(w http.ResponseWriter, r *http.Request) {
	u, ok := currentUser(w, r)
	if !ok {
		return
	}
	var req taskRequest
	if !httpserver.DecodeJSON(w, r, &req) {
		return
	}
	in, err := req.toInput()
	if err != nil {
		h.writeError(w, r, err)
		return
	}
	t, err := h.svc.CreateDraft(r.Context(), u.ID, in)
	if err != nil {
		h.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, toDTO(t))
}

// GetTask returns a task the caller may read (owner or assigned referee).
func (h *Handler) GetTask(w http.ResponseWriter, r *http.Request) {
	u, ok := currentUser(w, r)
	if !ok {
		return
	}
	t, err := h.svc.GetReadable(r.Context(), u.ID, r.PathValue("id"))
	if err != nil {
		h.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, toDTO(t))
}

// PatchTask replaces the editable fields of a draft the caller owns.
func (h *Handler) PatchTask(w http.ResponseWriter, r *http.Request) {
	u, ok := currentUser(w, r)
	if !ok {
		return
	}
	var req taskRequest
	if !httpserver.DecodeJSON(w, r, &req) {
		return
	}
	in, err := req.toInput()
	if err != nil {
		h.writeError(w, r, err)
		return
	}
	t, err := h.svc.UpdateDraft(r.Context(), u.ID, r.PathValue("id"), in)
	if err != nil {
		h.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, toDTO(t))
}

// DeleteTask removes a draft the caller owns.
func (h *Handler) DeleteTask(w http.ResponseWriter, r *http.Request) {
	u, ok := currentUser(w, r)
	if !ok {
		return
	}
	if err := h.svc.DeleteDraft(r.Context(), u.ID, r.PathValue("id")); err != nil {
		h.writeError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// GetMyTasks lists the caller's tasks, optionally filtered by ?status= with
// ?limit=/?offset= paging (defaults: 50 / 0, capped at 100).
func (h *Handler) GetMyTasks(w http.ResponseWriter, r *http.Request) {
	u, ok := currentUser(w, r)
	if !ok {
		return
	}
	q := r.URL.Query()
	p := ListParams{
		Status: q.Get("status"),
		Limit:  clampInt(atoiOr(q.Get("limit"), 50), 1, 100),
		Offset: max(atoiOr(q.Get("offset"), 0), 0),
	}
	tasks, err := h.svc.ListOwned(r.Context(), u.ID, p)
	if err != nil {
		h.writeError(w, r, err)
		return
	}
	out := make([]taskDTO, 0, len(tasks))
	for _, t := range tasks {
		out = append(out, toDTO(t))
	}
	writeJSON(w, http.StatusOK, out)
}

type publishRequest struct {
	RefereeCount int `json:"refereeCount"`
}

// PostPublish opens a draft the caller owns and creates its referee requests.
func (h *Handler) PostPublish(w http.ResponseWriter, r *http.Request) {
	u, ok := currentUser(w, r)
	if !ok {
		return
	}
	var req publishRequest
	if !httpserver.DecodeJSON(w, r, &req) {
		return
	}
	t, err := h.svc.Publish(r.Context(), u.ID, r.PathValue("id"), req.RefereeCount)
	if err != nil {
		h.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, toDTO(t))
}

// --- helpers --------------------------------------------------------------

func currentUser(w http.ResponseWriter, r *http.Request) (identity.User, bool) {
	u, ok := identity.CurrentUser(r.Context())
	if !ok {
		httpserver.WriteError(w, r, http.StatusUnauthorized, httpserver.CodeUnauthenticated, "missing user")
	}
	return u, ok
}

func (h *Handler) writeError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, ErrNotFound):
		httpserver.WriteError(w, r, http.StatusNotFound, httpserver.CodeNotFound, "not found")
	case errors.Is(err, ErrForbidden):
		httpserver.WriteError(w, r, http.StatusForbidden, httpserver.CodeForbidden, "not allowed")
	case errors.Is(err, ErrConflict):
		httpserver.WriteError(w, r, http.StatusConflict, httpserver.CodeConflict, "task state conflict")
	case errors.Is(err, ErrValidation):
		httpserver.WriteError(w, r, http.StatusBadRequest, httpserver.CodeInvalidArgument, "invalid argument")
	default:
		httpserver.WriteError(w, r, http.StatusInternalServerError, httpserver.CodeInternal, "internal error")
	}
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func atoiOr(s string, def int) int {
	if s == "" {
		return def
	}
	n, err := strconv.Atoi(s)
	if err != nil {
		return def
	}
	return n
}

func clampInt(v, lo, hi int) int {
	return min(max(v, lo), hi)
}
