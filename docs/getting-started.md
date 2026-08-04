# Getting started

This guide covers the shortest supported paths for the current migration
branch. It does not require the legacy Supabase stack for the migrated identity
path.

## Prerequisites

- Docker with Docker Compose
- Flutter matching the SDK constraint in `peppercheck_flutter/pubspec.yaml`
- Xcode and an iOS Simulator, or the Android SDK and an emulator
- Firebase application configuration for the selected dev platform

Atlas v1.2.0 is required only for backend migration generation and the complete
backend test target. The local Compose stack uses the pinned Atlas container.

## Run the backend only

```sh
cd backend
make up
curl http://localhost/livez
curl http://localhost/readyz
```

`make up` creates `backend/.env` from the committed example when it is missing.
That file is local-only. Keep real provider credentials and production secrets
out of it. To exercise a flow that calls a real external service (e.g. R2
avatar uploads), run `make up BWS_PROJECT_ID=<id>` instead — see
[Bitwarden Secrets Manager development injection](development/bws-development.md).

Stop the stack while preserving data with `make down`. Use `make down-v` only
when intentionally discarding the local database and WAL archive.

## Run the mobile app and backend

From the repository root:

```sh
scripts/dev-run.sh --ios
```

Use `--android` for Android. Run one platform at a time — `flutter run` holds
the terminal for interactive hot reload (`r` / `R` / `q`). A platform flag
ensures the backend is up (starting it only if it is not already answering),
boots the selected simulator or emulator, and runs the Flutter dev flavor.

Backend control:

```sh
scripts/dev-run.sh --android            # ensure backend is up, then run Android
scripts/dev-run.sh --backend --android  # rebuild/restart backend, then run Android
scripts/dev-run.sh --backend            # (re)build/restart the backend only
```

Pass `--backend` after editing backend code to force `make up` (rebuild changed
images, recreate changed containers). Without it, a running backend is left
untouched. For a full reset including the local database, use `make reset`.

Other options:

```sh
scripts/dev-run.sh --build                          # Android debug APK compile check (no backend/emulator)
scripts/dev-run.sh --android --avd NAME
scripts/dev-run.sh --android --caddy-port 18080 --postgres-port 15432
```

`--build` compiles a debug APK with the JDK-21 pin and `--flavor dev` applied,
as a quick compile check.

See [local port configuration](operations/local-ports.md) when running multiple
worktrees or products concurrently. To run several isolated backends in parallel
worktrees, use `scripts/worktree/dev.sh` — see
[parallel development with worktrees](development/git-worktrees.md).

## Verify changes

Backend:

```sh
cd backend
make fmt
make vet
make test
```

Flutter:

```sh
cd peppercheck_flutter
flutter pub get
flutter analyze
flutter test
```

Consult the component README files for narrower caveats:

- [Go backend](../backend/README.md)
- [Flutter client](../peppercheck_flutter/README.md)
