# Parallel local development with Git worktrees

Use a separate Git worktree for each agent or feature that needs to build or
run locally. The helper scripts keep local configuration, Docker Compose
resources, host ports, and Flutter build output isolated per worktree.

## Bootstrap a worktree

Create the worktree using your normal Git or agent workflow, then run this
command from its repository root:

```sh
scripts/worktree/bootstrap.sh
```

The script copies only this reviewed list of machine-local configuration from
the primary worktree: backend local configuration, all Flutter environment
assets, Android Firebase configs, iOS Firebase plists, and iOS signing
xcconfigs. It does not copy build directories, Pods, `.dart_tool`, caches, or
arbitrary ignored files. It then runs `flutter pub get` in the target worktree.

The primary worktree is the first entry reported by `git worktree list`. To use
another source explicitly, pass `--source /absolute/path`. Use
`--skip-pub-get` only when dependency resolution should be deferred.

The copied files can contain provider configuration or signing identifiers.
The bootstrap script verifies that every destination remains ignored by Git;
they are copied only on the local machine and must never be committed.

## Run an isolated backend

```sh
scripts/worktree/dev.sh backend-up
scripts/worktree/dev.sh settings
scripts/worktree/dev.sh status
scripts/worktree/dev.sh backend-down
```

The script derives a Docker Compose project name from the full worktree path.
Before starting a backend or test database, it probes ports beginning with a
stable path-derived candidate and selects the first fully available set. The
backend selection is stored in the worktree's Git administrative directory, so
later lifecycle commands use the same stack. Each worktree therefore receives
its own containers, volumes, network, Caddy HTTP/HTTPS ports, Postgres port,
and temporary Postgres instance for `backend-test`.

Override the defaults when necessary:

```sh
scripts/worktree/dev.sh \
  --instance task-editor \
  --caddy-port 18081 \
  --https-port 19081 \
  --postgres-port 15433 \
  --test-postgres-port 16433 \
  backend-up
```

Use the same flags for later `backend-down`, `status`, and `backend-logs`
calls. `backend-test` passes an isolated temporary container name and port to
the backend Makefile:

```sh
scripts/worktree/dev.sh backend-test
```

## Run Flutter against that backend

First obtain a distinct simulator or emulator for each concurrently running
worktree. A dev flavor has one application identifier, so installing two
builds of that flavor onto the same device replaces the prior build.

```sh
flutter devices
scripts/worktree/dev.sh flutter-run --device <device-id>
```

`flutter-run` passes the worktree's Caddy HTTP port as `DEV_API_PORT`; the
Flutter app therefore reaches the matching isolated backend. The script runs
the dev flavor only. Use the ordinary flavor commands for staging or production
validation.

Flutter build output, `.dart_tool`, iOS Pods, and Gradle intermediate files
are already worktree-local. Shared SDK caches may serialize initial dependency
downloads, but do not share the generated application outputs.

## Clean up a worktree

Cleanup has two levels: pausing a worktree you will return to, and fully
removing one you are done with. The primary worktree's stack is a separate
Docker Compose project, so none of these commands affect it.

### Stop the Flutter session

How you stop the app depends on how `flutter run` is attached to a terminal.

- **Interactive terminal (normal human use).** When you started the app with
  `scripts/worktree/dev.sh flutter-run` in your own terminal, press `q` in that
  terminal to quit: it terminates the app on the device and detaches the
  tooling. `r` (hot reload), `R` (hot restart), and `d` (detach, leaving the app
  running) work there too.
- **Backgrounded or killed run (non-interactive, e.g. an agent).** If the
  `flutter run` process is killed instead of quit with `q`, the tooling detaches
  without a clean shutdown, and the two platforms differ:
  - Android keeps the app running, because it was launched as an ordinary
    process the tooling only attached to. Stop it explicitly:
    `adb -s <emulator-id> shell am force-stop dev.cloveclove.peppercheck.dev`.
  - The iOS simulator app is launched under the debugger, so it exits on detach
    on its own. Terminate it explicitly only if needed:
    `xcrun simctl terminate <simulator-udid> dev.cloveclove.peppercheck.dev`.

  (`dev.cloveclove.peppercheck.dev` is the dev flavor's application/bundle id on
  both platforms.)

### Stop the backend (keep the worktree)

Run from the worktree:

```sh
scripts/worktree/dev.sh backend-down
```

This stops and removes the worktree's containers and network but keeps its
volumes (Postgres data, the local WAL archive, and Caddy state), so the next
`backend-up` resumes with the same data.

### Fully remove a worktree

When you are finished with a worktree, tear the backend down together with its
volumes, then remove the worktree itself. Run from the worktree:

```sh
scripts/worktree/dev.sh backend-down --volumes
```

`--volumes` (short: `-v`) removes the worktree's containers, network, and
volumes (Postgres data, the local WAL archive, and Caddy state) in one step —
Docker resources live outside the worktree, so removing the checkout alone would
leave them orphaned. Then remove the worktree and, if it was a throwaway branch,
delete it. Run these from the primary worktree (or any directory outside the
target):

```sh
git worktree remove <path-to-worktree> --force
git branch -D <branch>   # only if the branch is no longer needed
```

`--force` is required because bootstrap copies machine-local configuration and
build output into the worktree, so Git treats it as dirty. Removing the worktree
deletes those local copies; the shared SDK caches are untouched.

If you removed the worktree before running `backend-down --volumes`, the
containers and volumes are orphaned but still carry the `pc_` name prefix, so
you can clean them up manually:

```sh
docker ps -a --filter "name=pc_" --format '{{.Names}}'   # find leftover containers
docker volume ls --filter "name=pc_"                     # find leftover volumes
docker rm -f <container>...
docker volume rm <volume>...
```
