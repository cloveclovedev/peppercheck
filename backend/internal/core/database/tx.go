package database

import (
	"context"
	"database/sql"
	"fmt"
)

// WithTx runs fn inside a single transaction, committing on nil error and
// rolling back on error or panic. It is the unit-of-work boundary used by
// application services that span more than one store: fn receives a Querier
// bound to the transaction (*sql.Tx satisfies Querier), so every store call it
// makes commits or rolls back atomically together.
func WithTx(ctx context.Context, db *sql.DB, fn func(Querier) error) (err error) {
	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin: %w", err)
	}
	defer func() {
		if p := recover(); p != nil {
			_ = tx.Rollback()
			panic(p)
		}
		if err != nil {
			_ = tx.Rollback()
		}
	}()
	if err = fn(tx); err != nil {
		return err
	}
	if err = tx.Commit(); err != nil {
		return fmt.Errorf("commit: %w", err)
	}
	return nil
}
