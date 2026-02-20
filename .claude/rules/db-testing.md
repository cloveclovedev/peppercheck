# DB Testing

## `supabase/tests/` vs `supabase/snippets/`

- **`supabase/tests/`** — Automated unit tests. Transactional (`BEGIN`/`ROLLBACK`), self-contained, assertion-based. Run via `docker exec psql`. No data persists after execution.
- **`supabase/snippets/`** — Manual test helpers. Set up real data in the local DB for emulator-based manual testing. Data persists so the app can interact with it. Include placeholder user IDs that the developer fills in.

Do not put assertion-based unit tests in `snippets/`. Do not put persistent data setup in `tests/`.

## Unit Tests for Schema Changes

When modifying `supabase/schemas/` (tables, functions, triggers, policies, etc.), always create or update corresponding unit tests in `supabase/tests/`.

### Test file conventions

- File name: `supabase/tests/test_<feature_name>.sql`
- Pattern: `BEGIN` → setup → `DO $$ ... ASSERT ... $$` blocks → `ROLLBACK`
- Run via: `docker cp supabase/tests/<file>.sql supabase_db_supabase:/tmp/ && docker exec supabase_db_supabase psql -U postgres -f /tmp/<file>.sql`

### Regression testing

After all schema changes and new tests pass, run ALL existing tests to verify no regressions:

```bash
for f in supabase/tests/test_*.sql; do
  echo "=== Running $f ==="
  docker cp "$f" supabase_db_supabase:/tmp/ && \
  docker exec supabase_db_supabase psql -U postgres -f "/tmp/$(basename "$f")"
  echo ""
done
```

All tests must pass before committing the migration.
