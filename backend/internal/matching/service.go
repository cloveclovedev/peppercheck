package matching

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"hash/fnv"
	"time"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
	"github.com/cloveclovedev/peppercheck/backend/internal/core/jobs"
	"github.com/cloveclovedev/peppercheck/backend/internal/judgement"
)

// notifier is the subset of the notification sender the matching engine uses.
// It is defined here (not imported from notification) so matching stays
// independent of that feature; the composition root passes the real
// notification.Sender, tests pass a fake.
type notifier interface {
	EnqueueInTx(ctx context.Context, tx database.Querier, userID, keyBase string, args []string, data map[string]string) error
	EnqueueIdempotentInTx(ctx context.Context, tx database.Querier, userID, keyBase string, args []string, data map[string]string, idempotencyKey string) error
}

// Service is the matching use case: it turns a match job into (at most) one
// accepted referee, provisions the judgement, and notifies both parties, all in
// one transaction. It also owns the sweep that expires past-cutoff pendings.
type Service struct {
	db          *database.Handle
	store       *Store
	points      PointLocker
	obligations ObligationChecker
	judgements  *judgement.Provisioner
	notifier    notifier
	jobs        *jobs.Store
}

// NewService wires the matching use case. points/obligations are the Phase 5
// seams (no-ops in 4a); judgements provisions the awaiting_evidence row; the
// notifier and jobs store back the notification outbox and worker enqueues.
func NewService(db *database.Handle, store *Store, points PointLocker, obligations ObligationChecker, judgements *judgement.Provisioner, notifier notifier, jobsStore *jobs.Store) *Service {
	return &Service{
		db:          db,
		store:       store,
		points:      points,
		obligations: obligations,
		judgements:  judgements,
		notifier:    notifier,
		jobs:        jobsStore,
	}
}

// HandleMatch is the idempotent worker handler for one match job: pick a
// least-workload eligible referee, accept them (CAS), provision the judgement,
// and notify. A redelivery whose request is already accepted is a no-op. A
// same-task double-assignment (23505) MUST propagate out of the transaction to
// force a rollback — treating it as success inside the callback would make
// Commit fail (P4a-D16) — so the sentinel is mapped to success OUTSIDE the tx.
func (s *Service) HandleMatch(ctx context.Context, j *jobs.Job) error {
	var p struct {
		RequestID string `json:"requestId"`
	}
	if err := json.Unmarshal(j.Payload, &p); err != nil {
		return fmt.Errorf("unmarshal match payload: %w", err)
	}
	if p.RequestID == "" {
		return fmt.Errorf("match payload: empty requestId")
	}
	requestID := p.RequestID

	err := database.WithTx(ctx, s.db, func(tx database.Querier) error {
		candidates, err := s.store.CandidateReferees(ctx, tx, requestID)
		if err != nil {
			return err
		}
		if len(candidates) == 0 {
			// No eligible referee right now; leave the request pending for the
			// sweep to retry. If it is a re-match after a cancel, tell the tasker
			// once (idempotent).
			return s.maybeNotifyCancelledPending(ctx, tx, requestID)
		}

		// Obligation priority (Phase 5 seam; 4a returns none, so pick == candidates).
		pick := candidates
		obligated, err := s.obligations.FilterObligated(ctx, candidates)
		if err != nil {
			return err
		}
		if len(obligated) > 0 {
			pick = obligated
		}
		isObligation := len(pick) < len(candidates) // narrowed only by obligation
		referee := pick[pickIndex(requestID, len(pick))]

		won, err := s.store.MarkAcceptedInTx(ctx, tx, requestID, referee, isObligation)
		if err != nil {
			return err // ErrRefereeTaken propagates -> WithTx rolls back
		}
		if !won {
			// Another worker already matched it, or the request slipped past the
			// rematch cutoff; either way the sweep owns the outcome.
			return nil
		}
		if err := s.judgements.CreateAwaitingEvidenceInTx(ctx, tx, requestID); err != nil {
			return err
		}
		return s.notifyMatch(ctx, tx, requestID, referee)
	})
	if errors.Is(err, ErrRefereeTaken) {
		return nil // a concurrent match took this referee on the task; sweep retries
	}
	return err
}

// notifyMatch tells the assigned referee they have a new task and the tasker
// their request matched (or was reassigned, if a prior request on the task was
// cancelled). A deleted tasker (nil id) is skipped.
func (s *Service) notifyMatch(ctx context.Context, tx database.Querier, requestID, refereeID string) error {
	rc, err := s.store.RequestContext(ctx, tx, requestID)
	if err != nil {
		return err
	}
	data := map[string]string{"route": "/tasks/" + rc.TaskID}
	if err := s.notifier.EnqueueInTx(ctx, tx, refereeID,
		"notification_task_assigned_referee", []string{rc.Title}, data); err != nil {
		return err
	}
	if rc.TaskerID == "" {
		return nil
	}
	taskerKey := "notification_request_matched_tasker"
	if rc.HasCancelledSibling {
		taskerKey = "notification_matching_reassigned_tasker"
	}
	return s.notifier.EnqueueInTx(ctx, tx, rc.TaskerID, taskerKey, []string{rc.Title}, data)
}

// maybeNotifyCancelledPending tells the tasker their re-match is still searching,
// but only for a cancel-originated request (its task has a prior cancelled
// request) with a live tasker, and only once — the idempotency key survives the
// sweep's repeated re-matches (P4a-D19). A first-time (non-cancel) pending is a
// silent no-op; the sweep keeps retrying.
func (s *Service) maybeNotifyCancelledPending(ctx context.Context, tx database.Querier, requestID string) error {
	rc, err := s.store.RequestContext(ctx, tx, requestID)
	if errors.Is(err, sql.ErrNoRows) {
		return nil // request vanished (e.g. its task was deleted); nothing to notify (#464)
	}
	if err != nil {
		return err
	}
	if !rc.HasCancelledSibling || rc.TaskerID == "" {
		return nil
	}
	return s.notifier.EnqueueIdempotentInTx(ctx, tx, rc.TaskerID,
		"notification_matching_cancelled_pending_tasker", []string{rc.Title},
		map[string]string{"route": "/tasks/" + rc.TaskID},
		"cancelled_pending:"+requestID)
}

// Cancel lets the assigned referee drop an accepted request before the cancel
// deadline: it marks the request cancelled, removes the awaiting_evidence
// judgement, inserts a fresh pending replacement carrying the original funding
// source (P4a-D17), and enqueues a match — all atomically. Only the matched
// referee may cancel, only while the request is still accepted with its
// judgement un-progressed, and only before due minus cancel_deadline_hours.
func (s *Service) Cancel(ctx context.Context, requestID, callerID string) error {
	cfg, err := s.store.LoadConfig(ctx)
	if err != nil {
		return err
	}
	return database.WithTx(ctx, s.db, func(tx database.Querier) error {
		req, err := s.store.GetRequestForCancelInTx(ctx, tx, requestID)
		if errors.Is(err, sql.ErrNoRows) {
			return ErrNotFound
		}
		if err != nil {
			return err
		}
		if !req.MatchedRefereeID.Valid || req.MatchedRefereeID.String != callerID {
			return ErrForbidden
		}
		if req.Status != "accepted" {
			return ErrConflict
		}
		if !req.DueDate.Valid {
			return ErrConflict
		}
		if req.DueDate.Time.Add(-time.Duration(cfg.CancelDeadlineHours) * time.Hour).Before(time.Now()) {
			return ErrCancelDeadlinePassed
		}
		if err := s.store.SetStatusInTx(ctx, tx, requestID, "cancelled"); err != nil {
			return err
		}
		deleted, err := s.judgements.DeleteIfAwaitingEvidenceInTx(ctx, tx, requestID)
		if err != nil {
			return err
		}
		if !deleted {
			return ErrConflict // evidence review has progressed; cannot cancel
		}
		newID, err := s.store.InsertRequestInTx(ctx, tx, req.TaskID)
		if err != nil {
			return err
		}
		if err := s.store.SetPointSourceInTx(ctx, tx, newID, req.PointSource); err != nil {
			return err
		}
		return s.EnqueueMatchInTx(ctx, tx, newID)
	})
}

// HandleSweep is the recurring worker pass. It first reschedules itself (so a
// mid-run failure never stops the chain — the bucketed key makes a duplicate
// schedule on retry a no-op), then expires every pending request past the
// rematch cutoff (refund + notify, each in its own transaction) and re-enqueues
// a match for the pendings still inside the window.
func (s *Service) HandleSweep(ctx context.Context, _ *jobs.Job) error {
	if err := s.scheduleNextSweep(ctx); err != nil {
		return err
	}
	cfg, err := s.store.LoadConfig(ctx)
	if err != nil {
		return err
	}

	// Expire past-cutoff pendings. The expire CAS shares the transaction with the
	// refund + notify, so a request a concurrent match already accepted is neither
	// expired nor refunded.
	expiring, err := s.store.PastCutoffPendingIDs(ctx, cfg.RematchCutoffHours)
	if err != nil {
		return err
	}
	for _, e := range expiring {
		if err := database.WithTx(ctx, s.db, func(tx database.Querier) error {
			expired, err := s.store.ExpireIfPendingInTx(ctx, tx, e.ID)
			if err != nil {
				return err
			}
			if !expired {
				return nil // a concurrent match accepted it; leave it be
			}
			if err := s.points.RefundForRequestInTx(ctx, tx, e.ID, "matching expired: no referee found"); err != nil {
				return err
			}
			if e.TaskerID == "" {
				return nil // tasker was deleted; nothing to notify
			}
			return s.notifier.EnqueueInTx(ctx, tx, e.TaskerID,
				"notification_matching_expired_refunded_tasker", []string{e.Title},
				map[string]string{"route": "/tasks/" + e.TaskID})
		}); err != nil {
			return err
		}
	}

	// Re-enqueue a match for the pendings still inside the window.
	remaining, err := s.store.PendingWithinWindow(ctx, cfg.RematchCutoffHours)
	if err != nil {
		return err
	}
	for _, id := range remaining {
		if err := database.WithTx(ctx, s.db, func(tx database.Querier) error {
			return s.EnqueueMatchInTx(ctx, tx, id)
		}); err != nil {
			return err
		}
	}
	return nil
}

// pickIndex derives a stable index into the least-workload candidate set from
// the request id, so the choice is deterministic and idempotent (no math/rand
// inside the transaction). Faithful randomness is not required — any stable pick
// within the least-workload set preserves the balancing intent.
func pickIndex(requestID string, n int) int {
	h := fnv.New64a()
	_, _ = h.Write([]byte(requestID))
	return int(h.Sum64() % uint64(n))
}
