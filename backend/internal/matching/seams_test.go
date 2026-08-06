package matching_test

import (
	"context"
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/matching"
)

func TestNoopPointLockerSucceeds(t *testing.T) {
	pl := matching.NewNoopPointLocker()
	src, err := pl.LockForRequestInTx(context.Background(), nil, "tasker-1", "req-1", 1)
	if err != nil || src != "regular" {
		t.Fatalf("noop lock should return (\"regular\", nil), got (%q, %v)", src, err)
	}
	if err := pl.RefundForRequestInTx(context.Background(), nil, "req-1", "expired"); err != nil {
		t.Fatalf("noop refund should be nil, got %v", err)
	}
}

func TestNoObligationsReturnsEmpty(t *testing.T) {
	oc := matching.NewNoObligations()
	got, err := oc.FilterObligated(context.Background(), []string{"cand-1"})
	if err != nil || len(got) != 0 {
		t.Fatalf("want empty, got %v err %v", got, err)
	}
}
