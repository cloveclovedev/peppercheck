package accountdeletion

import (
	"context"
	"errors"
	"strings"

	"github.com/cloveclovedev/peppercheck/backend/internal/identity"
)

// userLookup resolves a claimed email to a user (identity.Store satisfies it).
type userLookup interface {
	FindUserByEmail(ctx context.Context, email string) (identity.User, error)
}

type requestStore interface {
	Upsert(ctx context.Context, userID, claimedEmail string) error
}

// Service owns the request-deletion use case.
type Service struct {
	users userLookup
	store requestStore
}

// NewService builds a Service over a user lookup and a request store.
func NewService(users userLookup, store requestStore) *Service {
	return &Service{users: users, store: store}
}

// RequestDeletion records an unverified deletion request IFF the claimed
// email matches a real account. No match (or an empty/invalid email) is a
// silent no-op -- the caller always returns the same uniform response. A
// non-nil error means an infrastructure failure only.
func (s *Service) RequestDeletion(ctx context.Context, claimedEmail string) error {
	email := strings.TrimSpace(strings.ToLower(claimedEmail))
	if email == "" || !strings.Contains(email, "@") {
		return nil
	}
	u, err := s.users.FindUserByEmail(ctx, email)
	if errors.Is(err, identity.ErrNotFound) {
		return nil
	}
	if err != nil {
		return err
	}
	return s.store.Upsert(ctx, u.ID, email)
}
