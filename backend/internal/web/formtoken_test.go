package web

import (
	"testing"
	"time"
)

func TestFormTokenRoundTrip(t *testing.T) {
	ft := NewFormToken([]byte("test-key"))
	now := time.Unix(1_800_000_000, 0)
	tok := ft.Issue(now)

	// submitted after a human-plausible delay -> OK
	if err := ft.Verify(tok, now.Add(5*time.Second)); err != nil {
		t.Fatalf("valid token rejected: %v", err)
	}
	// too fast -> rejected
	if err := ft.Verify(tok, now.Add(200*time.Millisecond)); err == nil {
		t.Fatal("expected too-fast rejection")
	}
	// expired -> rejected
	if err := ft.Verify(tok, now.Add(2*time.Hour)); err == nil {
		t.Fatal("expected expiry rejection")
	}
	// tampered -> rejected
	if err := ft.Verify(tok+"x", now.Add(5*time.Second)); err == nil {
		t.Fatal("expected signature rejection")
	}
	// wrong key -> rejected
	if err := NewFormToken([]byte("other")).Verify(tok, now.Add(5*time.Second)); err == nil {
		t.Fatal("expected wrong-key rejection")
	}
	// malformed -> rejected
	if err := ft.Verify("not-a-token", now.Add(5*time.Second)); err == nil {
		t.Fatal("expected malformed-token rejection")
	}
}
