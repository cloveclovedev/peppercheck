package api

import (
	"context"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
	"github.com/cloveclovedev/peppercheck/backend/internal/identity"
	"github.com/cloveclovedev/peppercheck/backend/internal/notification"
	"github.com/cloveclovedev/peppercheck/backend/internal/profile"
)

// provisioner fans first-sighting provisioning out to the profile and
// notification stores (in that order) inside the identity transaction.
type provisioner struct {
	profile      *profile.Store
	notification *notification.Store
}

// NewProvisioner composes the profile + notification provisioning fan-out as an
// identity.Provisioner. main.go and the api integration tests both use it, so
// the wiring stays single-sourced.
func NewProvisioner(p *profile.Store, n *notification.Store) identity.Provisioner {
	return provisioner{profile: p, notification: n}
}

func (pr provisioner) ProvisionInTx(ctx context.Context, q database.Querier, userID string) error {
	if err := pr.profile.ProvisionInTx(ctx, q, userID); err != nil {
		return err
	}
	return pr.notification.ProvisionSettingsInTx(ctx, q, userID)
}
