package matching

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"github.com/google/uuid"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/httpserver"
	"github.com/cloveclovedev/peppercheck/backend/internal/identity"
	"github.com/cloveclovedev/peppercheck/backend/internal/task"
)

const dateLayout = "2006-01-02"

// taskLoader renders the Task read-model for the cancel response. Declared here
// so the referee handler can return the §7.1 Task envelope after a cancel;
// task.Store satisfies it.
type taskLoader interface {
	LoadAggregate(ctx context.Context, taskID string) (task.Task, error)
}

// Handler serves the referee HTTP surface: availability CRUD and request
// cancellation, scoped to the authenticated caller. Availability reads/writes go
// straight to the store (plain CRUD); cancel goes through the service and
// renders the updated Task via the task loader. GET /matching/config exposes the
// public matching configuration.
type Handler struct {
	svc   *Service
	store *Store
	tasks taskLoader
}

// NewHandler builds a Handler over the matching service, store, and the task
// loader used to render the cancel response.
func NewHandler(svc *Service, store *Store, tasks taskLoader) *Handler {
	return &Handler{svc: svc, store: store, tasks: tasks}
}

// --- DTOs -----------------------------------------------------------------

type timeSlotDTO struct {
	ID       string `json:"id"`
	DOW      int    `json:"dow"`
	StartMin int    `json:"startMin"`
	EndMin   int    `json:"endMin"`
	IsActive bool   `json:"isActive"`
}

type timeSlotRequest struct {
	DOW      int   `json:"dow"`
	StartMin int   `json:"startMin"`
	EndMin   int   `json:"endMin"`
	IsActive *bool `json:"isActive"` // defaults to true when omitted
}

func (r timeSlotRequest) toDomain() TimeSlot {
	active := true
	if r.IsActive != nil {
		active = *r.IsActive
	}
	return TimeSlot{DOW: r.DOW, StartMin: r.StartMin, EndMin: r.EndMin, IsActive: active}
}

func toTimeSlotDTO(s TimeSlot) timeSlotDTO {
	return timeSlotDTO{ID: s.ID, DOW: s.DOW, StartMin: s.StartMin, EndMin: s.EndMin, IsActive: s.IsActive}
}

type blockedDateDTO struct {
	ID        string  `json:"id"`
	StartDate string  `json:"startDate"`
	EndDate   string  `json:"endDate"`
	Reason    *string `json:"reason"`
}

type blockedDateRequest struct {
	StartDate string  `json:"startDate"`
	EndDate   string  `json:"endDate"`
	Reason    *string `json:"reason"`
}

func toBlockedDateDTO(b BlockedDate) blockedDateDTO {
	return blockedDateDTO{
		ID:        b.ID,
		StartDate: b.StartDate.Format(dateLayout),
		EndDate:   b.EndDate.Format(dateLayout),
		Reason:    b.Reason,
	}
}

type matchingConfigDTO struct {
	OpenDeadlineHours   int `json:"openDeadlineHours"`
	CancelDeadlineHours int `json:"cancelDeadlineHours"`
	RematchCutoffHours  int `json:"rematchCutoffHours"`
	MaxRefereesPerTask  int `json:"maxRefereesPerTask"`
	MatchingPointCost   int `json:"matchingPointCost"`
}

// GetConfig returns the public matching configuration (deadlines + limits).
func (h *Handler) GetConfig(w http.ResponseWriter, r *http.Request) {
	cfg, err := h.store.LoadConfig(r.Context())
	if err != nil {
		httpserver.WriteError(w, r, http.StatusInternalServerError, httpserver.CodeInternal, "internal error")
		return
	}
	writeJSON(w, http.StatusOK, matchingConfigDTO{
		OpenDeadlineHours:   cfg.OpenDeadlineHours,
		CancelDeadlineHours: cfg.CancelDeadlineHours,
		RematchCutoffHours:  cfg.RematchCutoffHours,
		MaxRefereesPerTask:  cfg.MaxRefereesPerTask,
		MatchingPointCost:   cfg.PointCostPerRequest,
	})
}

// --- time slots -----------------------------------------------------------

// GetTimeSlots lists the caller's availability slots.
func (h *Handler) GetTimeSlots(w http.ResponseWriter, r *http.Request) {
	u, ok := currentUser(w, r)
	if !ok {
		return
	}
	slots, err := h.store.ListTimeSlots(r.Context(), u.ID)
	if err != nil {
		h.writeError(w, r, err)
		return
	}
	out := make([]timeSlotDTO, 0, len(slots))
	for _, s := range slots {
		out = append(out, toTimeSlotDTO(s))
	}
	writeJSON(w, http.StatusOK, map[string]any{"timeSlots": out})
}

// PostTimeSlot creates a slot for the caller.
func (h *Handler) PostTimeSlot(w http.ResponseWriter, r *http.Request) {
	u, ok := currentUser(w, r)
	if !ok {
		return
	}
	var req timeSlotRequest
	if !httpserver.DecodeJSON(w, r, &req) {
		return
	}
	slot := req.toDomain()
	if err := slot.Validate(); err != nil {
		h.writeError(w, r, err)
		return
	}
	created, err := h.store.CreateTimeSlot(r.Context(), u.ID, slot)
	if err != nil {
		h.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, toTimeSlotDTO(created))
}

// PutTimeSlot updates a slot the caller owns.
func (h *Handler) PutTimeSlot(w http.ResponseWriter, r *http.Request) {
	u, ok := currentUser(w, r)
	if !ok {
		return
	}
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	var req timeSlotRequest
	if !httpserver.DecodeJSON(w, r, &req) {
		return
	}
	slot := req.toDomain()
	if err := slot.Validate(); err != nil {
		h.writeError(w, r, err)
		return
	}
	if err := h.store.UpdateTimeSlot(r.Context(), u.ID, id, slot); err != nil {
		h.writeError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// DeleteTimeSlot removes a slot the caller owns.
func (h *Handler) DeleteTimeSlot(w http.ResponseWriter, r *http.Request) {
	u, ok := currentUser(w, r)
	if !ok {
		return
	}
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	if err := h.store.DeleteTimeSlot(r.Context(), u.ID, id); err != nil {
		h.writeError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// --- blocked dates --------------------------------------------------------

// GetBlockedDates lists the caller's blocked date ranges.
func (h *Handler) GetBlockedDates(w http.ResponseWriter, r *http.Request) {
	u, ok := currentUser(w, r)
	if !ok {
		return
	}
	dates, err := h.store.ListBlockedDates(r.Context(), u.ID)
	if err != nil {
		h.writeError(w, r, err)
		return
	}
	out := make([]blockedDateDTO, 0, len(dates))
	for _, b := range dates {
		out = append(out, toBlockedDateDTO(b))
	}
	writeJSON(w, http.StatusOK, map[string]any{"blockedDates": out})
}

// PostBlockedDate creates a blocked range for the caller.
func (h *Handler) PostBlockedDate(w http.ResponseWriter, r *http.Request) {
	u, ok := currentUser(w, r)
	if !ok {
		return
	}
	var req blockedDateRequest
	if !httpserver.DecodeJSON(w, r, &req) {
		return
	}
	b, err := parseBlockedDate(req)
	if err != nil {
		h.writeError(w, r, err)
		return
	}
	created, err := h.store.CreateBlockedDate(r.Context(), u.ID, b)
	if err != nil {
		h.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, toBlockedDateDTO(created))
}

// PutBlockedDate updates a blocked range the caller owns.
func (h *Handler) PutBlockedDate(w http.ResponseWriter, r *http.Request) {
	u, ok := currentUser(w, r)
	if !ok {
		return
	}
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	var req blockedDateRequest
	if !httpserver.DecodeJSON(w, r, &req) {
		return
	}
	b, err := parseBlockedDate(req)
	if err != nil {
		h.writeError(w, r, err)
		return
	}
	if err := h.store.UpdateBlockedDate(r.Context(), u.ID, id, b); err != nil {
		h.writeError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// DeleteBlockedDate removes a blocked range the caller owns.
func (h *Handler) DeleteBlockedDate(w http.ResponseWriter, r *http.Request) {
	u, ok := currentUser(w, r)
	if !ok {
		return
	}
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	if err := h.store.DeleteBlockedDate(r.Context(), u.ID, id); err != nil {
		h.writeError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func parseBlockedDate(req blockedDateRequest) (BlockedDate, error) {
	start, err := time.Parse(dateLayout, req.StartDate)
	if err != nil {
		return BlockedDate{}, errors.Join(ErrValidation, err)
	}
	end, err := time.Parse(dateLayout, req.EndDate)
	if err != nil {
		return BlockedDate{}, errors.Join(ErrValidation, err)
	}
	b := BlockedDate{StartDate: start, EndDate: end, Reason: req.Reason}
	if err := b.Validate(); err != nil {
		return BlockedDate{}, err
	}
	return b, nil
}

// --- cancel ---------------------------------------------------------------

// PostCancel cancels the caller's accepted request, triggers a re-match, and
// returns the updated Task (§7.1).
func (h *Handler) PostCancel(w http.ResponseWriter, r *http.Request) {
	u, ok := currentUser(w, r)
	if !ok {
		return
	}
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	taskID, err := h.svc.Cancel(r.Context(), id, u.ID)
	if err != nil {
		h.writeError(w, r, err)
		return
	}
	t, err := h.tasks.LoadAggregate(r.Context(), taskID)
	if err != nil {
		h.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, task.TaskResponse(t))
}

// --- helpers --------------------------------------------------------------

func currentUser(w http.ResponseWriter, r *http.Request) (identity.User, bool) {
	u, ok := identity.CurrentUser(r.Context())
	if !ok {
		httpserver.WriteError(w, r, http.StatusUnauthorized, httpserver.CodeUnauthenticated, "missing user")
	}
	return u, ok
}

// pathID reads and validates the {id} path parameter as a UUID, rejecting a
// malformed id as a 400 before it reaches a uuid-typed query (which would
// otherwise surface as a 500 invalid-text-representation error).
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
	case errors.Is(err, ErrConflict), errors.Is(err, ErrCancelDeadlinePassed):
		httpserver.WriteError(w, r, http.StatusConflict, httpserver.CodeConflict, "request state conflict")
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
