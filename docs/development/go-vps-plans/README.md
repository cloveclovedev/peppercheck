# Go/VPS Refactoring Plan Policy

This directory temporarily preserves detailed implementation plans for the
Supabase-to-Go/VPS refactoring program. The plans capture useful sequencing,
constraints, and verification work, but they are not the source of truth for
current architecture or project status.

## Sources of truth

- Approved design documents own durable decisions and rationale.
- GitHub Issues own status, priority, dependencies, and acceptance criteria.
  The current program parent is
  [#477](https://github.com/cloveclovedev/peppercheck/issues/477).
- Pull requests and the current code own implementation outcomes.
- Plans provide execution guidance and must be revalidated before use.

## Lifecycle

Use one of these statuses when maintaining the plan inventory:

- `Implemented`: the phase has landed; retain the plan for later-phase context.
- `Needs revalidation`: the plan predates current code or dependency state and
  must be checked before execution.
- `Blocked`: a required design decision or dependency has not landed.
- `Superseded`: a later decision or plan replaced the execution approach.
- `Historical`: retained for context but not an executable Go/VPS plan.

Do not use plan checkboxes as a second project tracker. When a phase is
implemented, record completion in its Issue and pull request, mark the plan as
`Implemented` in this inventory, and leave the file in place until the overall
program closes. The final refactoring cleanup removes these temporary plans
after preserving durable decisions in design documents.

## Plan requirement from Phase 4b onward

A separate implementation plan is optional starting with Phase 4b. An approved
design plus scoped GitHub Issues and verifiable acceptance criteria are
sufficient when they make the work clear. Write a plan only when it adds value
for sequencing, migration safety, cross-component coordination, or detailed
verification.

The existing Phase 4b plan is intentionally retained. Later phases do not need
to create matching plan files solely for process consistency.

## Current inventory

| Plan | Status | Note |
| --- | --- | --- |
| `2026-07-23-phase1-foundation.md` | Implemented | The current Go foundation supersedes plan snippets where they differ. |
| `2026-07-24-phase2-backend-identity.md` | Implemented | Backend identity landed in the integration branch. |
| `2026-07-25-phase2-flutter-identity-client.md` | Implemented | Flutter identity and client boundary landed in the integration branch. |
| `2026-07-25-phase3a-backend.md` | Needs revalidation | The Go-maintained `updated_at` convention is reconciled; revalidate against current code and dependencies before execution. |
| `2026-07-25-phase3a-flutter.md` | Needs revalidation | Revalidate after the Phase 3a backend contract lands. |
| `2026-07-25-phase4a-backend.md` | Needs revalidation | The database convention is reconciled; revalidate after Phase 3a and against current backend APIs. |
| `2026-07-25-phase7a-infra-ops-foundation.md` | Implemented | Infrastructure and operations foundation landed in the integration branch. |
| `2026-07-26-infra-foundation-setup.md` | Blocked | Reconcile its design reference and current operator workflow before execution. |
| `2026-07-26-phase3b-go-web.md` | Needs revalidation | Revalidate dependencies and the final database conventions. |
| `2026-07-26-phase4a-flutter-task-authoring-matching.md` | Needs revalidation | Depends on the Phase 3a Flutter and Phase 4a backend contracts. |
| `2026-07-26-phase4b-evidence-private-r2.md` | Needs revalidation | Existing optional plan with the database convention reconciled; revalidate dependencies and current APIs before execution. |
