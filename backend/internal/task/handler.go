package task

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/google/uuid"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/httpserver"
	"github.com/cloveclovedev/peppercheck/backend/internal/identity"
)

const defaultPageLimit = 20

// Handler serves the task HTTP surface (the §7.1 wire contract), scoped to the
// authenticated caller.
type Handler struct {
	svc *Service
}

// NewHandler builds a Handler over the task service.
func NewHandler(svc *Service) *Handler { return &Handler{svc: svc} }

// --- DTOs (§7.1) ----------------------------------------------------------

type publicProfileDTO struct {
	UserID    string  `json:"userId"`
	Username  string  `json:"username"`
	AvatarURL *string `json:"avatarUrl"`
}

func toProfileDTO(p *PublicProfile) *publicProfileDTO {
	if p == nil {
		return nil
	}
	return &publicProfileDTO{UserID: p.UserID, Username: p.Username, AvatarURL: p.AvatarURL}
}

type refereeRequestDTO struct {
	ID               string            `json:"id"`
	TaskID           string            `json:"taskId"`
	Status           string            `json:"status"`
	MatchedRefereeID *string           `json:"matchedRefereeId"`
	RespondedAt      *string           `json:"respondedAt"`
	PointSource      *string           `json:"pointSource"`
	IsObligation     bool              `json:"isObligation"`
	CreatedAt        string            `json:"createdAt"`
	UpdatedAt        string            `json:"updatedAt"`
	Referee          *publicProfileDTO `json:"referee"`
}

type taskDTO struct {
	ID              string              `json:"id"`
	TaskerID        string              `json:"taskerId"`
	Title           string              `json:"title"`
	Description     *string             `json:"description"`
	Criteria        *string             `json:"criteria"`
	DueDate         *string             `json:"dueDate"`
	Status          string              `json:"status"`
	CreatedAt       string              `json:"createdAt"`
	UpdatedAt       string              `json:"updatedAt"`
	Tasker          *publicProfileDTO   `json:"tasker"`
	RefereeRequests []refereeRequestDTO `json:"refereeRequests"`
}

func rfc3339Ptr(t *time.Time) *string {
	if t == nil {
		return nil
	}
	s := t.UTC().Format(time.RFC3339)
	return &s
}

func toDTO(t Task) taskDTO {
	reqs := make([]refereeRequestDTO, 0, len(t.RefereeRequests))
	for _, r := range t.RefereeRequests {
		reqs = append(reqs, refereeRequestDTO{
			ID:               r.ID,
			TaskID:           r.TaskID,
			Status:           r.Status,
			MatchedRefereeID: r.MatchedRefereeID,
			RespondedAt:      rfc3339Ptr(r.RespondedAt),
			PointSource:      r.PointSource,
			IsObligation:     r.IsObligation,
			CreatedAt:        r.CreatedAt.UTC().Format(time.RFC3339),
			UpdatedAt:        r.UpdatedAt.UTC().Format(time.RFC3339),
			Referee:          toProfileDTO(r.Referee),
		})
	}
	return taskDTO{
		ID:              t.ID,
		TaskerID:        t.TaskerID,
		Title:           t.Title,
		Description:     t.Description,
		Criteria:        t.Criteria,
		DueDate:         rfc3339Ptr(t.DueDate),
		Status:          t.Status,
		CreatedAt:       t.CreatedAt.UTC().Format(time.RFC3339),
		UpdatedAt:       t.UpdatedAt.UTC().Format(time.RFC3339),
		Tasker:          toProfileDTO(t.Tasker),
		RefereeRequests: reqs,
	}
}

func nextCursorPtr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

type tasksPageDTO struct {
	Tasks      []taskDTO `json:"tasks"`
	NextCursor *string   `json:"nextCursor"`
}

type assignmentsPageDTO struct {
	Assignments []taskDTO `json:"assignments"`
	NextCursor  *string   `json:"nextCursor"`
}

func toTaskDTOs(tasks []Task) []taskDTO {
	out := make([]taskDTO, 0, len(tasks))
	for _, t := range tasks {
		out = append(out, toDTO(t))
	}
	return out
}

// TaskResponse renders a Task as its §7.1 wire object, for cross-feature
// handlers that must return a Task (e.g. matching's cancel endpoint) without
// re-implementing the DTO.
func TaskResponse(t Task) any { return toDTO(t) }

// --- request bodies -------------------------------------------------------

type createTaskRequest struct {
	Title       string  `json:"title"`
	Description *string `json:"description"`
	Criteria    *string `json:"criteria"`
	DueDate     *string `json:"dueDate"`
}

func (req createTaskRequest) toInput() (DraftInput, error) {
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
	var req createTaskRequest
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
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	t, err := h.svc.GetReadable(r.Context(), u.ID, id)
	if err != nil {
		h.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, toDTO(t))
}

// PatchTask applies a presence-aware partial update to a draft the caller owns.
func (h *Handler) PatchTask(w http.ResponseWriter, r *http.Request) {
	u, ok := currentUser(w, r)
	if !ok {
		return
	}
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	patch, err := decodePatch(r)
	if err != nil {
		h.writeError(w, r, err)
		return
	}
	t, err := h.svc.UpdateDraft(r.Context(), u.ID, id, patch)
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
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	if err := h.svc.DeleteDraft(r.Context(), u.ID, id); err != nil {
		h.writeError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// GetMyTasks lists the caller's tasks as a cursor page (?status=&cursor=&limit=).
func (h *Handler) GetMyTasks(w http.ResponseWriter, r *http.Request) {
	u, ok := currentUser(w, r)
	if !ok {
		return
	}
	q := r.URL.Query()
	page, err := h.svc.ListOwned(r.Context(), u.ID, q.Get("status"), q.Get("cursor"), pageLimit(q.Get("limit")))
	if err != nil {
		h.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, tasksPageDTO{Tasks: toTaskDTOs(page.Tasks), NextCursor: nextCursorPtr(page.NextCursor)})
}

// GetAssignments lists the tasks the caller referees as a cursor page.
func (h *Handler) GetAssignments(w http.ResponseWriter, r *http.Request) {
	u, ok := currentUser(w, r)
	if !ok {
		return
	}
	q := r.URL.Query()
	page, err := h.svc.Assignments(r.Context(), u.ID, q.Get("cursor"), pageLimit(q.Get("limit")))
	if err != nil {
		h.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, assignmentsPageDTO{Assignments: toTaskDTOs(page.Tasks), NextCursor: nextCursorPtr(page.NextCursor)})
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
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	var req publishRequest
	if !httpserver.DecodeJSON(w, r, &req) {
		return
	}
	t, err := h.svc.Publish(r.Context(), u.ID, id, req.RefereeCount)
	if err != nil {
		h.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, toDTO(t))
}

// --- helpers --------------------------------------------------------------

// decodePatch parses a presence-aware PATCH body: only the keys present in the
// JSON are marked for update, so an omitted field is untouched while an explicit
// null clears a nullable field. Unknown keys and a malformed dueDate are 400.
func decodePatch(r *http.Request) (PatchInput, error) {
	var raw map[string]json.RawMessage
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(&raw); err != nil {
		return PatchInput{}, fmt.Errorf("%w: invalid request body", ErrValidation)
	}
	var p PatchInput
	for k, v := range raw {
		switch k {
		case "title":
			p.SetTitle = true
			if err := json.Unmarshal(v, &p.Title); err != nil {
				return PatchInput{}, fmt.Errorf("%w: title", ErrValidation)
			}
		case "description":
			p.SetDesc = true
			if err := json.Unmarshal(v, &p.Description); err != nil {
				return PatchInput{}, fmt.Errorf("%w: description", ErrValidation)
			}
		case "criteria":
			p.SetCriteria = true
			if err := json.Unmarshal(v, &p.Criteria); err != nil {
				return PatchInput{}, fmt.Errorf("%w: criteria", ErrValidation)
			}
		case "dueDate":
			p.SetDueDate = true
			var s *string
			if err := json.Unmarshal(v, &s); err != nil {
				return PatchInput{}, fmt.Errorf("%w: dueDate", ErrValidation)
			}
			if s != nil {
				due, err := time.Parse(time.RFC3339, *s)
				if err != nil {
					return PatchInput{}, fmt.Errorf("%w: dueDate must be RFC3339", ErrValidation)
				}
				p.DueDate = &due
			}
		default:
			return PatchInput{}, fmt.Errorf("%w: unknown field %q", ErrValidation, k)
		}
	}
	return p, nil
}

func currentUser(w http.ResponseWriter, r *http.Request) (identity.User, bool) {
	u, ok := identity.CurrentUser(r.Context())
	if !ok {
		httpserver.WriteError(w, r, http.StatusUnauthorized, httpserver.CodeUnauthenticated, "missing user")
	}
	return u, ok
}

// pathID reads and validates the {id} path parameter as a UUID, rejecting a
// malformed id as a 400 before it reaches a uuid-typed query.
func pathID(w http.ResponseWriter, r *http.Request) (string, bool) {
	id := r.PathValue("id")
	if uuid.Validate(id) != nil {
		httpserver.WriteError(w, r, http.StatusBadRequest, httpserver.CodeInvalidArgument, "invalid id")
		return "", false
	}
	return id, true
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

// pageLimit parses ?limit= with a default of 20, clamped to 1..100.
func pageLimit(s string) int {
	if s == "" {
		return defaultPageLimit
	}
	n, err := strconv.Atoi(s)
	if err != nil {
		return defaultPageLimit
	}
	return min(max(n, 1), 100)
}
