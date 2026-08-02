package r2

import (
	"context"
	"net/url"
	"strings"
	"testing"
	"time"
)

func testClient(t *testing.T) *Client {
	t.Helper()
	c, err := New(Config{
		AccountID:       "acct123",
		AccessKeyID:     "AKIAEXAMPLE",
		SecretAccessKey: "secretexample",
		Bucket:          "avatars",
		PublicDomain:    "cdn.example.com",
	})
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	return c
}

func TestNewRequiresCompleteConfig(t *testing.T) {
	if _, err := New(Config{AccountID: "a"}); err == nil {
		t.Fatal("expected error for incomplete config")
	}
}

func TestPresignPutSignsURL(t *testing.T) {
	c := testClient(t)
	raw, err := c.PresignPut(context.Background(), PresignPutInput{
		Key:           "avatar/u1/pic.jpg",
		ContentType:   "image/jpeg",
		ContentLength: 1024,
		TTL:           600 * time.Second,
	})
	if err != nil {
		t.Fatalf("PresignPut: %v", err)
	}
	u, err := url.Parse(raw)
	if err != nil {
		t.Fatalf("parse presigned url: %v", err)
	}
	if u.Scheme != "https" || u.Host != "acct123.r2.cloudflarestorage.com" {
		t.Fatalf("endpoint = %s://%s, want the R2 account endpoint", u.Scheme, u.Host)
	}
	if !strings.Contains(u.Path, "avatar/u1/pic.jpg") {
		t.Fatalf("path = %q, want to contain the object key", u.Path)
	}
	q := u.Query()
	if q.Get("X-Amz-Signature") == "" {
		t.Fatalf("missing X-Amz-Signature in %q", u.RawQuery)
	}
	if got := q.Get("X-Amz-Expires"); got != "600" {
		t.Fatalf("X-Amz-Expires = %q, want 600", got)
	}
}

func TestPublicURL(t *testing.T) {
	c := testClient(t)
	if got := c.PublicURL("avatar/u1/pic.jpg"); got != "https://cdn.example.com/avatar/u1/pic.jpg" {
		t.Fatalf("PublicURL = %q", got)
	}
}
