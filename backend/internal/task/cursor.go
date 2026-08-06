package task

import (
	"encoding/base64"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
)

// cursor is an opaque keyset position over the (created_at DESC, id DESC) sort
// used by the task and assignment listings. It is serialized as an opaque
// base64 token the client echoes back as ?cursor=; clients must not parse it.
type cursor struct {
	CreatedAt time.Time
	ID        string
}

// encodeCursor renders a keyset position as an opaque token.
func encodeCursor(c cursor) string {
	raw := c.CreatedAt.UTC().Format(time.RFC3339Nano) + "|" + c.ID
	return base64.RawURLEncoding.EncodeToString([]byte(raw))
}

// decodeCursor parses an opaque token; an empty token means "from the start".
func decodeCursor(token string) (cursor, bool, error) {
	if token == "" {
		return cursor{}, false, nil
	}
	raw, err := base64.RawURLEncoding.DecodeString(token)
	if err != nil {
		return cursor{}, false, fmt.Errorf("%w: malformed cursor", ErrValidation)
	}
	parts := strings.SplitN(string(raw), "|", 2)
	if len(parts) != 2 {
		return cursor{}, false, fmt.Errorf("%w: malformed cursor", ErrValidation)
	}
	ts, err := time.Parse(time.RFC3339Nano, parts[0])
	if err != nil {
		return cursor{}, false, fmt.Errorf("%w: malformed cursor", ErrValidation)
	}
	// The id is bound to a uuid comparison in the keyset query; validate it here
	// so a crafted cursor is a 400, not a 500 from a Postgres uuid-syntax error.
	if uuid.Validate(parts[1]) != nil {
		return cursor{}, false, fmt.Errorf("%w: malformed cursor", ErrValidation)
	}
	return cursor{CreatedAt: ts, ID: parts[1]}, true, nil
}
