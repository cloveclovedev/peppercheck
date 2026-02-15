# Supabase CLI Workflow Rules

## Migration File Creation

NEVER manually create migration SQL files in `supabase/migrations/`.

Always use the auto-generation workflow:
1. Apply schema changes directly to the local database (via Studio UI, SQL editor, or direct SQL)
2. Run `supabase db diff -f <descriptive_migration_name>` to auto-generate the migration file
3. Review the generated migration file for correctness
4. Run `supabase db reset` to verify the full migration history works from scratch

Use descriptive snake_case names:
- `supabase db diff -f add_user_profiles_table`
- `supabase db diff -f add_rls_policies_to_orders`
