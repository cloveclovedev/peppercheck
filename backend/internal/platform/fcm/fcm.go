// Package fcm is the Firebase Cloud Messaging adapter. It is the only place the
// Firebase Admin SDK's messaging types appear (platform boundary): the rest of
// the backend passes the provider-neutral Message/SendResult defined here. All
// notifications are localized on the device via loc-keys — the server never
// sends human-readable copy — so message text lives in the Flutter app's i18n
// bundle keyed by TitleLocKey/BodyLocKey.
//
// API shapes verified against firebase.google.com/go/v4 v4.21.0:
// AndroidNotification.{Title,Body}Loc{Key,Args}, ApsAlert.{TitleLocKey,
// TitleLocArgs,LocKey,LocArgs}, Client.SendEachForMulticast, and the
// IsUnregistered/IsInvalidArgument per-message error classifiers.
package fcm

import (
	"context"
	"fmt"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
)

// Message is a provider-neutral, loc-key push notification. LocArgs fills both
// the title and body placeholders (they share one argument list, matching the
// notification templates).
type Message struct {
	TitleLocKey string
	BodyLocKey  string
	LocArgs     []string
	Data        map[string]string
}

// SendResult reports tokens the provider rejected as permanently invalid
// (unregistered / malformed), so the caller can prune them from its token store.
type SendResult struct {
	InvalidTokens []string
}

// Client sends a message to a set of device tokens.
type Client interface {
	Send(ctx context.Context, tokens []string, msg Message) (SendResult, error)
}

type client struct{ msg *messaging.Client }

// New builds an FCM client using Application Default Credentials for projectID
// (the worker's GOOGLE_APPLICATION_CREDENTIALS service account). Unlike Phase 2
// token verification, sending requires real credentials.
func New(ctx context.Context, projectID string) (Client, error) {
	app, err := firebase.NewApp(ctx, &firebase.Config{ProjectID: projectID})
	if err != nil {
		return nil, fmt.Errorf("firebase app: %w", err)
	}
	m, err := app.Messaging(ctx)
	if err != nil {
		return nil, fmt.Errorf("messaging client: %w", err)
	}
	return &client{msg: m}, nil
}

// buildMulticast builds a loc-key multicast message for Android and iOS. The
// title and body share LocArgs. Kept as a pure function so message construction
// is unit-tested without Firebase.
func buildMulticast(tokens []string, m Message) *messaging.MulticastMessage {
	return &messaging.MulticastMessage{
		Tokens: tokens,
		Data:   m.Data,
		Android: &messaging.AndroidConfig{
			Notification: &messaging.AndroidNotification{
				TitleLocKey:  m.TitleLocKey,
				TitleLocArgs: m.LocArgs,
				BodyLocKey:   m.BodyLocKey,
				BodyLocArgs:  m.LocArgs,
			},
		},
		APNS: &messaging.APNSConfig{
			Payload: &messaging.APNSPayload{Aps: &messaging.Aps{
				Alert: &messaging.ApsAlert{
					TitleLocKey:  m.TitleLocKey,
					TitleLocArgs: m.LocArgs,
					LocKey:       m.BodyLocKey,
					LocArgs:      m.LocArgs,
				},
			}},
		},
	}
}

// Send delivers msg to tokens and returns the tokens FCM reported as permanently
// invalid. A nil/empty token list is a no-op. A transport-level error fails the
// whole send; per-token failures are classified, not returned as an error, so a
// partial success still prunes dead tokens.
func (c *client) Send(ctx context.Context, tokens []string, m Message) (SendResult, error) {
	if len(tokens) == 0 {
		return SendResult{}, nil
	}
	resp, err := c.msg.SendEachForMulticast(ctx, buildMulticast(tokens, m))
	if err != nil {
		return SendResult{}, fmt.Errorf("fcm send: %w", err)
	}
	var invalid []string
	for i, r := range resp.Responses {
		if r.Error != nil && (messaging.IsUnregistered(r.Error) || messaging.IsInvalidArgument(r.Error)) {
			invalid = append(invalid, tokens[i])
		}
	}
	return SendResult{InvalidTokens: invalid}, nil
}
