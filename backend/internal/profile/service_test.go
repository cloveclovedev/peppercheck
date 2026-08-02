package profile

import (
	"context"
	"errors"
	"testing"
)

// fakeStore records the last Update and scripts results.
type fakeStore struct {
	profile   Profile
	getErr    error
	updated   Profile
	prev      *string
	updateErr error
	lastMu    UpdateFields
}

func (f *fakeStore) GetByUserID(_ context.Context, _ string) (Profile, error) {
	return f.profile, f.getErr
}

func (f *fakeStore) Update(_ context.Context, _ string, in UpdateFields) (Profile, *string, error) {
	f.lastMu = in
	if f.updateErr != nil {
		return Profile{}, nil, f.updateErr
	}
	return f.updated, f.prev, nil
}

const testDomain = "cdn.example.com"

func newService(store storeIface) *Service {
	return NewService(store, nil, testDomain)
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
	s := newService(&fakeStore{updated: Profile{Timezone: "Asia/Tokyo"}})
	tz := "Asia/Tokyo"
	if _, err := s.UpdateOwn(context.Background(), "u1", UpdateInput{Timezone: &tz}); err != nil {
		t.Fatalf("valid tz: %v", err)
	}
	bad := "Nowhere/Nope"
	_, err := s.UpdateOwn(context.Background(), "u1", UpdateInput{Timezone: &bad})
	if !errors.Is(err, ErrInvalidTimezone) {
		t.Fatalf("err = %v, want ErrInvalidTimezone", err)
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
