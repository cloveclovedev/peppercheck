# Phase 2 Backend — Identity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the Go API a Firebase-verified identity spine — verify Firebase ID tokens, resolve them to a stable internal user UUID via `user_identities`, and serve `GET /api/v1/me`.

**Architecture:** Adopt the repo-wide `core`/`platform`/features naming convention (reorganize the Phase 1 `internal/platform/*` foundation into `internal/core/*`). Add `internal/platform/auth` as the first external-service adapter: a narrow `TokenVerifier` boundary implemented by the Firebase Admin SDK, plus authentication middleware that resolves a verified `(issuer, subject)`. Add the `internal/identity` feature (`domain.go`/`service.go`/`store.go`/`handler.go`) that provisions `users` + `user_identities` on first sighting and returns the internal user from `GET /api/v1/me`.

**Tech Stack:** Go (stdlib `net/http`, `database/sql` via the pgx driver), Firebase Admin Go SDK (`firebase.google.com/go/v4`), Atlas-managed Postgres (tables already exist from Phase 1), Docker-based integration tests.

Spec: `docs/designs/2026-07-24-phase2-identity-client-boundary-design.md`. This plan covers the **backend** PRs **P2-1, P2-2, P2-3**. The Flutter PRs (P2-4/5/6) get a separate plan written after this one is implemented and the API is runnable.

## Global Constraints

Every task's requirements implicitly include this section.

- **Module path:** `github.com/cloveclovedev/peppercheck/backend`. Work inside `backend/`.
- **Go version:** `go 1.26` (see `backend/go.mod`). Stdlib-first; the only pre-existing dependency is `github.com/jackc/pgx/v5` (database/sql driver). This plan adds exactly one external dependency: the **Firebase Admin Go SDK** (`firebase.google.com/go/v4` + `google.golang.org/api/option`) — a justified platform-boundary adapter (token verification is security-critical and must not be hand-rolled). Do not add other dependencies.
- **Naming convention (repo-wide):** top-level `internal/core/` (our own foundation), `internal/platform/` (third-party SaaS adapters — SDK types stop here), `internal/<feature>/` (features). A feature package uses files `domain.go` / `service.go` (`type Service`) / `store.go` (`type Store`) / `handler.go` (`type Handler`). `platform/*` may depend on `core/*`, never the reverse. Domain/service code never imports Firebase types.
- **Schema:** tables only, no DB functions/triggers. `updated_at` is set by Go on every `UPDATE` (`updated_at = now()`); provisioning inserts rely on column defaults. `users` and `user_identities` already exist (`backend/schema/identity/{01_users.sql,02_user_identities.sql}`); this plan writes no new migration.
- **Error envelope (verbatim shape):** `{"error":{"code":"<stable-code>","message":"<text>","requestId":"<id>"}}`. Stable codes used here: `unauthenticated` (401), `unavailable` (503), `internal` (500). Never expose a raw provider error string to the client.
- **HTTP port (single source of truth):** the deployed port is defined **once** as `API_PORT` in the Compose `.env`; the `api` service maps it to `PORT` and Caddy reads the same `API_PORT` for its upstream (`reverse_proxy api:{$API_PORT}`). The Go config default (`8765`) matches it and is only the fallback for standalone (non-Compose) runs. Never hardcode the port in more than one place.
- **Test command:** unit tests run with `go test ./...` from `backend/`. Integration tests (those calling `testsupport.DB(t)`) **skip** unless `DATABASE_URL` is set; run the full suite incl. integration with `make test` (spins a throwaway Postgres, applies Atlas migrations, runs `go test -race -p 1 -count=1 ./...`). Requires host `atlas` v1.2.0 + Docker.
- **Commits:** Conventional Commits. Every commit message body ends with the implementing session's standard trailers (a `Co-Authored-By:` line for the Claude model plus a `Claude-Session:` URL) per the repo convention. Do **not** copy a specific session URL out of this document — use the session actually making the commit. (Trailers are omitted from the sample commands below for brevity — always append them.)
- **Branch:** work on `feat/phase2-identity-client-boundary` (already created off `refactor/go-api-vps`).

---

## Task 1: Reorganize `internal/platform/*` → `internal/core/*` (PR P2-1)

Mechanical move of the Phase 1 foundation packages (config, database, httpserver, logging, jobs, inbox) into `internal/core/`, per the naming convention. Package names are unchanged — only import paths move. This is a self-contained, independently-reviewable refactor with no behavior change.

**Files:**
- Move: `backend/internal/platform/` → `backend/internal/core/` (directory rename via `git mv`)
- Modify: every `.go` file importing `.../internal/platform/...` (import path rewrite): `cmd/peppercheck/main.go`, `internal/api/api.go`, `internal/worker/worker.go`, `internal/testsupport/db.go`, and files within the moved packages that import sibling platform packages.

**Interfaces:**
- Consumes: nothing new.
- Produces: the foundation packages are now importable as `github.com/cloveclovedev/peppercheck/backend/internal/core/<pkg>` (e.g. `core/config`, `core/database`, `core/httpserver`, `core/logging`, `core/jobs`, `core/inbox`). Later tasks import from `core/`.

- [ ] **Step 1: Move the directory**

```bash
cd backend
git mv internal/platform internal/core
```

- [ ] **Step 2: Rewrite import paths (platform → core)**

```bash
cd backend
grep -rl 'backend/internal/platform/' --include='*.go' . \
  | xargs sed -i '' 's|backend/internal/platform/|backend/internal/core/|g'
```
(macOS `sed` requires the empty `-i ''` argument.)

- [ ] **Step 3: Confirm no stray references remain**

```bash
cd backend
grep -rn 'internal/platform' --include='*.go' . || echo "clean"
```
Expected: `clean` (no output from grep).

- [ ] **Step 4: Build and vet**

Run:
```bash
cd backend && go build ./... && go vet ./...
```
Expected: no errors.

- [ ] **Step 5: Run the full test suite (incl. DB integration)**

Run: `cd backend && make test`
Expected: all packages PASS (the move is behavior-preserving).

- [ ] **Step 6: Update the README layout reference if present**

Check whether the README documents the package layout:
```bash
cd backend && grep -n 'internal/platform' README.md || echo "no README reference"
```
If it prints a line, edit `backend/README.md` to say `internal/core` instead. If it prints `no README reference`, skip.

- [ ] **Step 7: Stage explicitly, review, and commit**

Never `git add -A` — the worktree has unrelated changes (root docs, Flutter generated files). Stage only the backend reorg and verify before committing:
```bash
cd backend
git add internal cmd README.md
git diff --cached --stat   # confirm ONLY backend/internal/**, backend/cmd/**, backend/README.md are staged
git commit -m "refactor(backend): move platform foundation packages to internal/core

Adopt the repo-wide core/platform/features naming convention: the Phase 1
foundation (config, database, httpserver, logging, jobs, inbox) is our own
infrastructure and moves to internal/core. internal/platform is reserved for
third-party SaaS adapters (added next). Import-path-only change; no behavior
change."
```
If `git diff --cached --stat` shows anything outside those paths, unstage it with `git restore --staged <path>` before committing.

---

## Task 2: Config additions — Firebase project ID and local port default (PR P2-2)

**Files:**
- Modify: `backend/internal/core/config/config.go`
- Test: `backend/internal/core/config/config_test.go`

**Interfaces:**
- Consumes: nothing new.
- Produces: `config.Config` gains `FirebaseProjectID string` (from `FIREBASE_PROJECT_ID`, default `""`). `config.Load()` default `Port` is `8765`.

- [ ] **Step 1: Update the existing default test and add a Firebase test**

The existing `TestLoadDefaults` (in `backend/internal/core/config/config_test.go` after the Task 1 move) asserts the default port is `8080`; the new default will break it, so **update it in the same step** rather than adding a duplicate. In `TestLoadDefaults`: add `t.Setenv("FIREBASE_PROJECT_ID", "")`, replace the `8080` assertion, and add a Firebase default check:
```go
	if c.Port != 8765 {
		t.Errorf("Port = %d, want 8765", c.Port)
	}
	if c.FirebaseProjectID != "" {
		t.Errorf("FirebaseProjectID = %q, want empty by default", c.FirebaseProjectID)
	}
```
Then append a test for the override:
```go
func TestLoadReadsFirebaseProjectID(t *testing.T) {
	t.Setenv("FIREBASE_PROJECT_ID", "peppercheck-dev")
	c, err := Load()
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if c.FirebaseProjectID != "peppercheck-dev" {
		t.Fatalf("FirebaseProjectID = %q, want peppercheck-dev", c.FirebaseProjectID)
	}
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd backend && go test ./internal/core/config/ -v`
Expected: FAIL — first a compile error (`FirebaseProjectID` field does not exist yet); once that compiles, `TestLoadDefaults` fails because `c.Port` is still `8080`.

- [ ] **Step 3: Implement**

In `backend/internal/core/config/config.go`, add the field to `Config`:
```go
	FirebaseProjectID string // Firebase project ID for ID-token verification
```
Change the `Port` default in `Load()` from `8080` to `8765`:
```go
		Port:            getenvInt("PORT", 8765),
```
Add to the `Config{...}` literal in `Load()`:
```go
		FirebaseProjectID: os.Getenv("FIREBASE_PROJECT_ID"),
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd backend && go test ./internal/core/config/ -v`
Expected: PASS.

- [ ] **Step 5: Wire the port and Firebase project ID through Compose**

Edit `backend/compose.yaml`. In the `api` service `environment:` block, drive `PORT` from a single `API_PORT` knob and inject the project ID **fail-closed** (`:?`) so a missing value fails loudly instead of booting into silent auth failures. Local `make up` copies `.env` from `.env.example` (which carries a dummy `FIREBASE_PROJECT_ID`), so local boot still works; staging/production **must** set the real value; CI passes an explicit dummy. (`firebase.NewApp` with `WithoutAuthentication` does not contact the network at construction, so any non-empty ID lets the api start — only per-token verification needs the real project.)
```yaml
    environment:
      APP_ENV: local
      PORT: ${API_PORT:?API_PORT is required (set it in .env)}
      LOG_LEVEL: info
      FIREBASE_PROJECT_ID: ${FIREBASE_PROJECT_ID:?FIREBASE_PROJECT_ID is required (set it in .env; a dummy like peppercheck-local is fine locally)}
      DATABASE_URL: postgres://peppercheck_app:${POSTGRES_APP_PASSWORD:?POSTGRES_APP_PASSWORD is required}@postgres:5432/peppercheck?sslmode=disable
```
In the same file, give the `caddy` service the same port so its upstream stays in sync — add `API_PORT` to its `environment:`:
```yaml
    environment:
      CADDY_SITE_ADDRESS: ${CADDY_SITE_ADDRESS:-:80}
      API_PORT: ${API_PORT:?API_PORT is required (set it in .env)}
```
`API_PORT` is **required** (no `:-8765` fallback) in both services so the port lives in exactly one place — the `.env` — with no duplicated defaults to drift.

- [ ] **Step 6: Point Caddy at the single-source port**

Edit `backend/deploy/caddy/Caddyfile` — replace the hardcoded upstream port with the env placeholder (with a matching fallback):
```
{$CADDY_SITE_ADDRESS::80} {
	reverse_proxy api:{$API_PORT}
}
```

- [ ] **Step 7: Update `.env.example` (and README if it documents the port)**

Append to `backend/.env.example`:
```
# api HTTP port — single source of truth; Caddy proxies to api:$API_PORT
API_PORT=8765
# Firebase project whose ID tokens the api verifies. A dummy value lets the
# stack boot offline; set the real per-env project to actually authenticate.
FIREBASE_PROJECT_ID=peppercheck-local
```
`cmd/peppercheck/main.go`'s `runHealthcheck` builds its URL from `cfg.Port` (resolved from `PORT`/`API_PORT`), so it stays in sync — no code change. If `backend/README.md` documents the port or compose env, update it to reference `API_PORT`.

- [ ] **Step 8: Give the CI compose-validation job the new required vars**

`.github/workflows/ci-backend.yml`'s `image` job runs `docker compose config` (and `build`). Now that `API_PORT` and `FIREBASE_PROJECT_ID` are required (`:?`), that step fails until they are set. Add throwaway values to that job's existing `env:` block (next to `POSTGRES_*`/`AGE_RECIPIENT`):
```yaml
      API_PORT: "8765"
      FIREBASE_PROJECT_ID: ci
```

- [ ] **Step 9: Commit**

```bash
cd backend
git add internal/core/config/config.go internal/core/config/config_test.go compose.yaml deploy/caddy/Caddyfile .env.example README.md ../.github/workflows/ci-backend.yml
git diff --cached --stat   # confirm only these files are staged
git commit -m "feat(backend): single-source api port via API_PORT and inject FIREBASE_PROJECT_ID"
```

---

## Task 3: Error envelope writer in `core/httpserver` (PR P2-2)

**Files:**
- Create: `backend/internal/core/httpserver/errors.go`
- Test: `backend/internal/core/httpserver/errors_test.go`

**Interfaces:**
- Consumes: `RequestIDFrom(ctx)` (existing in `core/httpserver/middleware.go`).
- Produces: `func WriteError(w http.ResponseWriter, r *http.Request, status int, code, message string)` — writes `{"error":{"code","message","requestId"}}` with `Content-Type: application/json` and the given status. Stable code constants: `CodeUnauthenticated = "unauthenticated"`, `CodeInternal = "internal"`.

- [ ] **Step 1: Write the failing test**

Create `backend/internal/core/httpserver/errors_test.go`:
```go
package httpserver

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestWriteErrorEnvelope(t *testing.T) {
	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/x", nil)
	req.Header.Set(RequestIDHeader, "req-123")
	// RequestID middleware normally seeds the context; seed it directly here.
	req = req.WithContext(withRequestID(req.Context(), "req-123"))

	WriteError(rec, req, http.StatusUnauthorized, CodeUnauthenticated, "missing token")

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", rec.Code)
	}
	if ct := rec.Header().Get("Content-Type"); ct != "application/json" {
		t.Fatalf("content-type = %q", ct)
	}
	var body struct {
		Error struct {
			Code, Message, RequestID string
		} `json:"error"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("unmarshal: %v; body=%s", err, rec.Body.String())
	}
	if body.Error.Code != "unauthenticated" || body.Error.Message != "missing token" || body.Error.RequestID != "req-123" {
		t.Fatalf("envelope = %+v", body.Error)
	}
}
```

- [ ] **Step 2: Add the test-only context seeder**

The test needs to seed the request ID without running the middleware. In `backend/internal/core/httpserver/middleware.go`, expose an unexported helper next to `RequestID` (used by both the middleware and the test — keep the key private):
```go
// withRequestID stores id in ctx under the private requestIDKey.
func withRequestID(ctx context.Context, id string) context.Context {
	return context.WithValue(ctx, requestIDKey, id)
}
```
Then refactor `RequestID` to call it (replace the inline `context.WithValue(r.Context(), requestIDKey, id)` with `withRequestID(r.Context(), id)`).

- [ ] **Step 3: Run to verify it fails**

Run: `cd backend && go test ./internal/core/httpserver/ -run TestWriteErrorEnvelope -v`
Expected: FAIL (`WriteError`, `CodeUnauthenticated` undefined).

- [ ] **Step 4: Implement**

Create `backend/internal/core/httpserver/errors.go`:
```go
package httpserver

import (
	"encoding/json"
	"net/http"
)

// Stable, machine-readable error codes returned in the error envelope.
const (
	CodeUnauthenticated = "unauthenticated" // 401: caller's auth is missing/invalid/expired
	CodeUnavailable     = "unavailable"     // 503: a dependency (e.g. token key fetch) failed
	CodeInternal        = "internal"        // 500: unexpected server error
)

type errorEnvelope struct {
	Error errorBody `json:"error"`
}

type errorBody struct {
	Code      string `json:"code"`
	Message   string `json:"message"`
	RequestID string `json:"requestId"`
}

// WriteError writes the standard JSON error envelope with the given HTTP status.
// It never exposes a raw provider error — callers pass a safe, stable message.
func WriteError(w http.ResponseWriter, r *http.Request, status int, code, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(errorEnvelope{Error: errorBody{
		Code:      code,
		Message:   message,
		RequestID: RequestIDFrom(r.Context()),
	}})
}
```

- [ ] **Step 5: Run to verify it passes**

Run: `cd backend && go test ./internal/core/httpserver/ -v`
Expected: PASS (existing middleware tests + the new one).

- [ ] **Step 6: Route panics through the envelope**

The existing `Recover` middleware writes a bare `WriteHeader(500)` with no body. Send it through `WriteError` so a panic returns the same envelope (with `requestId`) as any other error. In `backend/internal/core/httpserver/middleware.go`, change the recover branch inside `Recover`:
```go
			defer func() {
				if rec := recover(); rec != nil {
					logger.LogAttrs(r.Context(), slog.LevelError, "panic_recovered",
						slog.Any("error", rec),
						slog.String("request_id", RequestIDFrom(r.Context())),
					)
					WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
				}
			}()
```
Add a test that drives a panicking handler through the real middleware chain. Append to `errors_test.go` (add `"io"` and `"log/slog"` to its imports):
```go
func TestRecoverWritesEnvelope(t *testing.T) {
	panicky := http.HandlerFunc(func(http.ResponseWriter, *http.Request) { panic("boom") })
	h := Chain(panicky, RequestID, Recover(slog.New(slog.NewTextHandler(io.Discard, nil))))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/x", nil))
	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want 500", rec.Code)
	}
	var body struct {
		Error struct{ Code, RequestID string } `json:"error"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("unmarshal: %v; body=%s", err, rec.Body.String())
	}
	if body.Error.Code != "internal" || body.Error.RequestID == "" {
		t.Fatalf("envelope = %+v", body.Error)
	}
}
```

- [ ] **Step 7: Run and commit**

Run: `cd backend && go test ./internal/core/httpserver/ -v` (Expected: PASS), then:
```bash
cd backend
git add internal/core/httpserver/errors.go internal/core/httpserver/errors_test.go internal/core/httpserver/middleware.go
git commit -m "feat(backend): add stable JSON error envelope and route panics through it"
```

---

## Task 4: Firebase `TokenVerifier` boundary in `platform/auth` (PR P2-2)

**Files:**
- Create: `backend/internal/platform/auth/auth.go` (types + `TokenVerifier` interface + fake)
- Create: `backend/internal/platform/auth/firebase.go` (Firebase Admin SDK implementation)
- Test: `backend/internal/platform/auth/auth_test.go`
- Modify: `backend/go.mod`, `backend/go.sum` (add the Firebase SDK)

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `type Identity struct { Issuer, Subject, Email string; EmailVerified bool }`
  - `type TokenVerifier interface { Verify(ctx context.Context, rawToken string) (Identity, error) }`
  - `type FakeVerifier struct { Identity Identity; Err error }` implementing `TokenVerifier` (returns its configured `Identity`/`Err`) — used by later tasks' tests.
  - `func NewFirebaseVerifier(ctx context.Context, projectID string) (*FirebaseVerifier, error)` and `(*FirebaseVerifier).Verify(...)`.
  - `var ErrInvalidToken = errors.New("invalid token")` — returned by `Verify` **only** for an invalid/expired token (the caller maps it to 401). Any other failure (e.g. public-key fetch / network) is returned wrapped, so the caller can treat it as 503 and log the cause.

- [ ] **Step 1: Write the failing test (types + fake)**

Create `backend/internal/platform/auth/auth_test.go`:
```go
package auth

import (
	"context"
	"errors"
	"testing"
)

func TestFakeVerifierReturnsIdentity(t *testing.T) {
	var v TokenVerifier = &FakeVerifier{Identity: Identity{Issuer: "iss", Subject: "sub", Email: "a@b.c", EmailVerified: true}}
	got, err := v.Verify(context.Background(), "any")
	if err != nil {
		t.Fatalf("Verify: %v", err)
	}
	if got.Issuer != "iss" || got.Subject != "sub" || !got.EmailVerified {
		t.Fatalf("identity = %+v", got)
	}
}

func TestFakeVerifierReturnsError(t *testing.T) {
	var v TokenVerifier = &FakeVerifier{Err: ErrInvalidToken}
	if _, err := v.Verify(context.Background(), "any"); !errors.Is(err, ErrInvalidToken) {
		t.Fatalf("err = %v, want ErrInvalidToken", err)
	}
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd backend && go test ./internal/platform/auth/ -run TestFakeVerifier -v`
Expected: FAIL (package/types undefined).

- [ ] **Step 3: Implement the boundary types and fake**

Create `backend/internal/platform/auth/auth.go`:
```go
// Package auth is the third-party authentication boundary: it verifies a client
// ID token and hands the rest of the app a provider-neutral Identity. Only this
// package imports the Firebase SDK; domain and service code never do.
package auth

import (
	"context"
	"errors"
)

// ErrInvalidToken is returned by Verify only for an invalid or expired token;
// the caller maps it to 401. Any other failure (infrastructure — e.g. a
// public-key fetch or a timeout) is returned wrapped so the caller can treat it
// as 503 and log the cause.
var ErrInvalidToken = errors.New("invalid token")

// Identity is a verified external identity. Issuer + Subject uniquely identify
// the external account; today Subject holds the Firebase UID.
type Identity struct {
	Issuer        string
	Subject       string
	Email         string
	EmailVerified bool
}

// TokenVerifier verifies a raw bearer token and returns the external Identity.
type TokenVerifier interface {
	Verify(ctx context.Context, rawToken string) (Identity, error)
}

// FakeVerifier is a test double: Verify returns Identity, or Err if set.
type FakeVerifier struct {
	Identity Identity
	Err      error
}

// Verify implements TokenVerifier.
func (f *FakeVerifier) Verify(ctx context.Context, rawToken string) (Identity, error) {
	if f.Err != nil {
		return Identity{}, f.Err
	}
	return f.Identity, nil
}
```

- [ ] **Step 4: Run to verify the fake test passes**

Run: `cd backend && go test ./internal/platform/auth/ -run TestFakeVerifier -v`
Expected: PASS.

- [ ] **Step 5: Add the Firebase SDK dependency (pinned)**

Pin an explicit version for reproducibility (v4.21.0 is the current stable per the Firebase Admin setup docs — bump deliberately, never float on `@latest`). Do **not** run `go mod tidy` here: no `.go` file imports the SDK until Step 6, so tidy would prune the just-added module. Just add it:
```bash
cd backend
go get firebase.google.com/go/v4@v4.21.0
```
`google.golang.org/api/option` comes transitively; both are recorded by the `go mod tidy` in Step 8 (after `firebase.go` imports them).

- [ ] **Step 6: Implement the Firebase verifier**

Create `backend/internal/platform/auth/firebase.go`:
```go
package auth

import (
	"context"
	"fmt"
	"time"

	firebase "firebase.google.com/go/v4"
	fbauth "firebase.google.com/go/v4/auth"
	"google.golang.org/api/option"
)

// defaultVerifyTimeout bounds a single verification, including the SDK's
// public-key fetch, so a hung fetch surfaces as a 503 instead of hanging the
// request.
const defaultVerifyTimeout = 5 * time.Second

// idTokenClient is the slice of the Firebase auth client this package needs;
// *fbauth.Client satisfies it, and tests substitute a fake.
type idTokenClient interface {
	VerifyIDToken(ctx context.Context, idToken string) (*fbauth.Token, error)
}

// FirebaseVerifier verifies Firebase ID tokens. Plain VerifyIDToken needs only
// the project ID and Google's public keys (fetched over a public endpoint), so
// the app is initialized without a service-account credential. A later phase
// that needs privileged calls (delete user / revoke tokens) swaps
// option.WithoutAuthentication() for a real credential.
type FirebaseVerifier struct {
	client  idTokenClient
	timeout time.Duration
}

// NewFirebaseVerifier builds a verifier for the given Firebase project.
func NewFirebaseVerifier(ctx context.Context, projectID string) (*FirebaseVerifier, error) {
	if projectID == "" {
		return nil, fmt.Errorf("firebase: empty project ID")
	}
	app, err := firebase.NewApp(ctx, &firebase.Config{ProjectID: projectID}, option.WithoutAuthentication())
	if err != nil {
		return nil, fmt.Errorf("firebase: new app: %w", err)
	}
	client, err := app.Auth(ctx)
	if err != nil {
		return nil, fmt.Errorf("firebase: auth client: %w", err)
	}
	return &FirebaseVerifier{client: client, timeout: defaultVerifyTimeout}, nil
}

// Verify checks the token's signature, aud (=project ID), iss, sub and expiry,
// and returns the external Identity. It bounds the whole call (incl. the SDK's
// public-key fetch) with its own timeout. An invalid/expired token returns
// ErrInvalidToken (the caller maps it to 401); any other failure — a public-key
// fetch, network error, or timeout — is wrapped and returned as-is so the caller
// can treat it as 503 and log the cause. It is NOT the user's fault.
func (v *FirebaseVerifier) Verify(ctx context.Context, rawToken string) (Identity, error) {
	ctx, cancel := context.WithTimeout(ctx, v.timeout)
	defer cancel()
	tok, err := v.client.VerifyIDToken(ctx, rawToken)
	if err != nil {
		if fbauth.IsIDTokenInvalid(err) || fbauth.IsIDTokenExpired(err) {
			return Identity{}, ErrInvalidToken
		}
		return Identity{}, fmt.Errorf("firebase verify id token: %w", err)
	}
	email, _ := tok.Claims["email"].(string)
	emailVerified, _ := tok.Claims["email_verified"].(bool)
	return Identity{
		Issuer:        tok.Issuer,
		Subject:       tok.Subject,
		Email:         email,
		EmailVerified: emailVerified,
	}, nil
}
```

- [ ] **Step 7: Add offline verifier tests (construction + timeout)**

Verifying a real token needs Firebase; assert the offline behavior — empty project ID rejected, interface satisfied, and (crucially) that a stuck key fetch **times out** to a non-`ErrInvalidToken` (503-mapped) error via the verifier's own deadline. Append to `auth_test.go` (add `"time"` and `fbauth "firebase.google.com/go/v4/auth"` to its imports):
```go
func TestNewFirebaseVerifierRejectsEmptyProject(t *testing.T) {
	if _, err := NewFirebaseVerifier(context.Background(), ""); err == nil {
		t.Fatal("expected error for empty project ID")
	}
}

func TestFirebaseVerifierImplementsInterface(t *testing.T) {
	var _ TokenVerifier = (*FirebaseVerifier)(nil)
}

// hangingClient blocks until the context deadline, simulating a stuck key fetch.
type hangingClient struct{}

func (hangingClient) VerifyIDToken(ctx context.Context, _ string) (*fbauth.Token, error) {
	<-ctx.Done()
	return nil, ctx.Err()
}

func TestFirebaseVerifierTimesOutToInfraError(t *testing.T) {
	v := &FirebaseVerifier{client: hangingClient{}, timeout: 10 * time.Millisecond}
	_, err := v.Verify(context.Background(), "tok")
	if err == nil || errors.Is(err, ErrInvalidToken) {
		t.Fatalf("a timed-out verification must be a non-invalid (503) error, got %v", err)
	}
}
```

- [ ] **Step 8: Tidy modules, run tests and vet**

Now that `firebase.go` imports the SDK, record the dependency graph, then test:
```bash
cd backend
go mod tidy   # firebase.go now imports the SDK, so tidy retains it
go test ./internal/platform/auth/ -v && go vet ./internal/platform/auth/
```
Expected: `go.mod`/`go.sum` list `firebase.google.com/go/v4 v4.21.0`; tests PASS; no vet errors.

- [ ] **Step 9: Commit**

```bash
cd backend
git add internal/platform/auth/ go.mod go.sum
git commit -m "feat(backend): add platform/auth TokenVerifier boundary with Firebase impl"
```

---

## Task 5: Authentication middleware in `platform/auth` (PR P2-2)

The middleware verifies the `Authorization: Bearer <token>` header and stores the `Identity` in the request context. It lives in `platform/auth` (cohesive with the verifier) and depends on `core/httpserver` for the error envelope (platform → core, allowed).

**Files:**
- Create: `backend/internal/platform/auth/middleware.go`
- Test: `backend/internal/platform/auth/middleware_test.go`

**Interfaces:**
- Consumes: `TokenVerifier` (Task 4); `httpserver.WriteError`, `httpserver.CodeUnauthenticated` (Task 3).
- Produces:
  - `func Middleware(v TokenVerifier, logger *slog.Logger) func(http.Handler) http.Handler` — missing/malformed header or invalid/expired token → 401 (`unauthenticated`); any other verifier failure (infra, e.g. public-key fetch) → 503 (`unavailable`) with the cause logged server-side; otherwise stores the `Identity` and calls next. A nil logger falls back to `slog.Default()`.
  - `func IdentityFrom(ctx context.Context) (Identity, bool)` — reads the stored identity.

- [ ] **Step 1: Write the failing test**

Create `backend/internal/platform/auth/middleware_test.go`:
```go
package auth

import (
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"
)

func discardLogger() *slog.Logger { return slog.New(slog.NewTextHandler(io.Discard, nil)) }

func protected(t *testing.T) http.Handler {
	t.Helper()
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id, ok := IdentityFrom(r.Context())
		if !ok {
			t.Fatal("handler reached without an identity in context")
		}
		_, _ = w.Write([]byte(id.Subject))
	})
}

func codeOf(rec *httptest.ResponseRecorder) string {
	var body struct {
		Error struct{ Code string } `json:"error"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &body)
	return body.Error.Code
}

func TestMiddlewareRejectsMissingHeader(t *testing.T) {
	h := Middleware(&FakeVerifier{}, discardLogger())(protected(t))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/x", nil))
	if rec.Code != http.StatusUnauthorized || codeOf(rec) != "unauthenticated" {
		t.Fatalf("status=%d code=%q, want 401 unauthenticated", rec.Code, codeOf(rec))
	}
}

func TestMiddlewareRejectsInvalidToken(t *testing.T) {
	h := Middleware(&FakeVerifier{Err: ErrInvalidToken}, discardLogger())(protected(t))
	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/x", nil)
	req.Header.Set("Authorization", "Bearer bad")
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusUnauthorized || codeOf(rec) != "unauthenticated" {
		t.Fatalf("status=%d code=%q, want 401 unauthenticated", rec.Code, codeOf(rec))
	}
}

func TestMiddlewareInfraErrorReturns503(t *testing.T) {
	// A non-token error (e.g. public-key fetch failure) is infrastructure, not
	// the caller's fault: 503, not 401.
	h := Middleware(&FakeVerifier{Err: errors.New("key fetch failed")}, discardLogger())(protected(t))
	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/x", nil)
	req.Header.Set("Authorization", "Bearer whatever")
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusServiceUnavailable || codeOf(rec) != "unavailable" {
		t.Fatalf("status=%d code=%q, want 503 unavailable", rec.Code, codeOf(rec))
	}
}

func TestMiddlewarePassesIdentity(t *testing.T) {
	h := Middleware(&FakeVerifier{Identity: Identity{Subject: "sub-1"}}, discardLogger())(protected(t))
	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/x", nil)
	req.Header.Set("Authorization", "Bearer good")
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK || rec.Body.String() != "sub-1" {
		t.Fatalf("status=%d body=%q", rec.Code, rec.Body.String())
	}
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd backend && go test ./internal/platform/auth/ -run TestMiddleware -v`
Expected: FAIL (`Middleware`, `IdentityFrom` undefined).

- [ ] **Step 3: Implement**

Create `backend/internal/platform/auth/middleware.go`:
```go
package auth

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"strings"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/httpserver"
)

type ctxKey int

const identityKey ctxKey = 0

// IdentityFrom returns the verified Identity stored by Middleware.
func IdentityFrom(ctx context.Context) (Identity, bool) {
	id, ok := ctx.Value(identityKey).(Identity)
	return id, ok
}

// Middleware verifies the bearer token and stores the Identity in the context.
// A missing/malformed header or an invalid/expired token returns 401; any other
// verifier failure (infrastructure, e.g. a public-key fetch) returns 503 with
// the cause logged server-side. A nil logger falls back to slog.Default().
func Middleware(v TokenVerifier, logger *slog.Logger) func(http.Handler) http.Handler {
	if logger == nil {
		logger = slog.Default()
	}
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			raw, ok := bearerToken(r)
			if !ok {
				httpserver.WriteError(w, r, http.StatusUnauthorized, httpserver.CodeUnauthenticated, "missing bearer token")
				return
			}
			id, err := v.Verify(r.Context(), raw)
			if err != nil {
				if errors.Is(err, ErrInvalidToken) {
					httpserver.WriteError(w, r, http.StatusUnauthorized, httpserver.CodeUnauthenticated, "invalid or expired token")
					return
				}
				logger.LogAttrs(r.Context(), slog.LevelError, "token_verify_failed",
					slog.String("request_id", httpserver.RequestIDFrom(r.Context())),
					slog.Any("error", err),
				)
				httpserver.WriteError(w, r, http.StatusServiceUnavailable, httpserver.CodeUnavailable, "authentication temporarily unavailable")
				return
			}
			ctx := context.WithValue(r.Context(), identityKey, id)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// bearerToken extracts a non-empty token from an "Authorization: Bearer <t>"
// header, case-insensitive on the scheme.
func bearerToken(r *http.Request) (string, bool) {
	h := r.Header.Get("Authorization")
	const prefix = "bearer "
	if len(h) <= len(prefix) || !strings.EqualFold(h[:len(prefix)], prefix) {
		return "", false
	}
	tok := strings.TrimSpace(h[len(prefix):])
	return tok, tok != ""
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd backend && go test ./internal/platform/auth/ -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd backend
git add internal/platform/auth/middleware.go internal/platform/auth/middleware_test.go
git commit -m "feat(backend): add Firebase auth middleware and IdentityFrom context accessor"
```

---

## Task 6: Identity feature — domain + store (PR P2-3)

**Files:**
- Create: `backend/internal/identity/domain.go`
- Create: `backend/internal/identity/store.go`
- Test: `backend/internal/identity/store_test.go` (integration — real Postgres)

**Interfaces:**
- Consumes: `core/database` (the `*sql.DB` handle); `testsupport.DB` for tests.
- Produces:
  - `type User struct { ID, Status string; CreatedAt, UpdatedAt time.Time }`
  - `var ErrNotFound = errors.New("identity not found")`
  - `type Store struct { ... }`; `func NewStore(db *sql.DB) *Store`
  - `func (s *Store) FindByIdentity(ctx, issuer, subject string) (User, error)` — `ErrNotFound` when absent.
  - `func (s *Store) CreateWithIdentity(ctx, issuer, subject string) (User, error)` — inserts `users` + `user_identities` in one tx; returns `ErrNotFound` (a "lost the race, go re-find" signal) on a `(issuer,subject)` unique violation.

- [ ] **Step 1: Write the failing integration test**

Create `backend/internal/identity/store_test.go`:
```go
package identity

import (
	"context"
	"errors"
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
)

func newStore(t *testing.T) *Store {
	t.Helper()
	db := testsupport.DB(t)
	if _, err := db.Exec("TRUNCATE public.users CASCADE"); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	return NewStore(db)
}

func TestFindByIdentityNotFound(t *testing.T) {
	s := newStore(t)
	if _, err := s.FindByIdentity(context.Background(), "iss", "missing"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("err = %v, want ErrNotFound", err)
	}
}

func TestCreateWithIdentityThenFind(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()

	created, err := s.CreateWithIdentity(ctx, "iss", "sub-1")
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if created.ID == "" || created.Status != "active" {
		t.Fatalf("created = %+v", created)
	}

	found, err := s.FindByIdentity(ctx, "iss", "sub-1")
	if err != nil {
		t.Fatalf("find: %v", err)
	}
	if found.ID != created.ID {
		t.Fatalf("find returned %s, want %s", found.ID, created.ID)
	}
}

func TestCreateWithIdentityDuplicateSignalsNotFound(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()
	if _, err := s.CreateWithIdentity(ctx, "iss", "sub-dup"); err != nil {
		t.Fatalf("first create: %v", err)
	}
	// Second create for the same (issuer, subject) hits the unique constraint
	// and reports ErrNotFound so the caller re-resolves.
	if _, err := s.CreateWithIdentity(ctx, "iss", "sub-dup"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("duplicate create err = %v, want ErrNotFound", err)
	}
	// The rolled-back second insert must leave NO orphan users row: the users
	// INSERT and the user_identities INSERT share one transaction.
	var n int
	if err := s.db.QueryRowContext(ctx, `SELECT count(*) FROM public.users`).Scan(&n); err != nil {
		t.Fatalf("count users: %v", err)
	}
	if n != 1 {
		t.Fatalf("users count = %d after duplicate; want 1 (no orphan)", n)
	}
}

func TestDeleteUserCascadesIdentities(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()
	u, err := s.CreateWithIdentity(ctx, "iss", "sub-fk")
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if _, err := s.db.ExecContext(ctx, `DELETE FROM public.users WHERE id = $1`, u.ID); err != nil {
		t.Fatalf("delete user: %v", err)
	}
	var n int
	if err := s.db.QueryRowContext(ctx, `SELECT count(*) FROM public.user_identities WHERE user_id = $1`, u.ID).Scan(&n); err != nil {
		t.Fatalf("count identities: %v", err)
	}
	if n != 0 {
		t.Fatalf("identities remaining = %d after user delete; want 0 (FK cascade)", n)
	}
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd backend && make test` (or, with a running throwaway DB and `DATABASE_URL` set, `go test ./internal/identity/ -v`).
Expected: FAIL (package `identity`, `Store`, `User` undefined).

- [ ] **Step 3: Implement the domain type**

Create `backend/internal/identity/domain.go`:
```go
// Package identity resolves a verified external identity to the internal user
// anchor. PepperCheck owns users.id (a UUID); user_identities maps
// (issuer, subject) to it. No provider UID is ever a domain key.
package identity

import "time"

// User is the internal user anchor. Domain FKs reference User.ID, never a
// provider UID.
type User struct {
	ID        string
	Status    string
	CreatedAt time.Time
	UpdatedAt time.Time
}
```

- [ ] **Step 4: Implement the store**

Create `backend/internal/identity/store.go`:
```go
package identity

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5/pgconn"
)

// ErrNotFound means no user maps to the given (issuer, subject). CreateWithIdentity
// also returns it when a concurrent insert won the unique constraint, signalling
// the caller to re-resolve.
var ErrNotFound = errors.New("identity not found")

// Store issues the SQL over users / user_identities.
type Store struct {
	db *sql.DB
}

// NewStore builds a Store over an open database handle.
func NewStore(db *sql.DB) *Store { return &Store{db: db} }

// FindByIdentity returns the internal user for a verified (issuer, subject).
func (s *Store) FindByIdentity(ctx context.Context, issuer, subject string) (User, error) {
	var u User
	err := s.db.QueryRowContext(ctx, `
		SELECT u.id, u.status, u.created_at, u.updated_at
		FROM public.users u
		JOIN public.user_identities i ON i.user_id = u.id
		WHERE i.issuer = $1 AND i.subject = $2`,
		issuer, subject,
	).Scan(&u.ID, &u.Status, &u.CreatedAt, &u.UpdatedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return User{}, ErrNotFound
	}
	if err != nil {
		return User{}, fmt.Errorf("find by identity: %w", err)
	}
	return u, nil
}

// CreateWithIdentity inserts a users row and its user_identities row in one
// transaction. A (issuer, subject) unique violation (a concurrent first sighting
// won) returns ErrNotFound so the caller re-resolves.
func (s *Store) CreateWithIdentity(ctx context.Context, issuer, subject string) (User, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return User{}, fmt.Errorf("begin: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	var u User
	if err := tx.QueryRowContext(ctx, `
		INSERT INTO public.users DEFAULT VALUES
		RETURNING id, status, created_at, updated_at`,
	).Scan(&u.ID, &u.Status, &u.CreatedAt, &u.UpdatedAt); err != nil {
		return User{}, fmt.Errorf("insert user: %w", err)
	}

	if _, err := tx.ExecContext(ctx, `
		INSERT INTO public.user_identities (user_id, issuer, subject)
		VALUES ($1, $2, $3)`,
		u.ID, issuer, subject,
	); err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" { // unique_violation
			return User{}, ErrNotFound
		}
		return User{}, fmt.Errorf("insert identity: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return User{}, fmt.Errorf("commit: %w", err)
	}
	return u, nil
}
```

- [ ] **Step 5: Run to verify it passes**

Run: `cd backend && make test`
Expected: the `identity` integration tests PASS (and no regressions).

- [ ] **Step 6: Add a schema-constraint test in db/tests**

`backend/db/tests/` holds transactional assert-SQL files (see `test_role_separation.sql`), and **CI already runs them** — `.github/workflows/ci-backend.yml`'s "Role-model SQL test" step runs `psql -f db/tests/test_role_separation.sql`. Add a constraint test in that same style. Create `backend/db/tests/test_identity_constraints.sql`:
```sql
-- Verifies the identity schema constraints in isolation: user_identities is
-- unique on (issuer, subject), and deleting a user cascades to its identities.
-- Transactional and self-cleaning (matches db/tests/test_role_separation.sql).
BEGIN;

WITH u AS (INSERT INTO public.users DEFAULT VALUES RETURNING id)
INSERT INTO public.user_identities (user_id, issuer, subject)
SELECT id, 'iss', 'sub-1' FROM u;

DO $$
BEGIN
  BEGIN
    INSERT INTO public.user_identities (user_id, issuer, subject)
    SELECT id, 'iss', 'sub-1' FROM public.users LIMIT 1;
    RAISE EXCEPTION 'duplicate (issuer, subject) should violate the unique constraint';
  EXCEPTION
    WHEN unique_violation THEN NULL; -- expected
  END;
END $$;

DELETE FROM public.users;
DO $$
BEGIN
  ASSERT (SELECT count(*) FROM public.user_identities) = 0,
    'deleting a user must cascade-delete its user_identities';
END $$;

ROLLBACK;
```

- [ ] **Step 7: Generalize the CI runner to all db/tests/\*.sql**

So future assert-SQL files run automatically, replace the single-file "Role-model SQL test" step in `.github/workflows/ci-backend.yml` with a loop over the directory (same connection string + `ON_ERROR_STOP=1`):
```yaml
      - name: Run db/tests assert-SQL
        run: |
          set -euo pipefail
          for f in db/tests/*.sql; do
            echo "== $f =="
            psql "postgres://postgres:postgres@localhost:5432/peppercheck?sslmode=disable" -v ON_ERROR_STOP=1 -f "$f"
          done
```
Confirm locally against the running Compose Postgres before committing:
```bash
cd backend
docker compose cp db/tests/test_identity_constraints.sql postgres:/tmp/t.sql
docker compose exec -T postgres psql -U postgres -d peppercheck -v ON_ERROR_STOP=1 -f /tmp/t.sql
```
Expected: no error (the DO blocks pass; the transaction rolls back).

- [ ] **Step 8: Commit**

```bash
cd backend
git add internal/identity/domain.go internal/identity/store.go internal/identity/store_test.go db/tests/test_identity_constraints.sql ../.github/workflows/ci-backend.yml
git diff --cached --stat
git commit -m "feat(backend): add identity domain and store (users/user_identities)"
```

---

## Task 7: Identity feature — service (PR P2-3)

**Files:**
- Create: `backend/internal/identity/service.go`
- Test: `backend/internal/identity/service_test.go` (unit — fake store)

**Interfaces:**
- Consumes: the store methods (Task 6).
- Produces:
  - `type store interface { FindByIdentity(ctx, issuer, subject string) (User, error); CreateWithIdentity(ctx, issuer, subject string) (User, error) }` (unexported, satisfied by `*Store`; lets the service test with a fake).
  - `type Service struct { ... }`; `func NewService(s store) *Service`
  - `func (s *Service) ResolveOrProvision(ctx, issuer, subject string) (User, error)` — find; if `ErrNotFound`, create; if create also reports `ErrNotFound` (lost the race), find once more.

- [ ] **Step 1: Write the failing test**

Create `backend/internal/identity/service_test.go`:
```go
package identity

import (
	"context"
	"testing"
)

// fakeStore scripts FindByIdentity/CreateWithIdentity results per call.
type fakeStore struct {
	findResults   []result
	createResults []result
	finds         int
	creates       int
}

type result struct {
	u   User
	err error
}

func (f *fakeStore) FindByIdentity(_ context.Context, _, _ string) (User, error) {
	r := f.findResults[f.finds]
	f.finds++
	return r.u, r.err
}

func (f *fakeStore) CreateWithIdentity(_ context.Context, _, _ string) (User, error) {
	r := f.createResults[f.creates]
	f.creates++
	return r.u, r.err
}

func TestResolveExistingUser(t *testing.T) {
	f := &fakeStore{findResults: []result{{u: User{ID: "u1"}}}}
	got, err := NewService(f).ResolveOrProvision(context.Background(), "iss", "sub")
	if err != nil || got.ID != "u1" {
		t.Fatalf("got %+v err %v", got, err)
	}
	if f.creates != 0 {
		t.Fatalf("should not create when user exists")
	}
}

func TestResolveProvisionsNewUser(t *testing.T) {
	f := &fakeStore{
		findResults:   []result{{err: ErrNotFound}},
		createResults: []result{{u: User{ID: "u2"}}},
	}
	got, err := NewService(f).ResolveOrProvision(context.Background(), "iss", "sub")
	if err != nil || got.ID != "u2" {
		t.Fatalf("got %+v err %v", got, err)
	}
}

func TestResolveRefindsWhenCreateLosesRace(t *testing.T) {
	f := &fakeStore{
		findResults:   []result{{err: ErrNotFound}, {u: User{ID: "u3"}}}, // 1st: absent, 2nd: winner's row
		createResults: []result{{err: ErrNotFound}},                      // create lost the unique race
	}
	got, err := NewService(f).ResolveOrProvision(context.Background(), "iss", "sub")
	if err != nil || got.ID != "u3" {
		t.Fatalf("got %+v err %v", got, err)
	}
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd backend && go test ./internal/identity/ -run TestResolve -v`
Expected: FAIL (`NewService`, `Service`, `store` undefined).

- [ ] **Step 3: Implement**

Create `backend/internal/identity/service.go`:
```go
package identity

import (
	"context"
	"errors"
	"fmt"
)

// store is the persistence the service needs; *Store satisfies it.
type store interface {
	FindByIdentity(ctx context.Context, issuer, subject string) (User, error)
	CreateWithIdentity(ctx context.Context, issuer, subject string) (User, error)
}

// Service owns the resolve-or-provision use case for identities.
type Service struct {
	store store
}

// NewService builds a Service over a store.
func NewService(s store) *Service { return &Service{store: s} }

// ResolveOrProvision maps a verified (issuer, subject) to the internal user,
// creating it on first sighting. A concurrent first sighting is resolved by
// re-finding after the losing insert reports ErrNotFound.
func (s *Service) ResolveOrProvision(ctx context.Context, issuer, subject string) (User, error) {
	u, err := s.store.FindByIdentity(ctx, issuer, subject)
	if err == nil {
		return u, nil
	}
	if !errors.Is(err, ErrNotFound) {
		return User{}, err
	}

	u, err = s.store.CreateWithIdentity(ctx, issuer, subject)
	if err == nil {
		return u, nil
	}
	if !errors.Is(err, ErrNotFound) {
		return User{}, err
	}

	// Lost the race: the row exists now — re-find it.
	u, err = s.store.FindByIdentity(ctx, issuer, subject)
	if err != nil {
		return User{}, fmt.Errorf("resolve after create race: %w", err)
	}
	return u, nil
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd backend && go test ./internal/identity/ -run TestResolve -v`
Expected: PASS.

- [ ] **Step 5: Add a real concurrency test (integration)**

The fake-store race test proves the re-find logic; this proves it against real Postgres under actual concurrency (exactly one user for N racing first-sightings). Append to `backend/internal/identity/service_test.go` (add imports `"sync"` and the `testsupport` package):
```go
func TestResolveOrProvisionConcurrentFirstSighting(t *testing.T) {
	db := testsupport.DB(t)
	if _, err := db.Exec("TRUNCATE public.users CASCADE"); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	svc := NewService(NewStore(db))

	const n = 8
	var wg sync.WaitGroup
	ids := make([]string, n)
	errs := make([]error, n)
	for i := 0; i < n; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			u, err := svc.ResolveOrProvision(context.Background(), "iss", "race")
			ids[i], errs[i] = u.ID, err
		}(i)
	}
	wg.Wait()

	for i, err := range errs {
		if err != nil {
			t.Fatalf("goroutine %d: %v", i, err)
		}
		if ids[i] == "" || ids[i] != ids[0] {
			t.Fatalf("goroutine %d resolved %q, want the single shared id %q", i, ids[i], ids[0])
		}
	}
	var count int
	if err := db.QueryRow("SELECT count(*) FROM public.users").Scan(&count); err != nil {
		t.Fatalf("count: %v", err)
	}
	if count != 1 {
		t.Fatalf("users count = %d after concurrent first sighting; want exactly 1", count)
	}
}
```
(The `TestResolve*` unit tests use only the fake store, so `service_test.go` will now hold both unit and integration tests; the integration one skips when `DATABASE_URL` is unset.)

- [ ] **Step 6: Run and commit**

Run: `cd backend && make test` (Expected: PASS, including the concurrency test under `-race`), then:
```bash
cd backend
git add internal/identity/service.go internal/identity/service_test.go
git commit -m "feat(backend): add identity service ResolveOrProvision"
```

---

## Task 8: Identity handler, wiring, and API integration (PR P2-3)

Serve `GET /api/v1/me`, mount it behind the auth middleware, wire the verifier + store + service in `main.go`, and prove the whole path with an HTTP integration test (fake verifier + real Postgres).

**Files:**
- Create: `backend/internal/identity/handler.go`
- Modify: `backend/internal/api/api.go` (route + deps)
- Modify: `backend/cmd/peppercheck/main.go` (construct + inject)
- Test: `backend/internal/api/me_test.go` (integration)

**Interfaces:**
- Consumes: `Service.ResolveOrProvision` (Task 7); `auth.IdentityFrom`, `auth.Middleware` (Tasks 4/5); `httpserver.WriteError` (Task 3).
- Produces:
  - `type Handler struct { svc *Service }`; `func NewHandler(svc *Service) *Handler`; `func (h *Handler) Me(w http.ResponseWriter, r *http.Request)`.
  - `api.Deps struct { Ready func(context.Context) error; Verifier auth.TokenVerifier; Identity *identity.Handler }` and `api.Run(ctx, cfg, logger, deps Deps)`.

- [ ] **Step 1: Write the handler's failing test (via the API integration test)**

Create `backend/internal/api/me_test.go`:
```go
package api

import (
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/cloveclovedev/peppercheck/backend/internal/identity"
	"github.com/cloveclovedev/peppercheck/backend/internal/platform/auth"
	"github.com/cloveclovedev/peppercheck/backend/internal/testsupport"
)

func meHandler(t *testing.T, v auth.TokenVerifier) http.Handler {
	t.Helper()
	db := testsupport.DB(t)
	if _, err := db.Exec("TRUNCATE public.users CASCADE"); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	svc := identity.NewService(identity.NewStore(db))
	// Use the SAME chain builder as Run() so the tests exercise the real
	// middleware stack; RequestID seeds the id the error envelope carries.
	return rootHandler(
		Deps{Verifier: v, Identity: identity.NewHandler(svc, nil)},
		slog.New(slog.NewTextHandler(io.Discard, nil)),
	)
}

// envelope decodes {"error":{code,message,requestId}} from a response body.
func envelope(t *testing.T, rec *httptest.ResponseRecorder) (code, requestID string) {
	t.Helper()
	var body struct {
		Error struct{ Code, Message, RequestID string } `json:"error"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("unmarshal envelope: %v; body=%s", err, rec.Body.String())
	}
	return body.Error.Code, body.Error.RequestID
}

func TestMeRejectsMissingToken(t *testing.T) {
	h := meHandler(t, &auth.FakeVerifier{})
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/api/v1/me", nil))
	code, reqID := envelope(t, rec)
	if rec.Code != http.StatusUnauthorized || code != "unauthenticated" || reqID == "" {
		t.Fatalf("status=%d code=%q requestId=%q, want 401 unauthenticated with a request id", rec.Code, code, reqID)
	}
}

func TestMeRejectsInvalidToken(t *testing.T) {
	h := meHandler(t, &auth.FakeVerifier{Err: auth.ErrInvalidToken})
	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/api/v1/me", nil)
	req.Header.Set("Authorization", "Bearer bad")
	h.ServeHTTP(rec, req)
	code, _ := envelope(t, rec)
	if rec.Code != http.StatusUnauthorized || code != "unauthenticated" {
		t.Fatalf("status=%d code=%q, want 401 unauthenticated", rec.Code, code)
	}
}

func TestMeInfraErrorReturns503(t *testing.T) {
	// A non-token verifier failure (e.g. public-key fetch) is infrastructure,
	// not the caller's fault: 503 unavailable, with a request id.
	h := meHandler(t, &auth.FakeVerifier{Err: errors.New("key fetch failed")})
	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/api/v1/me", nil)
	req.Header.Set("Authorization", "Bearer whatever")
	h.ServeHTTP(rec, req)
	code, reqID := envelope(t, rec)
	if rec.Code != http.StatusServiceUnavailable || code != "unavailable" || reqID == "" {
		t.Fatalf("status=%d code=%q requestId=%q, want 503 unavailable with a request id", rec.Code, code, reqID)
	}
}

func TestMeProvisionsAndReturnsSameUser(t *testing.T) {
	h := meHandler(t, &auth.FakeVerifier{Identity: auth.Identity{Issuer: "iss", Subject: "sub-A"}})

	call := func() string {
		rec := httptest.NewRecorder()
		req := httptest.NewRequest("GET", "/api/v1/me", nil)
		req.Header.Set("Authorization", "Bearer t")
		h.ServeHTTP(rec, req)
		if rec.Code != http.StatusOK {
			t.Fatalf("status = %d, want 200; body=%s", rec.Code, rec.Body.String())
		}
		var body struct {
			User struct{ ID, Status string } `json:"user"`
		}
		if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
			t.Fatalf("unmarshal: %v", err)
		}
		if body.User.ID == "" || body.User.Status != "active" {
			t.Fatalf("user = %+v", body.User)
		}
		return body.User.ID
	}

	first := call()
	second := call() // same identity -> same internal user, no duplicate
	if first != second {
		t.Fatalf("me returned different ids for the same identity: %s != %s", first, second)
	}
}

func TestMeIsolatesUsers(t *testing.T) {
	db := testsupport.DB(t)
	if _, err := db.Exec("TRUNCATE public.users CASCADE"); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	svc := identity.NewService(identity.NewStore(db))

	me := func(subject string) string {
		h := buildHandler(Deps{
			Verifier: &auth.FakeVerifier{Identity: auth.Identity{Issuer: "iss", Subject: subject}},
			Identity: identity.NewHandler(svc, nil),
		})
		rec := httptest.NewRecorder()
		req := httptest.NewRequest("GET", "/api/v1/me", nil)
		req.Header.Set("Authorization", "Bearer t")
		h.ServeHTTP(rec, req)
		var body struct {
			User struct{ ID string } `json:"user"`
		}
		_ = json.Unmarshal(rec.Body.Bytes(), &body)
		return body.User.ID
	}

	if a, b := me("sub-A"), me("sub-B"); a == b || a == "" || b == "" {
		t.Fatalf("distinct identities must resolve to distinct users: a=%q b=%q", a, b)
	}
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd backend && make test` (integration). Expected: FAIL to compile (`Deps`, `identity.NewHandler` undefined).

- [ ] **Step 3: Implement the handler**

Create `backend/internal/identity/handler.go`:
```go
package identity

import (
	"encoding/json"
	"log/slog"
	"net/http"

	"github.com/cloveclovedev/peppercheck/backend/internal/core/httpserver"
	"github.com/cloveclovedev/peppercheck/backend/internal/platform/auth"
)

// Handler serves the identity HTTP surface.
type Handler struct {
	svc    *Service
	logger *slog.Logger
}

// NewHandler builds a Handler over the identity service. A nil logger falls back
// to slog.Default().
func NewHandler(svc *Service, logger *slog.Logger) *Handler {
	if logger == nil {
		logger = slog.Default()
	}
	return &Handler{svc: svc, logger: logger}
}

type meResponse struct {
	User     meUser     `json:"user"`
	Identity meIdentity `json:"identity"`
}

type meUser struct {
	ID        string `json:"id"`
	Status    string `json:"status"`
	CreatedAt string `json:"createdAt"`
}

type meIdentity struct {
	Issuer string `json:"issuer"`
}

// Me resolves the verified identity to the internal user, provisioning on first
// sighting, and returns it. It assumes the auth middleware ran.
func (h *Handler) Me(w http.ResponseWriter, r *http.Request) {
	id, ok := auth.IdentityFrom(r.Context())
	if !ok {
		httpserver.WriteError(w, r, http.StatusUnauthorized, httpserver.CodeUnauthenticated, "missing identity")
		return
	}
	u, err := h.svc.ResolveOrProvision(r.Context(), id.Issuer, id.Subject)
	if err != nil {
		h.logger.LogAttrs(r.Context(), slog.LevelError, "me_resolve_failed",
			slog.String("request_id", httpserver.RequestIDFrom(r.Context())),
			slog.Any("error", err),
		)
		httpserver.WriteError(w, r, http.StatusInternalServerError, httpserver.CodeInternal, "could not resolve user")
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(meResponse{
		User: meUser{
			ID:        u.ID,
			Status:    u.Status,
			CreatedAt: u.CreatedAt.UTC().Format("2006-01-02T15:04:05Z07:00"),
		},
		Identity: meIdentity{Issuer: id.Issuer},
	})
}
```

- [ ] **Step 4: Wire the route and deps in `api.go`**

Replace `buildHandler` and `Run` in `backend/internal/api/api.go` so routes receive dependencies. The new `buildHandler` mounts `/api/v1/me` behind the auth middleware; health routes stay unauthenticated:
```go
// Deps are the runtime dependencies the api handler wires into routes.
type Deps struct {
	Ready    func(context.Context) error
	Verifier auth.TokenVerifier
	Identity *identity.Handler
	Logger   *slog.Logger // used by the auth middleware; Run injects the run logger when nil
}

func buildHandler(deps Deps) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /livez", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})
	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, r *http.Request) {
		if deps.Ready != nil {
			ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
			defer cancel()
			if err := deps.Ready(ctx); err != nil {
				w.WriteHeader(http.StatusServiceUnavailable)
				_, _ = w.Write([]byte("not ready"))
				return
			}
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ready"))
	})

	if deps.Identity != nil && deps.Verifier != nil {
		authed := auth.Middleware(deps.Verifier, deps.Logger)
		mux.Handle("GET /api/v1/me", authed(http.HandlerFunc(deps.Identity.Me)))
	}
	return mux
}

// rootHandler wraps the route mux in the full middleware chain. Run and the API
// integration tests both call it, so the tests exercise the exact chain
// production runs (RequestID → AccessLog → Recover), not a subset.
func rootHandler(deps Deps, logger *slog.Logger) http.Handler {
	if deps.Logger == nil {
		deps.Logger = logger
	}
	return httpserver.Chain(buildHandler(deps),
		httpserver.RequestID,
		httpserver.AccessLog(logger),
		httpserver.Recover(logger),
	)
}

func Run(ctx context.Context, cfg config.Config, logger *slog.Logger, deps Deps) error {
	srv := httpserver.New(cfg.Port, rootHandler(deps, logger))
	return httpserver.Run(ctx, logger, srv, time.Duration(cfg.ShutdownTimeout)*time.Second)
}
```
Update the imports in `api.go` to add:
```go
	"github.com/cloveclovedev/peppercheck/backend/internal/identity"
	"github.com/cloveclovedev/peppercheck/backend/internal/platform/auth"
```
Update the existing `api_test.go` calls `buildHandler(nil)` / `buildHandler(func...)` to the new signature: `buildHandler(Deps{})` and `buildHandler(Deps{Ready: func(context.Context) error { return errors.New("down") }})` respectively.

- [ ] **Step 5: Wire construction in `main.go`**

In `backend/cmd/peppercheck/main.go`, in the `case "api":` block, after the DB connect, construct the verifier, store, service, handler and pass `api.Deps`:
```go
	case "api":
		db, err := database.Connect(ctx, cfg.DatabaseURL)
		if err != nil {
			logger.Error("database connect failed", "error", err)
			os.Exit(1)
		}
		defer db.Close()

		verifier, err := auth.NewFirebaseVerifier(ctx, cfg.FirebaseProjectID)
		if err != nil {
			logger.Error("firebase verifier init failed", "error", err)
			os.Exit(1)
		}
		idHandler := identity.NewHandler(identity.NewService(identity.NewStore(db)), logger)

		if err := api.Run(ctx, cfg, logger, api.Deps{
			Ready:    db.PingContext,
			Verifier: verifier,
			Identity: idHandler,
		}); err != nil {
			logger.Error("api exited with error", "error", err)
			os.Exit(1)
		}
```
Add imports to `main.go`:
```go
	"github.com/cloveclovedev/peppercheck/backend/internal/identity"
	"github.com/cloveclovedev/peppercheck/backend/internal/platform/auth"
```

- [ ] **Step 6: Run the full suite**

Run: `cd backend && make test`
Expected: PASS — `me_test.go` (missing-token 401, provision-then-same-user, isolation), plus all prior tests. `go vet ./...` clean.

- [ ] **Step 7: Manual smoke (optional, documents the path)**

The api is not published to the host (only Caddy binds :80/:443, matching prod), so smoke-test **through Caddy** on `:80`. With the stack up (`make up`) and a real `FIREBASE_PROJECT_ID`, a valid Firebase ID token returns the internal user; without a token it 401s:
```bash
curl -s localhost/api/v1/me | jq .            # -> {"error":{"code":"unauthenticated",...}}
curl -s -H "Authorization: Bearer <firebase-id-token>" localhost/api/v1/me | jq .
```

- [ ] **Step 8: Commit**

```bash
cd backend
git add internal/identity/handler.go internal/api/api.go internal/api/api_test.go internal/api/me_test.go cmd/peppercheck/main.go
git commit -m "feat(backend): serve GET /api/v1/me with Firebase auth and identity resolution"
```

---

## Self-Review

**Spec coverage (backend scope of the Phase 2 spec §5, §8, §9):**
- §4 naming convention / §5.1 reorg → Task 1. ✅
- §5.5 config (FIREBASE_PROJECT_ID) + single-source port (API_PORT across config/compose/Caddy) → Task 2. ✅
- §5.3 error envelope + panic path (Recover → envelope) → Task 3. ✅
- §5.2 TokenVerifier boundary (Firebase + fake), pinned SDK version → Task 4. ✅
- §5.3 auth middleware with 401 (invalid/expired) vs 503 (infra) split + server-side logging → Task 5. ✅
- §5.4 identity store/service/handler, ResolveOrProvision, `/api/v1/me` → Tasks 6–8. ✅
- §8 Go unit (service resolve/provision/race with fake store) → Task 7; Go API integration (missing token, **invalid token**, provision-then-same-user, user isolation) → Task 8; **real concurrent first-sighting** (N goroutines → exactly one user) → Task 7; **no-orphan-user** + **FK cascade** assertions → Task 6. ✅
- §9 provisioning atomicity + concurrent first-sighting dedup → Task 6 (store tx + unique + orphan assertion) & Task 7 (re-find + concurrency test). ✅

**Schema-constraint testing (finding 5):** `db/tests/` assert-SQL **is** run in CI today (`ci-backend.yml` runs `test_role_separation.sql`). Task 6/7 add `test_identity_constraints.sql` (UNIQUE + FK cascade) and generalize the CI step to a `db/tests/*.sql` loop so it and future files run automatically. No pgTAP is introduced — the strategy's "pgTAP" wording is aspirational; the spec §8 and PR table now say "assert-SQL constraint tests". The Go store integration tests remain the primary CI coverage. **Error-contract coverage:** the API integration tests assert the full envelope (`code` + non-empty `requestId`) for `401 unauthenticated` and `503 unavailable`, through the real RequestID chain (Task 8).

**Deferred (correctly out of this backend plan):** expired-token client refresh behavior (Flutter), username/profile provisioning (Phase 3), the Flutter client boundary (P2-4/5/6, separate plan).

**Placeholder scan:** none — every code step has complete code; every run step has an exact command + expected result.

**Type consistency:** `Store.FindByIdentity`/`CreateWithIdentity` (Task 6) match the `store` interface and `Service` calls (Task 7); `identity.NewService`/`NewStore`/`NewHandler`, `Handler.Me`, `api.Deps{Ready,Verifier,Identity,Logger}`, `auth.TokenVerifier`/`FakeVerifier`/`Middleware(v, logger)`/`IdentityFrom`/`ErrInvalidToken`, `httpserver.WriteError`/`CodeUnauthenticated`/`CodeUnavailable`/`CodeInternal` are used consistently across tasks.
