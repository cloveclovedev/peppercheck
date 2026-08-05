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
- **external** — presigned PUT/GET, and public-read URL composition
  (client-reachable)

In production both collapse to the single R2 endpoint / Cloudflare custom
domain.

**The external base must be request-derived, not a single static value.**
Storage URLs (presigned PUT/GET and the public avatar URL) are composed and
**signed by the Go server**, and SigV4 covers the host — so the client cannot
rewrite it after the fact. The Flutter dev app applies `10.0.2.2` (Android) vs
`127.0.0.1` (iOS) only when *it* builds the API base URL; that per-platform
choice does **not** carry over to a server-emitted host. A single configured
external endpoint would therefore hand one of the two emulators an unreachable
or wrongly-signed URL.

Resolve it by deriving the external base from the **incoming request's host**
(the `Host` / `X-Forwarded-Host` that Caddy forwards): a request that arrived
via `10.0.2.2` gets `10.0.2.2`-based storage URLs, one via `127.0.0.1` gets
`127.0.0.1`-based ones, and the SigV4 signature matches because the presign is
computed against that same host. Caddy fronts both the API and Garage on that
host, so the URL routes back to Garage. (An alternative — binding a single host
LAN IP both emulators can reach — is more fragile and network-specific;
request-derived is preferred.) In CI there is no emulator, so the request host
is stable and this collapses to a single value. This corrects an earlier draft
that claimed "no new per-platform axis": there is one, but it is satisfied by
request-derived hosts rather than static per-platform config.

### 4. Garage is the default; real R2 is operator opt-in

The local Compose stack ships a Garage service plus a bootstrap as the
**default** backend (zero flags). The bootstrap must create: both buckets
(public + private), an access key granting both, CORS rules on both (browser
presigned upload/download), and — critically — **website exposure on the public
bucket** (`garage bucket website --allow`, i.e. `PutBucketWebsite`), without
which Garage's web port (3902) will not serve the bucket anonymously even though
the bucket exists. Omitting this is a silent trap: presigned PUT/Head/List can
all pass while the stable avatar URL still 404s. Real R2 is an operator opt-in
override (mirrors the BWS secret-injection opt-in default, #480/#482). CI uses
Garage with internal == external (no emulator, no host split).

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
Caddy owns the `Host`-header → public-bucket routing so no `Host`-header
handling leaks into app config. The public host itself is **request-derived**
per §3 — the server composes the avatar URL from the host the request arrived
on, so Android (`10.0.2.2`) and iOS (`127.0.0.1`) each get a fetchable URL
without static per-platform config. Because local serving is http on a non-443
port, the public-base composition must carry a **scheme (and port)** — either
widen the avatar public-URL config/logic from a bare hostname to a full,
request-derived base URL, or terminate TLS at Caddy so the existing
`https://…/<key>` composition still holds. Production is unaffected: the
Cloudflare custom domain already provides scheme + a stable host, so the
request-derived base collapses to today's single value. The implementation issue
(#523) must not treat this as a config-only change; it carries the
request-derived `PublicURL` widening described here, and the public-bucket
website-allow bootstrap step above.

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

- Config axes added: the operator opt-in R2 override, and the internal/external
  endpoint seam whose **external base is request-derived** (from the
  Caddy-forwarded host) so it stays per-platform-safe without static
  Android/iOS config. This is a real mechanism, not a no-op — the Go server must
  compose/sign storage URLs from the request host, not a fixed env value.
- The Garage bootstrap must include **website-allow on the public bucket**
  (`PutBucketWebsite`); without it the anonymous avatar URL 404s even though
  presigned PUT/Head/List pass.
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
- **2026-08-06** — Second Codex round on PR #526. (1) **Corrected** the
  overstated "no new per-platform axis" claim in §3: server-emitted, SigV4-signed
  storage URLs cannot be client-rewritten, so a single static external endpoint
  breaks one of Android/iOS. The external base is now specified as
  **request-derived** (Caddy-forwarded host), which is per-platform-safe without
  static config. (2) Added **public-bucket website-allow** (`PutBucketWebsite`)
  to the Garage bootstrap contract, without which the anonymous avatar URL 404s
  despite passing presigned PUT/Head/List.
