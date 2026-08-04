# Verification checks: where each is enforced

The checks under "Verify changes" in [getting-started](../getting-started.md) are
enforced automatically — you do not need to re-run them by hand. This records
what runs where, and the rule for placing a check.

## Placement rule

- **pre-commit** — fast, deterministic checks that need no build and no external
  services, so local feedback is immediate.
- **CI** — checks that compile the module, need a database or other services, or
  are slow enough that they belong in the pipeline rather than every commit.

A check may run in both (e.g. formatting), giving fast local feedback while CI
remains the enforcement gate.

## Where each check runs

| Check | pre-commit | CI |
|-------|:----------:|:--:|
| Flutter `dart format` | `dart-format` | `ci-flutter` (format check) |
| Flutter `flutter analyze` | `flutter-analyze` | `ci-flutter` |
| Flutter import boundaries | — | `ci-flutter` (`check-flutter-imports.sh`) |
| Flutter `flutter test` | — | `ci-flutter` |
| Backend `gofmt` | `gofmt` | `ci-backend` (`gofmt -l`) |
| Backend `go vet` | — | `ci-backend` |
| Backend `go test` (race, + real Postgres, migrations, roles) | — | `ci-backend` |
| Edge Functions `deno fmt` / `deno lint` | `deno-fmt` / `deno-lint` | — (pre-commit only) |
| Webapp `prettier` | `prettier-webapp` | `ci-webapp` (Format Check) |
| Secret scan (Stripe live keys) | `no-stripe-live-keys` | — |

`go vet` and the Go/Flutter test suites are CI-only by design: `go vet` compiles
the module, `go test` needs a throwaway Postgres and runs migrations and role
checks, and `flutter test` is slower than a per-commit hook should be.

Edge Function `deno fmt` / `deno lint` are **pre-commit only** — `ci-supabase`
runs the migration and database-test suite for `supabase/migrations/**`, not the
function formatters, so a contributor who bypasses pre-commit can merge
unformatted function changes. This is acceptable while Supabase is being migrated
out; revisit if Edge Function churn makes it worth a CI gate.

## Triggers

- pre-commit runs on staged files matching each hook's path filter.
- `ci-backend` runs on pull requests touching `backend/**` (any base branch) and
  on pushes to `refactor/go-api-vps`. `ci-flutter` runs on pull requests touching
  `peppercheck_flutter/**`. A PR that changes neither (docs, scripts, agent
  rules) runs neither — that is expected, not a gap.

## References

- Hooks: [`.pre-commit-config.yaml`](../../.pre-commit-config.yaml)
- Workflows: `.github/workflows/ci-backend.yml`, `ci-flutter.yml`,
  `ci-supabase.yml`, `ci-webapp.yml`
- Commands to run a check by hand: "Verify changes" in
  [getting-started](../getting-started.md)
