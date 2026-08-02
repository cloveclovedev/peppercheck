package profile

import (
	"context"
	"errors"
	"net/url"
	"regexp"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/cloveclovedev/peppercheck/backend/internal/platform/r2"
)

var (
	// ErrInvalidArgument means a field failed validation (400).
	ErrInvalidArgument = errors.New("invalid argument")
	// ErrInvalidTimezone means the timezone is not a valid IANA name (400).
	ErrInvalidTimezone = errors.New("invalid timezone")
)

// storeIface is the persistence the service needs; *Store satisfies it.
type storeIface interface {
	GetByUserID(ctx context.Context, userID string) (Profile, error)
	Update(ctx context.Context, userID string, in UpdateFields) (Profile, *string, error)
}

// Service owns profile reads and updates, scoped to the authenticated caller.
type Service struct {
	store        storeIface
	uploader     r2.Uploader // avatar finalize (Head/Delete); may be nil where avatars are unused
	publicDomain string      // the R2 public host avatar URLs must match
}

// NewService builds a Service. uploader may be nil in contexts that never touch
// avatars (e.g. validation-only tests).
func NewService(store storeIface, uploader r2.Uploader, publicDomain string) *Service {
	return &Service{store: store, uploader: uploader, publicDomain: publicDomain}
}

// UpdateInput is a partial profile update from the caller; a nil field is
// omitted from the update.
type UpdateInput struct {
	Username  *string
	Timezone  *string
	AvatarURL *string
}

// GetOwn returns the caller's profile.
func (s *Service) GetOwn(ctx context.Context, userID string) (Profile, error) {
	return s.store.GetByUserID(ctx, userID)
}

// UpdateOwn validates and applies a partial update to the caller's profile. The
// avatar finalize (Head backstop + inline delete-previous) is layered on in the
// avatar task; here the avatar URL is validated and persisted.
func (s *Service) UpdateOwn(ctx context.Context, userID string, in UpdateInput) (Profile, error) {
	var fields UpdateFields
	if in.Username != nil {
		if err := validateUsername(*in.Username); err != nil {
			return Profile{}, err
		}
		fields.Username = in.Username
	}
	if in.Timezone != nil {
		if err := validateTimezone(*in.Timezone); err != nil {
			return Profile{}, ErrInvalidTimezone
		}
		fields.Timezone = in.Timezone
	}
	if in.AvatarURL != nil {
		if _, err := s.parseAvatarKey(*in.AvatarURL, userID); err != nil {
			return Profile{}, ErrInvalidArgument
		}
		fields.AvatarURL = in.AvatarURL
	}

	updated, _, err := s.store.Update(ctx, userID, fields)
	if err != nil {
		return Profile{}, err
	}
	return updated, nil
}

var usernameCharset = regexp.MustCompile(`^[\p{L}\p{N}_-]+$`)

// validateUsername enforces length 2..20 (runes) and the allowed charset,
// mirroring the Flutter client rule; the server is authoritative.
func validateUsername(u string) error {
	if n := utf8.RuneCountInString(u); n < 2 || n > 20 {
		return ErrInvalidArgument
	}
	if !usernameCharset.MatchString(u) {
		return ErrInvalidArgument
	}
	return nil
}

// validateTimezone requires a valid IANA timezone (needs the tz database; the
// api embeds it via time/tzdata).
func validateTimezone(tz string) error {
	if tz == "" {
		return ErrInvalidTimezone
	}
	if _, err := time.LoadLocation(tz); err != nil {
		return ErrInvalidTimezone
	}
	return nil
}

// parseAvatarKey validates an avatar URL by parsing it (never a string-prefix
// check) and returns the object key. It requires scheme https, no userinfo, no
// query/fragment, an exact host match (incl. port), and a path that is exactly
// avatar/{userID}/<file> — rejecting encoded slashes and dot segments — so a
// caller cannot point at an arbitrary or another user's object.
func (s *Service) parseAvatarKey(raw, userID string) (string, error) {
	u, err := url.Parse(raw)
	if err != nil {
		return "", ErrInvalidArgument
	}
	if u.Scheme != "https" || u.User != nil || u.Host != s.publicDomain || u.RawQuery != "" || u.Fragment != "" {
		return "", ErrInvalidArgument
	}
	if strings.Contains(strings.ToLower(u.EscapedPath()), "%2f") {
		return "", ErrInvalidArgument
	}
	segs := strings.Split(strings.TrimPrefix(u.Path, "/"), "/")
	if len(segs) != 3 || segs[0] != "avatar" || segs[1] != userID {
		return "", ErrInvalidArgument
	}
	for _, seg := range segs {
		if seg == "" || seg == "." || seg == ".." {
			return "", ErrInvalidArgument
		}
	}
	return "avatar/" + userID + "/" + segs[2], nil
}
