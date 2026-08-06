# Local dev port map

Host ports published by the local dev stack, and how to move them when another
project already holds one. Defaults preserve the current behavior — you only
need to change these on a clash.

| Service | Container port | Default host port | Env var (`backend/.env`) | dev-run flag |
|---------|----------------|-------------------|--------------------------|--------------|
| Caddy — app ingress | 80 | 80 | `CADDY_HTTP_PORT` | `--caddy-port N` |
| Caddy — HTTPS | 443 | 443 | `CADDY_HTTPS_PORT` | — |
| Postgres | 5432 | 5432 (loopback only) | `POSTGRES_HOST_PORT` | `--postgres-port N` |

Not published to the host (reachable only inside the Compose network): **api**
(`8765`, behind Caddy), **worker**, **migrate**. The Flutter app talks to the
api through Caddy, never to `8765` directly.

## Changing a port

Two equivalent ways:

- **`backend/.env`** — set e.g. `POSTGRES_HOST_PORT=5433`, then `make up`.
- **`scripts/dev-run.sh`** — pass `--postgres-port 5433` and/or `--caddy-port 8080`.

## The one coupling: the ingress port

The Flutter dev app must reach Caddy, so if you move `CADDY_HTTP_PORT` the app
has to use the same port. Two cases:

- **Via `dev-run.sh`** — `--caddy-port` is the single source of truth: it
  publishes Caddy on that port **and** passes `--dart-define=DEV_API_PORT=<port>`
  to `flutter run`, so the two always agree. Nothing else to do.
- **Running `flutter run` yourself** — pass the matching define, e.g.
  `flutter run --flavor dev -t lib/main_dev.dart --dart-define=DEV_API_PORT=8080`.
  The app builds `http://127.0.0.1:<port>` (iOS) / `http://10.0.2.2:<port>`
  (Android); the port is omitted entirely when it is the default 80.

`POSTGRES_HOST_PORT` has no app coupling — it only affects host tools (psql,
Atlas); the api/worker reach Postgres over the Compose network regardless.

## Why Postgres is loopback-only

`compose.override.yaml` binds Postgres to `127.0.0.1` (never `0.0.0.0`) so it is
not exposed off-host. Production runs Compose without the override
(`-f compose.yaml`), so `:5432` is never published there.
