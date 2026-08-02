package profile

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"strings"
	"testing"
	"time"

	"github.com/cloveclovedev/peppercheck/backend/internal/platform/r2"
)

// fakeStore records the last Update and scripts results.
type fakeStore struct {
	profile      Profile
	getErr       error
	updated      Profile
	prev         *string
	updateErr    error
	lastMu       UpdateFields
	updateCalled bool
}

func (f *fakeStore) GetByUserID(_ context.Context, _ string) (Profile, error) {
	return f.profile, f.getErr
}

func (f *fakeStore) Update(_ context.Context, _ string, in UpdateFields) (Profile, *string, error) {
	f.updateCalled = true
	f.lastMu = in
	if f.updateErr != nil {
		return Profile{}, nil, f.updateErr
	}
	return f.updated, f.prev, nil
}

// fakeUploader scripts the r2.Uploader surface and records calls.
type fakeUploader struct {
	presignURL string
	presignErr error
	headMeta   r2.ObjectMetadata
	headErr    error
	headCalls  []string
	deleted    []string
	deleteErr  error
}

func (f *fakeUploader) PresignPut(_ context.Context, in r2.PresignPutInput) (string, error) {
	if f.presignErr != nil {
		return "", f.presignErr
	}
	if f.presignURL != "" {
		return f.presignURL, nil
	}
	return "https://acct.r2.cloudflarestorage.com/bucket/" + in.Key + "?X-Amz-Signature=x", nil
}

func (f *fakeUploader) Head(_ context.Context, key string) (r2.ObjectMetadata, error) {
	f.headCalls = append(f.headCalls, key)
	return f.headMeta, f.headErr
}

func (f *fakeUploader) Delete(_ context.Context, key string) error {
	f.deleted = append(f.deleted, key)
	return f.deleteErr
}

type allowAll struct{}

func (allowAll) Allow(string) (bool, time.Duration) { return true, 0 }

type denyAll struct{ retry time.Duration }

func (d denyAll) Allow(string) (bool, time.Duration) { return false, d.retry }

const testDomain = "cdn.example.com"

func discard() *slog.Logger { return slog.New(slog.NewTextHandler(io.Discard, nil)) }

// newService wires a service with a permissive uploader (valid Head) and limiter
// for the validation-focused tests; avatar-specific tests build their own.
func newService(store storeIface) *Service {
	up := &fakeUploader{headMeta: r2.ObjectMetadata{ContentLength: 1024, ContentType: "image/jpeg"}}
	return NewService(store, up, testDomain, allowAll{}, discard())
}

func TestValidateUsername(t *testing.T) {
	cases := []struct {
		name string
		in   string
		ok   bool
	}{
		{"ok ascii", "alice", true},
		{"ok generated", "user_1a2b3c4d", true},
		{"ok unicode", "さくら", true},
		{"ok with dash", "a-b_c", true},
		{"too short", "a", false},
		{"too long", "abcdefghijklmnopqrstu", false}, // 21
		{"space", "a b", false},
		{"symbol", "a@b", false},
		{"empty", "", false},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			err := validateUsername(c.in)
			if c.ok && err != nil {
				t.Fatalf("validateUsername(%q) = %v, want ok", c.in, err)
			}
			if !c.ok && err == nil {
				t.Fatalf("validateUsername(%q) = nil, want error", c.in)
			}
		})
	}
}

func TestUpdateOwnTimezoneValidation(t *testing.T) {
	for _, tz := range []string{"Asia/Tokyo", "UTC"} {
		s := newService(&fakeStore{updated: Profile{Timezone: tz}})
		v := tz
		if _, err := s.UpdateOwn(context.Background(), "u1", UpdateInput{Timezone: &v}); err != nil {
			t.Fatalf("valid tz %q: %v", tz, err)
		}
	}
	// "Local" resolves via LoadLocation to Go's process zone (non-IANA,
	// host-dependent) and must be rejected alongside garbage input.
	for _, tz := range []string{"Nowhere/Nope", "Local", ""} {
		s := newService(&fakeStore{updated: Profile{}})
		v := tz
		_, err := s.UpdateOwn(context.Background(), "u1", UpdateInput{Timezone: &v})
		if !errors.Is(err, ErrInvalidTimezone) {
			t.Fatalf("tz %q err = %v, want ErrInvalidTimezone", tz, err)
		}
	}
}

func TestUpdateOwnUsernameTakenMaps(t *testing.T) {
	s := newService(&fakeStore{updateErr: ErrUsernameTaken})
	name := "taken"
	_, err := s.UpdateOwn(context.Background(), "u1", UpdateInput{Username: &name})
	if !errors.Is(err, ErrUsernameTaken) {
		t.Fatalf("err = %v, want ErrUsernameTaken", err)
	}
}

func TestUpdateOwnAvatarURLValidation(t *testing.T) {
	const uid = "11111111-1111-1111-1111-111111111111"
	good := "https://" + testDomain + "/avatar/" + uid + "/pic.jpg"
	cases := []struct {
		name string
		url  string
		ok   bool
	}{
		{"valid", good, true},
		{"http scheme", "http://" + testDomain + "/avatar/" + uid + "/pic.jpg", false},
		{"wrong host", "https://evil.example.com/avatar/" + uid + "/pic.jpg", false},
		{"userinfo", "https://user@" + testDomain + "/avatar/" + uid + "/pic.jpg", false},
		{"host in query bypass", "https://evil.example.com/?x=https://" + testDomain + "/avatar/" + uid + "/pic.jpg", false},
		{"another user", "https://" + testDomain + "/avatar/22222222-2222-2222-2222-222222222222/pic.jpg", false},
		{"dot-dot traversal", "https://" + testDomain + "/avatar/" + uid + "/../pic.jpg", false},
		{"encoded slash", "https://" + testDomain + "/avatar/" + uid + "%2Fpic.jpg", false},
		{"extra segment", "https://" + testDomain + "/avatar/" + uid + "/sub/pic.jpg", false},
		{"missing file", "https://" + testDomain + "/avatar/" + uid + "/", false},
		{"query present", good + "?v=2", false},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			s := newService(&fakeStore{updated: Profile{}})
			u := c.url
			_, err := s.UpdateOwn(context.Background(), uid, UpdateInput{AvatarURL: &u})
			if c.ok && err != nil {
				t.Fatalf("avatarURL %q = %v, want ok", c.url, err)
			}
			if !c.ok && !errors.Is(err, ErrInvalidArgument) {
				t.Fatalf("avatarURL %q = %v, want ErrInvalidArgument", c.url, err)
			}
		})
	}
}

func TestRequestAvatarUpload(t *testing.T) {
	const uid = "11111111-1111-1111-1111-111111111111"

	t.Run("valid", func(t *testing.T) {
		up := &fakeUploader{}
		s := NewService(&fakeStore{}, up, testDomain, allowAll{}, discard())
		out, err := s.RequestAvatarUpload(context.Background(), uid, AvatarUploadInput{ContentType: "image/png", FileSizeBytes: 2048})
		if err != nil {
			t.Fatalf("valid: %v", err)
		}
		if !strings.HasPrefix(out.PublicURL, "https://"+testDomain+"/avatar/"+uid+"/") || !strings.HasSuffix(out.PublicURL, ".png") {
			t.Fatalf("publicURL = %q, want avatar/%s/<token>.png", out.PublicURL, uid)
		}
		if out.UploadURL == "" || !out.ExpiresAt.After(time.Now()) {
			t.Fatalf("upload = %+v", out)
		}
	})

	t.Run("bad content type", func(t *testing.T) {
		s := NewService(&fakeStore{}, &fakeUploader{}, testDomain, allowAll{}, discard())
		_, err := s.RequestAvatarUpload(context.Background(), uid, AvatarUploadInput{ContentType: "application/pdf", FileSizeBytes: 2048})
		if !errors.Is(err, ErrInvalidArgument) {
			t.Fatalf("err = %v, want ErrInvalidArgument", err)
		}
	})

	t.Run("size bounds", func(t *testing.T) {
		s := NewService(&fakeStore{}, &fakeUploader{}, testDomain, allowAll{}, discard())
		for _, sz := range []int64{0, maxAvatarBytes + 1} {
			if _, err := s.RequestAvatarUpload(context.Background(), uid, AvatarUploadInput{ContentType: "image/jpeg", FileSizeBytes: sz}); !errors.Is(err, ErrInvalidArgument) {
				t.Fatalf("size %d err = %v, want ErrInvalidArgument", sz, err)
			}
		}
	})

	t.Run("rate limited", func(t *testing.T) {
		s := NewService(&fakeStore{}, &fakeUploader{}, testDomain, denyAll{retry: 90 * time.Second}, discard())
		_, err := s.RequestAvatarUpload(context.Background(), uid, AvatarUploadInput{ContentType: "image/jpeg", FileSizeBytes: 2048})
		if !errors.Is(err, ErrRateLimited) {
			t.Fatalf("err = %v, want ErrRateLimited", err)
		}
		var rl *RateLimited
		if !errors.As(err, &rl) || rl.RetryAfter != 90*time.Second {
			t.Fatalf("retryAfter not carried: %v", err)
		}
	})
}

func TestAvatarFinalize(t *testing.T) {
	const uid = "11111111-1111-1111-1111-111111111111"
	newURL := "https://" + testDomain + "/avatar/" + uid + "/new.jpg"
	newKey := "avatar/" + uid + "/new.jpg"
	oldURL := "https://" + testDomain + "/avatar/" + uid + "/old.jpg"
	oldKey := "avatar/" + uid + "/old.jpg"
	validMeta := r2.ObjectMetadata{ContentLength: 4096, ContentType: "image/jpeg"}

	t.Run("deletes prior after commit", func(t *testing.T) {
		up := &fakeUploader{headMeta: validMeta}
		store := &fakeStore{updated: Profile{AvatarURL: &newURL}, prev: &oldURL}
		s := NewService(store, up, testDomain, allowAll{}, discard())
		u := newURL
		if _, err := s.UpdateOwn(context.Background(), uid, UpdateInput{AvatarURL: &u}); err != nil {
			t.Fatalf("update: %v", err)
		}
		if len(up.headCalls) != 1 || up.headCalls[0] != newKey {
			t.Fatalf("head calls = %v, want [%s]", up.headCalls, newKey)
		}
		if len(up.deleted) != 1 || up.deleted[0] != oldKey {
			t.Fatalf("deleted = %v, want [%s]", up.deleted, oldKey)
		}
	})

	t.Run("same-url retry does not delete", func(t *testing.T) {
		up := &fakeUploader{headMeta: validMeta}
		store := &fakeStore{updated: Profile{AvatarURL: &newURL}, prev: &newURL} // prev == new
		s := NewService(store, up, testDomain, allowAll{}, discard())
		u := newURL
		if _, err := s.UpdateOwn(context.Background(), uid, UpdateInput{AvatarURL: &u}); err != nil {
			t.Fatalf("update: %v", err)
		}
		if len(up.deleted) != 0 {
			t.Fatalf("deleted = %v, want none on same-url retry", up.deleted)
		}
	})

	t.Run("delete failure is swallowed", func(t *testing.T) {
		up := &fakeUploader{headMeta: validMeta, deleteErr: errors.New("r2 down")}
		store := &fakeStore{updated: Profile{AvatarURL: &newURL}, prev: &oldURL}
		s := NewService(store, up, testDomain, allowAll{}, discard())
		u := newURL
		if _, err := s.UpdateOwn(context.Background(), uid, UpdateInput{AvatarURL: &u}); err != nil {
			t.Fatalf("a delete failure must not fail the PATCH: %v", err)
		}
	})

	t.Run("db failure skips delete", func(t *testing.T) {
		up := &fakeUploader{headMeta: validMeta}
		store := &fakeStore{updateErr: errors.New("db down"), prev: &oldURL}
		s := NewService(store, up, testDomain, allowAll{}, discard())
		u := newURL
		if _, err := s.UpdateOwn(context.Background(), uid, UpdateInput{AvatarURL: &u}); err == nil {
			t.Fatal("want the db error")
		}
		if len(up.deleted) != 0 {
			t.Fatalf("deleted = %v, want none when the DB update failed", up.deleted)
		}
	})

	t.Run("head rejects bad object", func(t *testing.T) {
		cases := map[string]r2.ObjectMetadata{
			"zero bytes": {ContentLength: 0, ContentType: "image/jpeg"},
			"oversized":  {ContentLength: maxAvatarBytes + 1, ContentType: "image/jpeg"},
			"wrong type": {ContentLength: 4096, ContentType: "application/pdf"},
		}
		for name, meta := range cases {
			t.Run(name, func(t *testing.T) {
				up := &fakeUploader{headMeta: meta}
				store := &fakeStore{}
				s := NewService(store, up, testDomain, allowAll{}, discard())
				u := newURL
				if _, err := s.UpdateOwn(context.Background(), uid, UpdateInput{AvatarURL: &u}); !errors.Is(err, ErrInvalidArgument) {
					t.Fatalf("err = %v, want ErrInvalidArgument", err)
				}
				if store.updateCalled {
					t.Fatal("store.Update must not run when the Head backstop rejects")
				}
			})
		}
	})

	t.Run("head missing rejects", func(t *testing.T) {
		up := &fakeUploader{headErr: r2.ErrObjectNotFound}
		store := &fakeStore{}
		s := NewService(store, up, testDomain, allowAll{}, discard())
		u := newURL
		if _, err := s.UpdateOwn(context.Background(), uid, UpdateInput{AvatarURL: &u}); !errors.Is(err, ErrInvalidArgument) {
			t.Fatalf("err = %v, want ErrInvalidArgument", err)
		}
		if store.updateCalled {
			t.Fatal("store.Update must not run when the object is missing")
		}
	})

	t.Run("head transient error is unavailable not invalid", func(t *testing.T) {
		// A non-not-found Head failure (timeout/auth/5xx) is a dependency issue:
		// 503-retryable, never a 400 malformed-request.
		up := &fakeUploader{headErr: errors.New("r2 timeout")}
		store := &fakeStore{}
		s := NewService(store, up, testDomain, allowAll{}, discard())
		u := newURL
		if _, err := s.UpdateOwn(context.Background(), uid, UpdateInput{AvatarURL: &u}); !errors.Is(err, ErrUnavailable) {
			t.Fatalf("err = %v, want ErrUnavailable", err)
		}
		if store.updateCalled {
			t.Fatal("store.Update must not run when Head fails transiently")
		}
	})
}

func TestAvatarDisabledWhenNoUploader(t *testing.T) {
	const uid = "11111111-1111-1111-1111-111111111111"
	// A nil uploader models R2 not being configured: avatar operations fail
	// closed (unavailable), while non-avatar profile updates still work.
	s := NewService(&fakeStore{updated: Profile{Username: "alice"}}, nil, testDomain, allowAll{}, discard())

	if _, err := s.RequestAvatarUpload(context.Background(), uid, AvatarUploadInput{ContentType: "image/jpeg", FileSizeBytes: 2048}); !errors.Is(err, ErrUnavailable) {
		t.Fatalf("RequestAvatarUpload err = %v, want ErrUnavailable", err)
	}
	avatarURL := "https://" + testDomain + "/avatar/" + uid + "/pic.jpg"
	if _, err := s.UpdateOwn(context.Background(), uid, UpdateInput{AvatarURL: &avatarURL}); !errors.Is(err, ErrUnavailable) {
		t.Fatalf("avatar PATCH err = %v, want ErrUnavailable", err)
	}
	// A non-avatar update still succeeds with no uploader.
	name := "alice"
	if _, err := s.UpdateOwn(context.Background(), uid, UpdateInput{Username: &name}); err != nil {
		t.Fatalf("username update with no uploader: %v", err)
	}
}
