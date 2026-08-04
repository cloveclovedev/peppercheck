---
name: run-and-verify
description: Run the PepperCheck app + Go backend locally and verify a change end-to-end (backend and iOS/Android simulators). Use when starting the local stack or manually verifying a change — follow the canonical scripts/dev-run.sh / make paths and the SoT docs instead of invoking docker compose or gradle directly.
---

# Run and verify locally

Canonical way to bring up the local stack and verify a change by hand. The
detailed steps live in the docs — this skill routes you to them and flags the
non-obvious traps. Treat [`docs/getting-started.md`](../../../docs/getting-started.md)
as the source of truth; do not run `docker compose`, `gradlew`, or `flutter run`
directly when a `scripts/dev-run.sh` / `make` path exists.

## Choose the launcher

- **Primary worktree / single stack** → `scripts/dev-run.sh` (below).
- **Several isolated backends in parallel worktrees** → `scripts/worktree/dev.sh`
  (`backend-up`, `flutter-run`, `status`, `backend-down`). It isolates each
  worktree's Compose project, volumes, and ports. See
  [`docs/development/git-worktrees.md`](../../../docs/development/git-worktrees.md).
  Do not use `dev-run.sh` for parallel backends.

## Run the single stack

```sh
scripts/dev-run.sh --android            # ensure backend is up, then run Android
scripts/dev-run.sh --ios                # ensure backend is up, then run iOS
scripts/dev-run.sh --backend --android  # rebuild/restart backend, then run app
scripts/dev-run.sh --backend            # (re)build/restart the backend only
```

- A bare platform flag ensures the backend (starts it only if it is not already
  up on `--caddy-port`), leaving a running backend and its data untouched.
- Pass `--backend` after editing backend code to force a rebuild/restart. For a
  full reset including the local DB, use `cd backend && make reset`.
- Run one platform at a time; see `scripts/dev-run.sh --help` for port and AVD
  options and [`docs/operations/local-ports.md`](../../../docs/operations/local-ports.md).

## Who runs the interactive app

`dev-run.sh --ios|--android` execs `flutter run` in the foreground, so
interactive hot reload (`r` / `R` / `q`) works **only when a human runs it in
their own terminal**. An agent invoking it as a captured command cannot relay
keystrokes and will just block. Division of labour:

- **Agent** manages the backend (`scripts/dev-run.sh --backend`) and uses
  `scripts/dev-run.sh --build` for a compile check (JDK-pinned, flavored debug
  APK; no backend or emulator needed).
- **Human** runs the interactive app (`scripts/dev-run.sh --android`); the
  idempotent backend check means it will not disturb the agent's backend.

## Gotchas

- **Real external services (R2 avatar upload).** Plain `make up` / `dev-run.sh`
  works without secrets, but the R2 avatar-upload flow is non-functional and, per
  [#483](https://github.com/cloveclovedev/peppercheck/issues/483), fails *open* —
  it returns a presigned URL to a nonexistent account instead of erroring. To
  exercise it, inject real dev secrets: `make up BWS_PROJECT_ID=<id>` (find the id
  with `bws project list`). Everything else (auth/login, `/me`, profile,
  notification tokens) works without it. See
  [`docs/development/bws-development.md`](../../../docs/development/bws-development.md).
- **Manual `flutter build apk`** (only when not using `dev-run.sh`) needs
  `--flavor dev`, and Android requires a JDK ≤ 21. `dev-run.sh` handles both;
  direct builds do not. See [`.claude/rules/flutter.md`](../../rules/flutter.md)
  and [`docs/development/flutter/android-jdk.md`](../../../docs/development/flutter/android-jdk.md).

## Automated checks

Lint, format, analyze, and tests are enforced by the pre-commit hooks and CI —
this skill covers launching the stack and manual verification, not re-running
those checks. The check commands, if you need them, are under "Verify changes"
in [`docs/getting-started.md`](../../../docs/getting-started.md).
