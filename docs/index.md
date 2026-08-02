# PepperCheck documentation

This directory is the entry point for current project documentation. Use the
links below instead of inferring current behavior from historical plans or
legacy component documents.

## Start here

- [Getting started](getting-started.md) — shortest verified path to a local
  backend or mobile development session
- [Current architecture](architecture/overview.md) — what exists now, including
  the temporary migration boundary
- [Go/VPS refactoring strategy](designs/2026-07-22-supabase-to-go-vps-refactor-design.md)
  — approved target direction and program-level decisions
- [Go/VPS implementation-plan inventory](development/go-vps-plans/README.md) —
  retained execution guidance and lifecycle policy

## Documentation by purpose

- `architecture/` describes the current system in the present tense.
- `designs/` contains dated design decisions and historical baselines.
- `development/` contains task-oriented development procedures.
- `operations/` contains environment and operator runbooks.
- `overview/` contains product context and terminology.
- `plans/` contains older implementation plans retained for historical context.
  They must be revalidated before use and are not a work tracker.
- `stripe/` contains legacy Stripe-specific operational notes pending migration
  into the relevant operations or design documents.

GitHub Issues own accepted work, prioritization, dependencies, and progress.
Pull requests own implementation summaries and verification evidence. Do not
add a Markdown backlog that duplicates Issues.

## Refactoring documentation

The detailed Go/VPS plans are temporarily committed because they contain useful
sequencing and verification detail. They remain subordinate to the current
code, approved designs, and GitHub Issues. Starting with Phase 4b, a standalone
plan is optional when the design and Issues already provide enough guidance.

The `developer-docs/` tree is legacy content outside this documentation model.
It is not a contribution-rule source and should be inspected only as part of an
explicit migration or audit.
