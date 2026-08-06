package notification_test

import (
	"context"
	"database/sql"
	"encoding/json"
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/jobs"
	"github.com/cloveclovedev/peppercheck/backend/internal/notification"
	"github.com/cloveclovedev/peppercheck/backend/internal/platform/fcm"
	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
)

type fakeFCM struct {
	gotTokens []string
	invalid   []string
}

func (f *fakeFCM) Send(_ context.Context, tokens []string, _ fcm.Message) (fcm.SendResult, error) {
	f.gotTokens = tokens
	return fcm.SendResult{InvalidTokens: f.invalid}, nil
}

// seedUserWithTokens inserts a user and binds the given device tokens to them,
// returning the user id.
func seedUserWithTokens(t *testing.T, db *sql.DB, tokens ...string) string {
	t.Helper()
	ctx := context.Background()
	var userID string
	if err := db.QueryRowContext(ctx, `INSERT INTO public.users DEFAULT VALUES RETURNING id`).Scan(&userID); err != nil {
		t.Fatalf("seed user: %v", err)
	}
	for _, tok := range tokens {
		if _, err := db.ExecContext(ctx,
			`INSERT INTO public.device_push_tokens (user_id, token) VALUES ($1, $2)`, userID, tok,
		); err != nil {
			t.Fatalf("seed token %q: %v", tok, err)
		}
	}
	return userID
}

func TestHandleSendDeliversAndCleansInvalidTokens(t *testing.T) {
	db := testsupport.DB(t)
	userID := seedUserWithTokens(t, db, "good-token", "bad-token")
	fake := &fakeFCM{invalid: []string{"bad-token"}}
	sender := notification.NewSender(notification.NewStore(db), fake)

	payload, _ := json.Marshal(map[string]any{
		"userId":  userID,
		"keyBase": "notification_task_assigned_referee",
		"args":    []string{"Wash the car"},
		"data":    map[string]string{"route": "/tasks/1"},
	})
	job := &jobs.Job{Kind: notification.JobKindSendNotification, Payload: payload}
	if err := sender.HandleSend(context.Background(), job); err != nil {
		t.Fatalf("HandleSend: %v", err)
	}

	if len(fake.gotTokens) != 2 {
		t.Fatalf("want 2 tokens sent, got %d (%v)", len(fake.gotTokens), fake.gotTokens)
	}
	var remaining int
	if err := db.QueryRow(`SELECT count(*) FROM public.device_push_tokens WHERE user_id=$1`, userID).Scan(&remaining); err != nil {
		t.Fatalf("count remaining: %v", err)
	}
	if remaining != 1 {
		t.Fatalf("want invalid token pruned (1 left), got %d", remaining)
	}
}

func TestHandleSendNoTokensIsNoop(t *testing.T) {
	db := testsupport.DB(t)
	userID := seedUserWithTokens(t, db) // user with zero tokens
	fake := &fakeFCM{}
	sender := notification.NewSender(notification.NewStore(db), fake)

	payload, _ := json.Marshal(map[string]any{"userId": userID, "keyBase": "notification_x", "args": []string{}})
	if err := sender.HandleSend(context.Background(), &jobs.Job{Payload: payload}); err != nil {
		t.Fatalf("HandleSend: %v", err)
	}
	if fake.gotTokens != nil {
		t.Fatalf("want no send for zero tokens, got %v", fake.gotTokens)
	}
}
