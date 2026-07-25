// Package identity resolves a verified external identity to the internal user
// anchor. PepperCheck owns users.id (a UUID); user_identities maps
// (issuer, subject) to it. No provider UID is ever a domain key.
package identity

import "time"

// User is the internal user anchor. Domain FKs reference User.ID, never a
// provider UID.
type User struct {
	ID        string
	Status    string
	CreatedAt time.Time
	UpdatedAt time.Time
}
