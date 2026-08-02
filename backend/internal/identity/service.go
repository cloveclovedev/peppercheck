package identity

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
)

// store is the persistence the service needs; *Store satisfies it.
type store interface {
	FindByIdentity(ctx context.Context, issuer, subject string) (User, error)
	CreateWithIdentity(ctx context.Context, issuer, subject string,
		provision func(ctx context.Context, tx *sql.Tx, userID string) error) (User, error)
}

// Provisioner fans first-sighting provisioning out to feature stores inside the
// identity transaction. profile.Store and notification.Store implement it; the
// combined provisioner is composed in main.go. A nil provisioner means no
// fan-out (identity + user only), used where features are not wired (tests).
type Provisioner interface {
	ProvisionInTx(ctx context.Context, q database.Querier, userID string) error
}

// Service owns the resolve-or-provision use case for identities.
type Service struct {
	store       store
	provisioner Provisioner
}

// NewService builds a Service over a store and an optional Provisioner (nil = no
// fan-out).
func NewService(s store, p Provisioner) *Service {
	return &Service{store: s, provisioner: p}
}

// ResolveOrProvision maps a verified (issuer, subject) to the internal user,
// creating it on first sighting. First-sighting creation runs the provisioner
// fan-out inside the same transaction, so users + identity + profile + settings
// commit atomically. A concurrent first sighting is resolved by re-finding after
// the losing insert reports ErrNotFound.
func (s *Service) ResolveOrProvision(ctx context.Context, issuer, subject string) (User, error) {
	u, err := s.store.FindByIdentity(ctx, issuer, subject)
	if err == nil {
		return u, nil
	}
	if !errors.Is(err, ErrNotFound) {
		return User{}, err
	}

	u, err = s.store.CreateWithIdentity(ctx, issuer, subject,
		func(ctx context.Context, tx *sql.Tx, userID string) error {
			if s.provisioner == nil {
				return nil
			}
			// *sql.Tx satisfies database.Querier, so the fan-out shares the tx.
			return s.provisioner.ProvisionInTx(ctx, tx, userID)
		})
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
