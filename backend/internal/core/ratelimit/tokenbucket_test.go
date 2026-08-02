package ratelimit

import (
	"testing"
	"time"
)

// mockClock is an injectable, advanceable clock.
type mockClock struct{ t time.Time }

func (c *mockClock) now() time.Time      { return c.t }
func (c *mockClock) add(d time.Duration) { c.t = c.t.Add(d) }

func newClock() *mockClock {
	return &mockClock{t: time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)}
}

func TestBurstThenLimited(t *testing.T) {
	c := newClock()
	// capacity 10, refill 10/hour.
	tb := NewTokenBucket(10, 10, time.Hour, c.now)

	for i := 0; i < 10; i++ {
		ok, _ := tb.Allow("u1")
		if !ok {
			t.Fatalf("request %d should be allowed within the burst", i+1)
		}
	}
	ok, retry := tb.Allow("u1")
	if ok {
		t.Fatal("11th request should be rate limited")
	}
	if retry <= 0 {
		t.Fatalf("retryAfter = %v, want positive", retry)
	}
	// Refill is 1 token per 6 minutes; retry should be ~6 min.
	if retry > 6*time.Minute+time.Second || retry < 6*time.Minute-time.Second {
		t.Fatalf("retryAfter = %v, want ~6m", retry)
	}
}

func TestRefillAfterInterval(t *testing.T) {
	c := newClock()
	tb := NewTokenBucket(10, 10, time.Hour, c.now)
	for i := 0; i < 10; i++ {
		tb.Allow("u1")
	}
	if ok, _ := tb.Allow("u1"); ok {
		t.Fatal("should be empty")
	}
	// Advance 6 minutes -> one token refilled.
	c.add(6 * time.Minute)
	if ok, _ := tb.Allow("u1"); !ok {
		t.Fatal("one token should have refilled after 6 minutes")
	}
	if ok, _ := tb.Allow("u1"); ok {
		t.Fatal("only one token should have refilled")
	}
}

func TestSeparateKeysIndependent(t *testing.T) {
	c := newClock()
	tb := NewTokenBucket(10, 10, time.Hour, c.now)
	for i := 0; i < 10; i++ {
		tb.Allow("u1")
	}
	if ok, _ := tb.Allow("u2"); !ok {
		t.Fatal("a different key must have its own full bucket")
	}
}

func TestIdleEviction(t *testing.T) {
	c := newClock()
	tb := NewTokenBucket(10, 10, time.Hour, c.now)
	tb.Allow("u1")
	tb.Allow("u1") // 8 tokens left
	// Idle past the TTL: the entry is swept and recreated full on next access.
	c.add(time.Hour + time.Minute)
	if _, ok := tb.buckets["u1"]; ok {
		// Not yet swept until an Allow triggers eviction; trigger it via another key.
		tb.Allow("u2")
	}
	if _, ok := tb.buckets["u1"]; ok {
		t.Fatal("idle entry should have been evicted")
	}
	// After eviction the key starts fresh (full burst again).
	for i := 0; i < 10; i++ {
		if ok, _ := tb.Allow("u1"); !ok {
			t.Fatalf("post-eviction burst request %d should be allowed", i+1)
		}
	}
}
