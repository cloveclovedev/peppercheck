package profile

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"log/slog"
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
	// ErrRateLimited means the per-user avatar-upload quota was exceeded (429).
	// The returned error is a *RateLimited carrying the retry delay.
	ErrRateLimited = errors.New("rate limited")
	// ErrUnavailable means the avatar object store is not configured or a
	// dependency (R2) failed transiently — the caller should retry (503), not
	// treat it as a malformed request.
	ErrUnavailable = errors.New("avatar service unavailable")
)

// RateLimited is returned when the avatar-upload rate limit is hit; it carries
// the wait until the next allowed request. errors.Is(err, ErrRateLimited) matches.
type RateLimited struct{ RetryAfter time.Duration }

func (e *RateLimited) Error() string        { return "rate limited" }
func (e *RateLimited) Is(target error) bool { return target == ErrRateLimited }

const (
	minAvatarBytes   = 1
	maxAvatarBytes   = 5 * 1024 * 1024 // 5 MiB, best-effort (see spec §4.6)
	avatarPresignTTL = 600 * time.Second
)

// allowedAvatarContentTypes maps an accepted content type to its file extension.
var allowedAvatarContentTypes = map[string]string{
	"image/jpeg": "jpg",
	"image/png":  "png",
	"image/webp": "webp",
	"image/gif":  "gif",
	"image/heic": "heic",
	"image/heif": "heif",
}

// storeIface is the persistence the service needs; *Store satisfies it.
type storeIface interface {
	GetByUserID(ctx context.Context, userID string) (Profile, error)
	Update(ctx context.Context, userID string, in UpdateFields) (Profile, *string, error)
}

// Limiter bounds avatar-upload issuance per user; *ratelimit.TokenBucket
// satisfies it.
type Limiter interface {
	Allow(key string) (bool, time.Duration)
}

// Service owns profile reads and updates, scoped to the authenticated caller.
type Service struct {
	store        storeIface
	uploader     r2.Uploader // avatar presign + finalize (Head/Delete); may be nil where avatars are unused
	publicDomain string      // the R2 public host avatar URLs must match
	limiter      Limiter     // per-user avatar-upload rate limit
	logger       *slog.Logger
}

// NewService builds a Service. uploader/limiter may be nil in contexts that
// never touch avatars (e.g. validation-only tests). A nil logger falls back to
// slog.Default().
func NewService(store storeIface, uploader r2.Uploader, publicDomain string, limiter Limiter, logger *slog.Logger) *Service {
	if logger == nil {
		logger = slog.Default()
	}
	return &Service{store: store, uploader: uploader, publicDomain: publicDomain, limiter: limiter, logger: logger}
}

// UpdateInput is a partial profile update from the caller; a nil field is
// omitted from the update.
type UpdateInput struct {
	Username  *string
	Timezone  *string
	AvatarURL *string
}

// AvatarUploadInput is the request for a presigned avatar upload URL.
type AvatarUploadInput struct {
	ContentType   string
	FileSizeBytes int64
}

// AvatarUpload is the presigned-upload response.
type AvatarUpload struct {
	UploadURL string
	PublicURL string
	ExpiresAt time.Time
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
	var newAvatarKey string
	if in.AvatarURL != nil {
		if s.uploader == nil {
			return Profile{}, ErrUnavailable
		}
		key, err := s.parseAvatarKey(*in.AvatarURL, userID)
		if err != nil {
			return Profile{}, ErrInvalidArgument
		}
		// Finalize backstop: the object must exist, be within 1..5 MiB, and be an
		// allowed content type. Best-effort (TOCTOU; not a hard cap) — see §4.6.
		meta, err := s.uploader.Head(ctx, key)
		if err != nil {
			// A missing object is the caller's fault (400); a transient/dependency
			// failure (timeout, auth, 5xx) must not be reported as malformed (503).
			if errors.Is(err, r2.ErrObjectNotFound) {
				return Profile{}, ErrInvalidArgument
			}
			s.logger.Error("avatar head failed", "error", err)
			return Profile{}, ErrUnavailable
		}
		if meta.ContentLength < minAvatarBytes || meta.ContentLength > maxAvatarBytes {
			return Profile{}, ErrInvalidArgument
		}
		if _, ok := allowedAvatarContentTypes[meta.ContentType]; !ok {
			return Profile{}, ErrInvalidArgument
		}
		newAvatarKey = key
		fields.AvatarURL = in.AvatarURL
	}

	// Commit the DB update FIRST, then delete the previous object. This never
	// turns a committed change into a failure and never deletes on a DB failure.
	updated, prevAvatar, err := s.store.Update(ctx, userID, fields)
	if err != nil {
		return Profile{}, err
	}

	if in.AvatarURL != nil && prevAvatar != nil {
		// Only delete a real, different prior object; a same-URL retry keeps it.
		if oldKey, perr := s.parseAvatarKey(*prevAvatar, userID); perr == nil && oldKey != newAvatarKey {
			if derr := s.uploader.Delete(ctx, oldKey); derr != nil {
				// Log-only: the stale object is reclaimed by the Phase 4 sweep;
				// the already-committed PATCH must still succeed.
				s.logger.Warn("avatar delete-previous failed", "error", derr)
			}
		}
	}
	return updated, nil
}

// RequestAvatarUpload rate-limits per user, validates the content type and size,
// and returns a presigned PUT URL plus the eventual public URL. The key is
// versioned per upload (avatar/{userID}/{token}.{ext}) so an upload never
// clobbers the current avatar.
func (s *Service) RequestAvatarUpload(ctx context.Context, userID string, in AvatarUploadInput) (AvatarUpload, error) {
	if s.uploader == nil {
		return AvatarUpload{}, ErrUnavailable
	}
	if ok, retry := s.limiter.Allow(userID); !ok {
		return AvatarUpload{}, &RateLimited{RetryAfter: retry}
	}
	ext, ok := allowedAvatarContentTypes[in.ContentType]
	if !ok {
		return AvatarUpload{}, ErrInvalidArgument
	}
	if in.FileSizeBytes < minAvatarBytes || in.FileSizeBytes > maxAvatarBytes {
		return AvatarUpload{}, ErrInvalidArgument
	}
	token, err := randomToken()
	if err != nil {
		return AvatarUpload{}, err
	}
	key := fmt.Sprintf("avatar/%s/%s.%s", userID, token, ext)
	uploadURL, err := s.uploader.PresignPut(ctx, r2.PresignPutInput{
		Key:           key,
		ContentType:   in.ContentType,
		ContentLength: in.FileSizeBytes,
		TTL:           avatarPresignTTL,
	})
	if err != nil {
		return AvatarUpload{}, fmt.Errorf("presign avatar upload: %w", err)
	}
	return AvatarUpload{
		UploadURL: uploadURL,
		PublicURL: fmt.Sprintf("https://%s/%s", s.publicDomain, key),
		ExpiresAt: time.Now().Add(avatarPresignTTL),
	}, nil
}

// randomToken returns a 16-byte random hex string for a per-upload object key.
func randomToken() (string, error) {
	var b [16]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "", fmt.Errorf("random token: %w", err)
	}
	return hex.EncodeToString(b[:]), nil
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
// api embeds it via time/tzdata). It rejects the empty string and Go's "Local"
// pseudo-zone, which time.LoadLocation resolves to the deployment-dependent
// process zone rather than an IANA entry — a non-portable value that would make
// scheduling host-dependent. ("UTC" is a genuine IANA zone and stays allowed.)
func validateTimezone(tz string) error {
	if tz == "" || tz == "Local" {
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
