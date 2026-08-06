// Package ratelimit provides a small in-memory per-key token bucket. It suits
// the single-instance api topology; revisit if the api is horizontally scaled.
package ratelimit

import (
	"sync"
	"time"
)

// TokenBucket is a per-key token bucket. Each key starts full (capacity tokens)
// and refills at refillPerSec. Idle keys are swept on access after idleTTL to
// bound memory. It is safe for concurrent use.
type TokenBucket struct {
	mu           sync.Mutex
	buckets      map[string]*bucket
	capacity     float64
	refillPerSec float64
	idleTTL      time.Duration
	now          func() time.Time
}

type bucket struct {
	tokens float64
	last   time.Time
}

// NewTokenBucket builds a bucket allowing a burst of capacity and a sustained
// refillPerHour tokens/hour, evicting entries idle longer than idleTTL. now may
// be nil (defaults to time.Now); tests inject a clock.
func NewTokenBucket(capacity int, refillPerHour float64, idleTTL time.Duration, now func() time.Time) *TokenBucket {
	if now == nil {
		now = time.Now
	}
	return &TokenBucket{
		buckets:      make(map[string]*bucket),
		capacity:     float64(capacity),
		refillPerSec: refillPerHour / 3600.0,
		idleTTL:      idleTTL,
		now:          now,
	}
}

// Allow consumes one token for key. It returns (true, 0) when allowed, or
// (false, retryAfter) with the wait until the next token when the bucket is
// empty.
func (t *TokenBucket) Allow(key string) (bool, time.Duration) {
	t.mu.Lock()
	defer t.mu.Unlock()
	now := t.now()
	t.evictLocked(now)

	b, ok := t.buckets[key]
	if !ok {
		b = &bucket{tokens: t.capacity, last: now}
		t.buckets[key] = b
	} else {
		elapsed := now.Sub(b.last).Seconds()
		if elapsed > 0 {
			b.tokens = min(t.capacity, b.tokens+elapsed*t.refillPerSec)
			b.last = now
		}
	}

	if b.tokens >= 1 {
		b.tokens -= 1
		return true, 0
	}
	need := 1 - b.tokens
	retry := time.Duration(need / t.refillPerSec * float64(time.Second))
	return false, retry
}

// evictLocked removes entries idle beyond idleTTL. Called under the lock on each
// Allow — cheap at the small avatar-request volume this guards.
func (t *TokenBucket) evictLocked(now time.Time) {
	for k, b := range t.buckets {
		if now.Sub(b.last) > t.idleTTL {
			delete(t.buckets, k)
		}
	}
}
