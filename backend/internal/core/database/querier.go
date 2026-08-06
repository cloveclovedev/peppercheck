package database

import (
	"context"
	"database/sql"
)

// Querier is the subset of *sql.DB / *sql.Tx that stores use, so a store method
// can run either standalone or inside a caller-owned transaction (the Phase 3a
// provisioning fan-out). Both *sql.DB and *sql.Tx satisfy it.
type Querier interface {
	ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error)
	QueryContext(ctx context.Context, query string, args ...any) (*sql.Rows, error)
	QueryRowContext(ctx context.Context, query string, args ...any) *sql.Row
}
