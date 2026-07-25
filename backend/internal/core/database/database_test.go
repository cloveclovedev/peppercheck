package database

import (
	"context"
	"os"
	"testing"
)

func TestConnectEmptyDSN(t *testing.T) {
	if _, err := Connect(context.Background(), ""); err == nil {
		t.Fatal("expected error for empty DSN")
	}
}

func TestConnectPings(t *testing.T) {
	dsn := dsnFromEnv(t)
	db, err := Connect(context.Background(), dsn)
	if err != nil {
		t.Fatalf("Connect: %v", err)
	}
	defer db.Close()
	if err := db.PingContext(context.Background()); err != nil {
		t.Fatalf("Ping: %v", err)
	}
}

func dsnFromEnv(t *testing.T) string {
	t.Helper()
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		t.Skip("DATABASE_URL not set; skipping integration test")
	}
	return dsn
}
