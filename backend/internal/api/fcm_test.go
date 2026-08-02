package api

import (
	"io"
	"log/slog"
	"net/http"
	"testing"
	"time"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
	"github.com/cloveclovedev/peppercheck/backend/internal/core/ratelimit"
	"github.com/cloveclovedev/peppercheck/backend/internal/identity"
	"github.com/cloveclovedev/peppercheck/backend/internal/notification"
	"github.com/cloveclovedev/peppercheck/backend/internal/profile"
)

// fcmStackFor builds an authed stack for a subject over an existing DB (no
// truncate), used to add a second user in the same test.
func fcmStackFor(db *database.Handle, subject string) http.Handler {
	profileStore := profile.NewStore(db)
	notifStore := notification.NewStore(db)
	idSvc := identity.NewService(identity.NewStore(db), NewProvisioner(profileStore, notifStore))
	discard := slog.New(slog.NewTextHandler(io.Discard, nil))
	return rootHandler(Deps{
		Verifier:     fakeVerifier(subject),
		Identity:     identity.NewHandler(idSvc, nil),
		Profile:      profile.NewHandler(profile.NewService(profileStore, &fakeUploader{}, testR2Domain, ratelimit.NewTokenBucket(10, 10, time.Hour, nil), discard)),
		Notification: notification.NewHandler(notification.NewService(notifStore)),
		ResolveUser:  identity.NewMiddleware(idSvc, nil),
	}, discard)
}

func TestPutAndDeleteToken(t *testing.T) {
	h, db := stackDeps(t, fakeVerifier("sub-A"), &fakeUploader{}, ratelimit.NewTokenBucket(10, 10, time.Hour, nil))

	if rec := do(t, h, "PUT", "/api/v1/me/fcm-tokens", "sub-A", map[string]string{"token": "tok", "deviceType": "android"}); rec.Code != http.StatusNoContent {
		t.Fatalf("PUT status = %d, want 204; body=%s", rec.Code, rec.Body.String())
	}
	var count int
	if err := db.QueryRow(`SELECT count(*) FROM public.device_push_tokens WHERE token = 'tok'`).Scan(&count); err != nil {
		t.Fatalf("count: %v", err)
	}
	if count != 1 {
		t.Fatalf("token rows = %d, want 1", count)
	}

	// Idempotent re-PUT.
	if rec := do(t, h, "PUT", "/api/v1/me/fcm-tokens", "sub-A", map[string]string{"token": "tok", "deviceType": "android"}); rec.Code != http.StatusNoContent {
		t.Fatalf("re-PUT status = %d, want 204", rec.Code)
	}

	if rec := do(t, h, "DELETE", "/api/v1/me/fcm-tokens", "sub-A", map[string]string{"token": "tok"}); rec.Code != http.StatusNoContent {
		t.Fatalf("DELETE status = %d, want 204", rec.Code)
	}
	if err := db.QueryRow(`SELECT count(*) FROM public.device_push_tokens WHERE token = 'tok'`).Scan(&count); err != nil {
		t.Fatalf("count after delete: %v", err)
	}
	if count != 0 {
		t.Fatalf("token rows after delete = %d, want 0", count)
	}
}

func TestPutTokenRejectsEmpty(t *testing.T) {
	h, _ := stackDeps(t, fakeVerifier("sub-A"), &fakeUploader{}, ratelimit.NewTokenBucket(10, 10, time.Hour, nil))
	rec := do(t, h, "PUT", "/api/v1/me/fcm-tokens", "sub-A", map[string]string{"token": "", "deviceType": "android"})
	if rec.Code != http.StatusBadRequest || errorCode(t, rec) != "invalid_argument" {
		t.Fatalf("status = %d code = %q, want 400 invalid_argument", rec.Code, errorCode(t, rec))
	}
}

func TestDeleteTokenIsOwnershipScoped(t *testing.T) {
	hA, db := stackDeps(t, fakeVerifier("sub-A"), &fakeUploader{}, ratelimit.NewTokenBucket(10, 10, time.Hour, nil))
	if rec := do(t, hA, "PUT", "/api/v1/me/fcm-tokens", "sub-A", map[string]string{"token": "tok-a", "deviceType": "android"}); rec.Code != http.StatusNoContent {
		t.Fatalf("A PUT: %d", rec.Code)
	}

	// User B tries to delete A's token -> 204 (no-op), but the row survives.
	hB := fcmStackFor(db, "sub-B")
	if rec := do(t, hB, "DELETE", "/api/v1/me/fcm-tokens", "sub-B", map[string]string{"token": "tok-a"}); rec.Code != http.StatusNoContent {
		t.Fatalf("B DELETE status = %d, want 204 (scoped no-op)", rec.Code)
	}
	var count int
	if err := db.QueryRow(`SELECT count(*) FROM public.device_push_tokens WHERE token = 'tok-a'`).Scan(&count); err != nil {
		t.Fatalf("count: %v", err)
	}
	if count != 1 {
		t.Fatalf("A's token must survive B's scoped delete; rows = %d", count)
	}
}
