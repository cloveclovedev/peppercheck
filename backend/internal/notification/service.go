package notification

import (
	"context"
	"errors"
)

// ErrInvalidArgument means a required field failed validation (400).
var ErrInvalidArgument = errors.New("invalid argument")

// storeIface is the persistence the service needs; *Store satisfies it.
type storeIface interface {
	UpsertToken(ctx context.Context, userID, token, deviceType string) error
	DeleteToken(ctx context.Context, userID, token string) error
}

// Service owns FCM token registration/deregistration, scoped to the caller.
type Service struct {
	store storeIface
}

// NewService builds a Service over a store.
func NewService(store storeIface) *Service { return &Service{store: store} }

// RegisterToken binds (or rebinds) an FCM token to the user. An empty token is
// rejected.
func (s *Service) RegisterToken(ctx context.Context, userID, token, deviceType string) error {
	if token == "" {
		return ErrInvalidArgument
	}
	return s.store.UpsertToken(ctx, userID, token, deviceType)
}

// DeleteToken removes the caller's binding for a token. An empty token is
// rejected.
func (s *Service) DeleteToken(ctx context.Context, userID, token string) error {
	if token == "" {
		return ErrInvalidArgument
	}
	return s.store.DeleteToken(ctx, userID, token)
}
