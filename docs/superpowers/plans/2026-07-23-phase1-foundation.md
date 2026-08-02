# Phase 1 — Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up a provider-independent Go backend skeleton (api + worker), an Atlas-managed Postgres with an internal-UUID identity core, durable job + webhook-inbox primitives, a local Docker Compose/Caddy stack, a backup/WAL skeleton, and CI — so a clean clone starts the whole stack locally and migrations recreate the DB from scratch. **No feature RPC, Edge Function, or web route is ported in this phase.**

**Architecture:** One Go module at `backend/` produces a single binary (`peppercheck`) run as two commands — `api` (JSON/HTTP + health) and `worker` (Postgres-backed durable jobs). Postgres is managed declaratively with Atlas (feature-split schema). Three DB roles separate migration (DDL), runtime (least-privilege DML), and backup (read-only). The core Docker Compose stack is `caddy · migrate · api · worker · postgres`; an opt-in `backup` profile adds the `backup` service. The same image serves `api` and `worker`.

**Tech Stack:** Go 1.26 (stdlib `net/http` + `log/slog`), pgx v5, Atlas, PostgreSQL 17, Docker Compose, Caddy 2, `age` encryption, GitHub Actions.

**Source of truth:** Program strategy `docs/superpowers/specs/2026-07-22-supabase-to-go-vps-refactor-design.md` (§6, §7, §10, §12, §13, §18, §20, §22, §24) and Phase 0 baseline `docs/superpowers/specs/2026-07-22-phase0-baseline.md` (§12 operational decisions, §13 handoff).

> **Post-implementation review fixes (2026-07-24).** After the tasks were implemented and reviewed, two external plan reviews were incorporated. Some fixes live in the committed code beyond the task snippets below — treat the committed code as source of truth where they differ:
> - **Durable jobs hardened** (`fix(backend): fail poison jobs after max attempts and recover worker handler panics`): `jobs.Claim` reclaims an expired-lease job only while `attempts < max_attempts`; a new `jobs.Store.FailExpired` (called at the start of each `worker.RunDue`) marks exhausted expired-lease jobs `failed`; `worker.process` runs handlers through a panic-recovering wrapper so one bad job cannot crash the worker.
> - **backup.sh** guards each step with `|| return 1` (shell-independent; `set -e` is suppressed in a function under `if !`).
> - **AGE_RECIPIENT** is `${VAR:-}` (not `:?`) so the core stack's `docker compose up` parses without an age key; `backup.sh` enforces it at runtime.
> - **Atlas pinned to `v1.2.0`** across Compose + CI (Standard distribution, unauthenticated/free; `latest` is a moving canary).
> - **compose.override.yaml** restored to `127.0.0.1:5432`.
>
> **Third review round (2026-07-24, `fix/phase1-review-followups`):**
> - **Atlas migration history isolated** in a dedicated migrator-owned `atlas` schema (`--revisions-schema atlas` + `CREATE SCHEMA atlas AUTHORIZATION peppercheck_migrator` in `00-roles.sh`) so the least-privilege app role can't read/tamper with it (verified: app denied `USAGE` on `atlas`).
> - **WAL archiver** is now `deploy/postgres/archive-wal.sh` — idempotent (identical re-archive → exit 0), refuses to overwrite a different file, copies atomically; replaces the naive `test ! -f && cp` that looped forever on re-archive.
> - **`archive_timeout` 60 → 900** (matches the 15-min RPO; cuts WAL volume ~15×). Retention/pruning + off-site (B2) remains a Phase-7 pre-deploy requirement.
> - **`backend/Makefile` + `backend/README.md`** added — `make up` bootstraps `.env`; README documents the WAL-retention caveat and that real DB passwords in DSNs must be URI-safe/percent-encoded (Atlas requires a URI DSN).

## Global Constraints

- **Module path:** `github.com/cloveclovedev/peppercheck/backend`. Directory: `backend/`.
- **Go:** 1.26. **Postgres:** 17 (matches `supabase/config.toml` `major_version = 17`). **Atlas:** current release. **Caddy:** 2.
- **Schema management (decided 2026-07-23, all verified):** Atlas (**Standard distribution, used unauthenticated = free** — not the separate "Community Edition" build) manages **tables only** declaratively — `schema/<feature>/*.sql` (CREATE TABLE + constraints/indexes) → `atlas migrate diff` → versioned migration; declarative stays the source of truth. Unauthenticated Atlas gates functions/triggers/views behind `atlas login` (Atlas Pro), and `migrate lint` is Pro-only — so **no DB functions/triggers** in Phase 1: `updated_at` is set by Go in each store's UPDATE (`updated_at = now()`), never by a DB trigger. `atlas.hcl` lists each feature subdir explicitly in `src` (Atlas does **not** recurse into subdirectories). **Hybrid escape hatch:** any DB-side object unauthenticated Atlas cannot manage for free (function/trigger/view) that a *later* phase genuinely needs is hand-authored as a supplementary versioned migration — `atlas migrate apply` runs raw SQL including functions/triggers for free; Phase 1 needs none. Atlas commands used (all free): `migrate diff`/`apply`/`hash`/`validate`. **Not used:** `migrate lint` (Pro-gated). **Version pinned to `v1.2.0`** (a stable release — `latest` is a moving canary) across the Compose `migrate` service and CI `setup-atlas`; align the dev machine via `curl -sSf https://atlasgo.sh | sh -s -- --version v1.2.0` (Homebrew can't pin a specific version). Because max-Go keeps zero DB functions/triggers, the free tier is a durable choice — no Atlas Pro feature is ever needed.
- **Dependency policy (stdlib-first):** use the Go standard library wherever practical. The **only** external Go dependency in Phase 1 is `github.com/jackc/pgx/v5`, used purely as a `database/sql` driver (`pgx/v5/stdlib`) — the industry-standard Postgres driver, sanctioned by the Engineering Policy (`database/sql or pgx`). All query code targets the stdlib `database/sql` interface. HTTP (`net/http`+`ServeMux`), logging (`log/slog`), JSON (`encoding/json`), config (`os`), request IDs (`crypto/rand`) are stdlib. No web framework, router, config, or logging library. Any future dependency must be simple and industry-standard, and justified in its task.
- **Service names (strategy §6):** `caddy`, `api`, `worker`, `postgres`, `backup` (plus a one-shot `migrate`). The dir is `backend/` but the runtime **service** is `api`; the binary is `peppercheck`; `worker` is the same image, different command.
- **No feature ports (baseline §13):** no RPC, Edge Function, web route, R2/RevenueCat/Stripe/FCM integration in Phase 1. Identity tables are created, but Firebase token verification and `/api/v1/me` are **Phase 2**.
- **Provider independence (strategy §10):** no `auth.users` / `auth.uid()`; ownership anchors on internal `users.id` UUID. Domain/service Go code imports no cloud SDK.
- **Recovery target (baseline §12.1):** RPO 15 minutes / RTO 4 hours. Phase 1 delivers the **local WAL-archiving + encrypted-backup skeleton only**; real Backblaze B2 and the restore/PITR rehearsal are Phase 7.
- **DB roles (strategy §10):** `peppercheck_migrator` (DDL/owner) vs `peppercheck_app` (least-privilege DML) vs `peppercheck_backup` (read-only, `pg_read_all_data`, for `pg_dump`). `:5432` is never published in the base Compose file; a dev-only override may bind it to `127.0.0.1`.
- **Secrets management (decided 2026-07-23):** the local `.env` holds **non-sensitive local defaults only** (dev throwaway Postgres passwords, ports, the age **public** recipient) — never a real provider secret. It is gitignored; an accidental read has zero rotation impact because nothing in it is a real secret. Compose is **fail-closed**: base `compose.yaml` requires each secret via `${VAR:?...}` (a missing secret aborts startup rather than falling back to a dev default), with local values supplied from `.env`. **Real secrets** (Stripe, Firebase, R2, real DB passwords — later phases / staging / production) are **never placed in a plaintext `.env`**; they are injected at runtime via **Bitwarden Secrets Manager (`bws run`)** on the operator's machine and in CI (the operator already uses Bitwarden; Secrets Manager is a separate space from the personal password vault, so infra secrets never mix with personal logins), and delivered to the VPS as **Docker secrets** (`/run/secrets/*`) at deploy. **SOPS + age** (reusing the backup age key, fully OSS, no SaaS) is the recorded alternative. The runtime secret mechanism is **finalized in Phase 7** (confirm Bitwarden Secrets Manager quota/pricing then); Phase 1 has no real secrets, so it is documented here, not built.
- **English only** in all committed code, comments, commit messages, and this doc. Structured `slog` JSON logs to stdout; never log secrets/tokens/PII.
- **Container rules (strategy §18):** read port from env, no durable state on container FS, secrets at runtime, non-root where practical, graceful shutdown, liveness/readiness endpoints.
- **Branching:** work on a feature branch off `refactor/go-api-vps` (the integration branch); the branch stays buildable after each task. Do not commit to `main`.

---

## File Structure

```text
backend/
  go.mod  go.sum
  cmd/peppercheck/main.go                 # command dispatch: api | worker | healthcheck
  internal/
    api/api.go                            # api assembly: mux, /livez, /readyz, middleware chain
    worker/worker.go                      # durable-job scheduler loop + noop handler
    platform/
      config/config.go                    # env-based config with defaults
      logging/logging.go                  # slog JSON logger
      httpserver/server.go                # http.Server construction + graceful Run
      httpserver/middleware.go            # request-id, access log, recover, chain
      database/database.go                # database/sql (pgx driver) connect + ping
      jobs/jobs.go                        # durable job store (enqueue/claim/complete/fail)
      inbox/inbox.go                      # webhook inbox store (dedup insert)
    testsupport/db.go                     # DATABASE_URL test pool helper (skips if unset)
  schema/                                 # Atlas desired-state, TABLES ONLY, feature-split; atlas.hcl lists each subdir in src
    identity/01_users.sql                 # NN_ prefix: Atlas concatenates a dir's .sql in lexicographic order
    identity/02_user_identities.sql       #   so an FK-referencing table must sort AFTER its referent
    jobs/01_jobs.sql
    jobs/02_webhook_inbox.sql
  migrations/                             # Atlas-generated versioned SQL + atlas.sum
  atlas.hcl
  db/tests/test_role_separation.sql       # self-contained role-model SQL test
  deploy/
    caddy/Caddyfile
    postgres/init/00-roles.sh             # creates migrator + app roles, default privileges
    backup/Dockerfile
    backup/backup.sh
  Dockerfile
  .dockerignore
  compose.yaml
  compose.override.yaml                   # dev-only: publishes 127.0.0.1:5432
  .env.example
.github/workflows/ci-backend.yml
```

**Test DB convention (all integration tests):** tests read `DATABASE_URL`; if unset they `t.Skip`. Locally, run a throwaway Postgres and apply migrations first (commands given per task). In CI, a `postgres:17` service container + `atlas migrate apply` provide it.

---

### Task 1: Go module, config, and structured logging

**Files:**
- Create: `backend/go.mod`
- Create: `backend/internal/platform/config/config.go`
- Create: `backend/internal/platform/logging/logging.go`
- Test: `backend/internal/platform/config/config_test.go`
- Test: `backend/internal/platform/logging/logging_test.go`

**Interfaces:**
- Produces: `config.Config` struct (`Env, Port int, DatabaseURL, LogLevel string, ShutdownTimeout int`); `config.Load() (config.Config, error)`; `logging.New(level string) *slog.Logger`.

- [ ] **Step 1: Initialize the module**

```bash
cd backend
go mod init github.com/cloveclovedev/peppercheck/backend
go mod edit -go=1.26
```

- [ ] **Step 2: Write the failing config test** — `backend/internal/platform/config/config_test.go`

```go
package config

import "testing"

func TestLoadDefaults(t *testing.T) {
	t.Setenv("PORT", "")
	t.Setenv("DATABASE_URL", "")
	t.Setenv("LOG_LEVEL", "")
	t.Setenv("APP_ENV", "")
	c, err := Load()
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if c.Port != 8080 {
		t.Errorf("Port = %d, want 8080", c.Port)
	}
	if c.Env != "local" {
		t.Errorf("Env = %q, want local", c.Env)
	}
	if c.LogLevel != "info" {
		t.Errorf("LogLevel = %q, want info", c.LogLevel)
	}
	if c.ShutdownTimeout != 15 {
		t.Errorf("ShutdownTimeout = %d, want 15", c.ShutdownTimeout)
	}
}

func TestLoadOverridesAndValidation(t *testing.T) {
	t.Setenv("PORT", "9090")
	t.Setenv("DATABASE_URL", "postgres://x")
	c, err := Load()
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if c.Port != 9090 {
		t.Errorf("Port = %d, want 9090", c.Port)
	}
	if c.DatabaseURL != "postgres://x" {
		t.Errorf("DatabaseURL = %q", c.DatabaseURL)
	}

	t.Setenv("PORT", "70000")
	if _, err := Load(); err == nil {
		t.Errorf("expected error for out-of-range PORT")
	}
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `cd backend && go test ./internal/platform/config/`
Expected: FAIL (package/function `Load` undefined).

- [ ] **Step 4: Implement `config.go`** — `backend/internal/platform/config/config.go`

```go
// Package config loads runtime configuration from environment variables with
// sane defaults. Precedence is defaults then environment; secrets arrive only
// via environment variables, never from files committed to the repo.
package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

// Config is the fully-resolved runtime configuration for every command.
type Config struct {
	Env             string // local | staging | production
	Port            int    // HTTP listen port for the api command
	DatabaseURL     string // libpq/pgx connection string
	LogLevel        string // debug | info | warn | error
	ShutdownTimeout int    // graceful-shutdown budget in seconds
}

// Load reads configuration from the environment and validates it.
func Load() (Config, error) {
	c := Config{
		Env:             getenv("APP_ENV", "local"),
		Port:            getenvInt("PORT", 8080),
		DatabaseURL:     os.Getenv("DATABASE_URL"),
		LogLevel:        getenv("LOG_LEVEL", "info"),
		ShutdownTimeout: getenvInt("SHUTDOWN_TIMEOUT_SECONDS", 15),
	}
	if c.Port < 1 || c.Port > 65535 {
		return Config{}, fmt.Errorf("invalid PORT: %d", c.Port)
	}
	return c, nil
}

func getenv(key, def string) string {
	if v, ok := os.LookupEnv(key); ok && strings.TrimSpace(v) != "" {
		return v
	}
	return def
}

func getenvInt(key string, def int) int {
	if v, ok := os.LookupEnv(key); ok {
		if n, err := strconv.Atoi(strings.TrimSpace(v)); err == nil {
			return n
		}
	}
	return def
}
```

- [ ] **Step 5: Write the logging test** — `backend/internal/platform/logging/logging_test.go`

```go
package logging

import (
	"context"
	"log/slog"
	"testing"
)

func TestNewLevel(t *testing.T) {
	l := New("warn")
	if l.Enabled(context.Background(), slog.LevelInfo) {
		t.Errorf("info should be disabled at warn level")
	}
	if !l.Enabled(context.Background(), slog.LevelWarn) {
		t.Errorf("warn should be enabled at warn level")
	}
}

func TestNewDefaultsToInfo(t *testing.T) {
	l := New("nonsense")
	if !l.Enabled(context.Background(), slog.LevelInfo) {
		t.Errorf("unknown level must default to info")
	}
}
```

- [ ] **Step 6: Implement `logging.go`** — `backend/internal/platform/logging/logging.go`

```go
// Package logging builds the structured JSON logger used by every command.
package logging

import (
	"log/slog"
	"os"
	"strings"
)

// New returns a JSON slog.Logger writing to stdout at the given level.
// Unknown levels default to info.
func New(level string) *slog.Logger {
	var lvl slog.Level
	switch strings.ToLower(strings.TrimSpace(level)) {
	case "debug":
		lvl = slog.LevelDebug
	case "warn":
		lvl = slog.LevelWarn
	case "error":
		lvl = slog.LevelError
	default:
		lvl = slog.LevelInfo
	}
	h := slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: lvl})
	return slog.New(h)
}
```

- [ ] **Step 7: Run tests and gofmt**

Run: `cd backend && gofmt -l . && go test ./...`
Expected: no files listed by gofmt; tests PASS.

- [ ] **Step 8: Commit**

```bash
git add backend/go.mod backend/internal/platform/config backend/internal/platform/logging
git commit -m "feat(backend): add config and structured logging foundation"
```

---

### Task 2: HTTP server, health endpoints, middleware, and command dispatch

**Files:**
- Create: `backend/internal/platform/httpserver/middleware.go`
- Create: `backend/internal/platform/httpserver/server.go`
- Create: `backend/internal/api/api.go`
- Create: `backend/cmd/peppercheck/main.go`
- Test: `backend/internal/platform/httpserver/middleware_test.go`
- Test: `backend/internal/api/api_test.go`

**Interfaces:**
- Consumes: `config.Config`, `logging.New` (Task 1).
- Produces: `httpserver.RequestID`, `httpserver.AccessLog(*slog.Logger)`, `httpserver.Recover(*slog.Logger)`, `httpserver.Chain(http.Handler, ...func(http.Handler) http.Handler) http.Handler`, `httpserver.RequestIDFrom(context.Context) string`, `httpserver.RequestIDHeader`; `httpserver.New(port int, h http.Handler) *http.Server`; `httpserver.Run(ctx, *slog.Logger, *http.Server, time.Duration) error`; `api.Run(ctx, config.Config, *slog.Logger, ready func(context.Context) error) error` (a nil `ready` means always-ready).

- [ ] **Step 1: Write the middleware test** — `backend/internal/platform/httpserver/middleware_test.go`

```go
package httpserver

import (
	"bytes"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestRequestIDGeneratesAndEchoes(t *testing.T) {
	var seen string
	h := RequestID(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		seen = RequestIDFrom(r.Context())
	}))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/", nil))
	if seen == "" {
		t.Fatal("request id not present in context")
	}
	if rec.Header().Get(RequestIDHeader) != seen {
		t.Fatalf("response header %q != context id %q", rec.Header().Get(RequestIDHeader), seen)
	}
}

func TestRequestIDPreservesInbound(t *testing.T) {
	h := RequestID(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {}))
	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/", nil)
	req.Header.Set(RequestIDHeader, "abc123")
	h.ServeHTTP(rec, req)
	if rec.Header().Get(RequestIDHeader) != "abc123" {
		t.Fatalf("inbound request id not preserved: %q", rec.Header().Get(RequestIDHeader))
	}
}

// A panic (turned into a 500 by Recover) must still be access-logged. That only
// holds when AccessLog wraps Recover — the order used by api.Run.
func TestAccessLogRecordsPanicAsFiveHundred(t *testing.T) {
	var buf bytes.Buffer
	logger := slog.New(slog.NewJSONHandler(&buf, nil))
	panicking := http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		panic("boom")
	})
	h := Chain(panicking, AccessLog(logger), Recover(logger))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/x", nil))
	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want 500", rec.Code)
	}
	out := buf.String()
	if !strings.Contains(out, `"msg":"http_request"`) {
		t.Fatalf("panicking request was not access-logged: %s", out)
	}
	if !strings.Contains(out, `"status":500`) {
		t.Fatalf("access log did not record status 500: %s", out)
	}
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd backend && go test ./internal/platform/httpserver/`
Expected: FAIL (undefined `RequestID`).

- [ ] **Step 3: Implement `middleware.go`** — `backend/internal/platform/httpserver/middleware.go`

```go
package httpserver

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"log/slog"
	"net/http"
	"time"
)

type ctxKey int

const requestIDKey ctxKey = 0

// RequestIDHeader is the canonical header for propagating request IDs.
const RequestIDHeader = "X-Request-Id"

func newRequestID() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

// RequestIDFrom returns the request ID stored in ctx, or "" if none.
func RequestIDFrom(ctx context.Context) string {
	if v, ok := ctx.Value(requestIDKey).(string); ok {
		return v
	}
	return ""
}

// RequestID assigns (or preserves) a request ID and echoes it in the response.
func RequestID(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id := r.Header.Get(RequestIDHeader)
		if id == "" {
			id = newRequestID()
		}
		w.Header().Set(RequestIDHeader, id)
		ctx := context.WithValue(r.Context(), requestIDKey, id)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (s *statusRecorder) WriteHeader(code int) {
	s.status = code
	s.ResponseWriter.WriteHeader(code)
}

// AccessLog emits one structured log line per request.
func AccessLog(logger *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
			next.ServeHTTP(rec, r)
			logger.LogAttrs(r.Context(), slog.LevelInfo, "http_request",
				slog.String("request_id", RequestIDFrom(r.Context())),
				slog.String("method", r.Method),
				slog.String("path", r.URL.Path),
				slog.Int("status", rec.status),
				slog.Duration("duration", time.Since(start)),
			)
		})
	}
}

// Recover converts panics into 500s and logs them.
func Recover(logger *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			defer func() {
				if rec := recover(); rec != nil {
					logger.LogAttrs(r.Context(), slog.LevelError, "panic_recovered",
						slog.Any("error", rec),
						slog.String("request_id", RequestIDFrom(r.Context())),
					)
					w.WriteHeader(http.StatusInternalServerError)
				}
			}()
			next.ServeHTTP(w, r)
		})
	}
}

// Chain wraps h with mws so that mws[0] is the outermost middleware.
func Chain(h http.Handler, mws ...func(http.Handler) http.Handler) http.Handler {
	for i := len(mws) - 1; i >= 0; i-- {
		h = mws[i](h)
	}
	return h
}
```

- [ ] **Step 4: Implement `server.go`** — `backend/internal/platform/httpserver/server.go`

```go
package httpserver

import (
	"context"
	"errors"
	"log/slog"
	"net"
	"net/http"
	"strconv"
	"time"
)

// New builds an http.Server with conservative timeouts for a public listener.
func New(port int, handler http.Handler) *http.Server {
	return &http.Server{
		Addr:              net.JoinHostPort("0.0.0.0", strconv.Itoa(port)),
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       60 * time.Second,
	}
}

// Run serves until ctx is cancelled, then gracefully shuts down within timeout.
func Run(ctx context.Context, logger *slog.Logger, srv *http.Server, shutdownTimeout time.Duration) error {
	errCh := make(chan error, 1)
	go func() {
		logger.Info("http server listening", "addr", srv.Addr)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			errCh <- err
		}
	}()
	select {
	case err := <-errCh:
		return err
	case <-ctx.Done():
		logger.Info("shutting down http server")
		shutdownCtx, cancel := context.WithTimeout(context.Background(), shutdownTimeout)
		defer cancel()
		return srv.Shutdown(shutdownCtx)
	}
}
```

- [ ] **Step 5: Write the api test** — `backend/internal/api/api_test.go`

```go
package api

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestBuildHandlerLivez(t *testing.T) {
	h := buildHandler(nil)
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/livez", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("/livez = %d, want 200", rec.Code)
	}
}

func TestBuildHandlerReadyzUsesProbe(t *testing.T) {
	h := buildHandler(func(context.Context) error { return errors.New("down") })
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/readyz", nil))
	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("/readyz = %d, want 503 when probe fails", rec.Code)
	}
}

func TestBuildHandlerReadyzOKWhenNilProbe(t *testing.T) {
	h := buildHandler(nil)
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/readyz", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("/readyz = %d, want 200 when probe is nil", rec.Code)
	}
}
```

- [ ] **Step 6: Implement `api.go`** — `backend/internal/api/api.go`

```go
// Package api assembles and runs the HTTP api command. In Phase 1 it exposes
// only liveness and readiness; feature routes arrive in later phases.
package api

import (
	"context"
	"log/slog"
	"net/http"
	"time"

	"github.com/cloveclovedev/peppercheck/backend/internal/platform/config"
	"github.com/cloveclovedev/peppercheck/backend/internal/platform/httpserver"
)

// buildHandler wires routes and middleware. ready is the readiness probe; a nil
// probe means the process reports ready unconditionally.
func buildHandler(ready func(context.Context) error) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /livez", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})
	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, r *http.Request) {
		if ready != nil {
			ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
			defer cancel()
			if err := ready(ctx); err != nil {
				w.WriteHeader(http.StatusServiceUnavailable)
				_, _ = w.Write([]byte("not ready"))
				return
			}
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ready"))
	})
	return mux
}

// Run builds the handler and serves until ctx is cancelled. Middleware order
// (outermost first) is RequestID -> AccessLog -> Recover -> handler: AccessLog
// wraps Recover so a panic (which Recover turns into a 500) is still logged as
// an http_request. Putting Recover outside AccessLog would drop the access-log
// line for panicking requests.
func Run(ctx context.Context, cfg config.Config, logger *slog.Logger, ready func(context.Context) error) error {
	handler := httpserver.Chain(buildHandler(ready),
		httpserver.RequestID,
		httpserver.AccessLog(logger),
		httpserver.Recover(logger),
	)
	srv := httpserver.New(cfg.Port, handler)
	return httpserver.Run(ctx, logger, srv, time.Duration(cfg.ShutdownTimeout)*time.Second)
}
```

- [ ] **Step 7: Implement `main.go`** — `backend/cmd/peppercheck/main.go`

```go
// Command peppercheck is the single backend binary. It dispatches to the api or
// worker command; both share one image and set of application services.
package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/cloveclovedev/peppercheck/backend/internal/api"
	"github.com/cloveclovedev/peppercheck/backend/internal/platform/config"
	"github.com/cloveclovedev/peppercheck/backend/internal/platform/logging"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: peppercheck <api|worker|healthcheck>")
		os.Exit(2)
	}
	cfg, err := config.Load()
	if err != nil {
		fmt.Fprintln(os.Stderr, "config:", err)
		os.Exit(1)
	}

	if os.Args[1] == "healthcheck" {
		os.Exit(runHealthcheck(cfg))
	}

	logger := logging.New(cfg.LogLevel)
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	switch os.Args[1] {
	case "api":
		if err := api.Run(ctx, cfg, logger, nil); err != nil {
			logger.Error("api exited with error", "error", err)
			os.Exit(1)
		}
	default:
		fmt.Fprintf(os.Stderr, "unknown command: %s\n", os.Args[1])
		os.Exit(2)
	}
}

// runHealthcheck is used by the container HEALTHCHECK; it returns 0 when the
// local api answers /livez with 200.
func runHealthcheck(cfg config.Config) int {
	client := &http.Client{Timeout: 3 * time.Second}
	resp, err := client.Get(fmt.Sprintf("http://127.0.0.1:%d/livez", cfg.Port))
	if err != nil {
		return 1
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return 1
	}
	return 0
}
```

- [ ] **Step 8: Run tests, gofmt, vet, build**

Run: `cd backend && gofmt -l . && go vet ./... && go test ./... && go build ./cmd/peppercheck`
Expected: gofmt lists nothing; vet clean; tests PASS; build succeeds.

- [ ] **Step 9: Manually verify graceful shutdown**

Run: `cd backend && PORT=8081 go run ./cmd/peppercheck api` then in another shell `curl -s localhost:8081/livez` (expect `ok`), then press Ctrl-C in the first shell.
Expected: `curl` returns `ok`; on Ctrl-C the logs show `shutting down http server` and the process exits 0.

- [ ] **Step 10: Commit**

```bash
git add backend/internal/platform/httpserver backend/internal/api backend/cmd
git commit -m "feat(backend): add http server, health endpoints, and command dispatch"
```

---

### Task 3: Postgres connection and readiness wiring

**Files:**
- Create: `backend/internal/platform/database/database.go`
- Create: `backend/internal/testsupport/db.go`
- Modify: `backend/cmd/peppercheck/main.go` (connect DB in the api command, pass `db.PingContext` as the readiness probe)
- Test: `backend/internal/platform/database/database_test.go`

**Interfaces:**
- Consumes: `config.Config`, `api.Run` (Task 2).
- Produces: `database.Connect(ctx, dsn string) (*sql.DB, error)`; `testsupport.DB(t *testing.T) *sql.DB` (skips when `DATABASE_URL` unset). `*sql.DB.PingContext` is the readiness probe.

- [ ] **Step 1: Add the pgx driver dependency**

```bash
cd backend
go get github.com/jackc/pgx/v5/stdlib@latest
go mod tidy
```

- [ ] **Step 2: Write the database test** — `backend/internal/platform/database/database_test.go`

```go
package database

import (
	"context"
	"testing"
)

func TestConnectEmptyDSN(t *testing.T) {
	if _, err := Connect(context.Background(), ""); err == nil {
		t.Fatal("expected error for empty DSN")
	}
}

func TestConnectPings(t *testing.T) {
	dsn := dsnFromEnv(t)
	db, err := Connect(context.Background(), dsn)
	if err != nil {
		t.Fatalf("Connect: %v", err)
	}
	defer db.Close()
	if err := db.PingContext(context.Background()); err != nil {
		t.Fatalf("Ping: %v", err)
	}
}
```

Add the small env helper in the same test file:

```go
import "os"

func dsnFromEnv(t *testing.T) string {
	t.Helper()
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		t.Skip("DATABASE_URL not set; skipping integration test")
	}
	return dsn
}
```

(Combine the two `import` blocks into one when writing the file; shown separately for clarity.)

- [ ] **Step 3: Run it to verify it fails**

Run: `cd backend && go test ./internal/platform/database/`
Expected: FAIL (undefined `Connect`). The ping test skips without `DATABASE_URL`.

- [ ] **Step 4: Implement `database.go`** — `backend/internal/platform/database/database.go`

```go
// Package database opens the shared Postgres connection pool. It uses the
// stdlib database/sql interface with the pgx driver, so query code stays
// driver-agnostic.
package database

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	_ "github.com/jackc/pgx/v5/stdlib" // registers the "pgx" driver
)

// Connect opens a pooled *sql.DB and verifies connectivity with a ping.
func Connect(ctx context.Context, dsn string) (*sql.DB, error) {
	if dsn == "" {
		return nil, fmt.Errorf("DATABASE_URL is empty")
	}
	db, err := sql.Open("pgx", dsn)
	if err != nil {
		return nil, fmt.Errorf("open: %w", err)
	}
	db.SetMaxOpenConns(10)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(time.Hour)

	pingCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	if err := db.PingContext(pingCtx); err != nil {
		_ = db.Close()
		return nil, fmt.Errorf("ping: %w", err)
	}
	return db, nil
}
```

- [ ] **Step 5: Implement the test helper** — `backend/internal/testsupport/db.go`

```go
// Package testsupport provides shared helpers for integration tests.
package testsupport

import (
	"context"
	"os"
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/platform/database"
)

// DB returns a connected *sql.DB for integration tests, or skips the test when
// DATABASE_URL is not set. The pool is closed automatically at test cleanup.
func DB(t *testing.T) *database.Handle {
	t.Helper()
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		t.Skip("DATABASE_URL not set; skipping integration test")
	}
	db, err := database.Connect(context.Background(), dsn)
	if err != nil {
		t.Fatalf("connect: %v", err)
	}
	t.Cleanup(func() { _ = db.Close() })
	return db
}
```

Note: return type is `*sql.DB`. To avoid importing `database/sql` transitively here, add a tiny alias in `database.go`: `type Handle = sql.DB`. Add this line to `database.go` after the imports:

```go
// Handle is an alias for *sql.DB users hold; it keeps call sites importing this
// package rather than database/sql directly.
type Handle = sql.DB
```

- [ ] **Step 6: Wire the DB into the api command** — replace the `case "api":` block and add the import in `backend/cmd/peppercheck/main.go`

Add to the import block:

```go
	"github.com/cloveclovedev/peppercheck/backend/internal/platform/database"
```

Replace the `case "api":` block with:

```go
	case "api":
		db, err := database.Connect(ctx, cfg.DatabaseURL)
		if err != nil {
			logger.Error("database connect failed", "error", err)
			os.Exit(1)
		}
		defer db.Close()
		if err := api.Run(ctx, cfg, logger, db.PingContext); err != nil {
			logger.Error("api exited with error", "error", err)
			os.Exit(1)
		}
```

- [ ] **Step 7: Verify against a throwaway Postgres**

```bash
docker run --rm -d --name pc-pg -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=peppercheck -p 55432:5432 postgres:17
export DATABASE_URL='postgres://postgres:postgres@localhost:55432/peppercheck?sslmode=disable'
cd backend && gofmt -l . && go vet ./... && go test ./...
```

Expected: gofmt lists nothing; vet clean; `database` ping test PASSES (no longer skipped); all tests PASS.

- [ ] **Step 8: Verify the live readiness endpoint**

```bash
cd backend && PORT=8082 go run ./cmd/peppercheck api &
sleep 1
curl -s -o /dev/null -w '%{http_code}\n' localhost:8082/readyz   # expect 200
kill %1
```

Expected: `200`. (Leave the `pc-pg` container running for later tasks, or `docker rm -f pc-pg` when done.)

- [ ] **Step 9: Commit**

```bash
git add backend/go.mod backend/go.sum backend/internal/platform/database backend/internal/testsupport backend/cmd
git commit -m "feat(backend): connect Postgres and wire readiness probe"
```

---

### Task 4: Atlas setup, identity baseline schema, and DB role separation

**Files:**
- Create: `backend/atlas.hcl`
- Create: `backend/schema/identity/users.sql`
- Create: `backend/schema/identity/user_identities.sql`
- Create: `backend/deploy/postgres/init/00-roles.sh`
- Create: `backend/db/tests/test_role_separation.sql`
- Generate: `backend/migrations/<version>_phase1_baseline.sql` + `backend/migrations/atlas.sum`

**Interfaces:**
- Produces: DB objects `public.users`, `public.user_identities` (tables only — no functions/triggers); migration directory `file://migrations`; roles `peppercheck_migrator`, `peppercheck_app`; env `local` in `atlas.hcl`.

**Design notes (schema approach decided 2026-07-23 — see Global Constraints):**
- **Table-only declarative.** Unauthenticated Atlas gates functions/triggers behind `atlas login` (Pro), so Phase 1 keeps the schema to tables + constraints only. Atlas computes migrations via an ephemeral `docker://postgres/17/dev` database, free/no login.
- **No `handle_updated_at` trigger.** `updated_at` columns are set by Go in each store's UPDATE (`updated_at = now()`), not by a DB trigger. `users`/`user_identities` keep their `updated_at` column but have no trigger.
- **`atlas.hcl` lists each feature subdir explicitly in `src`** — Atlas does not recurse into subdirectories (verified). Task 4 lists only `schema/identity`; Task 5 adds `schema/jobs`.
- Role model: the **migrator** owns objects and holds DDL; `ALTER DEFAULT PRIVILEGES FOR ROLE peppercheck_migrator` grants the **app** role DML on every future migrator-owned table automatically. Atlas applies migrations as the migrator; `api`/`worker` connect as the app.

- [ ] **Step 1: Write `schema/identity/users.sql`**

```sql
-- Internal, provider-independent user anchor. FKs across the domain reference
-- users.id (never a provider UID). No provider column lives here; provider
-- links live in user_identities. updated_at is maintained by the Go store
-- (updated_at = now() on each UPDATE), not a DB trigger.
CREATE TABLE public.users (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    status     text NOT NULL DEFAULT 'active',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
```

- [ ] **Step 2: Write `schema/identity/user_identities.sql`**

```sql
-- Maps a verified external identity (issuer, subject) to the internal user.
-- Today subject holds the Firebase UID; the table can later hold real
-- per-provider subjects without touching users. updated_at is Go-maintained.
CREATE TABLE public.user_identities (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    uuid NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
    issuer     text NOT NULL,
    subject    text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT user_identities_issuer_subject_key UNIQUE (issuer, subject)
);
```

- [ ] **Step 3: Write `atlas.hcl`**

`src` is a **list** of feature subdirectories (Atlas does not recurse). Task 4 lists only `schema/identity`; Task 5 appends `schema/jobs`.

```hcl
variable "url" {
  type    = string
  default = getenv("DATABASE_URL")
}

env "local" {
  src = [
    "file://schema/identity",
  ]
  dev = "docker://postgres/17/dev?search_path=public"
  url = var.url
  migration {
    dir = "file://migrations"
  }
  format {
    migrate {
      diff = "{{ sql . \"  \" }}"
    }
  }
}
```

- [ ] **Step 4: Generate the baseline migration**

```bash
cd backend
atlas migrate diff phase1_baseline --env local
```

Expected: creates `migrations/<timestamp>_phase1_baseline.sql` containing `CREATE TABLE public.users` and `CREATE TABLE public.user_identities` (tables only — no functions/triggers), plus `migrations/atlas.sum`. (Atlas pulls `postgres:17` for the ephemeral dev DB on first run.) This is table-only DDL, so `atlas migrate diff` runs unauthenticated (free) without `atlas login`.

- [ ] **Step 5: Write the role init script** — `backend/deploy/postgres/init/00-roles.sh`

Passwords are passed to psql as variables (`-v`) and referenced with `:'name'`, which psql quotes and escapes safely — so a password containing a single quote cannot break the SQL (review item #2). The heredoc delimiter is quoted (`<<-'EOSQL'`) so the shell performs no expansion inside it.

```sh
#!/bin/bash
# Creates the migration, runtime, and backup roles on first database
# initialization. Passwords come from environment variables and are passed to
# psql as variables so :'name' quotes them safely even if they contain quotes.
# This runs only when the data directory is empty (docker-entrypoint-initdb.d).
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  -v migrator_pw="$POSTGRES_MIGRATOR_PASSWORD" \
  -v app_pw="$POSTGRES_APP_PASSWORD" \
  -v backup_pw="$POSTGRES_BACKUP_PASSWORD" <<-'EOSQL'
  -- Migration role: owns schema objects and may run DDL.
  CREATE ROLE peppercheck_migrator LOGIN PASSWORD :'migrator_pw';
  GRANT CREATE, USAGE ON SCHEMA public TO peppercheck_migrator;

  -- Runtime role: least-privilege DML only, never DDL.
  CREATE ROLE peppercheck_app LOGIN PASSWORD :'app_pw';
  GRANT USAGE ON SCHEMA public TO peppercheck_app;

  -- Backup role: read-only across all data (for pg_dump), no writes, no DDL.
  CREATE ROLE peppercheck_backup LOGIN PASSWORD :'backup_pw';
  GRANT USAGE ON SCHEMA public TO peppercheck_backup;
  GRANT pg_read_all_data TO peppercheck_backup;

  -- Tables the migrator creates later automatically grant DML to the app role.
  ALTER DEFAULT PRIVILEGES FOR ROLE peppercheck_migrator IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO peppercheck_app;
  ALTER DEFAULT PRIVILEGES FOR ROLE peppercheck_migrator IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO peppercheck_app;
EOSQL
```

Make it executable:

```bash
chmod +x backend/deploy/postgres/init/00-roles.sh
```

- [ ] **Step 6: Write the self-contained role-model test** — `backend/db/tests/test_role_separation.sql`

```sql
-- Verifies the runtime grant model in isolation: a migrator-owned table grants
-- DML to the app role automatically, and the app role cannot run DDL. Runs as a
-- superuser inside a transaction and rolls back, so it needs no container init.
BEGIN;

CREATE ROLE test_migrator;
GRANT CREATE, USAGE ON SCHEMA public TO test_migrator;
CREATE ROLE test_app;
GRANT USAGE ON SCHEMA public TO test_app;
ALTER DEFAULT PRIVILEGES FOR ROLE test_migrator IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO test_app;

SET ROLE test_migrator;
CREATE TABLE public.role_probe (id int PRIMARY KEY, note text);
RESET ROLE;

-- App role can DML the migrator-owned table.
SET ROLE test_app;
INSERT INTO public.role_probe (id, note) VALUES (1, 'ok');
DO $$
BEGIN
  ASSERT (SELECT count(*) FROM public.role_probe) = 1, 'app INSERT should succeed';
END $$;

-- App role must NOT be able to run DDL.
DO $$
BEGIN
  BEGIN
    EXECUTE 'CREATE TABLE public.should_not_exist (id int)';
    RAISE EXCEPTION 'app role must not be able to CREATE TABLE';
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL; -- expected
  END;
END $$;
RESET ROLE;

ROLLBACK;
```

- [ ] **Step 7: Apply migrations to a throwaway DB and verify**

```bash
# Reuse pc-pg from Task 3, or start it:
docker run --rm -d --name pc-pg -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=peppercheck -p 55432:5432 postgres:17 || true
export DATABASE_URL='postgres://postgres:postgres@localhost:55432/peppercheck?sslmode=disable'
cd backend
atlas migrate apply --env local
```

Expected: applies the baseline migration; output ends with the applied version and no error.

- [ ] **Step 8: Verify tables exist and there is no drift**

```bash
cd backend
PGPASSWORD=postgres psql -h localhost -p 55432 -U postgres -d peppercheck -c '\dt public.*'   # shows users, user_identities
atlas migrate diff check_no_drift --env local
```

Expected: `\dt` lists `public.users` and `public.user_identities`; `atlas migrate diff` prints `The migration directory is synced with the desired state, no changes to be made` and creates **no** new file (`git status backend/migrations` stays clean apart from the baseline).

- [ ] **Step 9: Run the role-model test**

```bash
PGPASSWORD=postgres psql -h localhost -p 55432 -U postgres -d peppercheck -f backend/db/tests/test_role_separation.sql
```

Expected: ends with `ROLLBACK` and no `ERROR` (all `ASSERT`s pass; the DDL attempt is caught).

- [ ] **Step 10: Commit**

```bash
git add backend/atlas.hcl backend/schema backend/migrations backend/deploy/postgres backend/db/tests
git commit -m "feat(backend): add Atlas baseline, identity core schema, and DB role separation"
```

---

### Task 5: Durable job primitive

**Files:**
- Create: `backend/schema/jobs/01_jobs.sql`
- Create: `backend/internal/platform/jobs/jobs.go`
- Generate: `backend/migrations/<version>_add_jobs.sql`
- Test: `backend/internal/platform/jobs/jobs_test.go`

**Interfaces:**
- Consumes: `testsupport.DB` (Task 3), `database.Handle` (`*sql.DB`).
- Produces: `jobs.Job{ID, Kind string, Payload json.RawMessage, Attempts, MaxAttempts int, LockedBy string}`; `jobs.DefaultLease` const; `jobs.Store` with `NewStore(*sql.DB) *Store`, `Enqueue(ctx, kind string, payload any, EnqueueOpts) (id string, err error)` (returns `"", nil` on idempotency-key conflict), `Claim(ctx) (*Job, error)` (`nil, nil` when none claimable; **reclaims running jobs whose lease expired** and issues a fresh lease token), `Complete(ctx, *Job) error` (conditional on the job's lease token), `Fail(ctx, *Job, cause error, backoff time.Duration) error` (conditional on the lease token); `jobs.EnqueueOpts{RunAt time.Time, MaxAttempts int, IdempotencyKey string}`.

**Design notes (crash-safe leasing — addresses review item #1):**
- A claimed job is **leased**: `Claim` sets `status='running'`, `locked_by`=a fresh random token, `lease_until = now() + DefaultLease`, and it **reclaims** any `running` job whose `lease_until` has passed (a worker that crashed/was killed mid-job). Without this, a crashed worker would strand its job in `running` forever, contradicting the durability goal.
- `Complete`/`Fail` are **conditional on `locked_by`** (`WHERE id=$1 AND locked_by=$token`). If this worker's lease expired and another worker reclaimed the job, the stale worker's update matches 0 rows and is a safe no-op — the new holder owns the outcome.
- Delivery is **at-least-once**: a reclaimed job runs again, so handlers must be idempotent. `DefaultLease` (5m) must exceed the longest expected job runtime; long-running jobs will need lease renewal (a documented future addition — Phase 1 runs only instant `noop`).

- [ ] **Step 1: Write `schema/jobs/01_jobs.sql`**

```sql
-- Durable job queue. The worker claims rows with FOR UPDATE SKIP LOCKED so
-- concurrent workers never process the same job. Each claim takes a lease
-- (locked_by token + lease_until); a running job whose lease expires (crashed
-- worker) is reclaimable. updated_at is set by the Go store (updated_at = now()
-- on each UPDATE), not a DB trigger.
CREATE TABLE public.jobs (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    kind            text NOT NULL,
    payload         jsonb NOT NULL DEFAULT '{}'::jsonb,
    idempotency_key text UNIQUE,
    status          text NOT NULL DEFAULT 'pending',
    run_at          timestamptz NOT NULL DEFAULT now(),
    attempts        integer NOT NULL DEFAULT 0,
    max_attempts    integer NOT NULL DEFAULT 20,
    last_error      text,
    locked_at       timestamptz,
    locked_by       text,
    lease_until     timestamptz,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT jobs_status_check CHECK (status IN ('pending', 'running', 'succeeded', 'failed'))
);

CREATE INDEX jobs_pending_run_at_idx ON public.jobs (run_at) WHERE status = 'pending';
CREATE INDEX jobs_running_lease_idx ON public.jobs (lease_until) WHERE status = 'running';
```

- [ ] **Step 2: Register the `schema/jobs` dir in `atlas.hcl`, then generate and apply the migration**

Add `schema/jobs` to the `src` list in `backend/atlas.hcl` (Atlas does not recurse, so each feature subdir is listed explicitly):

```hcl
  src = [
    "file://schema/identity",
    "file://schema/jobs",
  ]
```

Then:

```bash
cd backend
atlas migrate diff add_jobs --env local
atlas migrate apply --env local   # DATABASE_URL still points at pc-pg:55432
```

Expected: a new `add_jobs` migration (table + partial index, no trigger) is created and applied without error.

- [ ] **Step 3: Write the failing jobs test** — `backend/internal/platform/jobs/jobs_test.go`

```go
package jobs

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
)

func newStore(t *testing.T) *Store {
	t.Helper()
	db := testsupport.DB(t)
	if _, err := db.Exec("TRUNCATE public.jobs"); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	return NewStore(db)
}

func TestEnqueueClaimComplete(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()

	id, err := s.Enqueue(ctx, "noop", map[string]any{"x": 1}, EnqueueOpts{})
	if err != nil || id == "" {
		t.Fatalf("Enqueue: id=%q err=%v", id, err)
	}

	j, err := s.Claim(ctx)
	if err != nil || j == nil {
		t.Fatalf("Claim: job=%v err=%v", j, err)
	}
	if j.Kind != "noop" || j.Attempts != 1 {
		t.Fatalf("claimed job kind=%q attempts=%d", j.Kind, j.Attempts)
	}
	if j.LockedBy == "" {
		t.Fatal("claim must issue a lease token")
	}

	// No second claimable job.
	if j2, err := s.Claim(ctx); err != nil || j2 != nil {
		t.Fatalf("second Claim should be empty: job=%v err=%v", j2, err)
	}

	if err := s.Complete(ctx, j); err != nil {
		t.Fatalf("Complete: %v", err)
	}
}

func TestClaimReclaimsExpiredLease(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()
	if _, err := s.Enqueue(ctx, "noop", nil, EnqueueOpts{}); err != nil {
		t.Fatalf("enqueue: %v", err)
	}
	a, err := s.Claim(ctx)
	if err != nil || a == nil {
		t.Fatalf("first claim: %v %v", a, err)
	}
	// Simulate a crashed worker: force the lease to have already expired.
	if _, err := s.db.Exec(`UPDATE public.jobs SET lease_until = now() - interval '1 second' WHERE id = $1`, a.ID); err != nil {
		t.Fatalf("expire lease: %v", err)
	}
	b, err := s.Claim(ctx)
	if err != nil || b == nil {
		t.Fatalf("expired running job must be reclaimable: %v %v", b, err)
	}
	if b.ID != a.ID {
		t.Fatalf("reclaimed a different job: %s != %s", b.ID, a.ID)
	}
	if b.LockedBy == a.LockedBy {
		t.Fatal("reclaim must issue a new lease token")
	}
	if b.Attempts != 2 {
		t.Fatalf("reclaim should increment attempts, got %d", b.Attempts)
	}
}

func TestLostLeaseCompleteIsNoop(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()
	if _, err := s.Enqueue(ctx, "noop", nil, EnqueueOpts{}); err != nil {
		t.Fatalf("enqueue: %v", err)
	}
	a, err := s.Claim(ctx)
	if err != nil || a == nil {
		t.Fatalf("first claim: %v %v", a, err)
	}
	if _, err := s.db.Exec(`UPDATE public.jobs SET lease_until = now() - interval '1 second' WHERE id = $1`, a.ID); err != nil {
		t.Fatalf("expire lease: %v", err)
	}
	b, err := s.Claim(ctx)
	if err != nil || b == nil {
		t.Fatalf("reclaim: %v %v", b, err)
	}
	// The original holder lost the lease; its Complete must not take effect.
	if err := s.Complete(ctx, a); err != nil {
		t.Fatalf("stale Complete should be a no-op, not an error: %v", err)
	}
	var status string
	if err := s.db.QueryRow(`SELECT status FROM public.jobs WHERE id = $1`, a.ID).Scan(&status); err != nil {
		t.Fatalf("scan: %v", err)
	}
	if status != "running" {
		t.Fatalf("stale Complete changed status to %q; expected still running", status)
	}
	// The current holder can complete.
	if err := s.Complete(ctx, b); err != nil {
		t.Fatalf("current holder Complete: %v", err)
	}
	if err := s.db.QueryRow(`SELECT status FROM public.jobs WHERE id = $1`, a.ID).Scan(&status); err != nil {
		t.Fatalf("scan2: %v", err)
	}
	if status != "succeeded" {
		t.Fatalf("current holder Complete failed; status=%q", status)
	}
}

func TestEnqueueIdempotencyKeyDedupes(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()
	id1, err := s.Enqueue(ctx, "noop", nil, EnqueueOpts{IdempotencyKey: "k1"})
	if err != nil || id1 == "" {
		t.Fatalf("first enqueue: %q %v", id1, err)
	}
	id2, err := s.Enqueue(ctx, "noop", nil, EnqueueOpts{IdempotencyKey: "k1"})
	if err != nil {
		t.Fatalf("second enqueue err: %v", err)
	}
	if id2 != "" {
		t.Fatalf("duplicate idempotency key should return empty id, got %q", id2)
	}
}

func TestFailReschedulesUntilExhausted(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()
	if _, err := s.Enqueue(ctx, "noop", nil, EnqueueOpts{MaxAttempts: 1}); err != nil {
		t.Fatalf("enqueue: %v", err)
	}
	j, err := s.Claim(ctx)
	if err != nil || j == nil {
		t.Fatalf("claim: %v %v", j, err)
	}
	// attempts (1) >= max_attempts (1) => marked failed, not rescheduled.
	if err := s.Fail(ctx, j, errors.New("boom"), time.Second); err != nil {
		t.Fatalf("fail: %v", err)
	}
	if j2, err := s.Claim(ctx); err != nil || j2 != nil {
		t.Fatalf("exhausted job must not be reclaimable: %v %v", j2, err)
	}
}

func TestClaimIsExclusiveUnderConcurrency(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()
	if _, err := s.Enqueue(ctx, "noop", nil, EnqueueOpts{}); err != nil {
		t.Fatalf("enqueue: %v", err)
	}
	type res struct {
		j   *Job
		err error
	}
	ch := make(chan res, 2)
	for i := 0; i < 2; i++ {
		go func() {
			j, err := s.Claim(ctx)
			ch <- res{j, err}
		}()
	}
	got := 0
	for i := 0; i < 2; i++ {
		r := <-ch
		if r.err != nil {
			t.Fatalf("claim err: %v", r.err)
		}
		if r.j != nil {
			got++
		}
	}
	if got != 1 {
		t.Fatalf("exactly one goroutine should claim the job, got %d", got)
	}
}
```

- [ ] **Step 4: Run it to verify it fails**

Run: `cd backend && go test ./internal/platform/jobs/`
Expected: FAIL (undefined `Store`/`NewStore`).

- [ ] **Step 5: Implement `jobs.go`** — `backend/internal/platform/jobs/jobs.go`

```go
// Package jobs is the durable-job primitive backing the worker. Jobs live in a
// Postgres table and are claimed with FOR UPDATE SKIP LOCKED so multiple worker
// processes never run the same job. Each claim takes a lease (a random token +
// expiry); a running job whose lease expires — e.g. its worker crashed — is
// reclaimable, and Complete/Fail are conditional on the lease token so a stale
// worker cannot clobber a reclaimed job. It is a primitive only; no feature
// enqueues real work in Phase 1.
package jobs

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"time"
)

// DefaultLease is how long a claimed job stays leased before another worker may
// reclaim it. It must exceed the longest expected job runtime; long-running
// jobs must renew their lease (not needed in Phase 1 — noop jobs are instant).
const DefaultLease = 5 * time.Minute

// Job is a claimed unit of work handed to a worker handler. LockedBy is the
// lease token issued at claim time.
type Job struct {
	ID          string
	Kind        string
	Payload     json.RawMessage
	Attempts    int
	MaxAttempts int
	LockedBy    string
}

// Store issues the SQL that backs the job queue.
type Store struct {
	db    *sql.DB
	lease time.Duration
}

// NewStore builds a Store over an open database handle.
func NewStore(db *sql.DB) *Store { return &Store{db: db, lease: DefaultLease} }

// EnqueueOpts tunes a single enqueue. Zero values mean: run now, 20 attempts,
// no idempotency key.
type EnqueueOpts struct {
	RunAt          time.Time
	MaxAttempts    int
	IdempotencyKey string
}

// Enqueue inserts a job. When IdempotencyKey collides with an existing row it
// returns ("", nil) — the duplicate is a no-op, not an error.
func (s *Store) Enqueue(ctx context.Context, kind string, payload any, opts EnqueueOpts) (string, error) {
	raw, err := json.Marshal(payload)
	if err != nil {
		return "", fmt.Errorf("marshal payload: %w", err)
	}
	if opts.MaxAttempts == 0 {
		opts.MaxAttempts = 20
	}
	var runAt any
	if !opts.RunAt.IsZero() {
		runAt = opts.RunAt
	}
	var key any
	if opts.IdempotencyKey != "" {
		key = opts.IdempotencyKey
	}
	var id string
	err = s.db.QueryRowContext(ctx, `
		INSERT INTO public.jobs (kind, payload, run_at, max_attempts, idempotency_key)
		VALUES ($1, $2, COALESCE($3, now()), $4, $5)
		ON CONFLICT (idempotency_key) DO NOTHING
		RETURNING id`,
		kind, raw, runAt, opts.MaxAttempts, key,
	).Scan(&id)
	if errors.Is(err, sql.ErrNoRows) {
		return "", nil // duplicate idempotency key
	}
	if err != nil {
		return "", fmt.Errorf("insert job: %w", err)
	}
	return id, nil
}

// Claim atomically picks the oldest claimable job — either due-and-pending, or
// running with an expired lease (its worker crashed) — takes a fresh lease, and
// returns it. Returns (nil, nil) when nothing is claimable.
func (s *Store) Claim(ctx context.Context) (*Job, error) {
	token, err := newToken()
	if err != nil {
		return nil, err
	}
	var j Job
	var payload []byte
	err = s.db.QueryRowContext(ctx, `
		UPDATE public.jobs
		SET status = 'running',
		    locked_at = now(),
		    lease_until = now() + make_interval(secs => $1),
		    locked_by = $2,
		    attempts = attempts + 1,
		    updated_at = now()
		WHERE id = (
			SELECT id FROM public.jobs
			WHERE (status = 'pending' AND run_at <= now())
			   OR (status = 'running' AND lease_until < now())
			ORDER BY run_at
			FOR UPDATE SKIP LOCKED
			LIMIT 1
		)
		RETURNING id, kind, payload, attempts, max_attempts, locked_by`,
		s.lease.Seconds(), token,
	).Scan(&j.ID, &j.Kind, &payload, &j.Attempts, &j.MaxAttempts, &j.LockedBy)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("claim job: %w", err)
	}
	j.Payload = payload
	return &j, nil
}

// Complete marks the job succeeded, but only while this worker still holds the
// lease (locked_by matches). A lost lease affects 0 rows and is a safe no-op —
// another worker reclaimed the job and owns its outcome.
func (s *Store) Complete(ctx context.Context, j *Job) error {
	_, err := s.db.ExecContext(ctx,
		`UPDATE public.jobs SET status = 'succeeded', updated_at = now()
		 WHERE id = $1 AND locked_by = $2`,
		j.ID, j.LockedBy)
	return err
}

// Fail reschedules the job after backoff, or marks it failed once attempts are
// exhausted — only while this worker still holds the lease.
func (s *Store) Fail(ctx context.Context, j *Job, cause error, backoff time.Duration) error {
	if j.Attempts >= j.MaxAttempts {
		_, err := s.db.ExecContext(ctx,
			`UPDATE public.jobs SET status = 'failed', last_error = $2, updated_at = now()
			 WHERE id = $1 AND locked_by = $3`,
			j.ID, cause.Error(), j.LockedBy)
		return err
	}
	_, err := s.db.ExecContext(ctx,
		`UPDATE public.jobs
		 SET status = 'pending', run_at = now() + make_interval(secs => $2),
		     last_error = $3, locked_by = NULL, lease_until = NULL, updated_at = now()
		 WHERE id = $1 AND locked_by = $4`,
		j.ID, backoff.Seconds(), cause.Error(), j.LockedBy)
	return err
}

// newToken returns a random lease token.
func newToken() (string, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "", fmt.Errorf("generate lease token: %w", err)
	}
	return hex.EncodeToString(b), nil
}
```

- [ ] **Step 6: Run tests, gofmt, vet**

Run: `cd backend && gofmt -l . && go vet ./... && go test ./...`
Expected: gofmt lists nothing; vet clean; all jobs tests PASS.

- [ ] **Step 7: Commit**

```bash
git add backend/atlas.hcl backend/schema/jobs/01_jobs.sql backend/migrations backend/internal/platform/jobs
git commit -m "feat(backend): add durable job primitive with leased skip-locked claiming"
```

---

### Task 6: Webhook inbox primitive

**Files:**
- Create: `backend/schema/jobs/02_webhook_inbox.sql`
- Create: `backend/internal/platform/inbox/inbox.go`
- Generate: `backend/migrations/<version>_add_webhook_inbox.sql`
- Test: `backend/internal/platform/inbox/inbox_test.go`

**Interfaces:**
- Consumes: `testsupport.DB` (Task 3).
- Produces: `inbox.Store` with `NewStore(*sql.DB) *Store` and `Insert(ctx, source, eventID string, payload any) (isNew bool, err error)` — `isNew=false` when `(source, event_id)` was already recorded.

**Design note:** the inbox is the durable landing spot for at-least-once webhook deliveries (RevenueCat/Stripe in later phases). Phase 1 builds only the table + dedup insert; no HTTP endpoint receives events yet.

- [ ] **Step 1: Write `schema/jobs/02_webhook_inbox.sql`**

```sql
-- Idempotency ledger for inbound webhooks. The api records each event once;
-- duplicate deliveries collide on (source, event_id) and are ignored. The
-- worker later processes unprocessed rows.
CREATE TABLE public.webhook_inbox (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source       text NOT NULL,
    event_id     text NOT NULL,
    payload      jsonb NOT NULL,
    received_at  timestamptz NOT NULL DEFAULT now(),
    processed_at timestamptz,
    CONSTRAINT webhook_inbox_source_event_key UNIQUE (source, event_id)
);
```

- [ ] **Step 2: Generate and apply the migration**

```bash
cd backend
atlas migrate diff add_webhook_inbox --env local
atlas migrate apply --env local
```

Expected: a new `add_webhook_inbox` migration is created and applied without error.

- [ ] **Step 3: Write the failing inbox test** — `backend/internal/platform/inbox/inbox_test.go`

```go
package inbox

import (
	"context"
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
)

func newStore(t *testing.T) *Store {
	t.Helper()
	db := testsupport.DB(t)
	if _, err := db.Exec("TRUNCATE public.webhook_inbox"); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	return NewStore(db)
}

func TestInsertDedupes(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()

	isNew, err := s.Insert(ctx, "revenuecat", "evt_1", map[string]any{"type": "INITIAL_PURCHASE"})
	if err != nil {
		t.Fatalf("first insert: %v", err)
	}
	if !isNew {
		t.Fatal("first insert should be new")
	}

	isNew, err = s.Insert(ctx, "revenuecat", "evt_1", map[string]any{"type": "INITIAL_PURCHASE"})
	if err != nil {
		t.Fatalf("second insert: %v", err)
	}
	if isNew {
		t.Fatal("duplicate (source,event_id) must not be new")
	}
}

func TestInsertDistinctSourcesAreIndependent(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()
	if isNew, err := s.Insert(ctx, "revenuecat", "evt_1", nil); err != nil || !isNew {
		t.Fatalf("rc insert: new=%v err=%v", isNew, err)
	}
	if isNew, err := s.Insert(ctx, "stripe", "evt_1", nil); err != nil || !isNew {
		t.Fatalf("stripe insert should be new despite same event_id: new=%v err=%v", isNew, err)
	}
}
```

- [ ] **Step 4: Run it to verify it fails**

Run: `cd backend && go test ./internal/platform/inbox/`
Expected: FAIL (undefined `Store`).

- [ ] **Step 5: Implement `inbox.go`** — `backend/internal/platform/inbox/inbox.go`

```go
// Package inbox is the webhook idempotency primitive. Inbound webhook events
// are recorded once per (source, event_id); duplicate at-least-once deliveries
// are detected and ignored. Phase 1 provides the store only; no endpoint yet.
package inbox

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
)

// Store issues the SQL backing the webhook inbox.
type Store struct{ db *sql.DB }

// NewStore builds a Store over an open database handle.
func NewStore(db *sql.DB) *Store { return &Store{db: db} }

// Insert records a webhook event. It returns isNew=false when this
// (source, event_id) was already recorded (a duplicate delivery).
func (s *Store) Insert(ctx context.Context, source, eventID string, payload any) (isNew bool, err error) {
	raw, err := json.Marshal(payload)
	if err != nil {
		return false, fmt.Errorf("marshal payload: %w", err)
	}
	var id string
	err = s.db.QueryRowContext(ctx, `
		INSERT INTO public.webhook_inbox (source, event_id, payload)
		VALUES ($1, $2, $3)
		ON CONFLICT (source, event_id) DO NOTHING
		RETURNING id`,
		source, eventID, raw,
	).Scan(&id)
	if errors.Is(err, sql.ErrNoRows) {
		return false, nil // duplicate delivery
	}
	if err != nil {
		return false, fmt.Errorf("insert inbox event: %w", err)
	}
	return true, nil
}
```

- [ ] **Step 6: Run tests, gofmt, vet**

Run: `cd backend && gofmt -l . && go vet ./... && go test ./...`
Expected: gofmt lists nothing; vet clean; inbox tests PASS.

- [ ] **Step 7: Commit**

```bash
git add backend/schema/jobs/02_webhook_inbox.sql backend/migrations backend/internal/platform/inbox
git commit -m "feat(backend): add webhook inbox idempotency primitive"
```

---

### Task 7: Worker entrypoint and scheduler loop

**Files:**
- Create: `backend/internal/worker/worker.go`
- Modify: `backend/cmd/peppercheck/main.go` (add the `worker` command)
- Test: `backend/internal/worker/worker_test.go`

**Interfaces:**
- Consumes: `config.Config`, `database.Handle`, `jobs.Store`/`jobs.Job` (Tasks 3, 5).
- Produces: `worker.Handler = func(ctx, *jobs.Job) error`; `worker.New(*sql.DB, *slog.Logger) *Worker`; `(*Worker).Register(kind string, h Handler)`; `(*Worker).RunDue(ctx) error` (drains all currently-due jobs once); `(*Worker).Loop(ctx) error` (ticker loop until ctx cancelled); `worker.Run(ctx, config.Config, *slog.Logger, *sql.DB) error` (registers the built-in `noop` handler and loops).

**Design note:** the periodic scheduler lives inside `worker` (strategy §12). Phase 1 registers only a `noop` handler to exercise the machinery end-to-end; no real scheduled/business job is added.

- [ ] **Step 1: Write the failing worker test** — `backend/internal/worker/worker_test.go`

```go
package worker

import (
	"context"
	"errors"
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/platform/jobs"
	"github.com/cloveclovedev/peppercheck/backend/internal/platform/logging"
	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
)

func TestRunDueProcessesRegisteredJob(t *testing.T) {
	db := testsupport.DB(t)
	if _, err := db.Exec("TRUNCATE public.jobs"); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	ctx := context.Background()
	store := jobs.NewStore(db)
	if _, err := store.Enqueue(ctx, "noop", nil, jobs.EnqueueOpts{}); err != nil {
		t.Fatalf("enqueue: %v", err)
	}

	w := New(db, logging.New("error"))
	ran := false
	w.Register("noop", func(context.Context, *jobs.Job) error { ran = true; return nil })

	if err := w.RunDue(ctx); err != nil {
		t.Fatalf("RunDue: %v", err)
	}
	if !ran {
		t.Fatal("handler was not invoked")
	}

	var status string
	if err := db.QueryRow("SELECT status FROM public.jobs LIMIT 1").Scan(&status); err != nil {
		t.Fatalf("scan status: %v", err)
	}
	if status != "succeeded" {
		t.Fatalf("job status = %q, want succeeded", status)
	}
}

func TestRunDueFailingHandlerReschedules(t *testing.T) {
	db := testsupport.DB(t)
	if _, err := db.Exec("TRUNCATE public.jobs"); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	ctx := context.Background()
	store := jobs.NewStore(db)
	if _, err := store.Enqueue(ctx, "boom", nil, jobs.EnqueueOpts{MaxAttempts: 5}); err != nil {
		t.Fatalf("enqueue: %v", err)
	}

	w := New(db, logging.New("error"))
	w.Register("boom", func(context.Context, *jobs.Job) error { return errors.New("nope") })

	if err := w.RunDue(ctx); err != nil {
		t.Fatalf("RunDue: %v", err)
	}
	var status string
	if err := db.QueryRow("SELECT status FROM public.jobs LIMIT 1").Scan(&status); err != nil {
		t.Fatalf("scan status: %v", err)
	}
	if status != "pending" {
		t.Fatalf("failed job with attempts left should be pending, got %q", status)
	}
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd backend && go test ./internal/worker/`
Expected: FAIL (undefined `New`).

- [ ] **Step 3: Implement `worker.go`** — `backend/internal/worker/worker.go`

```go
// Package worker runs Postgres-backed durable jobs. A ticker drives a claim
// loop; each due job is dispatched to a registered handler and marked
// succeeded, rescheduled with backoff, or failed. Phase 1 registers only a
// noop handler to exercise the machinery.
package worker

import (
	"context"
	"database/sql"
	"fmt"
	"log/slog"
	"time"

	"github.com/cloveclovedev/peppercheck/backend/internal/platform/config"
	"github.com/cloveclovedev/peppercheck/backend/internal/platform/jobs"
)

// Handler processes one job. Returning an error reschedules (or fails) the job.
type Handler func(ctx context.Context, j *jobs.Job) error

// Worker claims and dispatches durable jobs.
type Worker struct {
	store    *jobs.Store
	logger   *slog.Logger
	handlers map[string]Handler
	interval time.Duration
}

// New builds a Worker over an open database handle.
func New(db *sql.DB, logger *slog.Logger) *Worker {
	return &Worker{
		store:    jobs.NewStore(db),
		logger:   logger,
		handlers: map[string]Handler{},
		interval: time.Second,
	}
}

// Register binds a handler to a job kind.
func (w *Worker) Register(kind string, h Handler) { w.handlers[kind] = h }

// RunDue drains every currently-due job, then returns. It stops early if ctx is
// cancelled or a claim errors.
func (w *Worker) RunDue(ctx context.Context) error {
	for {
		if err := ctx.Err(); err != nil {
			return err
		}
		j, err := w.store.Claim(ctx)
		if err != nil {
			return err
		}
		if j == nil {
			return nil
		}
		w.process(ctx, j)
	}
}

func (w *Worker) process(ctx context.Context, j *jobs.Job) {
	h, ok := w.handlers[j.Kind]
	if !ok {
		_ = w.store.Fail(ctx, j, fmt.Errorf("no handler registered for kind %q", j.Kind), 5*time.Minute)
		w.logger.Error("no handler for job kind", "kind", j.Kind, "job_id", j.ID)
		return
	}
	if err := h(ctx, j); err != nil {
		backoff := time.Duration(j.Attempts) * 30 * time.Second
		if ferr := w.store.Fail(ctx, j, err, backoff); ferr != nil {
			w.logger.Error("failed to record job failure", "job_id", j.ID, "error", ferr)
		}
		w.logger.Error("job failed", "kind", j.Kind, "job_id", j.ID, "attempts", j.Attempts, "error", err)
		return
	}
	if err := w.store.Complete(ctx, j); err != nil {
		w.logger.Error("failed to mark job complete", "job_id", j.ID, "error", err)
	}
}

// Loop runs RunDue on each tick until ctx is cancelled.
func (w *Worker) Loop(ctx context.Context) error {
	t := time.NewTicker(w.interval)
	defer t.Stop()
	w.logger.Info("worker started", "interval", w.interval.String())
	for {
		select {
		case <-ctx.Done():
			w.logger.Info("worker shutting down")
			return nil
		case <-t.C:
			if err := w.RunDue(ctx); err != nil && ctx.Err() == nil {
				w.logger.Error("run due failed", "error", err)
			}
		}
	}
}

// Run wires the built-in handlers and loops until ctx is cancelled.
func Run(ctx context.Context, _ config.Config, logger *slog.Logger, db *sql.DB) error {
	w := New(db, logger)
	w.Register("noop", func(context.Context, *jobs.Job) error { return nil })
	return w.Loop(ctx)
}
```

- [ ] **Step 4: Add the `worker` command to `main.go`**

Add to the import block in `backend/cmd/peppercheck/main.go`:

```go
	"github.com/cloveclovedev/peppercheck/backend/internal/worker"
```

Add a new case to the `switch os.Args[1]` block, before `default:`:

```go
	case "worker":
		db, err := database.Connect(ctx, cfg.DatabaseURL)
		if err != nil {
			logger.Error("database connect failed", "error", err)
			os.Exit(1)
		}
		defer db.Close()
		if err := worker.Run(ctx, cfg, logger, db); err != nil {
			logger.Error("worker exited with error", "error", err)
			os.Exit(1)
		}
```

- [ ] **Step 5: Run tests, gofmt, vet, build**

```bash
cd backend
export DATABASE_URL='postgres://postgres:postgres@localhost:55432/peppercheck?sslmode=disable'
gofmt -l . && go vet ./... && go test ./... && go build ./cmd/peppercheck
```

Expected: gofmt lists nothing; vet clean; worker tests PASS; build succeeds.

- [ ] **Step 6: Manually verify the worker processes a job end-to-end**

```bash
cd backend
# enqueue a noop job directly:
PGPASSWORD=postgres psql -h localhost -p 55432 -U postgres -d peppercheck \
  -c "INSERT INTO public.jobs (kind) VALUES ('noop')"
# run the worker briefly, then stop it:
go run ./cmd/peppercheck worker &
sleep 3
kill -INT %1
# confirm the job succeeded:
PGPASSWORD=postgres psql -h localhost -p 55432 -U postgres -d peppercheck \
  -c "SELECT status FROM public.jobs ORDER BY created_at DESC LIMIT 1"
```

Expected: worker logs `worker started` then `worker shutting down` on SIGINT and exits 0; the last job's `status` is `succeeded`.

- [ ] **Step 7: Commit**

```bash
git add backend/internal/worker backend/cmd
git commit -m "feat(backend): add durable worker scheduler with noop handler"
```

- [ ] **Step 8 (cleanup): stop the throwaway Postgres**

```bash
docker rm -f pc-pg
```

---

### Task 8: Container image, Compose stack, Caddy, and self-migration

**Files:**
- Create: `backend/Dockerfile`
- Create: `backend/.dockerignore`
- Create: `backend/deploy/caddy/Caddyfile`
- Create: `backend/compose.yaml`
- Create: `backend/compose.override.yaml`
- Create: `backend/.env.example`

**Interfaces:**
- Consumes: the `peppercheck` binary (`api`/`worker`/`healthcheck`), `migrations/`, `deploy/postgres/init/00-roles.sh` (Tasks 2, 4).
- Produces: a runnable local stack `caddy · migrate · api · worker · postgres` with WAL archiving enabled. (The `backup` service is added in Task 9.)

**Design notes:**
- One multi-stage image; `api` and `worker` are the same image with different commands (strategy §6/§18).
- A one-shot `migrate` service applies migrations as the **migrator** role; `api`/`worker` depend on it completing and connect as the **app** role — this is the "migrations recreate the DB" path from the Done criteria.
- WAL archiving is enabled here (the PITR/RPO mechanism, strategy §20); the `backup` container that consumes it comes in Task 9.
- **WAL retention (local caveat):** archiving is always-on and the `wal-archive` volume has **no pruning** in Phase 1, so it grows for as long as the stack runs. For local dev, `docker compose down -v` clears it. Real WAL retention — pruning segments once a base backup covers them, within the PITR window — is a **Phase 7** concern (it depends on the base-backup/B2 design). This is acceptable for a local skeleton; do not treat the always-on archive as production-ready retention.
- The base `compose.yaml` never publishes `:5432`; `compose.override.yaml` (auto-merged by Compose in dev) binds it to `127.0.0.1` for host tools.

- [ ] **Step 1: Write `Dockerfile`** — `backend/Dockerfile`

```dockerfile
# syntax=docker/dockerfile:1
FROM golang:1.26 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -o /out/peppercheck ./cmd/peppercheck

FROM gcr.io/distroless/static-debian12:nonroot AS runtime
COPY --from=build /out/peppercheck /peppercheck
USER nonroot:nonroot
ENTRYPOINT ["/peppercheck"]
CMD ["api"]
```

- [ ] **Step 2: Write `.dockerignore`** — `backend/.dockerignore`

```text
.git
Dockerfile
.dockerignore
compose.yaml
compose.override.yaml
deploy
migrations
schema
db
atlas.hcl
.env
.env.*
**/*_test.go
*.md
```

- [ ] **Step 3: Write the Caddyfile** — `backend/deploy/caddy/Caddyfile`

```text
{
	admin off
}

# Local dev defaults to :80 (plain HTTP). Production sets CADDY_SITE_ADDRESS to
# the real domain (e.g. peppercheck.dev) so Caddy provisions TLS automatically.
{$CADDY_SITE_ADDRESS::80} {
	reverse_proxy api:8080
}
```

- [ ] **Step 4: Write `.env.example`** — `backend/.env.example`

```text
# Copy to .env for local development (.env is gitignored). These are
# NON-SENSITIVE local throwaway values only — never put a real provider secret
# or a real DB password here. Real secrets (staging/production) are injected at
# runtime via Bitwarden Secrets Manager / Docker secrets, never a plaintext .env (see the
# Secrets management constraint).
POSTGRES_PASSWORD=postgres
POSTGRES_APP_PASSWORD=app_dev_pw
POSTGRES_MIGRATOR_PASSWORD=migrator_dev_pw
POSTGRES_BACKUP_PASSWORD=backup_dev_pw
# age public key (recipient). Not a secret. Only needed for the opt-in backup
# profile (Task 9); generate the keypair with age-keygen.
AGE_RECIPIENT=
# Set to the production domain to enable automatic HTTPS; leave empty for :80.
CADDY_SITE_ADDRESS=
```

Then ignore the real `.env` at the repo root so it is never committed. Append to `/Users/makoto/projects/peppercheck/.gitignore`:

```text
# Backend local environment file (secrets/local config)
backend/.env
```

- [ ] **Step 5: Write the base Compose file** — `backend/compose.yaml`

This is the **local-development** stack. Secrets are **fail-closed** (`${VAR:?}`): a missing secret aborts `docker compose up` rather than silently using a weak default — local values come from `.env`. No `restart:` policy is set because this file is for local dev; the production topology (Phase 7, separate Droplets) adds `restart: unless-stopped` and does not reuse this file's local assumptions.

```yaml
name: peppercheck

services:
  postgres:
    image: postgres:17
    environment:
      POSTGRES_DB: peppercheck
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required (set it in .env)}
      POSTGRES_APP_PASSWORD: ${POSTGRES_APP_PASSWORD:?POSTGRES_APP_PASSWORD is required}
      POSTGRES_MIGRATOR_PASSWORD: ${POSTGRES_MIGRATOR_PASSWORD:?POSTGRES_MIGRATOR_PASSWORD is required}
      POSTGRES_BACKUP_PASSWORD: ${POSTGRES_BACKUP_PASSWORD:?POSTGRES_BACKUP_PASSWORD is required}
    command:
      - postgres
      - -c
      - wal_level=replica
      - -c
      - archive_mode=on
      - -c
      - archive_command=test ! -f /wal-archive/%f && cp %p /wal-archive/%f
      - -c
      - archive_timeout=60
      - -c
      - max_wal_senders=3
    volumes:
      - pgdata:/var/lib/postgresql/data
      - wal-archive:/wal-archive
      - ./deploy/postgres/init:/docker-entrypoint-initdb.d:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d peppercheck"]
      interval: 5s
      timeout: 5s
      retries: 10
    networks: [pcnet]

  migrate:
    # Pin to a specific released Atlas tag, NOT :latest, for reproducibility.
    # Resolve the current stable tag at implementation time from
    # https://hub.docker.com/r/arigaio/atlas/tags (e.g. `docker run --rm
    # arigaio/atlas:<tag> version`) and pin it here.
    image: arigaio/atlas:1.2.0
    command:
      - migrate
      - apply
      - --dir
      - file:///migrations
      - --url
      - postgres://peppercheck_migrator:${POSTGRES_MIGRATOR_PASSWORD:?POSTGRES_MIGRATOR_PASSWORD is required}@postgres:5432/peppercheck?sslmode=disable
    volumes:
      - ./migrations:/migrations:ro
    depends_on:
      postgres:
        condition: service_healthy
    restart: "no"
    networks: [pcnet]

  api:
    build: .
    command: ["api"]
    environment:
      APP_ENV: local
      PORT: "8080"
      LOG_LEVEL: info
      DATABASE_URL: postgres://peppercheck_app:${POSTGRES_APP_PASSWORD:?POSTGRES_APP_PASSWORD is required}@postgres:5432/peppercheck?sslmode=disable
    depends_on:
      migrate:
        condition: service_completed_successfully
    healthcheck:
      test: ["CMD", "/peppercheck", "healthcheck"]
      interval: 10s
      timeout: 3s
      retries: 5
    networks: [pcnet]

  worker:
    build: .
    command: ["worker"]
    environment:
      APP_ENV: local
      LOG_LEVEL: info
      DATABASE_URL: postgres://peppercheck_app:${POSTGRES_APP_PASSWORD:?POSTGRES_APP_PASSWORD is required}@postgres:5432/peppercheck?sslmode=disable
    depends_on:
      migrate:
        condition: service_completed_successfully
    networks: [pcnet]

  caddy:
    image: caddy:2
    environment:
      CADDY_SITE_ADDRESS: ${CADDY_SITE_ADDRESS:-:80}
    depends_on: [api]
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./deploy/caddy/Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy-data:/data
      - caddy-config:/config
    networks: [pcnet]

volumes:
  pgdata:
  wal-archive:
  caddy-data:
  caddy-config:

networks:
  pcnet:
```

- [ ] **Step 6: Write the dev override** — `backend/compose.override.yaml`

```yaml
# Dev-only overrides, auto-merged by `docker compose` in local development.
# Binds Postgres to localhost so host tools (Atlas, psql) can reach it. The base
# compose.yaml never publishes :5432, matching the production topology.
services:
  postgres:
    ports:
      - "127.0.0.1:5432:5432"
```

- [ ] **Step 7: Build and bring the stack up from a clean state**

```bash
cd backend
cp -n .env.example .env || true
docker compose down -v
docker compose up -d --build
```

Expected: images build; `postgres` becomes healthy; `migrate` runs once and exits 0; `api`, `worker`, `caddy` start.

- [ ] **Step 8: Verify the clean-clone acceptance criteria**

```bash
# health through Caddy:
curl -fsS http://localhost/livez    # -> ok
curl -fsS http://localhost/readyz   # -> ready
# migrations recreated the DB (tables present):
docker compose exec -T postgres psql -U postgres -d peppercheck -c '\dt public.*'
# least-privilege runtime role cannot run DDL:
docker compose exec -T -e PGPASSWORD=${POSTGRES_APP_PASSWORD:-app_dev_pw} postgres \
  psql -U peppercheck_app -d peppercheck -c 'CREATE TABLE nope (i int)' || echo "DDL correctly denied"
```

Expected: `/livez` → `ok`; `/readyz` → `ready`; `\dt` lists `users`, `user_identities`, `jobs`, `webhook_inbox`; the `CREATE TABLE` as `peppercheck_app` fails with a permission error and prints `DDL correctly denied`.

- [ ] **Step 9: Verify graceful shutdown of a service**

```bash
cd backend
docker compose stop api
docker compose logs --tail=20 api
```

Expected: logs show `shutting down http server`; the container stops cleanly (exit 0). Restart with `docker compose start api`.

- [ ] **Step 10: Verify WAL archiving is active**

```bash
cd backend
docker compose exec -T postgres psql -U postgres -d peppercheck -c "SELECT pg_switch_wal();"
docker compose exec -T postgres ls -1 /wal-archive | head
```

Expected: `/wal-archive` contains one or more archived WAL segment files (24-char hex names), confirming continuous archiving works.

- [ ] **Step 11: Commit**

```bash
git add backend/Dockerfile backend/.dockerignore backend/deploy/caddy \
  backend/compose.yaml backend/compose.override.yaml backend/.env.example .gitignore
git commit -m "feat(backend): add container image, Compose stack, Caddy, and self-migration"
```

---

### Task 9: Backup / WAL skeleton (local)

**Files:**
- Create: `backend/deploy/backup/Dockerfile`
- Create: `backend/deploy/backup/backup.sh`
- Modify: `backend/compose.yaml` (add the `backup` service + `backups` volume)

**Interfaces:**
- Consumes: the `wal-archive` volume + a healthy `postgres` (Task 8), the read-only `peppercheck_backup` role + `POSTGRES_BACKUP_PASSWORD`, and `AGE_RECIPIENT` from `.env`.
- Produces: an **opt-in `backup` Compose profile** (not started by the default `up`) that runs continuous WAL archiving (already on) plus periodic verified, `age`-encrypted logical dumps written to a `backups` volume.

**Scope (baseline §12.1, strategy §20):** Phase 1 is the **local skeleton**: WAL archiving (the RPO-15m mechanism, on since Task 8) + an encrypted `pg_dump` pipeline (the independent logical fallback). **Physical base backups via `pg_basebackup`, off-site Backblaze B2 upload, and the restore/PITR rehearsal are Phase 7.** The backup container holds only the `age` **public** recipient; the private key never lives in the container (strategy §20).

- [ ] **Step 1: Write `deploy/backup/backup.sh`** — `backend/deploy/backup/backup.sh`

The pipeline is **dump-to-temp → verify → encrypt → atomic rename** (review item #4), so a failed `pg_dump` can never be recorded as a good backup: it aborts before any `dump-*.age` file appears, and only a fully-encrypted, verified artifact is atomically published. Temp files are dot-prefixed so a partial write is never mistaken for a finished backup.

```sh
#!/bin/sh
# Local backup skeleton: takes an age-encrypted, verified logical dump on startup
# and then every BACKUP_INTERVAL_SECONDS. Continuous WAL archiving (postgres
# archive_mode) provides the PITR/RPO mechanism separately. Off-site upload (B2)
# and physical base backups are added in Phase 7.
set -eu

: "${AGE_RECIPIENT:?AGE_RECIPIENT (age public key) is required}"
INTERVAL="${BACKUP_INTERVAL_SECONDS:-86400}"
mkdir -p /backups

cleanup_temps() {
  rm -f /backups/.dump-*.tmp /backups/.dump-*.age.tmp 2>/dev/null || true
}

# Each step guards with `|| return 1` so a failure aborts the backup regardless
# of `set -e`: POSIX/busybox-ash disable `set -e` inside a function called from a
# tested context (`if ! run_backup`), so relying on it would let a failed pg_dump
# slip past the pg_restore verify and publish a corrupt artifact.
run_backup() {
  ts=$(date -u +%Y%m%dT%H%M%SZ)
  tmp="/backups/.dump-${ts}.dump.tmp"       # dot-prefixed: not a published artifact
  enc="/backups/.dump-${ts}.dump.age.tmp"
  final="/backups/dump-${ts}.dump.age"
  echo "{\"level\":\"info\",\"msg\":\"logical backup start\",\"ts\":\"$ts\"}"
  pg_dump -h "$PGHOST" -U "$PGUSER" -d "$PGDATABASE" -Fc -f "$tmp" || return 1
  pg_restore -l "$tmp" >/dev/null || return 1   # verify it is a valid archive
  age -r "$AGE_RECIPIENT" -o "$enc" "$tmp" || return 1
  mv "$enc" "$final" || return 1                 # atomic publish; only now does dump-*.age exist
  rm -f "$tmp"
  echo "{\"level\":\"info\",\"msg\":\"logical backup done\",\"file\":\"dump-${ts}.dump.age\"}"
}

# Startup run: fail loudly if the very first backup cannot be taken.
if ! run_backup; then
  echo "{\"level\":\"error\",\"msg\":\"initial logical backup failed\"}"
  cleanup_temps
  exit 1
fi

while true; do
  sleep "$INTERVAL"
  if ! run_backup; then
    echo "{\"level\":\"error\",\"msg\":\"logical backup failed\"}"
    cleanup_temps
  fi
done
```

- [ ] **Step 2: Write `deploy/backup/Dockerfile`** — `backend/deploy/backup/Dockerfile`

```dockerfile
# Postgres client tools (pg_dump matching server major 17) + age for client-side
# encryption. Alpine keeps the image small.
FROM postgres:17-alpine
RUN apk add --no-cache age
COPY backup.sh /usr/local/bin/backup.sh
RUN chmod +x /usr/local/bin/backup.sh
ENTRYPOINT ["/usr/local/bin/backup.sh"]
```

- [ ] **Step 3: Add the `backup` service to `compose.yaml`**

Add this service under `services:` in `backend/compose.yaml`. It is in the
**`backup` Compose profile**, so the default `docker compose up` (Task 8) does
**not** start it — the core stack starts on a clean clone without any age key
(review item #3). It connects as the read-only `peppercheck_backup` role
(`pg_read_all_data`), never a superuser (review item #4).

```yaml
  backup:
    build: ./deploy/backup
    profiles: ["backup"]
    environment:
      PGHOST: postgres
      PGUSER: peppercheck_backup
      PGPASSWORD: ${POSTGRES_BACKUP_PASSWORD:?POSTGRES_BACKUP_PASSWORD is required}
      PGDATABASE: peppercheck
      # Empty default (NOT ${VAR:?}). Compose interpolates the whole file eagerly
      # — even services excluded by the active profile — so a required AGE_RECIPIENT
      # here would break the core stack's `docker compose up` (Task 8 clean-clone).
      # backup.sh enforces a non-empty AGE_RECIPIENT at runtime instead.
      AGE_RECIPIENT: ${AGE_RECIPIENT:-}
      BACKUP_INTERVAL_SECONDS: ${BACKUP_INTERVAL_SECONDS:-86400}
    depends_on:
      postgres:
        condition: service_healthy
    volumes:
      - wal-archive:/wal-archive:ro
      - backups:/backups
    networks: [pcnet]
```

Add `backups:` to the `volumes:` block in the same file:

```yaml
volumes:
  pgdata:
  wal-archive:
  backups:
  caddy-data:
  caddy-config:
```

- [ ] **Step 4: Generate an age keypair and set the recipient**

```bash
# age-keygen is installed via Homebrew: `brew install age`
age-keygen -o ~/.peppercheck-age.key    # prints the public key; keep the file private
# copy the "Public key: age1..." value into backend/.env as AGE_RECIPIENT
```

Set `AGE_RECIPIENT=age1...` in `backend/.env`. Keep `~/.peppercheck-age.key` (the private key) out of the repo; it is used only for the restore drill (Phase 7) and the decrypt check below.

- [ ] **Step 5: Bring up the backup service and confirm an encrypted artifact**

```bash
cd backend
docker compose --profile backup up -d --build backup
sleep 5
docker compose exec -T backup ls -1 /backups        # -> dump-<timestamp>.dump.age
docker compose --profile backup logs --tail=10 backup  # -> "logical backup done"
```

Expected: a `dump-*.dump.age` file exists in `/backups`; logs show a successful backup.

- [ ] **Step 6: Confirm the artifact is decryptable (integrity check, on the host)**

```bash
cd backend
f=$(docker compose exec -T backup sh -c 'ls -1 /backups/dump-*.dump.age | head -1' | tr -d '\r')
docker compose cp "backup:$f" /tmp/dump.age
age -d -i ~/.peppercheck-age.key /tmp/dump.age | pg_restore -l | head
rm -f /tmp/dump.age
```

Expected: `age -d` decrypts successfully and `pg_restore -l` lists the archive's table of contents (proves a valid custom-format dump). Decryption happens on the host with the private key — the container only holds the public recipient.

- [ ] **Step 7: Confirm WAL archiving still accumulates (RPO mechanism)**

```bash
cd backend
docker compose exec -T postgres psql -U postgres -d peppercheck -c "SELECT pg_switch_wal();"
docker compose exec -T backup ls -1 /wal-archive | tail
```

Expected: WAL segment files are present in the shared `/wal-archive` volume (read-only in the backup container).

- [ ] **Step 8: Commit**

```bash
git add backend/deploy/backup backend/compose.yaml
git commit -m "feat(backend): add local backup/WAL skeleton with age-encrypted dumps"
```

---

### Task 10: CI gates

**Files:**
- Create: `.github/workflows/ci-backend.yml`

**Interfaces:**
- Consumes: everything under `backend/` (Tasks 1–9).
- Produces: a `ci-backend` workflow with a `go` job (fmt, vet, Atlas validate/apply/drift, **real DB-role separation on real tables**, race tests serialized) and an `image` job (**Compose syntax validation + api and backup image builds**).

**Design note:** mirrors the existing workflow conventions in `.github/workflows/` (path-filtered `pull_request` trigger, `concurrency` group). The `go` job uses a `postgres:17` service container and **runs the real `00-roles.sh`** to create the actual `peppercheck_migrator`/`peppercheck_app`/`peppercheck_backup` roles, applies migrations **as the migrator** (owner → app gets DML via default privileges; also lets the go integration tests `TRUNCATE` their own tables), then verifies the real `peppercheck_app` role can DML real tables but is denied DDL (review item #2). The fast self-contained role-model SQL test is kept as a quick unit-level check. `go test` runs with `-p 1` so the jobs/worker packages don't `TRUNCATE` the shared DB concurrently (review item #6).

- [ ] **Step 1: Write the workflow** — `.github/workflows/ci-backend.yml`

```yaml
name: ci-backend

on:
  workflow_dispatch:
  pull_request:
    paths:
      - 'backend/**'
      - '.github/workflows/ci-backend.yml'

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

defaults:
  run:
    working-directory: backend

jobs:
  go:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:17
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: peppercheck
        ports:
          - 5432:5432
        options: >-
          --health-cmd "pg_isready -U postgres -d peppercheck"
          --health-interval 5s
          --health-timeout 5s
          --health-retries 10
    env:
      # go tests + atlas apply run AS THE MIGRATOR: it owns the tables (so tests
      # can TRUNCATE) and, via ALTER DEFAULT PRIVILEGES, the app role gets DML on
      # them — which the role-separation step below verifies.
      DATABASE_URL: postgres://peppercheck_migrator:migrator_ci_pw@localhost:5432/peppercheck?sslmode=disable
      # Consumed by the real 00-roles.sh:
      PGHOST: localhost
      PGPASSWORD: postgres
      POSTGRES_USER: postgres
      POSTGRES_DB: peppercheck
      POSTGRES_MIGRATOR_PASSWORD: migrator_ci_pw
      POSTGRES_APP_PASSWORD: app_ci_pw
      POSTGRES_BACKUP_PASSWORD: backup_ci_pw
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-go@v5
        with:
          go-version: '1.26'
          cache-dependency-path: backend/go.sum

      - name: gofmt
        run: test -z "$(gofmt -l .)" || (gofmt -l .; echo "run gofmt -w ."; exit 1)

      - name: go vet
        run: go vet ./...

      - uses: ariga/setup-atlas@v0
        with:
          version: v1.2.0   # pin (not latest/canary); match compose + dev

      - name: Provision DB roles (runs the real 00-roles.sh)
        run: bash deploy/postgres/init/00-roles.sh

      - name: Validate migration checksums
        run: atlas migrate validate --dir file://migrations

      - name: Apply migrations as the migrator role
        # --revisions-schema atlas: revision history goes to a dedicated migrator-owned
        # database-level CREATE for Atlas's default revision schema (same as the
        # compose migrate service in Task 8).
        run: atlas migrate apply --env local --url "$DATABASE_URL" --revisions-schema atlas

      - name: Check for schema/migration drift
        run: |
          atlas migrate diff ci_drift_check --env local
          if [ -n "$(git status --porcelain migrations)" ]; then
            echo "Schema and migrations are out of sync (uncommitted diff):"
            git status --porcelain migrations
            exit 1
          fi

      - name: Role-model SQL test (synthetic, fast)
        run: psql "postgres://postgres:postgres@localhost:5432/peppercheck?sslmode=disable" -v ON_ERROR_STOP=1 -f db/tests/test_role_separation.sql

      - name: Real role separation on real tables
        run: |
          set -euo pipefail
          APP="postgres://peppercheck_app:${POSTGRES_APP_PASSWORD}@localhost:5432/peppercheck?sslmode=disable"
          psql "$APP" -v ON_ERROR_STOP=1 -c "INSERT INTO public.users DEFAULT VALUES;"
          psql "$APP" -v ON_ERROR_STOP=1 -c "SELECT count(*) FROM public.users;"
          psql "$APP" -v ON_ERROR_STOP=1 -c "UPDATE public.users SET status = 'active';"
          if psql "$APP" -v ON_ERROR_STOP=1 -c "CREATE TABLE public.should_fail (i int);" 2>/dev/null; then
            echo "FAIL: app role must NOT be able to CREATE TABLE"; exit 1
          fi
          echo "app role: DML ok, DDL denied"

      - name: Tests (race, serialized packages)
        run: go test -race -p 1 ./...

  image:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: backend
    env:
      # Compose is fail-closed on secrets; supply throwaway values so `config`
      # and `build` can parse the file. These are not real secrets.
      POSTGRES_PASSWORD: ci
      POSTGRES_APP_PASSWORD: ci
      POSTGRES_MIGRATOR_PASSWORD: ci
      POSTGRES_BACKUP_PASSWORD: ci
      AGE_RECIPIENT: age1ci
    steps:
      - uses: actions/checkout@v4
      - name: Validate Compose syntax (incl. backup profile)
        run: docker compose --profile backup config >/dev/null
      - name: Build api image
        run: docker build -t peppercheck-backend:ci .
      - name: Build backup image
        run: docker build -t peppercheck-backup:ci deploy/backup
```

- [ ] **Step 2: Validate the workflow locally as far as possible**

Reproduce the CI gates locally with **no host `psql`** — do NOT `brew install`
anything. The throwaway Postgres runs the real `00-roles.sh` via the
init-mount path, and every `psql` check runs **inside the container** (the
`postgres` image bundles `psql`). Host tools used: `docker`, `go`, `atlas`
only. (CI on GitHub uses the runner's preinstalled `psql`; this local path
deliberately keeps the dev machine clean and exercises the real container
init.)

```bash
cd backend
docker run --rm -d --name pc-pg-ci \
  -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=peppercheck \
  -e POSTGRES_MIGRATOR_PASSWORD=migrator_ci_pw \
  -e POSTGRES_APP_PASSWORD=app_ci_pw \
  -e POSTGRES_BACKUP_PASSWORD=backup_ci_pw \
  -v "$PWD/deploy/postgres/init:/docker-entrypoint-initdb.d:ro" \
  -p 55432:5432 postgres:17
# wait until 00-roles.sh (init) has created the roles — proves init finished:
until docker exec pc-pg-ci psql -U postgres -d peppercheck -tAc \
  "SELECT 1 FROM pg_roles WHERE rolname='peppercheck_migrator'" 2>/dev/null | grep -q 1; do sleep 1; done

export DATABASE_URL='postgres://peppercheck_migrator:migrator_ci_pw@localhost:55432/peppercheck?sslmode=disable'
test -z "$(gofmt -l .)" && echo "gofmt clean"
go vet ./...
atlas migrate validate --dir file://migrations
atlas migrate apply --env local --url "$DATABASE_URL" --revisions-schema atlas   # migrator lacks db-level CREATE
atlas migrate diff ci_drift_check --env local           # expect "no changes"; no new file

# synthetic role-model SQL test — piped into the container's psql:
docker exec -i pc-pg-ci psql -U postgres -d peppercheck -v ON_ERROR_STOP=1 -f - < db/tests/test_role_separation.sql

# real app-role check (container psql): DML ok, DDL denied:
docker exec -e PGPASSWORD=app_ci_pw pc-pg-ci \
  psql -h localhost -U peppercheck_app -d peppercheck -v ON_ERROR_STOP=1 -c "INSERT INTO public.users DEFAULT VALUES;"
docker exec -e PGPASSWORD=app_ci_pw pc-pg-ci \
  psql -h localhost -U peppercheck_app -d peppercheck -c "CREATE TABLE public.should_fail (i int);" \
  && echo "UNEXPECTED: DDL allowed" || echo "DDL correctly denied"

go test -race -p 1 ./...
AGE_RECIPIENT=age1ci POSTGRES_PASSWORD=ci POSTGRES_APP_PASSWORD=ci POSTGRES_MIGRATOR_PASSWORD=ci POSTGRES_BACKUP_PASSWORD=ci \
  docker compose --profile backup config >/dev/null && echo "compose config ok"
docker build -t peppercheck-backend:ci .
docker build -t peppercheck-backup:ci deploy/backup
docker rm -f pc-pg-ci
```

Expected: every command succeeds; `atlas migrate diff` reports the directory is synced (no new file); the synthetic role test ends in `ROLLBACK`; the app role's `INSERT` succeeds and its `CREATE TABLE` is denied; `go test -race` passes; both images build.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci-backend.yml
git commit -m "ci(backend): add Go, Atlas, and image build gates"
```

- [ ] **Step 4: Open the PR into the integration branch**

```bash
git push -u origin <feature-branch>
gh pr create --base refactor/go-api-vps --title "feat(backend): Phase 1 foundation (Go api/worker, Atlas, Compose, backup, CI)" \
  --body "Implements Phase 1 (Foundation) per docs/superpowers/plans/2026-07-23-phase1-foundation.md. No feature ports."
```

---

## Phase 1 Done Checklist (maps to strategy §22 / baseline §13)

- [ ] A clean clone runs `make up` (= `cp .env.example .env` then `docker compose up`; a bare `docker compose up` is fail-closed on secrets by design) and the **core** stack starts (`caddy · migrate · api · worker · postgres`) with no age key required; the `backup` service is opt-in via `make backup` / `docker compose --profile backup up`. — Tasks 8, 9
- [ ] Migrations recreate the DB from scratch (`migrate` service applies the Atlas baseline; `\dt` shows `users`, `user_identities`, `jobs`, `webhook_inbox`). — Tasks 4–6, 8
- [ ] `api` and `worker` shut down cleanly on SIGINT/SIGTERM. — Tasks 2, 7, 8
- [ ] Provider-independent identity core exists (`users.id` UUID anchor, `user_identities(issuer, subject)`), no `auth.users`/`auth.uid()`. — Task 4
- [ ] Migration/runtime DB role separation enforced (app role cannot DDL). — Tasks 4, 8, 10
- [ ] Durable job primitive with `FOR UPDATE SKIP LOCKED` + idempotency + retry. — Task 5
- [ ] Webhook inbox idempotency primitive. — Task 6
- [ ] Backup/WAL skeleton at the accepted 15-minute RPO mechanism (continuous WAL archiving + encrypted logical dumps); real B2 + restore drill deferred to Phase 7. — Tasks 8, 9
- [ ] CI gates for Go (fmt/vet/race), Atlas (validate/apply/drift), and image build. — Task 10
- [ ] No feature RPC, Edge Function, or web route ported. — enforced throughout

## Self-Review (author checklist, completed)

**1. Spec coverage (baseline §13 handoff items 1–7):**
1. Go module + api/worker lifecycle → Tasks 1, 2, 3, 7. ✓
2. Provider-independent Atlas schema with internal user IDs → Task 4. ✓
3. Local Compose/Caddy/Postgres skeleton → Task 8. ✓
4. Migration/runtime DB role separation → Task 4 (+ verified in 8, 10). ✓
5. Durable job and webhook inbox primitives → Tasks 5, 6. ✓
6. Backup/WAL skeleton matching accepted RPO/RTO → Tasks 8 (WAL) + 9 (encrypted dumps); B2/restore deferred to Phase 7 per the user's "local skeleton only" decision. ✓
7. CI gates for Go, Atlas, Postgres, image → Task 10. ✓
   Strategy §22 "Done": clean clone starts stack, migrations recreate DB, api/worker shut down cleanly → Done Checklist above. ✓

**2. Placeholder scan:** No TBD/TODO; every code and config step contains complete content. ✓

**3. Type consistency:** `config.Config`, `api.Run(ctx, cfg, logger, ready)` (nil-probe contract stable across Tasks 2/3), `database.Connect → *sql.DB` (alias `database.Handle`), `jobs.Store`/`jobs.Job` field names consistent across Tasks 5 and 7, `inbox.Store.Insert` signature stable, `worker.New/Register/RunDue/Loop/Run` consistent. Schema is table-only (unauthenticated Atlas, free); `updated_at` is set in every `jobs` store UPDATE (Claim/Complete/Fail) in Go, replacing the DB trigger. ✓

**Notes for the executor:**
- Run all Go steps from `backend/`. Keep a throwaway Postgres (`pc-pg`) up across Tasks 3–7; Task 7 Step 8 tears it down.
- After Tasks 5 and 6 add schema files, always re-run `atlas migrate apply --env local` before that task's integration tests.
- The `migrate` service in Compose is the production-shaped migration path; the host `atlas` CLI is for local development and CI.
