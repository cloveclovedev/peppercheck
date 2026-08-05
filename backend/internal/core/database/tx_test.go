package database_test

import (
	"context"
	"database/sql"
	"errors"
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
)

// probeTable creates a fresh regular table for a WithTx test and drops it at
// cleanup. A regular (not TEMP) table is used deliberately: the pool hands out
// different connections across calls, and a TEMP table is only visible on the
// connection that created it, so a TEMP probe would be invisible to the
// post-commit assertion query. make test runs packages with -p 1 and these
// tests are not t.Parallel, so the fixed name never collides.
func probeTable(t *testing.T, db *sql.DB, name string) {
	t.Helper()
	ctx := context.Background()
	if _, err := db.ExecContext(ctx, `DROP TABLE IF EXISTS `+name); err != nil {
		t.Fatalf("drop probe table: %v", err)
	}
	if _, err := db.ExecContext(ctx, `CREATE TABLE `+name+` (n int)`); err != nil {
		t.Fatalf("create probe table: %v", err)
	}
	t.Cleanup(func() { _, _ = db.Exec(`DROP TABLE IF EXISTS ` + name) })
}

func TestWithTxCommitsOnSuccess(t *testing.T) {
	db := testsupport.DB(t)
	probeTable(t, db, "tx_probe")
	err := database.WithTx(context.Background(), db, func(tx database.Querier) error {
		_, err := tx.ExecContext(context.Background(), `INSERT INTO tx_probe VALUES (1)`)
		return err
	})
	if err != nil {
		t.Fatalf("WithTx: %v", err)
	}
	var n int
	if err := db.QueryRow(`SELECT count(*) FROM tx_probe`).Scan(&n); err != nil || n != 1 {
		t.Fatalf("want 1 row, got n=%d err=%v", n, err)
	}
}

func TestWithTxRollsBackOnError(t *testing.T) {
	db := testsupport.DB(t)
	probeTable(t, db, "tx_probe2")
	sentinel := errors.New("boom")
	err := database.WithTx(context.Background(), db, func(tx database.Querier) error {
		_, _ = tx.ExecContext(context.Background(), `INSERT INTO tx_probe2 VALUES (1)`)
		return sentinel
	})
	if !errors.Is(err, sentinel) {
		t.Fatalf("want sentinel, got %v", err)
	}
	var n int
	_ = db.QueryRow(`SELECT count(*) FROM tx_probe2`).Scan(&n)
	if n != 0 {
		t.Fatalf("want rollback (0 rows), got %d", n)
	}
}
