// Package accountdeletion captures unauthenticated web account-deletion
// requests. It resolves a claimed email to a real user and records an
// unverified request. Verification and the deletion saga are Phase 6.
package accountdeletion

import "time"

// DeletionRequest is one row in account_deletion_requests.
type DeletionRequest struct {
	ID           string
	UserID       string
	ClaimedEmail string
	Status       string
	Source       string
	RequestedAt  time.Time
	UpdatedAt    time.Time
}
