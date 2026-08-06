package notification

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
	"github.com/cloveclovedev/peppercheck/backend/internal/core/jobs"
	"github.com/cloveclovedev/peppercheck/backend/internal/platform/fcm"
)

// JobKindSendNotification is the worker job kind for a queued push notification.
const JobKindSendNotification = "send_notification"

// sendStore is the persistence the Sender needs; *Store satisfies it. It is
// separate from the registration service's storeIface so the two use cases
// depend only on what they use.
type sendStore interface {
	TokensForUser(ctx context.Context, userID string) ([]string, error)
	DeleteTokens(ctx context.Context, userID string, tokens []string) error
	EnqueueSendInTx(ctx context.Context, tx database.Querier, kind string, payload any) error
	EnqueueSendIdempotentInTx(ctx context.Context, tx database.Querier, kind string, payload any, idempotencyKey string) error
}

// Sender enqueues and delivers push notifications. It is distinct from the
// registration Service (device-token binding): the Sender owns the outbox
// enqueue and the send_notification worker handler.
type Sender struct {
	store sendStore
	fcm   fcm.Client
}

// NewSender builds a Sender over a store and an FCM client.
func NewSender(store sendStore, client fcm.Client) *Sender {
	return &Sender{store: store, fcm: client}
}

// sendPayload is the JSON job payload. KeyBase is the notification template key
// prefix; the worker appends _title/_body to form the device loc-keys. The
// server sends no human-readable copy — only keys the app localizes.
type sendPayload struct {
	UserID  string            `json:"userId"`
	KeyBase string            `json:"keyBase"`
	Args    []string          `json:"args"`
	Data    map[string]string `json:"data"`
}

// EnqueueInTx writes a send_notification job into the caller's transaction
// (transactional outbox) so the notification rides the caller's commit and
// never fires on rollback.
func (s *Sender) EnqueueInTx(ctx context.Context, tx database.Querier, userID, keyBase string, args []string, data map[string]string) error {
	return s.store.EnqueueSendInTx(ctx, tx, JobKindSendNotification, sendPayload{
		UserID:  userID,
		KeyBase: keyBase,
		Args:    args,
		Data:    data,
	})
}

// EnqueueIdempotentInTx is EnqueueInTx keyed by idempotencyKey, so a caller that
// may re-run the same enqueue (e.g. the matching sweep repeatedly re-matching a
// still-pending request) delivers the push exactly once.
func (s *Sender) EnqueueIdempotentInTx(ctx context.Context, tx database.Querier, userID, keyBase string, args []string, data map[string]string, idempotencyKey string) error {
	return s.store.EnqueueSendIdempotentInTx(ctx, tx, JobKindSendNotification, sendPayload{
		UserID:  userID,
		KeyBase: keyBase,
		Args:    args,
		Data:    data,
	}, idempotencyKey)
}

// HandleSend is the worker handler for JobKindSendNotification: load the user's
// tokens, send the loc-key message via FCM, and prune any tokens FCM reports as
// permanently invalid. It is at-least-once safe (#464): a redelivery re-sends
// the same push (an acceptable duplicate) and pruning is idempotent. Loading no
// tokens is a successful no-op.
func (s *Sender) HandleSend(ctx context.Context, j *jobs.Job) error {
	var p sendPayload
	if err := json.Unmarshal(j.Payload, &p); err != nil {
		return fmt.Errorf("unmarshal send payload: %w", err)
	}
	tokens, err := s.store.TokensForUser(ctx, p.UserID)
	if err != nil {
		return err
	}
	res, err := s.fcm.Send(ctx, tokens, fcm.Message{
		TitleLocKey: p.KeyBase + "_title",
		BodyLocKey:  p.KeyBase + "_body",
		LocArgs:     p.Args,
		Data:        p.Data,
	})
	if err != nil {
		return err
	}
	if err := s.store.DeleteTokens(ctx, p.UserID, res.InvalidTokens); err != nil {
		return err
	}
	return nil
}
