# Release Branch & Tag Workflow

PepperCheck deploys are tag-based. This rule covers how `beta/vX.Y` branches and `vX.Y.Z` tags are managed across the release lifecycle.

## Branch lifecycle

A `beta/vX.Y` branch is cut from `main` and serves as the staging branch for the `vX.Y.*` release line.

### Before the first `vX.Y.0` tag is cut

- Rebasing `beta/vX.Y` from `main` is **allowed** while the branch is still being stabilized.

### After `vX.Y.0` is tagged

- **Do not rebase `beta/vX.Y` from `main`.** The branch must stay stable so cherry-picks produce predictable diffs and the next patch tag is a clean superset of the prior one.
- Bring fixes in by **cherry-picking** specific commits from `main` into `beta/vX.Y`.
- Cut subsequent patch tags (`vX.Y.1`, `vX.Y.2`, ...) from the resulting `beta/vX.Y` head.

### Minor version bumps (`vX.Y+1.0`)

- Do **not** reuse `beta/vX.Y`. Cut a fresh `beta/vX.Y+1` from `main`. Pre-tag rebase rules apply to the new branch until its `vX.Y+1.0` tag.

## Deploy triggers

- Pushing to a `beta/v*` branch → `deploy-beta.yml` (staging).
- Pushing a `v*` tag → `deploy-production.yml` (production).
- A PR merge to `main` does **not** deploy on its own. The operator decides when to cut the next tag.

## Cherry-pick guidance

When picking commits from `main` into a frozen `beta/vX.Y`:

- Include only what should ship in the patch release; skip commits scoped to a future minor (e.g., new-OS-only changes that belong to `vX.Y+1.0`).
- Include changes to `.gitignore` and other repo metadata that would otherwise leave a checked-out `beta/vX.Y` with phantom untracked files (e.g., operator-private skill files that were gitignored on `main`).

## Out of scope

- Per-deploy operator actions (secret rotation, smoke tests, external service config) — see the operator-private `release-checklist` skill.
- When to bump major/minor/patch — the operator's call per release.
