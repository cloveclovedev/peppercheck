# Phase 3b — Go Server-Rendered Public Web (Design)

> Status: **Design (approved in brainstorming 2026-07-26).**
> Part of the Supabase → Go API + VPS refactor. Program strategy:
> `docs/designs/2026-07-22-supabase-to-go-vps-refactor-design.md`
> (see §22 Phase 3, §9 Web Route Freeze). Phase 0 baseline:
> `docs/designs/2026-07-22-phase0-baseline.md` (§9 Web Route Freeze).
> Builds on Phase 1 (foundation) and Phase 2 (identity & client boundary).
> Follows the **implemented** backend conventions (verified 2026-07-26), which
> differ from some Phase 3a *design* assumptions: `updated_at` is Go-maintained
> (no `set_updated_at()` trigger exists), stores hold `*sql.DB` directly (no
> `Querier` interface exists), and DB tests are plain transactional assert-SQL in
> `backend/db/tests/` (not pgTAP). Sibling:
> `docs/designs/2026-07-25-phase3a-profile-notification-design.md`
> (Phase 3a defined the 3a/3b split; this document is the 3b half).
>
> Each phase is its own `spec → plan → implementation` cycle; this document
> covers **Phase 3b only**. The implementation plan is produced separately by the
> writing-plans workflow and is not committed.

---

## 0. Phase 3 split — 3a vs 3b (recap)

Strategy §22 groups Phase 3 ("Low-risk slices + Go web") as one phase. Phase 3a's
design split it into two independent tracks with different runtimes, deploy
targets, and test surfaces:

- **Phase 3a** (separate spec) — app data slices behind the Go **JSON API** +
  Flutter client: profile and notification-token registration.
- **Phase 3b (this document)** — Go **`html/template`** server-rendered public
  web: marketing home, legal pages, Stripe Connect return/refresh landing pages,
  the provider-neutral web account-deletion **request** resource, and retiring
  the obsolete Next.js web app.

The two tracks share nothing at runtime (JSON API vs server-rendered HTML), which
is why they are separate spec→plan→implementation cycles.

---

## 1. Purpose & Scope

### 1.1 Purpose

Migrate the current public web app — Next.js 15 (App Router) on Cloudflare
Workers via OpenNext, served from `peppercheck.dev` — to **Go `html/template`
pages served from the VPS behind Caddy**, removing Supabase from the web entirely
and delivering a cutover-ready set of pages on the integration branch. The DNS
switch, staging verification, and Cloudflare teardown belong to **Phase 7**; 3b
produces the parity + tests, not the production cutover.

The public web is also a **marketing surface** (the app's public face), so visual
fidelity to the current design is a first-class requirement, not an afterthought.

### 1.2 In scope (the 8 "keep" routes)

Per baseline §9 (Web Route Freeze), narrowed by P3b-D15: **8 keep routes**. The 4
legacy auth/subscription routes (`auth/callback`, `login`, `dashboard`,
`pricing`) are dropped without a redirect — no Go route is registered for them,
so they 404 by default (see P3b-D15).

**Keep (ported to Go html/template):**

| Route | Notes |
|-------|-------|
| `/` and `/{locale}` | Marketing home; preserve locale redirect behavior. |
| `/{locale}/legal/privacy` | Privacy policy. |
| `/{locale}/legal/terms` | Terms of service. |
| `/{locale}/legal/refund` | Cancellation/refund policy (IAP-aligned). |
| `/{locale}/legal/tokushoho` | Act on Specified Commercial Transactions disclosure (price hardcoded, see §5.3). |
| `/{locale}/stripe/connect/return` | Static "onboarding complete" landing (path-fixed, see §5.2). |
| `/{locale}/stripe/connect/refresh` | Static "restart onboarding" landing (path-fixed, see §5.2). |
| `/{locale}/account/delete` | **Redefined** as an unauthenticated account-deletion **request/instructions** resource (see §4). |

### 1.3 Out of scope (explicit)

- **Browser-side auth / Firebase JS SDK** — not introduced. 3b has no
  authenticated web surface (this is the deliberate consequence of §4's request
  model, and is what keeps 3b small).
- **Account-deletion saga** (Firebase/RevenueCat/Stripe/R2/DB cross-system
  deletion, and the email round-trip verification of a web request) → **Phase 6**.
- **tokushoho price via API** (a machine-readable price source in Go) → **Phase
  5** (`subscription_plans` is seeded there). 3b hardcodes a reviewed constant.
- **DNS switch, staging/production droplet verification, Cloudflare Workers
  teardown, physical production removal of Next.js** → **Phase 7 cutover**.

### 1.4 Invariants (non-negotiable constraints)

- **URL structure is frozen.** The `/{locale}/` (`en`/`ja`) subdirectory prefix
  and every kept path are preserved **exactly**. The legal and account-deletion
  URLs are registered in Google Play Data Safety, the App Store, in-app links, and
  are indexed/back-linked — changing them would require store-console
  re-registration and old→new redirects. (See §3.4 for why subdirectory over
  subdomain.)
- **`/stripe/connect/return` and `/stripe/connect/refresh` paths are fixed**
  because `payout-setup` (ported to `POST /api/v1/payout/setup` in Phase 5) sends
  these as Stripe's `return_url`/`refresh_url` **without a locale prefix**; the
  bare paths must keep resolving (see §5.2).

---

## 2. Store-requirement basis for the deletion resource (§4)

The redefinition of `/{locale}/account/delete` from a self-service authenticated
delete into an **unauthenticated request/instructions** resource is grounded in
the official store policies (verified 2026-07-26):

- **Google Play** ([Account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111)):
  requires **both** (a) an in-app path to delete the account, **and** (b) a **web
  link resource** where users can *request* account deletion. The web resource
  **does not have to be self-service** — the policy explicitly allows "*an
  additional link that initiates account deletion, a customer service email or a
  form they can submit a request through*." The rationale: users who uninstalled
  the app must be able to request deletion "*without sending the user back to the
  app*."
- **Apple** ([Guideline 5.1.1(v)](https://developer.apple.com/news/?id=12m75xbj)):
  requires **in-app** account deletion. The web page is not what satisfies Apple;
  Apple is satisfied by the in-app self-service deletion (Phase 6).

**Conclusion:** the 3b web resource permanently satisfies Google Play's "web link
resource" requirement (b). It is **not** a substitute for the in-app self-service
deletion that both stores actually require — that is Phase 6. The web resource is
therefore a request/instructions page forever, by design.

---

## 3. Architecture

### 3.1 Module placement (AGENTS.md naming convention)

- A new **inbound web feature** `internal/web/` holds the `html/template`
  `Handler`. It returns HTML, is distinct from the JSON API (`internal/api`), but
  runs in the **same `api` process on the same origin** (baseline §9: the JSON API
  under `/api/v1` and the web share one origin — no second public hostname).
- The account-deletion request write path is small and account-scoped. It is
  implemented either as part of `internal/web` (inbound) delegating to a thin
  store, or as a tiny `internal/accountdeletion` feature owning the
  `account_deletion_requests` store. The plan picks one; either way the web
  handler is the inbound adapter and identity lookup is a dependency (§6.2).
- Templates and static assets (CSS, fonts) are compiled into the binary via Go
  **`embed`** — no external asset fetch at runtime, so the **same image runs
  local/staging/production** (engineering policy: portable, self-contained
  container).

### 3.2 Routing

The Go router (behind the existing single Caddy reverse-proxy to `api`) dispatches:

- `/api/v1/*` → JSON API (`internal/api`, unchanged).
- `/`, `/{locale}/*`, static assets → `internal/web`.
- The 4 legacy auth/subscription routes have no registered route and 404 by
  default (P3b-D15).

Caddy itself changes minimally: TLS/HSTS and `reverse_proxy api:{$API_PORT}` stay
as-is; all path dispatch happens inside the Go process.

### 3.3 Locale routing (replacing next-intl)

- A Go middleware resolves `/{locale}/` (`en`/`ja`), replacing `next-intl`'s
  locale routing (the Supabase half of the current `src/middleware.ts` is dropped
  with Supabase; the locale-routing half is reimplemented in Go).
- A **bare path** without a locale prefix (`/legal/privacy`, `/stripe/connect/return`)
  redirects to the default-locale version, preserving current behavior.
- The default locale stays **`en`** (current behavior). Switching the default to
  `ja` is a product decision recorded as a follow-up (§8), not a 3b change.
- **`hreflang` annotations are added** to every kept page:
  `<link rel="alternate" hreflang="ja" …>`, `hreflang="en"`, and
  `hreflang="x-default"`, cross-linking the ja/en versions. This is the one SEO
  best-practice gap the current app likely does not emit; the Go port closes it
  (Google [Managing Multi-Regional and Multilingual Sites](https://developers.google.com/search/docs/specialty/international/managing-multi-regional-sites)).
- A user-facing language switcher (the current EN/JP switcher) is retained; no
  automatic Accept-Language redirect is imposed on kept pages.

### 3.4 Why subdirectory, not subdomain (P3b-D6)

Google's guidance ranks ccTLD > subdirectory > subdomain for geo-targeting, but
**subdirectory is the recommended single-domain option** (best link-equity
consolidation). For a single bilingual (ja+en) app on one VPS, subdomain's only
real advantages — independent per-region geo-targeting and separate
infrastructure/CDN — do not apply. The decisive factor is the frozen URL
invariant (§1.4): subdirectory preserves every store-registered / indexed URL
exactly, requiring **no** store-console updates and **no** old→new redirects,
whereas subdomain would require both plus cross-host `hreflang` and a bare-domain
locale-redirect decision. Subdirectory is therefore chosen.

### 3.5 i18n content source of truth

The legal/marketing copy currently lives in the next-intl JSON catalogs
(`peppercheck-webapp/messages/{en,ja}.json`, namespaces `HomePage, Header,
Footer, StripeConnect, Privacy, Terms, Refund, Tokushoho, AccountDelete`, …). This
copy is **moved into a Go embedded message catalog (ja/en) as the single source
of truth**; the Next.js catalogs are removed with the web app (§5.1). The Go
templates render from this catalog. (Localized copy is data — the ja strings live
in the catalog per the repo's language convention.)

### 3.6 Fonts & visual fidelity (P3b-D10)

Rendering must be **identical** to the current design (marketing face). Achieved
by self-hosting the **same** fonts, so only the runtime Google Fonts dependency is
removed, not the look:

- Ship the current **Inter + Noto Sans JP** as **`woff2`**, embedded via Go
  `embed` and served same-origin.
- Load via `@font-face` with **`font-display: swap`**; **`preload`** the primary
  weights actually used. Serve every `/static/` asset with a **content-based
  `ETag`** (sha256, computed once at startup) and `Cache-Control: public,
  max-age=3600` — a fixed-name + hourly-revalidation policy (browsers get a cheap
  `304` when unchanged). This is chosen over content-hashed filenames because
  `embed.FS` has no mtime, so `http.FileServer` alone emits no validators; ETag
  gives correct revalidation for `styles.css` and the CSS-referenced fonts without
  a build-time fingerprint pipeline.
- **Noto Sans JP** is large (full JP glyph set is several MB). Use **`unicode-range`
  split subsets** (the technique Google Fonts itself uses) so the browser
  downloads only the ranges present on a page — preserving exact design while
  keeping transfer small, and robust to legal-copy edits. (Static subsetting via
  glyphhanger is a smaller but more fragile alternative; not chosen.)
- **License:** Inter and Noto Sans JP are both **SIL Open Font License (OFL)**,
  which permits self-hosting and redistribution — the embed is license-clean.

> Note: `next/font/google` already self-hosts fonts at build time, so the current
> app likely has no runtime Google Fonts dependency either; the Go port reproduces
> the same self-hosted outcome.

---

## 4. Account-deletion request resource

`/{locale}/account/delete` is redefined as an **unauthenticated
request/instructions** resource — **no browser auth** (P3b-D1, P3b-D2).

### 4.1 Page composition

- **Primary-path guidance:** the page leads with "the reliable way to delete your
  account is **from within the app**," linking/instructing toward in-app deletion.
- **Fallback form** (for users who can't use the app — uninstalled, lost device):
  - Visible fields: **email address (required)** + **one consent checkbox**
    ("I understand this requests permanent deletion of my account and data") +
    submit.
  - Helper text: "enter the email you used to sign in (Google / Apple)"; and "if
    you don't know it / used Apple Hide My Email, delete from within the app."
  - Hidden anti-abuse fields: **honeypot** + **signed form token** (see §6).
- Locale is taken from the URL.

Fields deliberately **omitted**: name (matching is by email; name adds friction,
no value) and free-text reason (not required by Google Play; free text is a
spam/abuse storage surface). A reason field, if ever wanted, is at most a single
optional field.

### 4.2 Request ≠ execution (the safety model, P3b-D3)

The core principle that makes an unauthenticated form safe: **the form only
records intent; it never deletes.** Because a raw request performs no destructive
action, "anyone can submit a request" is harmless. The destructive gate is at
**execution time**, not submission time:

- 3b captures an **unverified** deletion intent into `account_deletion_requests`.
- **Phase 6** verifies ownership (email round-trip: a confirmation link sent to
  the account's registered email — only someone controlling that email can
  confirm; proves control without app login) **before** running the deletion saga.

Trying to move verification to submission time would reintroduce browser auth —
exactly the surface 3a deferred. "Accept from anyone / verify before execution" is
what keeps 3b auth-free while remaining store-compliant and safe.

### 4.3 Abuse resistance (P3b-D4, P3b-D5)

Spam is defused structurally so operator confirmation cost scales with *real
accounts*, not *submissions*:

1. **No email is sent on submission** (removes the email-amplification / inbox-bomb
   vector and cost). Verification email is a Phase-6, processing-time action, and
   only to a matched account's registered address, per-account rate-limited.
2. **Store a row only if the claimed email matches an existing account**
   (server-side lookup against `user_identities.email`, §6.2 — email is persisted
   on `user_identities` as a 3b addition, see §6.1). Junk submissions for
   non-existent emails create **zero rows** and never reach the operator's
   confirmation queue. Confirmation cost is therefore bounded by real-account
   matches, which are naturally few.
3. **Uniform generic response** regardless of match ("if an account with this
   email exists, we'll process the request") — prevents account enumeration and
   harassment targeting.
4. **Honeypot** hidden field (drops naive bots, zero user friction).
5. **Signed form token + submission-timing check** — a short-lived HMAC-signed
   token embedded when the page is served; rejects scripted POSTs that never
   loaded the page and submissions faster than a human could fill. Stateless (no
   server-side session).
6. **Per-IP rate limiting** (core middleware) bounds volume.
7. **Upsert dedup per matched account** — repeated requests for one account
   collapse to a single row (bounds DB growth).

**Cloudflare Turnstile** (free, near-invisible CAPTCHA) is **not** included
initially; it is a follow-up to add only if real spam gets through the above. It
works standalone behind VPS/Caddy (widget + server-side siteverify + one secret).

### 4.4 Phase 6 boundary

3b hands off **"unverified deletion intents tied to real accounts"** and nothing
more. Phase 6 owns: email round-trip verification (`unverified` → `verified`),
running the deletion saga, and any per-account verification-email rate limiting.
Recorded in follow-ups (§8) so Phase 6 knows to consume `account_deletion_requests`.

---

## 5. Redirects, Stripe Connect landing, tokushoho price

### 5.1 Next.js retirement & Supabase-from-web removal (P3b-D11)

- **In 3b, once Go route parity is verified in CI, `peppercheck-webapp/` is
  deleted on the integration branch** (Next.js, OpenNext, `wrangler` config, the
  Supabase web SDK usage, and `ci-webapp.yml`). This satisfies strategy §22 Phase
  3's "done = these features have no Supabase imports; public web routes
  production-ready."
- **The live production site is unaffected:** it is served from `main`/Cloudflare
  until the Phase 7 cutover (the refactor is big-bang on the integration branch,
  merged to `main` only at Phase 7). Deleting the app on the integration branch
  does not touch the live site. The one operational caveat — a live-site hotfix
  before cutover is done on `main` (where the web app still exists) — is inherent
  to big-bang integration, not specific to this deletion.
- **Supabase-web verification caveat** (baseline §9.1): a grep for remaining web
  Supabase deps must match the **`@/lib/supabase` path alias**, not only the
  `@supabase` package name (`account/delete/page.tsx` used the alias and would not
  appear in a package-name grep). Better: rely on the Go port completing, not on
  grep.

### 5.2 Stripe Connect return / refresh (P3b-D7)

- Served as **static Go template pages** at `/{locale}/stripe/connect/{return,refresh}`
  (equivalent to the current `StaticInfoPage`: "onboarding complete, return to the
  app" / "onboarding needs restarting"). No auth, no external calls.
- **Path-fixed:** `payout-setup` (Phase 5 → `POST /api/v1/payout/setup`) sends
  `return_url`/`refresh_url` as the **bare, locale-less** paths
  `/stripe/connect/{return,refresh}`. Go must therefore **accept the bare paths**
  and redirect to the default-locale page (current next-intl behavior). Whatever
  Stripe redirects the browser to must resolve to the info page.
- Contact email (`hi@cloveclove.dev`) comes from the i18n catalog (was hardcoded in
  `StaticInfoPage.tsx`).
- **Known limitation — `refresh` stays static in 3b (faithful port).** Stripe's
  Account Links contract specifies that `refresh_url` should *generate a new
  Account Link and redirect back into onboarding*
  ([Stripe Account Links](https://docs.stripe.com/api/account_links/create)).
  That re-issue needs the Stripe Connect integration (identify the account,
  `accountLinks.create`), which is ported to Go with `payout-setup` in **Phase 5**.
  The current Next.js prod is also a static "please restart" page, so 3b preserves
  that behavior and records a Phase 5 follow-up (§8): make `refresh` regenerate the
  link via a short-lived signed `state` query param. The frozen path is preserved
  regardless.

### 5.3 tokushoho price (P3b-D8)

- The current page fetches price rows from Supabase; **3b removes that Supabase
  read** (removing the last Supabase dependency from the legal pages).
- The price is rendered from a **single reviewed constant** (one Go const / config
  value referenced by the template). The Act on Specified Commercial
  Transactions requires showing the real price,
  which this satisfies.
- **Launch-blocker linkage:** the baseline records a Premium price discrepancy
  (**2,580 vs 2,480**). The hardcoded value **must be the reconciled/reviewed
  price**, and the constant carries a comment referencing that blocker; resolve
  the discrepancy before shipping.
- A CI consistency check is **not** built in 3b: there is no machine-readable Go
  price source to compare against until Phase 5. **Phase 5 follow-up:** switch
  tokushoho to read the price from the Go subscription endpoint (single source of
  truth), at which point a consistency check is natural (§8).
- Other legally mandated fields (seller/contact info) stay as static copy from
  the i18n catalog. Operator is a **solo operation**; do not use
  "employee"/team-based wording in the copy (existing policy).

---

## 6. Data model, contracts, security, testing

### 6.1 Data model — one new table + one column addition

**New table `account_deletion_requests`:**

| Column | Notes |
|--------|-------|
| `id` | PK. |
| `user_id` | Matched internal user UUID, **NOT NULL**, **UNIQUE**, FK → `users(id) ON DELETE CASCADE` (a row exists only when the claimed email matched a real account). |
| `claimed_email` | The email submitted (matched). |
| `status` | Initially `unverified`; Phase 6 advances to `verified`/`processed`. |
| `source` | `web`. |
| `requested_at` | Submission time. |
| `updated_at` | **Go-maintained** (`updated_at = now()` in each `UPDATE`); no DB trigger (matches the implemented backend convention). |

- **Upsert on `user_id`** (`ON CONFLICT (user_id) DO UPDATE`) so repeated requests
  for one account collapse to a single row.
- Declared in a new Atlas schema dir `schema/web/` (registered in `atlas.hcl`
  `src`); a plain transactional **assert-SQL** test in `db/tests/` covers the
  unique constraint, cascade, and upsert behavior (repo backend DB-testing
  convention — not pgTAP).

**Column addition — `user_identities.email` (+ `email_verified`):** email is not
persisted anywhere today (Phase 2 stores only `issuer`/`subject`; the verified
token carries `Email` but it is never written). To make §4.3's match-on-real-
account work, 3b adds `email text` and `email_verified boolean` to
`user_identities` (the conceptually correct home — email is a per-provider-
identity attribute, and `users` deliberately holds no provider data), captures it
from the verified token at provisioning and refreshes it on each login, and adds
a `lower(email)` index for case-insensitive lookup. This modifies the implemented
Phase 2 identity code (opportunistic, same integration branch).

**Match safety:** the lookup (`FindUserByEmail`) matches **only `email_verified`
rows** and resolves to a user **only when unambiguous** — if the same verified
email maps to more than one distinct user it returns `ErrNotFound` (fail safe;
never picks an arbitrary account). The login-time refresh keeps the stored email
current, avoiding stale matches.

**State machine (write-time enforced):** `account_deletion_requests.status` moves
`unverified → verified → processed`, advanced **only by Phase 6**. The public
form's upsert writes only `unverified` and is guarded (`ON CONFLICT (user_id) DO
UPDATE … WHERE status = 'unverified'`), so a third party who merely knows an email
**cannot revert** a Phase-6-confirmed request back to `unverified`. A DB assert-SQL
test covers this.

### 6.2 Backend contracts

- **Account existence lookup:** `internal/identity` gains `FindUserByEmail`
  (a thin extension of the existing store, `struct { db *sql.DB }`), returning
  `ErrNotFound` on no match. A new domain feature `internal/accountdeletion`
  (domain + `Store.Upsert` + `Service.RequestDeletion`) consumes it via a
  consumer-declared interface (web → accountdeletion → identity, one-way).
- **Public POST handler** (`internal/web`): rate-limit → body cap → honeypot →
  consent → signed form token/timing → `accountdeletion.Service.RequestDeletion(claimedEmail)`
  (which normalizes the email, looks up the account, and upserts on match).
  **Response:** normally the uniform generic response (a PRG **303** redirect to
  `?submitted=1`) — identical for match, no-match, honeypot, bad token, and
  missing consent, so no account existence leaks. **Exception:** if
  `RequestDeletion` returns an infrastructure error (the request was NOT saved),
  return a **generic 503** retry page instead — never a "submitted" 303 — so the
  user is not misled into thinking a lost request succeeded. The 503 is
  independent of account match, so it too leaks nothing.
- **Signed form token:** on page render, embed an HMAC-signed token over
  `{issued_at, nonce}`; the POST verifies signature, expiry, and a minimum
  elapsed time. **Stateless** (no server session). The signing key is a new
  secret `WEB_FORM_SIGNING_KEY`, loaded via the env/file-secret pattern
  (`lookupEnvOrFile`) and delivered through Phase 7a's BWS → Docker file-based
  secret mechanism, scoped to the `api` service (a 3b-side addition, not a change
  to the 7a docs).
- **Rate limiting:** per-IP, via a **new** in-memory limiter middleware written in
  `internal/web` (no rate-limit middleware exists in the codebase yet). Client IP
  is taken from `X-Forwarded-For` (set by Caddy); this bounds casual abuse, not a
  determined spoofer — Turnstile is the escalation.
- Stores hold `*sql.DB` directly and run any transactions inline via `BeginTx`
  (the codebase has no `Querier` interface or tx/UoW helper).

### 6.3 Security & privacy

- **Account existence non-disclosure** (uniform response) prevents enumeration and
  harassment.
- **No confirmation email in 3b** (amplification prevention); verification/sending
  is Phase 6.
- `claimed_email` handling is minimal (a match key + Phase-6 verification target);
  **PII is never logged**.
- **CSP header is emitted** on every web response by the web handler — a strict
  policy (`default-src 'self'; script-src 'none'; style-src 'self'; font-src 'self';
  img-src 'self' data:; form-action 'self'; base-uri 'self'; frame-ancestors 'none';
  object-src 'none'`), plus `X-Content-Type-Options: nosniff` and a
  `Referrer-Policy`. The pages are self-contained (embedded CSS/fonts, no external
  hosts, no JavaScript), so this policy is enforceable as-is; a header test asserts
  it. Self-hosting alone does not enable CSP — the header must be set, and is.

### 6.4 Testing (strategy §24 "Web (in Go CI)")

- **Template render tests** for all kept pages × `ja`/`en`.
- **Per-locale route tests** + **`hreflang` output** verification.
- **Redirect tests**: bare Stripe Connect paths → default-locale page.
- **404 test**: the 4 legacy auth/subscription routes resolve to a plain 404
  (no route registered).
- **Deletion form tests** (fake identity store): valid token / honeypot tripped /
  timing too fast / rate-limited / matched vs unmatched email producing the
  **identical** response / upsert dedup.
- **Embedded-asset validation**: fonts/CSS are compiled in and resolve.
- **No CI job reads committed secrets or local secret files.**

---

## 7. Decision log

| ID | Decision | Rationale |
|----|----------|-----------|
| **P3b-D1** | Phase 3 already split into 3a/3b; **3b = Go `html/template` public web (static/near-static + redirects), no browser auth.** | Different runtime/deploy/test surface from 3a's JSON API; the request-only deletion model (D2/D3) removes the only reason 3b would need browser auth. |
| **P3b-D2** | Redefine the web deletion route as an **unauthenticated request/instructions** resource. | Google Play requires a web *request* resource that need not be self-service; it permanently satisfies that requirement and is not a substitute for in-app deletion (Apple's requirement, Phase 6). (§2) |
| **P3b-D3** | **Request ≠ execution:** the web only queues an *unverified* intent; verification (email round-trip) and execution are Phase 6. | Makes an unauthenticated form safe without browser auth; a raw request performs no destructive action. |
| **P3b-D4** | Accept from anyone, but **store a row only on a real-account email match**; **uniform generic response**; **no email on submission**. | Bounds operator confirmation cost to real accounts; prevents enumeration/harassment; removes the email-amplification vector. |
| **P3b-D5** | Anti-abuse layers: honeypot + signed form token + timing + per-IP rate limit + per-account upsert. Turnstile only if needed later. | Low-friction, no third-party dependency, no added secret; sufficient at this scale. |
| **P3b-D6** | **Locale = subdirectory `/{locale}/` (kept)** + add `hreflang`; not subdomain. | Preserves frozen store-registered/indexed URLs (no console updates, no old→new redirects); single origin; best link-equity for one bilingual app on one VPS. (§3.4) |
| **P3b-D7** | Stripe Connect return/refresh are **path-fixed static pages** accepting bare, locale-less paths. | `payout-setup` sends `return_url`/`refresh_url` as bare paths (no locale prefix) that must keep resolving regardless of locale routing. |
| **P3b-D8** | Act on Specified Commercial Transactions price = **hardcoded reviewed constant** (referencing the 2,580 vs 2,480 blocker); Phase 5 switches to API read. | No machine-readable Go price source exists until Phase 5; the Act requires a real price now. |
| **P3b-D9** | Move the i18n copy from the next-intl catalogs into a **Go embedded catalog as the single source of truth**. | The web app is deleted in 3b; the copy must live somewhere Go can render it. |
| **P3b-D10** | Self-host the **same** fonts (Inter + Noto Sans JP) as embedded `woff2` (Noto = `unicode-range` split), `font-display: swap`, `preload`, and content-`ETag` + `max-age=3600` revalidation for `/static/`. | Preserves the marketing design exactly while removing runtime Google Fonts dependency; OFL permits self-hosting; ETag revalidation avoids a fingerprint build pipeline for a small site. |
| **P3b-D11** | **Delete `peppercheck-webapp/` on the integration branch in 3b** once parity is verified; Cloudflare/DNS teardown is Phase 7. | Satisfies Phase 3 "no Supabase imports in web"; avoids carrying two web stacks; the live site (main/Cloudflare) is unaffected until cutover. |
| **P3b-D12** | The only new table is **`account_deletion_requests`** (name includes "account" for clarity vs other deletion concepts); the deletion domain lives in a dedicated **`internal/accountdeletion`** feature, not folded into `identity`. | Self-documenting; consistent with the existing `check_account_deletable` / `delete-account` vocabulary. Deletion is an account-lifecycle concern (Phase 6 grows it into the cross-system saga), distinct from identity's auth responsibility; `accountdeletion` is the precise bounded name (vs a broad `account` grab-bag). The split is for responsibility isolation + Phase 6 forward-compat, **not** DB least-privilege (roles are shared `peppercheck_app`). |
| **P3b-D13** | **Persist `email` (+ `email_verified`) on `user_identities`**, captured from the verified token at provisioning and refreshed on login; add `FindUserByEmail`. | Email is not stored today, so match-on-real-account (P3b-D4) is otherwise impossible. Email is a per-provider-identity attribute, so `user_identities` is the conceptually correct, best-practice home (`users` holds no provider data by design). |
| **P3b-D14** | **Follow the implemented backend conventions:** `updated_at` is Go-maintained (no `set_updated_at()` trigger), stores hold `*sql.DB` directly (no `Querier`), DB tests are plain assert-SQL in `db/tests/` (not pgTAP). The form-signing key `WEB_FORM_SIGNING_KEY` is a new secret via `lookupEnvOrFile` + 7a's file-secret delivery. | The codebase (verified 2026-07-26) does not yet have the Phase 3a-designed helper APIs. The Phase 3a design now agrees with this `updated_at` convention; the remaining helper dependencies still require execution-time revalidation. |
| **P3b-D15** | **Supersedes the redirect half of P3b-D7 (2026-08-04):** the 4 legacy auth/subscription routes (`auth/callback`, `login`, `dashboard`, `pricing`) are **not implemented and not redirected** — no Go route is registered for them, so they 404 by default. | The public web has not gone to production yet, so these routes carry no external indexing or backlinks to preserve. Treating them as if they never existed avoids unneeded redirect logic; a 301 can be added later without design impact if real external references ever surface. |

---

## 8. Follow-ups (recorded, not built in 3b)

| Item | Owner phase | Notes |
|------|-------------|-------|
| tokushoho price via API | Phase 5 | Read from the Go subscription endpoint once `subscription_plans` is the source of truth; add a consistency check then. |
| Stripe Connect `refresh` re-issues an Account Link | Phase 5 (**cutover release criterion**) | Regenerate the link (`accountLinks.create`) + 302 into onboarding, identifying the account via a short-lived signed `state`; ships with the Go `payout-setup` port. 3b ships a static page (faithful port of current prod). Required before production cutover so onboarding recovers from an expired link. |
| Consume `account_deletion_requests` | Phase 6 | Email round-trip verification (`unverified` → `verified`), run the deletion saga, per-account verification-email rate limiting. |
| Cloudflare Turnstile on the deletion form | Optional | Add only if real spam gets past the §4.3 layers. |
| Default locale `ja` vs `en` | Optional (product) | 3b keeps current default `en`; switching is a product decision, not a URL best-practice change. |
| "Subscription explanation" content for `pricing` | Optional | Default is a 301 to home; add a home section / static page only if wanted. |

---

## 9. "Done" means

- The 8 keep pages render via Go `html/template` in `ja`/`en`, **preserve the
  current design**, and emit `hreflang`.
- The 4 legacy auth/subscription routes have no registered route (404 by
  default). Stripe Connect return/refresh resolve at the fixed paths (including
  bare, locale-less paths).
- The account-deletion request resource works **without auth** (store-on-match,
  uniform response, anti-abuse layers), backed by `account_deletion_requests`.
- The web has **no Supabase imports** (`peppercheck-webapp/` deleted on the
  integration branch).
- Fonts/CSS are embedded and self-hosted; no runtime external-asset fetch.
- The Web CI gates pass; no CI job reads committed secrets.
- **Not** in 3b's "done": DNS switch, staging/production droplet verification, and
  Cloudflare teardown — those are the Phase 7 cutover (3b delivers a cutover-ready
  state).
