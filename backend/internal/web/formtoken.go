package web

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"
)

const (
	formTokenMinElapsed = 1 * time.Second
	formTokenMaxAge     = 30 * time.Minute
)

var errBadFormToken = errors.New("invalid form token")

// FormToken signs {issuedAtUnix, nonce} so a POST proves it came from a
// server-rendered form within a plausible time window. Stateless.
type FormToken struct{ key []byte }

// NewFormToken builds a FormToken over the HMAC signing key.
func NewFormToken(key []byte) *FormToken { return &FormToken{key: key} }

// Issue mints a token embedding the issue time and a random nonce.
func (ft *FormToken) Issue(now time.Time) string {
	nonce := make([]byte, 8)
	_, _ = rand.Read(nonce)
	payload := strconv.FormatInt(now.Unix(), 10) + "." + base64.RawURLEncoding.EncodeToString(nonce)
	return payload + "." + ft.sign(payload)
}

// Verify checks the signature and rejects a token that is malformed,
// tampered with, submitted faster than a human plausibly could, or expired.
func (ft *FormToken) Verify(token string, now time.Time) error {
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return errBadFormToken
	}
	payload := parts[0] + "." + parts[1]
	if !hmac.Equal([]byte(ft.sign(payload)), []byte(parts[2])) {
		return errBadFormToken
	}
	issued, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil {
		return errBadFormToken
	}
	age := now.Sub(time.Unix(issued, 0))
	if age < formTokenMinElapsed {
		return fmt.Errorf("%w: too fast", errBadFormToken)
	}
	if age > formTokenMaxAge {
		return fmt.Errorf("%w: expired", errBadFormToken)
	}
	return nil
}

func (ft *FormToken) sign(payload string) string {
	m := hmac.New(sha256.New, ft.key)
	m.Write([]byte(payload))
	return base64.RawURLEncoding.EncodeToString(m.Sum(nil))
}
