# Issue/Milestone Reorganization Design

## Problem

- Milestones are not maintained: v0.2.0/v0.3.0 are completed but not closed, v0.4.0/v1.0.0 have past due dates
- Only Epic issues have milestones; task-level issues are unassigned
- Epic management overhead is disproportionate for a solo developer
- anisecord's `/daily-plan` cannot generate useful plans because issues lack milestone assignment

## Decision

### Adopt flat issue + milestone model

**Milestone rules:**
- Milestone = release version + due date
- "Has milestone" = scheduled. "No milestone" = backlog (timing undecided)
- Only define the next 1-2 milestones concretely. Create future ones when needed
- Due dates exist only on milestones, not on individual issues

**Issue rules:**
- All issues are flat and directly actionable work units
- No Epic concept. Remove `type/epic` label
- Large features use 1 issue + body checklist. Split into separate issues only when needed
- Labels: `type/feature`, `type/task`, `bug`, `area/*` for classification

## Milestone Changes

| Action | Milestone | Reason |
|--------|-----------|--------|
| Close | v0.2.0 (Payment v1) | All issues completed |
| Keep | v0.3.0 (Flutter Android) | In progress. Update due date |
| Keep | v0.4.0 (Freemium v1) | Next after v0.3.0. Update due date |
| Keep | v1.0.0 (MVP Release) | Google Play release. Update due date |
| Keep | v1.1.0 (Flutter iOS) | After MVP. Re-evaluate due date after v1.0.0 |
| Delete | v1.3.0 (Flutter Android) | Empty milestone, no issues |
| Delete | v1.4.0 (Profile v1) | Too far ahead. Recreate when needed |
| Delete | v1.5.0 (Nudge v1) | Too far ahead. Recreate when needed |
| Delete | v1.6.0 (Multi-lang) | Too far ahead. Recreate when needed |

## Epic Issue Conversion

| Issue | Action |
|-------|--------|
| #72 Epic: Flutter Android (closed) | Keep as-is (used as working checklist). Remove `type/epic` label, assign to v0.3.0 |
| #70 Epic: Freemium v1 | Relabel `type/epic` → `type/feature`. Keep in v0.4.0 |
| #21 Epic: MVP release | Relabel `type/epic` → `type/feature`. Keep in v1.0.0 |
| #71 Epic: Flutter iOS | Relabel `type/epic` → `type/feature`. Keep in v1.1.0 |
| #73 Epic: Profile v1 | Relabel `type/epic` → `type/feature`. Remove milestone (backlog) |
| #74 Epic: Multi-lang/currency | Relabel `type/epic` → `type/feature`. Remove milestone (backlog) |
| #75 Epic: Nudge v1 | Relabel `type/epic` → `type/feature`. Remove milestone (backlog) |

## Issue Milestone Assignment

| Issue | Milestone | Reason |
|-------|-----------|--------|
| #253 Consolidate vault secrets | v1.0.0 | Infra improvement before release |
| #255 Migrate to pgTAP | v1.0.0 | Test infrastructure before release |
| #257 Notification audit | v1.0.0 | Quality assurance before release |
| #260 Trigger naming convention | v1.0.0 | Refactoring before release |
| #218 Revert verify_jwt | v1.0.0 | Technical debt resolution |
| #183 Refactor site_url | v1.0.0 | CI/CD improvement |
| #215 Save as Draft button | Backlog | Post-freemium feature |
| #251 Admin payout reporting | Backlog | Post-launch operational improvement |
| #252 Refined payout failure | Backlog | Post-launch operational improvement |

## Label Changes

- Delete: `type/epic`
- Keep: all other labels (`type/feature`, `type/task`, `bug`, `area/*`, `priority/*`, etc.)
