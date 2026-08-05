# Local Object Storage — Garage as the Zero-Flag Local + CI Backend

**Date:** 2026-08-05
**Issues:** #523 (this feature), #522 (parent — OSS local dev profile), #483 (dummy R2 config doesn't fail closed), #477 (Supabase → Go API + VPS refactor; Phase 4b evidence + private R2)
**Status:** Approved

## Context

Object storage in the Go backend goes through `internal/platform/r2` — a thin,
S3-compatible adapter over Cloudflare R2 (aws-sdk-go-v2, path-style). Phase 3a
uses it for avatar uploads (presigned PUT + finalize Head + inline Delete).
Phase 4b (designed ahead, uncommitted) extends it with `PresignGet` + `List`
for private evidence downloads and retention sweeps, and adds a **separate
private bucket** alongside the existing public avatar bucket.

Today the local dev stack points `platform/r2` at real Cloudflare R2 dev
credentials, or at non-working dummy values. The dummy path is broken rather
than functional (#483: `r2.New()` only rejects *empty* fields, so shipped
placeholders produce a non-nil uploader that signs presigned URLs against a
nonexistent account — `request-upload-url` returns 200 with an unreachable URL
instead of the documented 503). This blocks the goal, tracked under parent
#522, of running the full stack with **zero external accounts**.

### The key observation

`platform/r2` is almost entirely provider-neutral. Decomposing it:

| Surface | Nature | Provider dependency |
|---|---|---|
| presigned PUT (upload) | SigV4, `UsePathStyle` | neutral (endpoint + creds only) |
| presigned GET (private DL, 4b) | local HMAC, no R2 round-trip | neutral |
| Head / Delete / List | standard S3 | neutral |
| CORS (browser presigned) | `PutBucketCors` | neutral |
| **public read URL (avatar)** | `https://cdn.peppercheck.dev/<key>` — Cloudflare custom domain CDN | **the only Cloudflare-specific piece** |

Everything except public-read URL composition is a generic S3 contract that any
S3-compatible server can satisfy. [Garage](https://garagehq.deuxfleurs.fr) is
S3-compatible with verified support for SigV4 presigned PUT/GET, `HeadObject`,
`DeleteObject`, `ListObjectsV2`, `Get/PutBucketCors`, and path-style addressing
(website serving is only partially implemented — index/error doc + no redirects
— which does not affect serving an object by exact key).

## Goals

- A clean `git clone` runs avatar (and, post-4b, evidence) upload/download
  end-to-end **with zero external accounts and zero flags**.
- CI exercises the object-storage contract (presign round-trip, Head/Delete/
  List, CORS) against a **local** backend, never a real shared bucket — a hard
  requirement for Phase 4b private evidence (retention sweeps, object purge).
- Fix #483: the default local path actually works instead of failing late.
- Keep the production R2 code path unchanged and swappable via config alone.

## Non-goals

- Reproducing Cloudflare-specific behavior locally (custom-domain CDN, cache,
  public-access toggles, R2's exact CORS/error semantics). These are verified
  against real R2 as an operator opt-in before shipping.
- Auth and push local backends — separate legs of #522 (#524 Firebase Auth
  Emulator, #525 FCM stub).
- Changing the two-sweep design or evidence lifecycle from Phase 4b.

## Decision

### 1. Two-class media model (durable principle)

Classify every media type into exactly one class; the class fixes the bucket
and the URL model. New media picks a class first.

| Class | Examples | Bucket | URL model | Criterion |
|---|---|---|---|---|
| **public** | avatars, future public images | public bucket + public domain | **stable, anonymous, cacheable URL** (never presigned) | "anyone may view it" |
| **private** | evidence, future sensitive media | private bucket | **short-lived presigned GET** (after authz, TTL 900s) | "requires authorization / limited to owner + related parties" |

Avatars stay public because they are shown in bulk (profile lists, and future
rankings / referee pickers). Presigning them would defeat CDN/browser/image
caching (URL churns every TTL) and cost one signature per image per list — so
public media must resolve to a durable URL, and `PublicURL(key)` stays a pure
string composition with no S3 client call.

### 2. `core/objectstore` promotion

Promote the provider-neutral S3 client out of `platform/r2` into
`core/objectstore` (the neutrality test: swapping providers changes only config
— endpoint, creds, bucket — so it belongs in `core`; `core/objectstore` is
named as a `core` example in the engineering policy). The only piece that stays
provider-specific is public-domain URL composition. Phase 4b's `PresignGet` +
`List` land on this new home rather than on `platform/r2`.

### 3. Internal / external endpoint seam

Presigned URLs sign the host, so they must be signed with the host the client
(Flutter emulator / browser) actually reaches — which locally differs from the
host the API container uses. Introduce two endpoints:

- **internal** — server-side Head/Delete/List (`http://garage:3900` locally)
- **external** — presigned PUT/GET (emulator-reachable, e.g. Android
  `http://10.0.2.2:3900`, iOS sim `http://localhost:3900`)

In production both collapse to the single R2 endpoint. This seam is the one
genuinely new design element; it reuses the **same host mapping the Flutter dev
app already uses to reach the local Go API**, so it introduces no new
per-platform axis.

### 4. Garage is the default; real R2 is operator opt-in

The local Compose stack ships a Garage service plus a bucket/key/CORS bootstrap
as the **default** backend (zero flags). Real R2 is an operator opt-in override
(mirrors the BWS secret-injection opt-in default, #480/#482). CI uses Garage
with internal == external (no emulator, no host split).

Local reproduction per class:

- **public bucket (avatar)** — served anonymously via Garage's web port,
  yielding a stable URL that matches prod's CDN model. No presigning of public
  media, locally or in prod. See the routing note below — this is more than
  repointing `R2_PUBLIC_DOMAIN`.
- **private bucket (evidence)** — presigned GET via the S3 API port.

#### Local public-read routing (Garage web port)

Reproducing anonymous public avatar reads locally is **not** as simple as
pointing `R2_PUBLIC_DOMAIN` at `garage:3902`. Three facts collide:

1. Garage's web endpoint selects the bucket from the HTTP **`Host` header** and
   serves over **http**, on a **separate port** from the S3 API.
2. `PublicURL` composes `https://<R2_PUBLIC_DOMAIN>/<key>` from a
   **bare-hostname, no-scheme** config (the `R2_PUBLIC_DOMAIN`-no-scheme
   gotcha from #503) — it hardcodes `https` and cannot express http or a
   custom port cleanly.
3. The Flutter dev app reaches local containers as **`10.0.2.2` (Android)** vs
   **`127.0.0.1` (iOS)**.

Naively repointing `R2_PUBLIC_DOMAIN` therefore yields a stable URL the emulator
cannot actually fetch. Resolve it by **fronting Garage's web port with the
stack's existing Caddy reverse proxy** (the Compose stack already runs Caddy):
Caddy owns the `Host`-header → public-bucket routing and exposes one stable
public host that the emulator reaches through the **same host mapping already
used for the Go API** (`10.0.2.2` / `127.0.0.1`), so no `Host`-header handling
or per-platform axis leaks into app config. Because local serving is http on a
non-443 port, the public-base config must carry a **scheme (and port)** locally
— either widen the avatar public-URL config from a bare hostname to a full base
URL, or terminate TLS at Caddy so the existing `https://…/<key>` composition
still holds. Production is unaffected: the Cloudflare custom domain already
provides scheme + a stable host, so both collapse to today's behavior. The
implementation issue (#523) must not treat this as a config-only change; it
carries the small `PublicURL`/config widening described here.

### 5. Sequencing — land within Phase 4b

Do this with / just before Phase 4b, which already adds `PresignGet` + `List`
and the private bucket. Doing it earlier for avatars alone would build the
public-bucket seam once and rework it for the private bucket at 4b, and an OSS
path that works for avatars but breaks at evidence is not actually "done."

## Alternatives considered

- **Keep real R2 dev locally (status quo).** Works, but requires
  operator-provisioned Cloudflare credentials (blocks OSS zero-account
  onboarding), pollutes/depends on a shared bucket for tests, and cannot safely
  host Phase 4b evidence retention/purge tests. Rejected as the default; kept as
  operator opt-in.
- **Make dummy R2 config fail closed (#483's literal framing).** Produces a
  working *disabled* state, not a working *storage* path — OSS contributors
  still can't exercise uploads. Superseded: a real Garage backend makes the
  default path work, resolving #483's root concern.
- **Presign avatars locally too (avoids Garage's partial website serving).**
  Diverges the public URL model between environments and tempts presigning of
  public media, which the two-class principle rejects. Rejected in favor of
  Garage's web port for anonymous public serving.
- **MinIO instead of Garage.** MinIO's open-source server is archived / marked
  no longer maintained; the engineering policy already prefers Garage for
  S3-compatible local/CI testing. (The existing `compose.test.yaml` MinIO for
  pgBackRest is a separate concern; converging it on Garage is optional
  follow-up.)
- **Garage for CI only, keep emulator on real R2.** Considered, but the OSS
  onboarding goal (#522) requires the *emulator* path to work with zero
  accounts, so Garage must be the emulator-loop default, not CI-only.

## Consequences

- One config axis is added — the operator opt-in R2 override — and the
  internal/external endpoint seam. No new per-platform axis (rides the existing
  API host mapping).
- Fidelity gaps to verify against real R2 before shipping (operator opt-in):
  Cloudflare custom-domain CDN serving/cache/public-access toggle, R2's actual
  CORS enforcement, R2 not enforcing Content-Length (already backstopped by the
  finalize Head), and any R2-specific error shapes.
- #483 is resolved by construction (a real working backend), not by a separate
  fail-closed change.
- `platform/r2` shrinks to public-domain URL strategy; the S3 client moves to
  `core/objectstore`, tidying the architecture boundary.
- The avatar public-URL composition needs a small widening (scheme + port, i.e.
  a base URL instead of a bare hostname) plus a Caddy route in front of Garage's
  web port for local serving — see "Local public-read routing." Prod behavior is
  unchanged.

## Deferred / related work

- #524 Firebase Auth Emulator, #525 FCM stub — the auth and push legs of the
  same zero-account local profile (#522), following the same
  zero-flag-default / operator-opt-in pattern.
- #436 dev-only client mock layer — complementary: client-side simulated flows
  for services with **no** local emulator (Stripe / IAP purchase, payout). This
  design deliberately prefers a real local backend over client bypass wherever
  an emulator exists.

## References

- Garage S3 compatibility: https://garagehq.deuxfleurs.fr/documentation/reference-manual/s3-compatibility/
- `internal/platform/r2/r2.go` (current adapter)
- Phase 4b design: `docs/designs/2026-07-26-phase4b-evidence-private-r2-design.md`
- Engineering policy (Option E layout; `core/objectstore` example) — global AGENTS.md

## Decision log

- **2026-08-05** — Initial design. Established the two-class media model,
  `core/objectstore` promotion, internal/external endpoint seam, Garage as the
  zero-flag local + CI default with real R2 as operator opt-in, and 4b
  sequencing. Filed under parent #522 (OSS local dev profile) with siblings
  #524 (auth emulator) and #525 (FCM stub); supersedes the fail-closed framing
  of #483.
- **2026-08-06** — Added the "Local public-read routing" note after a Codex
  review of PR #526 flagged that repointing `R2_PUBLIC_DOMAIN` at Garage's web
  port cannot serve avatars to the emulator (Host-header bucket selection, http
  on a non-443 port, bare-hostname/no-scheme config, and Android `10.0.2.2` vs
  iOS `127.0.0.1`). Resolution: front Garage's web port with the existing Caddy
  proxy and widen the avatar public-URL config to a scheme-carrying base URL;
  prod unchanged.
