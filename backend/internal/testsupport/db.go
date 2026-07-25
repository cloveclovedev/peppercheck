// Package testsupport provides shared helpers for integration tests.
package testsupport

import (
	"context"
	"os"
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
)

// DB returns a connected *sql.DB for integration tests, or skips the test when
// DATABASE_URL is not set. The pool is closed automatically at test cleanup.
func DB(t *testing.T) *database.Handle {
	t.Helper()
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		t.Skip("DATABASE_URL not set; skipping integration test")
	}
	db, err := database.Connect(context.Background(), dsn)
	if err != nil {
		t.Fatalf("connect: %v", err)
	}
	t.Cleanup(func() { _ = db.Close() })
	return db
}
