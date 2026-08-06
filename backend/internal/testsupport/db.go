// Package testsupport provides shared helpers for integration tests.
package testsupport

import (
	"context"
	"os"
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
)

// DB returns a connected *sql.DB for integration tests using DATABASE_URL.
func DB(t *testing.T) *database.Handle {
	t.Helper()
	return DBFromEnv(t, "DATABASE_URL")
}

// DBFromEnv returns a connected *sql.DB using the named environment variable,
// or skips the test when it is not set. The pool is closed automatically at
// test cleanup.
func DBFromEnv(t *testing.T, envName string) *database.Handle {
	t.Helper()
	dsn := os.Getenv(envName)
	if dsn == "" {
		t.Skipf("%s not set; skipping integration test", envName)
	}
	db, err := database.Connect(context.Background(), dsn)
	if err != nil {
		t.Fatalf("connect using %s: %v", envName, err)
	}
	t.Cleanup(func() { _ = db.Close() })
	return db
}
