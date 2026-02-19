# Supabase CLI Workflow Rules

## Migration File Creation

NEVER manually create migration SQL files in `supabase/migrations/`.

Always use the auto-generation workflow:
1. Make changes to schema files in `supabase/schemas/` (functions, triggers, tables, etc.)
2. Register new schema files in `supabase/config.toml` under `[db.migrations]` — `db diff` only detects files listed in config.toml, not all files in the schemas directory
3. Run `supabase db diff -f <descriptive_migration_name>` to auto-generate the migration file
   - `db diff` compares the cumulative result of all existing migrations against the current `supabase/schemas/` directory
   - It does NOT depend on the local running DB state — no need to manually apply SQL to the local DB first
3. Review the generated migration file for correctness
   - DML statements (e.g. `cron.schedule()`) are NOT captured by `db diff` — manually append them to the migration file with a `-- DML, not detected by schema diff` comment
4. Run `./scripts/db-reset-and-clear-android-emulators-cache.sh` to verify the full migration history works from scratch and clear emulator caches for testing

## Migration Granularity

Bundle related schema changes into a single migration when they will be tested together. Only split migrations when you need to test intermediate states independently.

## Naming

Use descriptive snake_case names:
- `supabase db diff -f add_user_profiles_table`
- `supabase db diff -f add_rls_policies_to_orders`
