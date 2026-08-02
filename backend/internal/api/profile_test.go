package api

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
	"github.com/cloveclovedev/peppercheck/backend/internal/core/ratelimit"
	"github.com/cloveclovedev/peppercheck/backend/internal/identity"
	"github.com/cloveclovedev/peppercheck/backend/internal/notification"
	"github.com/cloveclovedev/peppercheck/backend/internal/platform/auth"
	"github.com/cloveclovedev/peppercheck/backend/internal/platform/r2"
	"github.com/cloveclovedev/peppercheck/backend/internal/profile"
	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
)

const testR2Domain = "cdn.example.com"

// fakeUploader implements r2.Uploader for the api integration tests.
type fakeUploader struct {
	headMeta  r2.ObjectMetadata
	headErr   error
	deleted   []string
	deleteErr error
}

func (f *fakeUploader) PresignPut(_ context.Context, in r2.PresignPutInput) (string, error) {
	return "https://acct.r2.cloudflarestorage.com/bucket/" + in.Key + "?X-Amz-Signature=x", nil
}
func (f *fakeUploader) Head(_ context.Context, _ string) (r2.ObjectMetadata, error) {
	return f.headMeta, f.headErr
}
func (f *fakeUploader) Delete(_ context.Context, key string) error {
	f.deleted = append(f.deleted, key)
	return f.deleteErr
}

// stackDeps builds the full authed stack over a truncated DB with a fake
// verifier, uploader, and limiter, plus the *sql.DB for direct assertions.
func stackDeps(t *testing.T, v auth.TokenVerifier, up r2.Uploader, limiter profile.Limiter) (http.Handler, *database.Handle) {
	t.Helper()
	db := testsupport.DB(t)
	if _, err := db.Exec("TRUNCATE public.users CASCADE"); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	profileStore := profile.NewStore(db)
	notifStore := notification.NewStore(db)
	idSvc := identity.NewService(identity.NewStore(db), NewProvisioner(profileStore, notifStore))
	discard := slog.New(slog.NewTextHandler(io.Discard, nil))
	profileSvc := profile.NewService(profileStore, up, testR2Domain, limiter, discard)
	h := rootHandler(Deps{
		Verifier:     v,
		Identity:     identity.NewHandler(idSvc, nil),
		Profile:      profile.NewHandler(profileSvc),
		Notification: notification.NewHandler(notification.NewService(notifStore)),
		ResolveUser:  identity.NewMiddleware(idSvc, nil),
	}, discard)
	return h, db
}

func do(t *testing.T, h http.Handler, method, path, subject string, body any) *httptest.ResponseRecorder {
	t.Helper()
	var r io.Reader
	if body != nil {
		b, _ := json.Marshal(body)
		r = bytes.NewReader(b)
	}
	req := httptest.NewRequest(method, path, r)
	req.Header.Set("Authorization", "Bearer "+subject) // FakeVerifier ignores it; subject set on the verifier
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec
}

func fakeVerifier(subject string) *auth.FakeVerifier {
	return &auth.FakeVerifier{Identity: auth.Identity{Issuer: "iss", Subject: subject}}
}

func TestProfileProvisionedAndIdless(t *testing.T) {
	up := &fakeUploader{}
	h, _ := stackDeps(t, fakeVerifier("sub-A"), up, ratelimit.NewTokenBucket(10, 10, time.Hour, nil))

	rec := do(t, h, "GET", "/api/v1/me/profile", "sub-A", nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200; body=%s", rec.Code, rec.Body.String())
	}
	// The generated username is present; the DTO is idless.
	var raw map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &raw); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if _, hasID := raw["id"]; hasID {
		t.Fatal("profile DTO must be idless")
	}
	username, _ := raw["username"].(string)
	if !strings.HasPrefix(username, "user_") {
		t.Fatalf("username = %q, want a generated user_ name", username)
	}
	if raw["timezone"] != "UTC" {
		t.Fatalf("timezone = %v, want UTC", raw["timezone"])
	}
}

func TestPatchUsernameHappyAndConflict(t *testing.T) {
	up := &fakeUploader{}
	limiter := ratelimit.NewTokenBucket(10, 10, time.Hour, nil)

	// FakeVerifier returns a fixed identity per stack, so A and B are separate
	// stacks over the same DB. User A takes "alice".
	hA, db := stackDeps(t, fakeVerifier("sub-A"), up, limiter)
	if rec := do(t, hA, "PATCH", "/api/v1/me/profile", "sub-A", map[string]string{"username": "alice"}); rec.Code != http.StatusOK {
		t.Fatalf("A patch status = %d; body=%s", rec.Code, rec.Body.String())
	}

	// User B (same DB) provisions, then tries to take "alice" -> 409.
	profileStore := profile.NewStore(db)
	notifStore := notification.NewStore(db)
	idSvc := identity.NewService(identity.NewStore(db), NewProvisioner(profileStore, notifStore))
	discard := slog.New(slog.NewTextHandler(io.Discard, nil))
	hB := rootHandler(Deps{
		Verifier:     fakeVerifier("sub-B"),
		Identity:     identity.NewHandler(idSvc, nil),
		Profile:      profile.NewHandler(profile.NewService(profileStore, up, testR2Domain, limiter, discard)),
		Notification: notification.NewHandler(notification.NewService(notifStore)),
		ResolveUser:  identity.NewMiddleware(idSvc, nil),
	}, discard)

	rec := do(t, hB, "PATCH", "/api/v1/me/profile", "sub-B", map[string]string{"username": "alice"})
	if rec.Code != http.StatusConflict {
		t.Fatalf("B patch status = %d, want 409; body=%s", rec.Code, rec.Body.String())
	}
	if code := errorCode(t, rec); code != "username_taken" {
		t.Fatalf("code = %q, want username_taken", code)
	}
}

func TestPatchInvalidTimezone(t *testing.T) {
	h, _ := stackDeps(t, fakeVerifier("sub-A"), &fakeUploader{}, ratelimit.NewTokenBucket(10, 10, time.Hour, nil))
	rec := do(t, h, "PATCH", "/api/v1/me/profile", "sub-A", map[string]string{"timezone": "Nowhere/Nope"})
	if rec.Code != http.StatusBadRequest || errorCode(t, rec) != "invalid_timezone" {
		t.Fatalf("status = %d code = %q, want 400 invalid_timezone; body=%s", rec.Code, errorCode(t, rec), rec.Body.String())
	}
}

func TestAvatarRequestUploadValidationAndRateLimit(t *testing.T) {
	up := &fakeUploader{}
	// capacity 1 so the second request is rate limited.
	h, _ := stackDeps(t, fakeVerifier("sub-A"), up, ratelimit.NewTokenBucket(1, 1, time.Hour, nil))

	// Size 0 rejected (does not consume the only token path differently — size
	// check is after Allow, so send a valid-size request first for rate-limit).
	rec := do(t, h, "POST", "/api/v1/me/avatar/request-upload-url", "sub-A", map[string]any{"contentType": "image/jpeg", "fileSizeBytes": 2048})
	if rec.Code != http.StatusOK {
		t.Fatalf("first upload status = %d; body=%s", rec.Code, rec.Body.String())
	}
	var body struct{ UploadURL, PublicURL, ExpiresAt string }
	_ = json.Unmarshal(rec.Body.Bytes(), &body)
	if body.UploadURL == "" || !strings.HasPrefix(body.PublicURL, "https://"+testR2Domain+"/avatar/") {
		t.Fatalf("upload body = %+v", body)
	}

	// Second request within the window -> 429 with Retry-After.
	rec2 := do(t, h, "POST", "/api/v1/me/avatar/request-upload-url", "sub-A", map[string]any{"contentType": "image/jpeg", "fileSizeBytes": 2048})
	if rec2.Code != http.StatusTooManyRequests || errorCode(t, rec2) != "rate_limited" {
		t.Fatalf("status = %d code = %q, want 429 rate_limited", rec2.Code, errorCode(t, rec2))
	}
	if rec2.Header().Get("Retry-After") == "" {
		t.Fatal("missing Retry-After header on 429")
	}
}

func TestAvatarRequestUploadRejectsBadSize(t *testing.T) {
	h, _ := stackDeps(t, fakeVerifier("sub-A"), &fakeUploader{}, ratelimit.NewTokenBucket(10, 10, time.Hour, nil))
	for _, sz := range []int64{0, 5*1024*1024 + 1} {
		rec := do(t, h, "POST", "/api/v1/me/avatar/request-upload-url", "sub-A", map[string]any{"contentType": "image/jpeg", "fileSizeBytes": sz})
		if rec.Code != http.StatusBadRequest || errorCode(t, rec) != "invalid_argument" {
			t.Fatalf("size %d: status = %d code = %q, want 400 invalid_argument", sz, rec.Code, errorCode(t, rec))
		}
	}
}

func TestAvatarFinalizeHeadRejectsMissing(t *testing.T) {
	up := &fakeUploader{headErr: r2.ErrObjectNotFound}
	h, _ := stackDeps(t, fakeVerifier("sub-A"), up, ratelimit.NewTokenBucket(10, 10, time.Hour, nil))

	// Get the caller's internal id to build a self-owned avatar URL.
	id := meID(t, h, "sub-A")
	avatarURL := "https://" + testR2Domain + "/avatar/" + id + "/pic.jpg"
	rec := do(t, h, "PATCH", "/api/v1/me/profile", "sub-A", map[string]string{"avatarUrl": avatarURL})
	if rec.Code != http.StatusBadRequest || errorCode(t, rec) != "invalid_argument" {
		t.Fatalf("status = %d code = %q, want 400 invalid_argument (Head missing); body=%s", rec.Code, errorCode(t, rec), rec.Body.String())
	}
}

func TestAvatarFinalizeAcceptsValidObject(t *testing.T) {
	up := &fakeUploader{headMeta: r2.ObjectMetadata{ContentLength: 4096, ContentType: "image/jpeg"}}
	h, _ := stackDeps(t, fakeVerifier("sub-A"), up, ratelimit.NewTokenBucket(10, 10, time.Hour, nil))
	id := meID(t, h, "sub-A")
	avatarURL := "https://" + testR2Domain + "/avatar/" + id + "/pic.jpg"
	rec := do(t, h, "PATCH", "/api/v1/me/profile", "sub-A", map[string]string{"avatarUrl": avatarURL})
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200; body=%s", rec.Code, rec.Body.String())
	}
	var raw map[string]any
	_ = json.Unmarshal(rec.Body.Bytes(), &raw)
	if raw["avatarUrl"] != avatarURL {
		t.Fatalf("avatarUrl = %v, want %q", raw["avatarUrl"], avatarURL)
	}
}

func TestAvatarUnavailableWhenR2Unconfigured(t *testing.T) {
	// nil uploader models R2 not configured (operator-provisioned at deploy):
	// avatar endpoints fail closed with 503, the rest of the api still serves.
	h, _ := stackDeps(t, fakeVerifier("sub-A"), nil, ratelimit.NewTokenBucket(10, 10, time.Hour, nil))

	rec := do(t, h, "POST", "/api/v1/me/avatar/request-upload-url", "sub-A", map[string]any{"contentType": "image/jpeg", "fileSizeBytes": 2048})
	if rec.Code != http.StatusServiceUnavailable || errorCode(t, rec) != "unavailable" {
		t.Fatalf("status = %d code = %q, want 503 unavailable", rec.Code, errorCode(t, rec))
	}
	// Non-avatar profile still works.
	if rec := do(t, h, "PATCH", "/api/v1/me/profile", "sub-A", map[string]string{"username": "alice"}); rec.Code != http.StatusOK {
		t.Fatalf("username PATCH should still work: %d %s", rec.Code, rec.Body.String())
	}
}

func TestProfileUserIsolation(t *testing.T) {
	up := &fakeUploader{}
	limiter := ratelimit.NewTokenBucket(10, 10, time.Hour, nil)
	// Build two stacks over the same DB (distinct identities).
	hA, db := stackDeps(t, fakeVerifier("sub-A"), up, limiter)
	if rec := do(t, hA, "PATCH", "/api/v1/me/profile", "sub-A", map[string]string{"username": "alice"}); rec.Code != http.StatusOK {
		t.Fatalf("A patch: %d %s", rec.Code, rec.Body.String())
	}
	profileStore := profile.NewStore(db)
	notifStore := notification.NewStore(db)
	idSvc := identity.NewService(identity.NewStore(db), NewProvisioner(profileStore, notifStore))
	discard := slog.New(slog.NewTextHandler(io.Discard, nil))
	hB := rootHandler(Deps{
		Verifier:     fakeVerifier("sub-B"),
		Identity:     identity.NewHandler(idSvc, nil),
		Profile:      profile.NewHandler(profile.NewService(profileStore, up, testR2Domain, limiter, discard)),
		Notification: notification.NewHandler(notification.NewService(notifStore)),
		ResolveUser:  identity.NewMiddleware(idSvc, nil),
	}, discard)
	if rec := do(t, hB, "PATCH", "/api/v1/me/profile", "sub-B", map[string]string{"username": "bob"}); rec.Code != http.StatusOK {
		t.Fatalf("B patch: %d %s", rec.Code, rec.Body.String())
	}

	// A still sees "alice" — B's change did not touch A.
	recA := do(t, hA, "GET", "/api/v1/me/profile", "sub-A", nil)
	var a map[string]any
	_ = json.Unmarshal(recA.Body.Bytes(), &a)
	if a["username"] != "alice" {
		t.Fatalf("A username = %v, want alice (isolation)", a["username"])
	}
}

// meID returns the caller's internal user id via GET /api/v1/me.
func meID(t *testing.T, h http.Handler, subject string) string {
	t.Helper()
	rec := do(t, h, "GET", "/api/v1/me", subject, nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("/me status = %d; body=%s", rec.Code, rec.Body.String())
	}
	var body struct {
		User struct{ ID string } `json:"user"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &body)
	if body.User.ID == "" {
		t.Fatal("empty user id from /me")
	}
	return body.User.ID
}

// errorCode extracts error.code from an envelope response.
func errorCode(t *testing.T, rec *httptest.ResponseRecorder) string {
	t.Helper()
	var body struct {
		Error struct{ Code string } `json:"error"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &body)
	return body.Error.Code
}
