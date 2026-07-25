package identity

import (
	"context"
	"errors"
	"fmt"
)

// store is the persistence the service needs; *Store satisfies it.
type store interface {
	FindByIdentity(ctx context.Context, issuer, subject string) (User, error)
	CreateWithIdentity(ctx context.Context, issuer, subject string) (User, error)
}

// Service owns the resolve-or-provision use case for identities.
type Service struct {
	store store
}

// NewService builds a Service over a store.
func NewService(s store) *Service { return &Service{store: s} }

// ResolveOrProvision maps a verified (issuer, subject) to the internal user,
// creating it on first sighting. A concurrent first sighting is resolved by
// re-finding after the losing insert reports ErrNotFound.
func (s *Service) ResolveOrProvision(ctx context.Context, issuer, subject string) (User, error) {
	u, err := s.store.FindByIdentity(ctx, issuer, subject)
	if err == nil {
		return u, nil
	}
	if !errors.Is(err, ErrNotFound) {
		return User{}, err
	}

	u, err = s.store.CreateWithIdentity(ctx, issuer, subject)
	if err == nil {
		return u, nil
	}
	if !errors.Is(err, ErrNotFound) {
		return User{}, err
	}

	// Lost the race: the row exists now — re-find it.
	u, err = s.store.FindByIdentity(ctx, issuer, subject)
	if err != nil {
		return User{}, fmt.Errorf("resolve after create race: %w", err)
	}
	return u, nil
}
