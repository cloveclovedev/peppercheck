package api

import (
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"testing"
	"time"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
	"github.com/cloveclovedev/peppercheck/backend/internal/core/jobs"
	"github.com/cloveclovedev/peppercheck/backend/internal/identity"
	"github.com/cloveclovedev/peppercheck/backend/internal/judgement"
	"github.com/cloveclovedev/peppercheck/backend/internal/matching"
	"github.com/cloveclovedev/peppercheck/backend/internal/notification"
	"github.com/cloveclovedev/peppercheck/backend/internal/platform/auth"
	"github.com/cloveclovedev/peppercheck/backend/internal/platform/fcm"
	"github.com/cloveclovedev/peppercheck/backend/internal/profile"
	"github.com/cloveclovedev/peppercheck/backend/internal/task"
	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
)

// taskStack builds the full authed stack with the task + referee handlers over a
// truncated DB. Both are wired exactly as main.go wires the api process (no-op
// FCM notifier, no-op Phase 5 seams).
func taskStack(t *testing.T, v auth.TokenVerifier) (http.Handler, *database.Handle) {
	t.Helper()
	db := testsupport.DB(t)
	if _, err := db.Exec("TRUNCATE public.users CASCADE"); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	discard := slog.New(slog.NewTextHandler(io.Discard, nil))
	notifStore := notification.NewStore(db)
	idSvc := identity.NewService(identity.NewStore(db), NewProvisioner(profile.NewStore(db), notifStore))
	matchingStore := matching.NewStore(db)
	matchingSvc := matching.NewService(
		db, matchingStore,
		matching.NewNoopPointLocker(), matching.NewNoObligations(),
		judgement.NewProvisioner(),
		notification.NewSender(notifStore, fcm.NewNoop(discard)),
		jobs.NewStore(db),
	)
	taskStore := task.NewStore(db)
	taskSvc := task.NewService(db, taskStore, matchingSvc)
	h := rootHandler(Deps{
		Verifier:    v,
		Identity:    identity.NewHandler(idSvc, nil),
		Task:        task.NewHandler(taskSvc),
		Referee:     matching.NewHandler(matchingSvc, matchingStore, taskStore),
		ResolveUser: identity.NewMiddleware(idSvc, nil),
	}, discard)
	return h, db
}

func TestTaskCreatePublishFlow(t *testing.T) {
	h, db := taskStack(t, fakeVerifier("sub-A"))
	due := time.Now().Add(48 * time.Hour).UTC().Format(time.RFC3339)

	rec := do(t, h, "POST", "/api/v1/tasks", "sub-A", map[string]any{
		"title": "Wash the car", "criteria": "photo of a clean car", "dueDate": due,
	})
	if rec.Code != http.StatusCreated {
		t.Fatalf("create: status %d; body=%s", rec.Code, rec.Body.String())
	}
	var created struct {
		ID              string           `json:"id"`
		Status          string           `json:"status"`
		RefereeRequests []map[string]any `json:"refereeRequests"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &created); err != nil {
		t.Fatalf("unmarshal created: %v", err)
	}
	if created.Status != "draft" {
		t.Fatalf("want draft, got %s", created.Status)
	}
	if created.RefereeRequests == nil || len(created.RefereeRequests) != 0 {
		t.Fatalf("draft must carry refereeRequests: [] (not null), got %v", created.RefereeRequests)
	}

	rec = do(t, h, "POST", "/api/v1/tasks/"+created.ID+"/publish", "sub-A", map[string]int{"refereeCount": 2})
	if rec.Code != http.StatusOK {
		t.Fatalf("publish: status %d; body=%s", rec.Code, rec.Body.String())
	}
	var published struct {
		Status   string `json:"status"`
		TaskerID string `json:"taskerId"`
		Tasker   *struct {
			UserID   string `json:"userId"`
			Username string `json:"username"`
		} `json:"tasker"`
		RefereeRequests []struct {
			Status string `json:"status"`
		} `json:"refereeRequests"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &published)
	if published.Status != "open" {
		t.Fatalf("want open, got %s", published.Status)
	}
	if published.TaskerID == "" || published.Tasker == nil || published.Tasker.UserID != published.TaskerID {
		t.Fatalf("publish response must embed taskerId + tasker profile, got %+v", published)
	}
	if len(published.RefereeRequests) != 2 {
		t.Fatalf("publish response must carry 2 refereeRequests, got %d", len(published.RefereeRequests))
	}
	for _, rr := range published.RefereeRequests {
		if rr.Status != "pending" {
			t.Fatalf("want pending requests, got %s", rr.Status)
		}
	}

	var requests, pending int
	_ = db.QueryRow(`SELECT count(*), count(*) FILTER (WHERE status='pending') FROM public.referee_requests WHERE task_id=$1`, created.ID).Scan(&requests, &pending)
	if requests != 2 || pending != 2 {
		t.Fatalf("want 2 pending requests, got total=%d pending=%d", requests, pending)
	}
	var jobsCount int
	_ = db.QueryRow(`SELECT count(*) FROM public.jobs WHERE kind='match_referee_request'
		AND payload->>'requestId' IN (SELECT id::text FROM public.referee_requests WHERE task_id=$1)`, created.ID).Scan(&jobsCount)
	if jobsCount != 2 {
		t.Fatalf("want 2 match jobs, got %d", jobsCount)
	}
}

func TestTaskCrossOwnerEditIsNotFound(t *testing.T) {
	// A creates a draft; B may not edit it (scoped away -> 404, not 403, so B
	// cannot even probe its existence).
	hA, _ := taskStack(t, fakeVerifier("sub-A"))
	rec := do(t, hA, "POST", "/api/v1/tasks", "sub-A", map[string]any{"title": "A's task"})
	var created struct {
		ID string `json:"id"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &created)

	hB, _ := taskStack(t, fakeVerifier("sub-B"))
	rec = do(t, hB, "PATCH", "/api/v1/tasks/"+created.ID, "sub-B", map[string]any{"title": "hijack"})
	if rec.Code != http.StatusNotFound {
		t.Fatalf("cross-owner edit: status %d, want 404; body=%s", rec.Code, rec.Body.String())
	}
}

func TestPublishMissingCriteriaIs400(t *testing.T) {
	h, _ := taskStack(t, fakeVerifier("sub-A"))
	due := time.Now().Add(48 * time.Hour).UTC().Format(time.RFC3339)
	rec := do(t, h, "POST", "/api/v1/tasks", "sub-A", map[string]any{"title": "no criteria", "dueDate": due})
	var created struct {
		ID string `json:"id"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &created)

	rec = do(t, h, "POST", "/api/v1/tasks/"+created.ID+"/publish", "sub-A", map[string]int{"refereeCount": 1})
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("publish without criteria: status %d, want 400; body=%s", rec.Code, rec.Body.String())
	}
}

func TestRefereeTimeSlotCreateValidatesAndLists(t *testing.T) {
	h, _ := taskStack(t, fakeVerifier("sub-A"))

	// Invalid: endMin before startMin -> 400.
	rec := do(t, h, "POST", "/api/v1/me/availability/time-slots", "sub-A", map[string]any{"dow": 1, "startMin": 600, "endMin": 500})
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("invalid slot: status %d, want 400; body=%s", rec.Code, rec.Body.String())
	}

	// Valid -> 201, then it appears in the list.
	rec = do(t, h, "POST", "/api/v1/me/availability/time-slots", "sub-A", map[string]any{"dow": 1, "startMin": 540, "endMin": 1020})
	if rec.Code != http.StatusCreated {
		t.Fatalf("valid slot: status %d, want 201; body=%s", rec.Code, rec.Body.String())
	}
	rec = do(t, h, "GET", "/api/v1/me/availability/time-slots", "sub-A", nil)
	var slotsEnv struct {
		TimeSlots []map[string]any `json:"timeSlots"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &slotsEnv)
	if len(slotsEnv.TimeSlots) != 1 {
		t.Fatalf("want 1 slot under timeSlots, got %d; body=%s", len(slotsEnv.TimeSlots), rec.Body.String())
	}
}

func TestMyTasksEnvelopeAndConfig(t *testing.T) {
	h, _ := taskStack(t, fakeVerifier("sub-A"))
	// Create a draft so the list is non-empty.
	do(t, h, "POST", "/api/v1/tasks", "sub-A", map[string]any{"title": "t"})

	rec := do(t, h, "GET", "/api/v1/me/tasks", "sub-A", nil)
	var page struct {
		Tasks      []map[string]any `json:"tasks"`
		NextCursor *string          `json:"nextCursor"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &page); err != nil {
		t.Fatalf("decode tasks envelope: %v; body=%s", err, rec.Body.String())
	}
	if len(page.Tasks) != 1 {
		t.Fatalf("want 1 task in the envelope, got %d", len(page.Tasks))
	}

	// GET /matching/config is public and exposes the seeded limits.
	rec = do(t, h, "GET", "/api/v1/matching/config", "sub-A", nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("config: status %d; body=%s", rec.Code, rec.Body.String())
	}
	var cfg struct {
		MaxRefereesPerTask  int `json:"maxRefereesPerTask"`
		CancelDeadlineHours int `json:"cancelDeadlineHours"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &cfg)
	if cfg.MaxRefereesPerTask != 2 || cfg.CancelDeadlineHours != 12 {
		t.Fatalf("unexpected config %+v", cfg)
	}
}

func TestMalformedIDPathParamsAre400(t *testing.T) {
	h, _ := taskStack(t, fakeVerifier("sub-A"))
	// Malformed (non-uuid) ids must be rejected at the boundary as 400, not reach
	// the uuid-typed query and surface as a 500.
	cases := []struct{ method, path string }{
		{"GET", "/api/v1/tasks/not-a-uuid"},
		{"PATCH", "/api/v1/tasks/not-a-uuid"},
		{"DELETE", "/api/v1/tasks/not-a-uuid"},
		{"POST", "/api/v1/tasks/not-a-uuid/publish"},
		{"POST", "/api/v1/referee-requests/not-a-uuid/cancel"},
		{"PUT", "/api/v1/me/availability/time-slots/not-a-uuid"},
		{"DELETE", "/api/v1/me/availability/blocked-dates/not-a-uuid"},
	}
	for _, c := range cases {
		var body any
		if c.method == "PATCH" || (c.method == "POST" && c.path != "/api/v1/referee-requests/not-a-uuid/cancel") {
			body = map[string]any{"title": "x", "refereeCount": 1}
		}
		if c.method == "PUT" {
			body = map[string]any{"dow": 1, "startMin": 0, "endMin": 1}
		}
		rec := do(t, h, c.method, c.path, "sub-A", body)
		if rec.Code != http.StatusBadRequest {
			t.Fatalf("%s %s: status %d, want 400; body=%s", c.method, c.path, rec.Code, rec.Body.String())
		}
	}
}

func TestCancelForbiddenAndNotFound(t *testing.T) {
	h, db := taskStack(t, fakeVerifier("sub-A"))
	_ = meID(t, h, "sub-A") // provision A

	// Missing request -> 404.
	rec := do(t, h, "POST", "/api/v1/referee-requests/00000000-0000-0000-0000-000000000000/cancel", "sub-A", nil)
	if rec.Code != http.StatusNotFound {
		t.Fatalf("cancel missing: status %d, want 404; body=%s", rec.Code, rec.Body.String())
	}

	// A request accepted by someone else -> A cancelling it is 403.
	var otherUser, taskID, reqID string
	_ = db.QueryRow(`INSERT INTO public.users DEFAULT VALUES RETURNING id`).Scan(&otherUser)
	_ = db.QueryRow(`INSERT INTO public.tasks (tasker_id, title, status, due_date) VALUES ($1,'t','open', now()+interval '30 days') RETURNING id`, otherUser).Scan(&taskID)
	_ = db.QueryRow(`INSERT INTO public.referee_requests (task_id, status, matched_referee_id) VALUES ($1,'accepted',$2) RETURNING id`, taskID, otherUser).Scan(&reqID)

	rec = do(t, h, "POST", "/api/v1/referee-requests/"+reqID+"/cancel", "sub-A", nil)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("cancel other's request: status %d, want 403; body=%s", rec.Code, rec.Body.String())
	}
}
