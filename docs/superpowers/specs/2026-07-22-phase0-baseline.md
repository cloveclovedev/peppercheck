# Phase 0 Baseline — Supabase → Go API + VPS Refactor

> Status: **Finalized.** This is the Phase 0 deliverable defined by the Phase 0
> spec — the single source of truth for the dependency inventory, DB-logic
> classification, launch-blocker register, Flutter API surface, critical-journey
> behavior catalog, reduced web routes, drop candidates, decisions ledger, and
> seed policy that gate Phase 1 (Foundation).
>
> Parent documents:
> - Program strategy: `docs/superpowers/specs/2026-07-22-supabase-to-go-vps-refactor-design.md`
> - Phase 0 spec (defines this deliverable's shape + Done checklist):
>   `docs/superpowers/specs/2026-07-22-phase0-freeze-baseline-design.md`
>
> Assembled from nine investigation part files
> (`docs/superpowers/plans/phase0-parts/`), with the operator's Phase 0
> adjudications folded in (2026-07-22). Where a part file's wording said
> "pending," "proposed," or left an item ambiguous, this document records the
> operator's resolution and supersedes that wording.
>
> Last updated: 2026-07-22.

---

## Operator adjudications folded into this baseline

1. **D2 (identity) and D4 (subscription/RevenueCat) are ACCEPTED**, not
   pending — see §8.
2. **T3 DB-logic ambiguities are resolved** — see §2 "Operator resolutions."
3. **Three financial-integrity risks surfaced by the journey catalog (§5) are
   added to the launch-blocker register (§3)** as "candidate — verify in
   owning phase," each assigned an owning phase (Phase 5 ×2, Phase 6 ×1).

---

## 1. Dependency Inventory

> Source: `docs/superpowers/plans/phase0-parts/01a-dependency-inventory.md`
> (Stripe Connect/Billing split + master table) and
> `docs/superpowers/plans/phase0-parts/01b-edge-functions.md` (per-function
> edge function detail). Synthesizes program design doc §16 (dependency
> inventory skeleton), §11 (billing vs. payouts), §17 (Edge Function → Go
> mapping), §13 (logic classification), §12 (background work).

### 1.1 Stripe Connect vs. Stripe Billing separation

Program §11 requires this split explicitly before any shared Stripe code is
deleted. Investigation of `supabase/schemas/stripe/` (only table:
`stripe_accounts`) plus its callers shows the split is **not clean at the
code level today** — two places interleave Connect (keep) and Billing (drop)
concerns in the same object:

#### Finding 1: `stripe_accounts` is one table with both concerns mixed in

`supabase/schemas/stripe/tables/stripe_accounts.sql` (single table, 12
columns):

| Column | Concern | Written by | Read by |
|---|---|---|---|
| `stripe_connect_account_id`, `charges_enabled`, `payouts_enabled`, `connect_requirements` | **Connect** (keep) | `payout-setup`, `handle-stripe-webhook`'s `handleAccountUpdated` | `payout-setup`, `create-express-dashboard-link`, `execute-pending-payouts`, `delete-account`, `reward/functions/prepare_monthly_payouts.sql`, Flutter `stripe_payout_repository.dart:23` |
| `stripe_customer_id`, `default_payment_method_id`, `pm_brand`, `pm_last4`, `pm_exp_month`, `pm_exp_year` | **Billing** (drop) | `billing-setup`, `create-stripe-checkout` | Flutter `stripe_billing_repository.dart:41` (confirmed dead — see Finding 3) |

No column is shared/ambiguous — each of the 10 non-key columns cleanly
belongs to one side. The RLS policy (`stripe_accounts_policies.sql`, 1
policy: "select if self") and the housekeeping trigger
(`on_stripe_accounts_update_set_updated_at.sql`) apply to the whole row and
don't need splitting themselves, but the **table itself should split into
two tables (or the Billing columns dropped outright)** when this migrates to
the new schema, since the Billing columns have no future caller once
`billing-setup`/`create-stripe-checkout` are dropped.

#### Finding 2: `handle-stripe-webhook` interleaves 3 Billing handlers with 1 Connect handler

`supabase/functions/handle-stripe-webhook/index.ts` switches on Stripe event
type: `checkout.session.completed`, `customer.subscription.{updated,deleted}`,
`invoice.payment_succeeded` (all **Billing** — subscription upsert into
`user_subscriptions`, point reset) vs. `account.updated` (the only **Connect**
case — syncs `charges_enabled`/`payouts_enabled`/`connect_requirements` on
`stripe_accounts`). `01b-edge-functions.md` describes this function as one
unit ("port as a signature-verified Go endpoint") without flagging the
internal split. Per §11 ("Money in" moves to RevenueCat; "Money out" keeps
`handle-stripe-webhook`), **the Go port should drop the 3 Billing case-handlers
and keep only the Connect `account.updated` handler** — this is a scope
narrowing that isn't visible from `01b`'s function-level table alone.

#### Finding 3: `stripe_billing_repository.dart` is confirmed dead code (resolves `04`'s open question)

`04-flutter-api-surface.md` flagged `stripe_billing_repository.dart:41`'s
read of `stripe_accounts` as having an "unresolved dependency" on the
unused `billing-setup` function. This investigation resolves it:
`grep -rn "BillingSetupSection(" peppercheck_flutter/lib/` returns **only
the widget's own class declaration** — it is never instantiated by any
screen. Both of `StripeBillingRepository`'s methods
(`createBillingSetupSession()` → invokes `billing-setup`;
`fetchDefaultBillingMethod()` → reads `pm_brand/pm_last4/pm_exp_month/pm_exp_year`
off `stripe_accounts`) are reachable only from `billing_controller.dart` and
the unmounted `billing_setup_section.dart`. **The entire
`stripe_billing_repository.dart` file, its controller wiring, and
`billing_setup_section.dart` are dead code** tied 1:1 to the dropped
`billing-setup` Edge Function — recommend deleting all three together
rather than porting any part.

#### Bonus finding: `profiles.stripe_connect_account_id` is a separate, never-written duplicate column

While tracing Connect columns, `supabase/schemas/profile/tables/profiles.sql:7`
also declares `stripe_connect_account_id`. Every functional read/write in the
codebase (payout functions, `handle-stripe-webhook`, migrations, tests) uses
`stripe_accounts.stripe_connect_account_id`, never the `profiles` one; the
only `INSERT INTO public.profiles` (`handle_new_user.sql:15`) sets `(id,
username)` only. This column is permanently `NULL`, leaks into the Flutter
`Profile` domain model (`profile.dart`, `profile.freezed.dart`) only because
`profile_repository.dart:24` does `.select()` (all columns), and has no
functional purpose. Not part of the Connect/Billing split itself, but an
opportunistic-refactor (§15) drop candidate worth flagging alongside it.

#### Conclusion

Stripe **Connect** (payouts — keep, port to Go): `stripe_accounts`'s 4
Connect columns, `payout-setup`, `create-express-dashboard-link`,
`execute-pending-payouts`, `payout-request` (net-new, launch-blocker),
`handle-stripe-webhook`'s `account.updated` case only, `recommend-payout-topup`
(operator tool).

Stripe **Billing** (subscription/card — drop, do not port): `stripe_accounts`'s
6 Billing columns, `billing-setup`, `create-stripe-checkout`,
`handle-stripe-webhook`'s 3 subscription-event cases, Flutter
`stripe_billing_repository.dart` + `billing_setup_section.dart` (confirmed
dead), webapp `SubscribeButton.tsx`/`pricing`/`dashboard` routes (already
flagged for removal by §6).

### 1.2 Master dependency inventory table

Columns: `integration | used-by feature | direct-client-call? | Go
replacement | data/config conversion | temporary coexistence | disposition`.

**Temporary coexistence — umbrella answer.** Per design doc §2 (decision D5)
and §5: big-bang cutover on a long-lived integration branch; `main` swaps
once. Per §2 (D9) and §20: fresh DB from Atlas + seed data at go-live, no
dual-write; the old Supabase env may stay read-only briefly for *comparison
only*, never in the runtime path. **This applies uniformly to every row
below** unless a row calls out a specific exception (e.g., a webhook URL
re-registration is a one-time flip, not a coexistence period).

#### PostgreSQL

| Column | Value |
|---|---|
| used-by feature | All — every feature persists through the shared Postgres instance |
| direct-client-call? | No — reached only via PostgREST/RPC/Edge Functions/webapp SSR clients, never a raw DB connection from a client |
| Go replacement | Self-hosted Postgres on the VPS (§16, §18) — same engine, re-platformed |
| data/config conversion | Drop `auth.users`/`auth.uid()` coupling (16 references, §2); ownership FKs move to an internal `users.id` (§13 baseline); connection config moves from Supabase's pooler to VPS-local Postgres |
| temporary coexistence | None — see umbrella answer; fresh Atlas-baselined DB at go-live (D9) |
| disposition | **Keep, re-platform** |

#### Supabase Auth

| Column | Value |
|---|---|
| used-by feature | authentication (Flutter), webapp `login`/`auth/callback` (both removal targets, §6) |
| direct-client-call? | Yes — 5 Supabase Auth SDK call sites / 4 files (§4's `auth` table: `Supabase.initialize`, `onAuthStateChange` ×2, `signInWithIdToken`, `signOut`), plus webapp's `signInWithOAuth`/`exchangeCodeForSession`/`updateSession` via `src/lib/supabase/{client,server,middleware}.ts` (§6) |
| Go replacement | Firebase Auth + internal-UUID identity (§10, §16) |
| data/config conversion | `auth.users` table (and everything FK'd to it) replaced by an internal `users` table; the 10 `presentation/`-layer `currentUser?.id` reads across 7 files (§4) must move to an app-level current-user provider |
| temporary coexistence | None — testers re-create accounts via Firebase login (D9); no dual-auth period |
| disposition | **Replace** — Firebase Auth |

#### PostgREST (`.from`)

| Column | Value |
|---|---|
| used-by feature | matching, notification, profile, task, report, currency, billing (point), payout — see §4's full 18-row call-site table |
| direct-client-call? | Yes — design doc §16 cites the raw grep baseline of 31; §4 reconciled this to **18 real call sites over 9 tables** (13 of 31 are Dart `Map.from`/`List.from` false positives, not Supabase calls) |
| Go replacement | Per-table `/api/v1/...` Go endpoints; only `GET /api/v1/me` is design-doc-fixed today, the rest are §4's naming proposals pending feature-phase confirmation |
| data/config conversion | RLS-scoped `eq('user_id', ...)` filters become explicit authenticated-user scoping in Go handlers; webapp's SSR reads of `user_subscriptions` (`dashboard`/`pricing`) are dropped with those routes (§6), not ported |
| temporary coexistence | None — Flutter's Supabase repositories are replaced by `ApiXxxRepository` at cutover, no side-by-side period (§5) |
| disposition | **Replace** — Go API endpoints |

#### RLS

| Column | Value |
|---|---|
| used-by feature | All 13 policy domains (evidence, judgement, matching, notification, point, profile, rating, report, reward, stripe, subscription, task, trial_point), 63 policies across 30 files (§2) |
| direct-client-call? | No — enforced transparently by Postgres/PostgREST; not a call site |
| Go replacement | Go service-layer authorization (§16); Firebase-verified JWT + application-layer checks (§13) |
| data/config conversion | **Retire all 63 policies** (§2); wallet/ledger-adjacent policies (point, trial_point, reward) flagged as possible defense-in-depth keepers — a Go-implementation decision, not designed here |
| temporary coexistence | None — RLS stays enforced on the old DB until cutover; no dual-authz period on the new stack |
| disposition | **Replace** — Go authz layer (narrow defense-in-depth RLS possibly retained, TBD) |

#### Storage

| Column | Value |
|---|---|
| used-by feature | n/a — zero usage confirmed: no `storage.buckets`/`storage.objects` reference in `supabase/schemas/`, `peppercheck_flutter/lib/`, or `peppercheck-webapp/src` (verified this investigation) |
| direct-client-call? | No |
| Go replacement | n/a — object storage is already R2 today (see R2 row), never Supabase Storage |
| data/config conversion | None needed |
| temporary coexistence | None |
| disposition | **No — unused** (confirms design doc §16) |

#### Realtime

| Column | Value |
|---|---|
| used-by feature | n/a for the client — zero `.channel(`/`RealtimeChannel`/`.stream(` usage in `peppercheck_flutter/lib/` (verified this investigation); MEMORY.md's subscription-refresh design already specifies polling, not Realtime |
| direct-client-call? | No |
| Go replacement | n/a — polling per existing subscription-refresh design (§16) |
| data/config conversion | **New finding beyond §2's scope** (functions/triggers/cron only): `supabase/schemas/subscription/tables/realtime.sql` still runs `ALTER PUBLICATION supabase_realtime ADD TABLE public.user_subscriptions`, with a comment claiming it's "so Flutter clients can detect subscription status changes" — but no client code consumes it. Dead schema config; flag as an opportunistic-refactor (§15) drop candidate during Atlas baselining |
| temporary coexistence | None |
| disposition | **No — unused** (confirms design doc §16); one dead schema object to clean up |

#### Edge Functions — Go endpoint only (4 of 12)

| Column | Value |
|---|---|
| Functions | `create-express-dashboard-link`, `payout-setup`, `handle-stripe-webhook` (Connect scope only — see 1.1 Finding 2), `generate-upload-url` |
| used-by feature | payout (Flutter `stripe_payout_repository.dart`), evidence + profile (`generate-upload-url`, shared) |
| direct-client-call? | Yes for 3 of 4 (`create-express-dashboard-link`, `payout-setup`, `generate-upload-url` — via `.functions.invoke`, §4); No for `handle-stripe-webhook` (external Stripe Dashboard webhook registration only) |
| Go replacement | Straightforward Go endpoints behind app auth middleware / signature verification (§1.3) |
| data/config conversion | Stripe secret key + webhook signing secret move from Supabase Vault to Go config/secret store; R2 credentials move similarly for `generate-upload-url` |
| temporary coexistence | None; Stripe webhook endpoint URL must be **re-registered** in the Stripe Dashboard at cutover — a one-time flip, not a coexistence period |
| disposition | **Port to Go endpoint** |

#### Edge Functions — Go endpoint + worker (2 of 12)

| Column | Value |
|---|---|
| Functions | `delete-account`, `send-notification` |
| used-by feature | account (Flutter + webapp, both callers per §1.3); notification (reached only via DB's `notify_event`, no direct client caller) |
| direct-client-call? | Yes for `delete-account` (Flutter `account_repository.dart:28` + webapp `account/delete/page.tsx:52`); No for `send-notification` (Postgres → `notify_event` → `pg_net` only) |
| Go replacement | `delete-account` → Go endpoint + worker, idempotent saga (§14, see also §3 T7-3 below); `send-notification` → Go endpoint + worker (FCM) — needs an equivalent trigger point since Postgres stops calling out over HTTP |
| data/config conversion | `delete-account`'s current implementation is best-effort/non-transactional across Stripe transfer, subscription cancel, Connect deauth, R2 cleanup — §14 requires converting this to persisted, retryable deletion state; `send-notification`'s Firebase Admin credentials move to Go config |
| temporary coexistence | None; both callers of `delete-account` (Flutter + webapp) must be re-pointed together at cutover |
| disposition | **Port to Go endpoint + worker** |

#### Edge Functions — Go worker only (2 of 12)

| Column | Value |
|---|---|
| Functions | `execute-pending-payouts`, `sweep-r2-stale-objects` |
| used-by feature | reward/payout; common (R2 hygiene) |
| direct-client-call? | No — both reached only via Postgres cron (`net.http_post`), never from Flutter/webapp |
| Go replacement | Go worker jobs (durable, §12) — the `pg_net` HTTP hop is dropped entirely, becoming an in-process worker call |
| data/config conversion | `execute-pending-payouts` and `delete-account`'s reward-payout step share near-duplicate Stripe-transfer + `deduct_reward_for_payout` logic — §1.3 recommends consolidating into one Go domain function during the port |
| temporary coexistence | None |
| disposition | **Port to Go worker** |

#### Edge Functions — Drop, unused legacy (1 of 12)

| Column | Value |
|---|---|
| Function | `billing-setup` |
| used-by feature | billing (Flutter `stripe_billing_repository.dart:22`) — **confirmed dead**, see 1.1 Finding 3 |
| direct-client-call? | Yes in code, but unreachable in practice (no mounted UI caller) |
| Go replacement | None — not ported |
| data/config conversion | n/a — delete Flutter caller alongside (`stripe_billing_repository.dart`, `billing_setup_section.dart`, `billing_controller.dart`'s billing-setup wiring) |
| temporary coexistence | None |
| disposition | **Drop** |

#### Edge Functions — Dropped, feature removed (1 of 12)

| Column | Value |
|---|---|
| Function | `create-stripe-checkout` |
| used-by feature | webapp `SubscribeButton.tsx` (removal target, §6) |
| direct-client-call? | Yes, webapp only — no Flutter caller |
| Go replacement | None — web subscribe checkout is removed per §9/§11, not ported |
| data/config conversion | n/a |
| temporary coexistence | None |
| disposition | **Dropped** (web subscribe removed) |

#### Edge Functions — Removed, replaced externally (1 of 12)

| Column | Value |
|---|---|
| Function | `handle-google-play-rtdn` |
| used-by feature | subscription — see the dedicated Google Play RTDN row below |
| direct-client-call? | No — external Google Cloud Pub/Sub push only |
| Go replacement | None on our side — RevenueCat ingests RTDN directly (§11) |
| data/config conversion | See Google Play RTDN row |
| temporary coexistence | None |
| disposition | **Removed** |

#### Edge Functions — Operator tool (1 of 12)

| Column | Value |
|---|---|
| Function | `recommend-payout-topup` |
| used-by feature | operator only — no automated caller found (no cron entry, no app invocation); auth via `X-Operator-Secret` |
| direct-client-call? | No (not app-facing); manual operator invocation only |
| Go replacement | **Go operator endpoint** (resolved by operator adjudication — see §2 "Operator resolutions," item on `get_payout_topup_metrics`: the endpoint exposes that read-only aggregate) |
| data/config conversion | `OPERATOR_AUTH_TOKEN` moves to Go config |
| temporary coexistence | None |
| disposition | **Port as a Go operator endpoint** (resolved; no longer "endpoint or script" — see §2) |

**Edge Functions reconciliation:** 4 (endpoint) + 2 (endpoint+worker) + 2
(worker) + 1 (drop, unused) + 1 (dropped, feature removed) + 1 (removed,
externally replaced) + 1 (operator tool) = **12 of 12**, matching §1.3's
totals line exactly ("2 dropped, 1 removed, 1 operator tool, 2 → worker, 6 →
endpoint [4 endpoint-only + 2 endpoint+worker]"). Plus the **`payout-request`
launch-blocker** (§4, §1.3): Flutter calls `.functions.invoke('payout-request')`
but no such Edge Function exists (404 today) — needs a net-new Go payout
endpoint, not a port; see §3.

#### DB Functions (68)

| Column | Value |
|---|---|
| used-by feature | All — full per-function table in §2 |
| direct-client-call? | Mixed — 21 of 68 called directly from Flutter via `.rpc()`/`.rpc<T>()` (§4's rpc table, 21 call sites = 21 distinct functions, zero duplicates); the rest are internal (triggers, other functions, or Edge Functions only) |
| Go replacement | Category split: business orchestration / authorization / external side-effect (41) → Go; integrity-atomicity / query-set (23) → stay in Postgres; obsolete Supabase-only support (4) → delete |
| data/config conversion | `auth.uid()`-gated functions (14, category 4) become explicit user-scoped SQL called from Go with an app-supplied user id; `get_point_for_matching_strategy` (#9) stays in Postgres for retained trigger callers but needs a duplicated Go constant for moved callers (§2, §4); `handle_new_user` (#43) is a special case — its trigger *mechanism* dies with Supabase Auth, but its provisioning logic (profile/notification_settings/user_ratings/point_wallet/trial_point_wallet creation) needs an explicit Go-side "create user" onboarding step, not a drop (§2, resolved — move-to-Go) |
| temporary coexistence | None; per §2, "completion is NOT all functions deleted" — complex transactional routines may remain behind the Go store post-cutover |
| disposition | **Split** — stay-in-Postgres **23** / move-to-Go **41** / delete **4** (matches §2's tally exactly) |

#### Triggers (36)

| Column | Value |
|---|---|
| used-by feature | matching, judgement, evidence, rating, task, auth (onboarding) for the 15 business triggers; all domains with `updated_at` columns for the 21 housekeeping triggers (§2) |
| direct-client-call? | No — fire on DB writes only, never called directly |
| Go replacement | 21 housekeeping (`set_updated_at`) stay as minimal DB triggers; of 15 business triggers, 10 move to Go (matching insert/update ×2, judgement notify/close/settle ×5, evidence notify ×1, `on_auth_user_created` ×1 — mechanism deleted, logic ported) and 5 stay in Postgres as invariant/derived-state triggers (`on_rating_histories_change_update_user_ratings`, `on_judgement_confirmed_close_request`, `on_task_evidences_{insert,update}_validate_due_date`, `on_all_judgements_confirmed_close_task`) |
| data/config conversion | Go-side equivalents for the 10 moved triggers become explicit calls inside the same business-orchestration functions that already move (e.g., `settle_evidence_timeout`'s notify step folds into the Go evidence-settlement flow) |
| temporary coexistence | None — new schema ships without the 10 moved triggers from day one |
| disposition | **Split** — 21 housekeeping + 5 business = **26 stay-in-Postgres**; **10 business move-to-Go** (matches §2's tally: 15 + 21 = 36) |

#### Cron (10)

| Column | Value |
|---|---|
| used-by feature | matching (1), judgement (3), notification (3), reward (2), common/R2 (1) — full table in §2 |
| direct-client-call? | No — internal `pg_cron` schedule, unreachable by any client |
| Go replacement | Go `worker`'s internal scheduler (§12); supercronic/ticker as periodic enqueue trigger; **all 10** business jobs move — "none of the 10 are pure DB-internal maintenance" (§2), so nothing stays as `pg_cron` |
| data/config conversion | 2 of 10 (`sweep-r2-stale-objects`, `execute-pending-payouts`) already call out via `pg_net`/`net.http_post` to Edge Functions today — these become direct in-process Go worker jobs, dropping the HTTP hop; underlying SQL for 3 of 10 (`detect_and_handle_review_timeouts`, `detect_auto_confirms`, `detect_and_handle_evidence_timeouts`) can remain Postgres functions the worker calls via RPC rather than being rewritten (§2) |
| temporary coexistence | None — `pg_cron` schedule entries retire with the old DB |
| disposition | **Move to Go worker** — all 10 (matches §2's tally) |

#### Stripe Connect (payouts)

| Column | Value |
|---|---|
| used-by feature | payout (Flutter `stripe_payout_repository.dart`), reward/payout cron+worker |
| direct-client-call? | Yes — `payout-setup`, `create-express-dashboard-link` via `.functions.invoke`; `payout-request` also invoked but 404s today (launch-blocker, no backing function); `execute-pending-payouts` reached only by DB cron, never by a client |
| Go replacement | Go endpoints for onboarding / dashboard-link / payout-request (net-new); Go worker for `execute-pending-payouts`; `handle-stripe-webhook`'s `account.updated` handler only (1.1 Finding 2) |
| data/config conversion | `stripe_accounts`'s 4 Connect columns (`stripe_connect_account_id`, `charges_enabled`, `payouts_enabled`, `connect_requirements`) carry over as-is (1.1 Finding 1); Stripe API key + Connect webhook signing secret move from Supabase Vault to Go config/secret store; webapp's static `stripe/connect/return`/`refresh` pages must keep resolving post-webapp-migration (§6) |
| temporary coexistence | None; Stripe webhook endpoint URL re-registration in the Stripe Dashboard is a one-time cutover flip |
| disposition | **Keep — port to Go** (money-out, unchanged per §11); `payout-request` is a Phase-0 launch-blocker needing net-new implementation (§3) |

#### Stripe Billing (subscription / card-on-file)

| Column | Value |
|---|---|
| used-by feature | billing (Flutter `stripe_billing_repository.dart` — **confirmed dead**, 1.1 Finding 3), webapp `SubscribeButton.tsx`/`pricing`/`dashboard` (removal targets, §6) |
| direct-client-call? | Yes in code but dead in practice — `billing-setup` has no mounted UI caller; `create-stripe-checkout`'s only caller (`SubscribeButton.tsx`) is itself a removal target |
| Go replacement | **None** — subscription entitlement moves to RevenueCat (§11 "Money in"); Stripe Billing is dropped outright, not ported |
| data/config conversion | n/a — being deleted; `stripe_accounts`'s 6 Billing-only columns become dead columns, drop during Atlas baselining (§15) rather than carry into the new schema; `handle-stripe-webhook`'s 3 subscription-event handlers drop from the Go port (1.1 Finding 2) |
| temporary coexistence | None — dropped, no port, no coexistence |
| disposition | **Drop** — `billing-setup` (unused legacy) + `create-stripe-checkout` (web subscribe removed); Flutter's `stripe_billing_repository.dart` + `billing_setup_section.dart` should be deleted, not ported (1.1 Finding 3) |

#### Google Play RTDN

| Column | Value |
|---|---|
| used-by feature | subscription — server-to-server only, no Flutter/webapp caller (§1.3) |
| direct-client-call? | No — external Google Cloud Pub/Sub push subscription, OIDC-token-verified |
| Go replacement | **None on our side** — RevenueCat ingests Google Play RTDN directly (§11); `handle-google-play-rtdn` is removed outright, not ported |
| data/config conversion | Google Play Developer Console's Pub/Sub topic/RTDN target must be repointed from our Supabase function URL to RevenueCat's ingestion endpoint — RC-side setup, not app code. **Not explicitly called out as a step in any Phase 0/5 roadmap text reviewed for this investigation; worth confirming it's on the RevenueCat setup checklist** before Phase 5 |
| temporary coexistence | None — cutover is a config change on Google's/RevenueCat's side, not a code coexistence period |
| disposition | **Removed** — RevenueCat takes over (confirms §11/§16) |

#### R2

| Column | Value |
|---|---|
| used-by feature | evidence (photo uploads), profile (avatar uploads), common (stale-object sweep), account (best-effort avatar cleanup on deletion) |
| direct-client-call? | No — Flutter never talks to R2 directly; it calls `generate-upload-url` and receives a presigned PUT URL, consistent with the engineering policy of never handing R2 keys to the client |
| Go replacement | Go endpoint issues the presigned URL (replaces `generate-upload-url`); Go worker runs the stale-object sweep (replaces `sweep-r2-stale-objects`) — both already covered under the Edge Function rows above |
| data/config conversion | R2 itself is unchanged — already the object store, already S3-compatible, already presigned-URL-based; only the presign-issuing process moves from a Supabase Edge Function to a Go endpoint; R2 credentials move from Supabase function env vars to Go's config/secret store |
| temporary coexistence | None — the R2 bucket/objects are not migrating data, only the presign-issuer changes |
| disposition | **Keep, re-point issuer** — R2 stays; only the Go-vs-Edge-Function presign issuer changes (design doc §16's "Storage: No / target R2" reflects that R2 was already the real storage target, not new) |

#### FCM

| Column | Value |
|---|---|
| used-by feature | notification — `user_fcm_tokens` table + `notification_repository.dart`'s register/unregister; dispatch reached via `notify_event()` → `send-notification`, called from many DB triggers/RPCs across the schema (fan-out out of scope for §1.3's edge-function-only table) |
| direct-client-call? | Yes for token registration (2 `.from('user_fcm_tokens')` call sites, §4); No for dispatch (server-side only) |
| Go replacement | Go endpoint for token registration (covered under PostgREST row); Go endpoint + worker for dispatch (covered under Edge Function "endpoint + worker" row) — §1.3 flags the Go port needs an equivalent trigger point (synchronous Go-API call vs. worker-consumed outbox) since Postgres stops calling out via `pg_net` |
| data/config conversion | Firebase Admin SDK credentials move from Supabase function env vars to Go's config/secret store; the 10 move-to-Go notification-dispatch triggers/functions (category 5, §2) become the new call sites feeding FCM dispatch, replacing `notify_event`'s `pg_net` hop |
| temporary coexistence | None |
| disposition | **Keep provider, replace dispatch path** — FCM itself unchanged; Postgres→`pg_net`→Edge-Function dispatch replaced by Go-native dispatch (endpoint or worker/outbox) |

### 1.3 Edge Function detail table

> Source: `docs/superpowers/plans/phase0-parts/01b-edge-functions.md`. Source
> of truth for target disposition: program design doc §17 "Edge Function →
> Go Mapping." Enumerates every directory under `supabase/functions/`
> (excluding dotfiles and `.env`/`.env.staging`, which were not opened) as of
> 2026-07-22. For each function: purpose (from its `index.ts` entrypoint),
> caller(s) (Flutter, webapp, or internal Postgres cron/trigger), the §17 Go
> destination, and a disposition summary.

| Edge function | Purpose | Caller(s) | Go destination (§17) | Disposition |
|---|---|---|---|---|
| `billing-setup` | Creates/fetches a Stripe `Customer` and issues a `SetupIntent` + ephemeral key for off-session card registration. | `peppercheck_flutter/lib/features/billing/data/stripe_billing_repository.dart:22` (`_supabase.functions.invoke('billing-setup')`). | **Drop — currently unused.** | Callable code path exists in Flutter, but §17 states its UI (`BillingSetupSection`) is not mounted on any screen — dead legacy flow from a pre-IAP billing design. Remove with the dormant Stripe billing UI/repo (D8); do not port. |
| `create-stripe-checkout` | Resolves/creates a Stripe `Customer`, looks up a `Price` by lookup key or explicit `price_id`, creates a Stripe Checkout `Session` (subscription or one-off) and returns its URL. | `peppercheck-webapp/src/components/SubscribeButton.tsx:36`. | **Dropped** (web subscribe removed). | Only caller is the webapp's web-pricing/checkout flow, which §9 marks as a remove target (purchase moves to in-app IAP). Consistent with the design doc; drop entirely, no Go port. |
| `create-express-dashboard-link` | Authenticates the user, looks up their `stripe_accounts.stripe_connect_account_id`, and creates a Stripe Express **login link** to the connected account's dashboard. | `peppercheck_flutter/lib/features/payout/data/stripe_payout_repository.dart:73` (`invoke('create-express-dashboard-link')`). | Go endpoint (Stripe Connect). | Straightforward auth + Stripe Connect passthrough; port as a Go endpoint behind the app's auth middleware. |
| `payout-setup` | Gets-or-creates a `stripe_accounts` row + Stripe Express Connect account for the user, refreshes `charges_enabled`/`payouts_enabled`/`connect_requirements`, and returns a Stripe `accountLinks` onboarding URL (`refresh_url`/`return_url` point at `peppercheck-webapp/.../stripe/connect/{refresh,return}`). | `peppercheck_flutter/lib/features/payout/data/stripe_payout_repository.dart:57` (`invoke('payout-setup')`). | Go endpoint (Stripe Connect onboarding). | Port as a Go endpoint; note the coupling to the webapp's static `stripe/connect/return`/`refresh` pages (kept per §6) — those return/refresh URLs must keep resolving after the webapp migrates. |
| `execute-pending-payouts` | Batch job: fetches up to 100 `reward_payouts` rows with `status='pending'`, creates an idempotent Stripe `Transfer` per row to the referee's Connect account, marks each payout success/failed, and deducts the reward wallet via the `deduct_reward_for_payout` RPC. On per-row failure, calls `notify_event` with `notification_payout_failed_referee`. | Postgres cron, not a client. `supabase/schemas/reward/cron/cron_execute_pending_payouts.sql:4,8` schedules a `net.http_post` to `.../functions/v1/execute-pending-payouts`. | Go **worker** (durable). | Money-moving batch job; §17 explicitly routes it to the durable Go worker rather than an HTTP endpoint. No Flutter/webapp caller — only reachable via the DB cron. See §3 T7-1 for an idempotency gap in this function. |
| `recommend-payout-topup` | Operator-only report: reads `get_payout_topup_metrics` RPC + live Stripe balance, computes a recommended Stripe balance top-up (JPY) to cover projected referee payout obligations through month end, and returns the recommendation with a "transfer-initiate deadline" (7 JP business days before the next scheduled payout run). Auth via constant-time `X-Operator-Secret` header check against `OPERATOR_AUTH_TOKEN`. | No caller found in `peppercheck_flutter/lib/`, `peppercheck-webapp/src`, or `supabase/schemas` cron/trigger SQL — only referenced in `supabase/functions/.env.example` (env var docs) and `supabase/config.toml` (function registration). Invoked manually by the operator (`X-Operator-Secret` design confirms this). | **Operator tool.** | Not app-facing and not cron-scheduled. **Resolved by operator adjudication**: port to a **Go operator endpoint** (see §2 "Operator resolutions") — the ambiguity between "endpoint or standalone operator script" is closed in favor of the endpoint. |
| `handle-stripe-webhook` | Verifies the Stripe webhook signature and handles `checkout.session.completed`, `customer.subscription.{updated,deleted}`, `invoice.payment_succeeded`, and `account.updated` — upserts `user_subscriptions`, resets subscription points via `reset_subscription_points` RPC, deactivates trial points, and syncs `stripe_accounts.{charges_enabled,payouts_enabled,connect_requirements}` on Connect account changes. | External: registered as a webhook endpoint URL in the Stripe Dashboard, not invoked from app code. No caller found in `peppercheck_flutter/lib/` or `peppercheck-webapp/src`; `supabase/snippets/setup_stripe_account_webhook_test.sql` is manual test setup only. | Go endpoint (signed, idempotent). | Port as a signature-verified Go endpoint; must stay idempotent per §17 given Stripe's at-least-once delivery. Re-register the endpoint URL with Stripe as part of cutover. **Scope narrowing**: per 1.1 Finding 2, the Go port keeps only the `account.updated` (Connect) case — the 3 Billing case-handlers are dropped, not carried over by default. |
| `handle-google-play-rtdn` | Verifies a Google Pub/Sub push OIDC token, decodes the RTDN envelope, and on subscription notifications fetches Play `subscriptionsv2` state, upserts `user_subscriptions`, resets points, and deactivates trial points. Always returns HTTP 200 (even on internal failure) to avoid Pub/Sub retry storms. | External: registered as a Google Cloud Pub/Sub push subscription endpoint, not invoked from app code. No caller found in `peppercheck_flutter/lib/` or `peppercheck-webapp/src`; only referenced in `supabase/functions/.env.example` and `supabase/config.toml`. | **Removed** (RevenueCat ingests RTDN). | §17: RevenueCat takes over Google Play RTDN ingestion, so this function is dropped outright, not ported. |
| `generate-upload-url` | Authenticates the user, validates `content_type`/extension/file size, verifies task ownership (for `kind='evidence'`) or scopes to the caller (`kind='avatar'`), derives a namespaced R2 key, and returns an R2 (S3-compatible) presigned `PUT` URL plus the eventual public URL. | `peppercheck_flutter/lib/features/evidence/data/evidence_repository.dart:40` and `peppercheck_flutter/lib/features/profile/data/profile_repository.dart:73` (both `invoke('generate-upload-url')`). | Go endpoint (R2 presigned upload). | Port as a Go endpoint; per the global engineering policy the Go API should keep issuing presigned URLs rather than handing R2 keys to the client — this function already does that. |
| `delete-account` | Multi-step account-deletion saga: checks `check_account_deletable` RPC, (unless `force`) pays out any positive reward wallet balance via a Stripe `Transfer` before deletion, best-effort cancels an active Stripe subscription and deauthorizes the Connect account, best-effort deletes R2 avatar objects, then calls `auth.admin.deleteUser` (DB `CASCADE`/`SET NULL` handles the rest). | `peppercheck_flutter/lib/features/account/data/account_repository.dart:28` (`invoke('delete-account')`) and `peppercheck-webapp/src/app/[locale]/account/delete/page.tsx:52` (same function, web account-deletion page — kept per §6). | Go endpoint + worker (idempotent saga, §14). | Two callers (Flutter + webapp), both must be re-pointed at the Go endpoint. §17/§14 call for an idempotent saga design — the current implementation is best-effort/non-transactional across several external side effects (Stripe transfer, subscription cancel, Connect deauth, R2 cleanup), which is exactly the gap §14 flags for the Go port. See §3 T7-3. |
| `send-notification` | Looks up FCM tokens for a set of `user_ids`, sends a localized multicast push (Android + APNs loc-key payloads) via Firebase Admin, and prunes tokens FCM reports as invalid/unregistered. | Postgres, not a client. `supabase/schemas/notification/functions/notify_event.sql:55,70` (`notify_event()` calls `net.http_post` to the `send-notification` Edge Function; doc comment on line 70 confirms). `notify_event` itself is called from many DB triggers/RPCs across the schema (out of scope for this table). | Go endpoint + worker (FCM). | No direct Flutter/webapp caller — reached only via the DB's `notify_event` helper. Go port needs an equivalent trigger point (either the Go API calling out synchronously, or a worker consuming an outbox/queue) rather than Postgres calling out over HTTP via `pg_net`. |
| `sweep-r2-stale-objects` | Cron sweep: deletes evidence-photo R2 objects under `evidence/<date>/` older than 90 days, and deletes orphaned/stale `avatar/<userId>/` objects (any object that isn't the user's current `avatar_url`, with a 10-minute grace period to avoid racing fresh uploads). Supports `dry_run`. | Postgres cron, not a client. `supabase/schemas/common/cron/cron_sweep_r2_stale_objects.sql:8,12` schedules a `net.http_post` to `.../functions/v1/sweep-r2-stale-objects`. | Go **worker**. | No Flutter/webapp caller — only reachable via the DB cron, same pattern as `execute-pending-payouts`. §17 routes both stale-object sweep and payout execution to the durable Go worker. |

**Totals: 12 edge function directories found → 12 rows.** 2 dropped
(`billing-setup`, `create-stripe-checkout`), 1 removed (`handle-google-play-rtdn`),
1 operator tool (`recommend-payout-topup`), 2 → Go worker (`execute-pending-payouts`,
`sweep-r2-stale-objects`), 6 → Go endpoint (`create-express-dashboard-link`,
`payout-setup`, `handle-stripe-webhook`, `generate-upload-url`, `delete-account`,
`send-notification`; the latter two are endpoint **+** worker per §17).

Verification:

```
$ ls -1 supabase/functions/ | grep -v '^\.' | wc -l
      12
```

Confirms exactly 12 edge function directories, matching the 12 rows above.

> The `payout-request` launch-blocker (Flutter calls a nonexistent Edge
> Function) is documented in full, with proposed fix and owning phase, in
> §3 — not repeated here to avoid duplication.

### 1.4 Completeness verification

**Every §16 integration has a row.** Program design doc §16 lists 11 items:
PostgreSQL ✓, Supabase Auth ✓, PostgREST ✓, RLS ✓, Storage ✓, Realtime ✓,
Edge Functions (12 → expanded into 7 class rows) ✓, DB Functions ✓, Triggers
✓, Cron ✓, Webhooks (Stripe + Google Play RTDN → expanded into 3 rows:
Stripe Connect, Stripe Billing, Google Play RTDN, per the brief's explicit
ask to split Stripe) ✓. Plus 2 rows requested beyond §16's own list: R2, FCM
(both already implied by §16's "Storage → R2" target and the
`send-notification`/FCM dispatch chain, but not broken out as their own §16
rows in the design doc). **Total: 21 rows**, all with a non-empty
`disposition` cell.

**Every edge-function disposition matches §1.3.** Reconciled inline above:
4 (endpoint) + 2 (endpoint+worker) + 2 (worker) + 1 (drop) + 1 (dropped) + 1
(removed) + 1 (operator tool) = 12 of 12, matching §1.3's totals line
exactly, plus the `payout-request` launch-blocker carried forward to §3.

**DB-logic disposition summary matches §2's tally.** DB Functions row:
stay-in-Postgres 23 / move-to-Go 41 / delete 4 — copied verbatim from §2's
"Function tally" table, not re-derived. Triggers row: 26 stay (21
housekeeping + 5 business) / 10 move — copied from §2's "Trigger tally."
Cron row: 10/10 move to Go worker — copied from §2's cron table.

**No empty disposition cells.** All 21 rows in 1.2 carry an explicit
disposition value (Keep/Replace/Split/Drop/Removed/Port/etc.) — verified by
re-reading each row while assembling this document.

### 1.5 Concerns for Phase 0 sign-off

1. **`stripe_accounts` needs an explicit split decision before the Atlas
   baseline is drafted** — this document identifies which columns are
   Connect vs. Billing (1.1 Finding 1), but whether the new schema keeps
   one table with the Billing columns dropped, or splits into two tables, is
   a schema-design decision for whoever drafts the Atlas baseline, not
   decided here.
2. **`handle-stripe-webhook`'s scope narrowing (1.1 Finding 2) is a
   correction to the naive "one porting unit" framing.** Flag this explicitly
   to whoever executes the Edge Function → Go port so the 3 Billing
   case-handlers aren't carried over by default.
3. **Recommend deleting `stripe_billing_repository.dart` +
   `billing_setup_section.dart` + their controller wiring as one PR**, now
   that 1.1 Finding 3 confirms `BillingSetupSection` has zero mount
   points — this resolves §4's open question with a concrete answer
   (delete, don't port) rather than leaving it as a pending joint decision.
4. **`profiles.stripe_connect_account_id` (bonus finding) and the dead
   `ALTER PUBLICATION supabase_realtime` statement (Realtime row) are both
   schema debris outside §2's function/trigger/cron scope** — neither is a
   function, trigger, or cron entry, so neither could have been caught by
   that inventory's grep methodology. Worth a broader one-time schema-debris
   sweep during Atlas baselining (§15) rather than assuming §2's 68/36/10
   counts are the complete list of things to clean up.
5. **Google Play RTDN's Play-Console-side repointing to RevenueCat isn't
   named as an explicit step anywhere read for this investigation** (design
   doc §11 says "RC ingests RTDN" but doesn't spell out the Play Console
   config change). Confirm it's on the RevenueCat setup checklist before
   Phase 5, not assumed to happen automatically.
6. `recommend-payout-topup` has no automated caller (no cron entry, no app
   invocation found) — its only trigger mechanism is a human calling it with
   `X-Operator-Secret`. Phase 0 should confirm there isn't an out-of-repo
   cron (e.g. a GitHub Actions scheduled workflow, or an external
   uptime/cron service) invoking it that this repo-only grep would miss.
7. `send-notification` and the two worker-bound functions
   (`execute-pending-payouts`, `sweep-r2-stale-objects`) are invoked from
   Postgres via `pg_net`'s `net.http_post`, not from application code. This
   repo-only investigation did not enumerate every DB trigger that
   ultimately calls `notify_event` → `send-notification`; that fan-out is
   out of scope for §1.3's table and would need its own inventory if the Go
   port changes the trigger point (e.g., moving from synchronous `pg_net`
   calls to a worker-consumed outbox).
8. This document reuses part-file findings verbatim per the assembly
   brief's instruction ("do not re-derive counts — cite them") — any
   correction to the underlying counts should be made in the source
   investigation, then this baseline re-assembled.

## 2. DB Logic Classification

> Source: `docs/superpowers/plans/phase0-parts/02-db-logic-classification.md`.
> Scope: `supabase/schemas/` only (declarative schema source of truth;
> migrations are generated from it and not separately inventoried).

### 2.1 Classification framework (program design §13)

Each function / business trigger / cron gets one of six categories, then a
coarse disposition:

1. integrity/atomicity → stay-in-Postgres
2. query/set → stay-in-Postgres
3. business orchestration → move-to-Go
4. authorization → move-to-Go
5. external side effect → move-to-Go (endpoint or worker)
6. obsolete Supabase support → delete

Retained by default: wallet/ledger mutations, job claiming (`FOR UPDATE SKIP
LOCKED`), row-locked state transitions. Moved by default: `auth.uid()`
checks, notification dispatch, external HTTP, provider webhooks,
UI-oriented response assembly.

### 2.2 Object counts (verified against `supabase/schemas/`)

| Object | grep count | Baseline expectation | Match |
|---|---|---|---|
| `CREATE [OR REPLACE] FUNCTION` | 68 | ~68 | yes |
| `CREATE [OR REPLACE] TRIGGER` | 36 | 36 | yes (21 housekeeping + 15 business) |
| `cron.schedule(...)` | 10 | 10 | yes |
| `CREATE POLICY` | 63 | 63 | yes |
| `auth.users` references | 16 | ~13 FK anchors | see note below |

Note on `auth.users` count: the ~13 FK-anchor estimate undercounts because
several tables reference `auth.users(id)` for more than one column pattern
and the `handle_new_user`/`on_auth_user_created` files reference `auth.users`
multiple times (trigger target + comments). No reconciliation needed — all
16 hits are legitimate FK/trigger-target references tied to Supabase Auth's
`auth.users` table, which is itself an artifact of the current auth model
(see the `handle_new_user` resolution below).

No file-count or `CREATE TRIGGER` vs `CREATE OR REPLACE TRIGGER`
discrepancies were found; all objects below are accounted for 1:1 against
the grep baseline.

### 2.3 Functions (68)

| # | function | file | category | disposition | note |
|---|---|---|---|---|---|
| 1 | `process_pending_requests()` | `matching/functions/process_pending_requests.sql` | 3 | move-to-Go (worker) | Cron orchestrator: expires stale pending requests (refunds via `route_unlock_points`), retries `process_matching` for the rest. |
| 2 | `update_referee_available_time_slot(...)` | `matching/functions/update_referee_available_time_slot.sql` | 4 | move-to-Go | `auth.uid()`-gated single-row CRUD + overlap validation. |
| 3 | `create_matching_request(...)` | `matching/functions/create_matching_request.sql` | 3 | move-to-Go | Locks points (`lock_points`, retained) then inserts request; hardcoded strategy→cost table (TODO comment in source already flags this). |
| 4 | `detect_and_handle_referee_timeouts()` | `matching/functions/detect_referee_timeouts.sql` | 6 | **delete (verify before drop)** | **Dead code.** Byte-for-byte duplicate business logic of `detect_and_handle_review_timeouts` (judgement domain), but has no `cron.schedule` entry anywhere in `matching/cron/` — unscheduled and unreferenced. **Resolved by operator adjudication — see 2.7.1.** |
| 5 | `create_referee_available_time_slot(...)` | `matching/functions/create_referee_available_time_slot.sql` | 4 | move-to-Go | `auth.uid()`-gated CRUD + overlap validation. |
| 6 | `auto_score_timeout_referee()` [trigger fn] | `matching/functions/auto_score_timeout_referee.sql` | 3 | move-to-Go | Inserts negative referee rating when a `review_timeout` judgement is confirmed. Logically overlaps with `settle_review_timeout`'s own negative-rating insert (both guarded by `ON CONFLICT DO NOTHING`, so idempotent, but redundant). **Resolved by operator adjudication — move-to-Go with dedup, see 2.7.3.** |
| 7 | `process_matching(uuid)` | `matching/functions/process_matching.sql` | 3 | move-to-Go | Core matching algorithm (availability, workload balancing, obligation priority, random tie-break) + 2 `notify_event` calls. Highest-complexity function in the schema. |
| 8 | `trigger_process_matching()` [trigger fn] | `matching/functions/process_matching.sql` (L265) | 3 | move-to-Go | Thin wrapper invoking `process_matching` on insert/update to `pending`. |
| 9 | `get_point_for_matching_strategy(strategy)` | `matching/functions/get_point_for_matching_strategy.sql` | 2 | stay-in-Postgres | Pure stateless lookup (hardcoded `standard`→1). Called by both retained triggers (`on_evidence_timeout_settle`, `on_review_timeout_settle`, `detect_auto_confirms`) and moving endpoints — keep in Postgres for the retained callers; duplicate the constant in Go for moved callers. |
| 10 | `create_referee_blocked_date(...)` | `matching/functions/create_referee_blocked_date.sql` | 4 | move-to-Go | `auth.uid()`-gated CRUD. |
| 11 | `cancel_referee_assignment(uuid)` | `matching/functions/cancel_referee_assignment.sql` | 3 | move-to-Go | Multi-step: cancel request, delete judgement, insert re-match request, notify. |
| 12 | `get_active_referee_tasks()` | `matching/functions/get_active_referee_tasks.sql` | 4 | move-to-Go | `auth.uid()`-scoped read, UI-shaped nested `jsonb` assembly. |
| 13 | `delete_referee_available_time_slot(uuid)` | `matching/functions/delete_referee_available_time_slot.sql` | 4 | move-to-Go | `auth.uid()`-gated delete. |
| 14 | `get_payment_summary()` | `payment_summary/functions/get_payment_summary.sql` | 4 | move-to-Go | `auth.uid()`-scoped dashboard aggregate read across 5 wallet/reward tables; UI-shaped response. |
| 15 | `delete_referee_blocked_date(uuid)` | `matching/functions/delete_referee_blocked_date.sql` | 4 | move-to-Go | `auth.uid()`-gated delete. |
| 16 | `update_referee_blocked_date(...)` | `matching/functions/update_referee_blocked_date.sql` | 4 | move-to-Go | `auth.uid()`-gated CRUD. |
| 17 | `lock_trial_points(...)` | `trial_point/functions/lock_trial_points.sql` | 1 | stay-in-Postgres | `FOR UPDATE` wallet mutation + ledger insert. |
| 18 | `deactivate_trial_points(uuid)` | `trial_point/functions/deactivate_trial_points.sql` | 1 | stay-in-Postgres | Idempotent wallet-state mutation on subscription start. |
| 19 | `route_consume_points(...)` | `trial_point/functions/route_consume_points.sql` | 1 | stay-in-Postgres | Pure routing dispatcher (trial vs regular) to retained wallet functions. |
| 20 | `unlock_trial_points(...)` | `trial_point/functions/unlock_trial_points.sql` | 1 | stay-in-Postgres | `FOR UPDATE` wallet mutation + ledger insert. |
| 21 | `route_referee_reward(...)` | `trial_point/functions/route_referee_reward.sql` | 1 | stay-in-Postgres | Routes to obligation fulfillment or `grant_reward` (retained). |
| 22 | `consume_trial_points(...)` | `trial_point/functions/consume_trial_points.sql` | 1 | stay-in-Postgres | `FOR UPDATE` wallet mutation + ledger insert + obligation creation. |
| 23 | `route_unlock_points(...)` | `trial_point/functions/route_unlock_points.sql` | 1 | stay-in-Postgres | Pure routing dispatcher to retained wallet functions. |
| 24 | `update_user_ratings()` [trigger fn] | `rating/functions/update_user_ratings.sql` | 2 | stay-in-Postgres | Recomputes aggregate rating counts/pct on `rating_histories` change — invariant maintenance, no external calls. |
| 25 | `notify_judgement_confirmed()` [trigger fn] | `judgement/triggers/on_judgement_confirmed_notify.sql` | 5 | move-to-Go | Push-notification dispatch (2x `notify_event`) on auto-confirm. |
| 26 | `close_referee_request_on_confirmed()` [trigger fn] | `judgement/triggers/on_judgement_confirmed_close_request.sql` | 1 | stay-in-Postgres | Single derived-state UPDATE (`task_referee_requests.status = 'closed'`), same-transaction consistency with judgement confirm. |
| 27 | `handle_judgement_confirmed()` [trigger fn] | `judgement/triggers/on_judgement_confirmed.sql` | 5 | move-to-Go | Push-notification dispatch on manual confirm. |
| 28 | `settle_evidence_timeout()` [trigger fn] | `judgement/triggers/on_evidence_timeout_settle.sql` | 5 | move-to-Go | Mixed: wallet settlement via `route_consume_points`/`route_referee_reward` (retained calls) + close request + 2x `notify_event`. Classified by its externally-visible side effect (notifications); wallet sub-calls stay as Postgres functions invoked from the Go orchestration. |
| 29 | `settle_review_timeout()` [trigger fn] | `judgement/triggers/on_review_timeout_settle.sql` | 5 | move-to-Go | Same pattern as #28: unlock points (retained call) + negative rating insert + close + 2x notify. Redundant rating insert with #6 — **resolved by operator adjudication, see 2.7.3.** |
| 30 | `on_judgements_status_changed()` [trigger fn] | `judgement/triggers/on_judgements_status_changed.sql` | 5 | move-to-Go | Status-change → notification key mapping + dispatch. |
| 31 | `judge_evidence(...)` | `judgement/functions/judge_evidence.sql` | 4 | move-to-Go | `auth.uid()`-gated single state transition (approve/reject). |
| 32 | `confirm_evidence_timeout(uuid)` | `judgement/functions/confirm_evidence_timeout.sql` | 4 | move-to-Go | `auth.uid()`-gated idempotent confirm. |
| 33 | `confirm_review_timeout(uuid)` | `judgement/functions/confirm_review_timeout.sql` | 4 | move-to-Go | `auth.uid()`-gated idempotent confirm. |
| 34 | `detect_auto_confirms()` | `judgement/functions/detect_auto_confirms.sql` | 1 | stay-in-Postgres | `FOR UPDATE SKIP LOCKED` job-claiming loop; settles points/rewards/rating via retained calls; **no external HTTP**. Candidate to remain a Postgres function invoked by the Go cron worker via RPC. |
| 35 | `detect_and_handle_review_timeouts()` | `judgement/functions/detect_review_timeouts.sql` | 2 | stay-in-Postgres | Single set-based `UPDATE ... FROM ... WHERE`, no side effects beyond the status column. |
| 36 | `confirm_judgement_and_rate_referee(...)` | `judgement/functions/confirm_judgement_and_rate_referee.sql` | 3 | move-to-Go | Multi-step: settle wallet + grant reward + insert rating + confirm, all `auth.uid()`-gated. **See §3 T7-2** — no explicit row lock; a race is possible under wallet headroom. |
| 37 | `on_task_evidences_upserted_notify_referee()` [trigger fn] | `evidence/triggers/on_task_evidences_upserted_notify_referee.sql` | 5 | move-to-Go | Notification dispatch on evidence insert/update. |
| 38 | `validate_evidence_due_date()` [trigger fn] | `evidence/functions/validate_evidence_due_date.sql` | 1 | stay-in-Postgres | Pure invariant check (due-date cutoff), no side effects. |
| 39 | `resubmit_evidence(...)` | `evidence/functions/resubmit_evidence.sql` | 3 | move-to-Go | Multi-table: evidence update, asset add/remove, judgement status transition (`rejected`→`in_review`), `auth.uid()`-gated. |
| 40 | `update_evidence(...)` | `evidence/functions/update_evidence.sql` | 4 | move-to-Go | `auth.uid()`-gated evidence + asset CRUD (no judgement-status change). |
| 41 | `submit_evidence(...)` | `evidence/functions/submit_evidence.sql` | 3 | move-to-Go | Multi-table: evidence insert, asset insert, judgement status transition, `auth.uid()`-gated. |
| 42 | `detect_and_handle_evidence_timeouts()` | `evidence/functions/detect_evidence_timeouts.sql` | 2 | stay-in-Postgres | Single set-based `UPDATE ... FROM ... WHERE`, no side effects. |
| 43 | `handle_new_user()` [trigger fn] | `auth/functions/handle_new_user.sql` | 3 | **move-to-Go** | Provisions profile + notification_settings + user_ratings + point_wallet + trial_point_wallet on signup. **Business logic moves** (reimplemented as a Go onboarding step after Firebase user creation); the trigger *mechanism* (listening on Supabase's `auth.users`) is what's obsolete, not the provisioning logic itself. **Confirmed by operator adjudication — this is the D2 provisioning path, see 2.7.4.** |
| 44 | `notify_event(...)` | `notification/functions/notify_event.sql` | 5 | move-to-Go | Reads Vault secrets, calls `net.http_post` to the `send-notification` Edge Function. Textbook external side effect. |
| 45 | `send_deadline_reminder(...)` | `notification/functions/send_deadline_reminder.sql` | 5 | move-to-Go | Idempotency log insert + `notify_event` dispatch. |
| 46 | `detect_judgement_deadline_warnings()` | `notification/functions/detect_judgement_deadline_warnings.sql` | 5 | move-to-Go | Scans + dispatches reminders via `send_deadline_reminder`. |
| 47 | `detect_evidence_deadline_warnings()` | `notification/functions/detect_evidence_deadline_warnings.sql` | 5 | move-to-Go | Same pattern as #46. |
| 48 | `detect_auto_confirm_deadline_warnings()` | `notification/functions/detect_auto_confirm_deadline_warnings.sql` | 5 | move-to-Go | Same pattern as #46; default OFF (`auto_confirm_reminder_minutes` NULL by default per comment). |
| 49 | `reset_subscription_points(...)` | `point/functions/reset_subscription_points.sql` | 1 | stay-in-Postgres | Idempotent (via ledger check) wallet reset on renewal; invoked by whatever handles the RevenueCat/Stripe renewal event (that caller moves to Go; this mutation stays). |
| 50 | `consume_points(...)` | `point/functions/consume_points.sql` | 1 | stay-in-Postgres | `FOR UPDATE` wallet mutation + ledger insert. |
| 51 | `lock_points(...)` | `point/functions/lock_points.sql` | 1 | stay-in-Postgres | `FOR UPDATE` wallet mutation + ledger insert. |
| 52 | `unlock_points(...)` | `point/functions/unlock_points.sql` | 1 | stay-in-Postgres | `FOR UPDATE` wallet mutation + ledger insert. |
| 53 | `handle_updated_at()` [trigger fn] | `common/functions/handle_updated_at.sql` | 2 | stay-in-Postgres | Generic `updated_at = now()` setter, used by all 21 housekeeping triggers. |
| 54 | `is_task_referee(task_uuid, user_uuid)` | `profile/functions/auth_helpers.sql` (L1) | 6 | delete | RLS-only helper (`SECURITY DEFINER`, `SET row_security = 'off'`). Only caller: `tasks_policies.sql` RLS policy. Not a drop candidate ahead of the broader RLS retirement — see 2.6. |
| 55 | `is_task_referee_candidate(task_uuid, user_uuid)` | `profile/functions/auth_helpers.sql` (L19) | 6 | delete | RLS-only helper, same caller as #54. Same note as #54. |
| 56 | `is_task_tasker(task_uuid, user_uuid)` | `profile/functions/auth_helpers.sql` (L37) | 6 | **delete (verify before drop)** | **Fully unreferenced** — no RLS policy or function calls it anywhere in `supabase/schemas/`. Already dead today, independent of the refactor. **Resolved by operator adjudication — see 2.7.2.** |
| 57 | `close_task_if_all_judgements_confirmed()` [trigger fn] | `task/triggers/on_all_judgements_confirmed_close_task.sql` | 1 | stay-in-Postgres | Row-locked (`FOR UPDATE` on `tasks`) state transition — closes task when all judgements confirmed. |
| 58 | `create_task(...)` | `task/functions/create_task.sql` | 3 | move-to-Go | Multi-step: validate inputs, validate open-requirements, insert task, create referee requests (which locks points). `SECURITY INVOKER` (relies on caller's RLS grants — another Supabase-specific mechanism). |
| 59 | `update_task(...)` | `task/functions/update_task.sql` | 3 | move-to-Go | Same multi-step pattern as #58, plus ownership + status-transition checks. |
| 60 | `delete_task(uuid)` | `task/functions/delete_task.sql` | 4 | move-to-Go | `auth.uid()`-gated ownership + status check + single delete. |
| 61 | `validate_task_inputs(...)` | `task/functions/utils/validate_task_inputs.sql` | 3 | move-to-Go | Pure business-rule validation, tightly coupled to `create_task`/`update_task` (both move); easy to port. |
| 62 | `create_task_referee_requests_from_json(...)` | `task/functions/utils/create_task_referee_requests_from_json.sql` | 3 | move-to-Go | Multi-step: cost calc, trial-vs-regular point-source decision, loop insert + lock (calls retained `lock_trial_points`/`lock_points`). |
| 63 | `validate_task_open_requirements(...)` | `task/functions/utils/validate_task_open_requirements.sql` | 3 | move-to-Go | Business-rule validation: due-date minimum, point-balance sufficiency (trial-first fallback to regular). |
| 64 | `prepare_monthly_payouts(...)` | `reward/functions/prepare_monthly_payouts.sql` | 3 | move-to-Go (worker) | Batch orchestration: last-day-of-month guard, exchange-rate lookup, per-wallet Stripe Connect readiness check, payout row insert, notify. |
| 65 | `deduct_reward_for_payout(...)` | `reward/functions/deduct_reward_for_payout.sql` | 1 | stay-in-Postgres | Optimistic-concurrency (`WHERE balance >= amount`) wallet mutation + ledger insert. |
| 66 | `grant_reward(...)` | `reward/functions/grant_reward.sql` | 1 | stay-in-Postgres | Upsert wallet mutation + ledger insert. |
| 67 | `get_payout_topup_metrics(text)` | `reward/functions/get_payout_topup_metrics.sql` | 2 | stay-in-Postgres | Read-only ops aggregate, `REVOKE`d from `anon`/`authenticated`, `GRANT`ed to `service_role` only — internal admin/ops query, not app-facing. **Resolved by operator adjudication — exposed via a Go operator endpoint, see 2.7.5.** |
| 68 | `check_account_deletable()` | `account/functions/check_account_deletable.sql` | 4 | move-to-Go | `auth.uid()`-gated read-only precondition check, called from both the Flutter app and the `delete-account` Edge Function. |

#### Function tally

| Disposition | Count |
|---|---|
| stay-in-Postgres (cat 1 + 2) | 23 (cat 1: 17, cat 2: 6) |
| move-to-Go (cat 3 + 4 + 5) | 41 (cat 3: 16, cat 4: 14, cat 5: 11) |
| delete (cat 6) | 4 |
| **Total** | **68** |

**Note (operator adjudication, 2026-07-22):** `get_payout_topup_metrics`
(#67) remains tallied as **stay-in-Postgres** (category 2) — the read-only
aggregate SQL itself stays in Postgres behind the Go store — but its Phase-0
ambiguity is now resolved rather than open: it is exposed to the operator
via a **Go operator endpoint**, which replaces the operator-tool role that
`recommend-payout-topup` held in the Supabase design (§1.3, §2.7.5). The
23/41/4 tally is unchanged by this — only the *access path* to #67 changes,
not its stay-in-Postgres disposition.

### 2.4 Business triggers (15) + housekeeping summary

| # | trigger | file | function called | category | disposition |
|---|---|---|---|---|---|
| 1 | `on_task_referee_requests_update_process_matching` | `matching/triggers/on_task_referee_requests_update_process_matching.sql` | `trigger_process_matching()` | 3 | move-to-Go |
| 2 | `on_task_referee_requests_insert_process_matching` | `matching/triggers/on_task_referee_requests_insert_process_matching.sql` | `trigger_process_matching()` | 3 | move-to-Go |
| 3 | `on_rating_histories_change_update_user_ratings` | `rating/triggers/on_rating_histories_change_update_user_ratings.sql` | `update_user_ratings()` | 2 | stay-in-Postgres |
| 4 | `on_judgement_confirmed_notify` | `judgement/triggers/on_judgement_confirmed_notify.sql` | `notify_judgement_confirmed()` | 5 | move-to-Go |
| 5 | `on_judgement_confirmed_close_request` | `judgement/triggers/on_judgement_confirmed_close_request.sql` | `close_referee_request_on_confirmed()` | 1 | stay-in-Postgres |
| 6 | `on_evidence_timeout_settle` | `judgement/triggers/on_evidence_timeout_settle.sql` | `settle_evidence_timeout()` | 5 | move-to-Go |
| 7 | `on_judgements_timeout_score_referee` | `judgement/triggers/on_judgements_timeout_score_referee.sql` | `auto_score_timeout_referee()` | 3 | move-to-Go |
| 8 | `on_judgements_status_changed` | `judgement/triggers/on_judgements_status_changed.sql` | `on_judgements_status_changed()` | 5 | move-to-Go |
| 9 | `on_review_timeout_settle` | `judgement/triggers/on_review_timeout_settle.sql` | `settle_review_timeout()` | 5 | move-to-Go |
| 10 | `on_judgement_confirmed` | `judgement/triggers/on_judgement_confirmed.sql` | `handle_judgement_confirmed()` | 5 | move-to-Go |
| 11 | `on_task_evidences_insert_validate_due_date` | `evidence/triggers/on_task_evidences_insert_validate_due_date.sql` | `validate_evidence_due_date()` | 1 | stay-in-Postgres |
| 12 | `on_task_evidences_upserted_notify_referee` | `evidence/triggers/on_task_evidences_upserted_notify_referee.sql` | `on_task_evidences_upserted_notify_referee()` | 5 | move-to-Go |
| 13 | `on_task_evidences_update_validate_due_date` | `evidence/triggers/on_task_evidences_update_validate_due_date.sql` | `validate_evidence_due_date()` | 1 | stay-in-Postgres |
| 14 | `on_auth_user_created` | `auth/triggers/on_auth_user_created.sql` | `handle_new_user()` | 3 | **move-to-Go** (mechanism deleted, logic ported — resolved, see 2.7.4) |
| 15 | `on_all_judgements_confirmed_close_task` | `task/triggers/on_all_judgements_confirmed_close_task.sql` | `close_task_if_all_judgements_confirmed()` | 1 | stay-in-Postgres |

**Housekeeping triggers (21, summary row):** all `on_<table>_update_set_updated_at` triggers across `matching`, `trial_point`, `rating`, `judgement`, `evidence`, `notification`, `point`, `subscription`, `profile`, `task`, `reward` (×4), `report`, `stripe` — all call `handle_updated_at()`. Category 2, disposition **stay-in-Postgres** (trivial, low-regret to keep as a DB-level convenience; equally fine to have the Go data layer set `updated_at` explicitly on every UPDATE if preferred).

#### Trigger tally

| Disposition | Count |
|---|---|
| stay-in-Postgres (business, cat 1+2) | 5 |
| move-to-Go (business, cat 3+5) | 10 |
| stay-in-Postgres (housekeeping, 1 summary row = 21 triggers) | 21 |
| **Total triggers accounted for** | **15 + 21 = 36** |

### 2.5 Cron (10)

| # | schedule name | frequency | job | disposition | note |
|---|---|---|---|---|---|
| 1 | `process-pending-requests` | hourly (`0 * * * *`) | `matching/cron/cron_process_pending_requests.sql` → `process_pending_requests()` | move-to-Go (worker) | |
| 2 | `detect-review-timeouts` | every 5 min | `judgement/cron/cron_detect_review_timeout.sql` → `detect_and_handle_review_timeouts()` | move-to-Go (worker) | Scheduling moves; the SQL function itself (cat 2) can remain a Postgres function the worker calls via RPC. |
| 3 | `detect-auto-confirms` | hourly | `judgement/cron/cron_detect_auto_confirm.sql` → `detect_auto_confirms()` | move-to-Go (worker) | Function itself (cat 1, job-claiming) can remain a Postgres function the worker calls via RPC. |
| 4 | `detect-evidence-timeouts` | every 5 min | `judgement/cron/cron_detect_evidence_timeout.sql` → `detect_and_handle_evidence_timeouts()` | move-to-Go (worker) | Function itself (cat 2) can remain a Postgres function the worker calls via RPC. |
| 5 | `detect-auto-confirm-deadline-warnings` | every minute | `notification/cron/cron_detect_auto_confirm_deadline_warnings.sql` → `detect_auto_confirm_deadline_warnings()` | move-to-Go (worker) | |
| 6 | `detect-evidence-deadline-warnings` | every minute | `notification/cron/cron_detect_evidence_deadline_warnings.sql` → `detect_evidence_deadline_warnings()` | move-to-Go (worker) | |
| 7 | `detect-judgement-deadline-warnings` | every minute | `notification/cron/cron_detect_judgement_deadline_warnings.sql` → `detect_judgement_deadline_warnings()` | move-to-Go (worker) | |
| 8 | `sweep-r2-stale-objects` | daily 18:00 UTC | `common/cron/cron_sweep_r2_stale_objects.sql` → `net.http_post` to `sweep-r2-stale-objects` Edge Function | move-to-Go (worker) | Already calls out to an external Edge Function directly from `pg_cron`; the Edge Function itself is covered by §1.3. |
| 9 | `prepare-monthly-payouts` | `0 15 28-31 * *` (guarded to last day) | `reward/cron/cron_prepare_monthly_payouts.sql` → `prepare_monthly_payouts('JPY')` | move-to-Go (worker) | |
| 10 | `execute-pending-payouts` | every 30 min | `reward/cron/cron_execute_pending_payouts.sql` → `net.http_post` to `execute-pending-payouts` Edge Function | move-to-Go (worker) | Same pattern as #8. See §3 T7-1 for a job-claiming gap in this function. |

**None of the 10 cron jobs are pure DB-internal maintenance** (no
`VACUUM`/`ANALYZE`/partition-rotation jobs exist in this schema) — all 10
encode product-domain business logic or external calls, so all 10 move to
the Go worker's own scheduler per the "all 10 business cron → move-to-Go
worker" framework default. The two that already call `net.http_post` (#8,
#10) are the clearest cases — they're already structurally "an external
side effect on a timer," just via `pg_cron` + `pg_net` instead of a Go
scheduler.

### 2.6 RLS summary

63 `CREATE POLICY` statements across 30 policy files (13 domains: evidence,
judgement, matching, notification, point, profile, rating, report, reward,
stripe, subscription, task, trial_point). Per program design §10,
authorization retires from Postgres RLS to the Go service layer wholesale —
**disposition: retire all 63** (auth model moves from Supabase
`auth.uid()`/RLS to Firebase-verified-JWT + application-layer authz checks
in Go). A handful of wallet/ledger-adjacent policies (point, trial_point,
reward tables) may be worth keeping as tested defense-in-depth once the Go
app owns primary authz, but that's a Go-implementation decision out of
scope for this coarse pass — **not resolved by the operator adjudication;
remains open**, see 2.7.6.

### 2.7 Operator resolutions (2026-07-22)

The source investigation (§2.8 below) flagged six ambiguous items for
operator confirmation. Five are resolved by this adjudication; one (RLS
defense-in-depth) remains open, deferred to Go-implementation design.

#### 2.7.1 `detect_and_handle_referee_timeouts()` — resolved: delete, verify before drop

**Resolved: delete (category 6), verify before drop.** The function
(`matching/functions/detect_referee_timeouts.sql`) is confirmed
unscheduled and unreferenced anywhere in `supabase/schemas/`. The operator
accepts the "dead code" classification but requires the drop to be
**verified** (not assumed silently correct) before it happens — i.e.,
confirm during the owning phase that this wasn't meant to be wired to a
cron schedule that was never added, per the source investigation's own
hedge (§7-C of this baseline). This is not a blocker; it closes the
ambiguity as "delete, with a verification step," not as "keep" or
"investigate further before deciding."

#### 2.7.2 `is_task_tasker(task_uuid, user_uuid)` — resolved: delete candidate, verify before drop

**Resolved: delete (category 6), verify before drop.** Zero callers in
`supabase/schemas/` (unlike its siblings `is_task_referee`/
`is_task_referee_candidate`, each called once from `tasks_policies.sql` —
those two are **not** drop candidates and are tied to the broader RLS
retirement, not today's dead-code list; do not conflate the three
`auth_helpers.sql` functions). The operator accepts "delete candidate" and
requires verification before drop, consistent with the historical-migration
trail (§7-C) showing it *was* called by earlier, since-refactored judgement
policies/functions — corroborating rather than contradicting "vestigial
today."

#### 2.7.3 `auto_score_timeout_referee()` + `settle_review_timeout()` redundant rating insert — resolved: move-to-Go with dedup

**Resolved: move-to-Go with dedup; not a launch blocker.** Both #6
(`auto_score_timeout_referee`, trigger `on_judgements_timeout_score_referee`)
and #29 (`settle_review_timeout`) insert the same "negative rating on
review_timeout" row, each guarded by
`ON CONFLICT (judgement_id, rating_type) DO NOTHING` — today's behavior is
correct despite the duplication. The operator's resolution: when both move
to Go (both are already category 3/5, move-to-Go), **consolidate into one
Go code path with deduplication** rather than preserving two independent
call sites asserting the same business rule. This is an implementation
instruction for the owning feature phase (judgement domain, Phase 4), not a
Phase 0 blocker — today's `ON CONFLICT DO NOTHING` protection means there is
no correctness bug to fix urgently.

#### 2.7.4 `handle_new_user()` / `on_auth_user_created` — confirmed: move-to-Go, this is the D2 provisioning path

**Resolved: move-to-Go (category 3), confirmed.** The provisioning logic —
create `profiles`, `notification_settings`, `user_ratings`, `point_wallet`,
`trial_point_wallet`, with a config-driven initial trial-point grant — is
real business logic that needs a Go-side home. The operator confirms the
framing proposed by the source investigation: the trigger *mechanism*
(`AFTER INSERT ON auth.users`, Supabase-Auth-specific) disappears entirely
under Firebase Auth + internal UUID, but the *logic* it runs is exactly the
onboarding step described in program design §10/D2 — an explicit
"create user" step the Go API runs after first-seen Firebase-authenticated
request (see also §5(a) "target" steps for the full flow). This closes
Ambiguous item #4 from the source investigation as confirmed, not merely
proposed.

#### 2.7.5 `get_payout_topup_metrics(text)` — resolved: exposed via a Go operator endpoint

**Resolved: exposed via a Go operator endpoint**, replacing the operator-tool
role `recommend-payout-topup` held in the Supabase Edge Function design
(§1.3). The read-only aggregate SQL itself (function #67, category 2)
**may stay in Postgres behind the Go store** — the resolution changes the
*access path* (a Go operator endpoint calls it, rather than a Supabase Edge
Function with `X-Operator-Secret` auth calling the RPC directly), not the
function's stay-in-Postgres disposition. This closes the "ad hoc query vs.
Go admin surface" question the source investigation left open (Ambiguous
item #5) in favor of a concrete Go admin surface. See also the Function
tally note in 2.3 and the `recommend-payout-topup` row in §1.3.

#### 2.7.6 RLS defense-in-depth candidates — remains open

**Not resolved by this adjudication.** The proposal to keep a handful of
wallet/ledger-adjacent RLS policies (point, trial_point, reward tables) as
tested defense-in-depth once the Go app owns primary authz is a design
recommendation, not a decision — it remains open, to be confirmed with the
operator during Go-implementation design (feature phase, not Phase 0).

### 2.8 Original ambiguous items (source investigation, pre-resolution)

Retained verbatim for audit trail — cross-referenced by 2.7 above.

1. **`detect_and_handle_referee_timeouts()`** (`matching/functions/detect_referee_timeouts.sql`) is byte-for-byte duplicate business logic of `detect_and_handle_review_timeouts()` (`judgement/functions/detect_review_timeouts.sql`) — both transition `in_review` judgements past `due_date + 3h` to `review_timeout`. Only the judgement-domain one has a `cron.schedule` entry; the matching-domain one is unscheduled and unreferenced anywhere in the schema. Classified here as dead code (category 6, delete), but confirm this wasn't meant to be wired to a different cron schedule before dropping it. → **Resolved 2.7.1.**
2. **`is_task_tasker(task_uuid, user_uuid)`** (`profile/functions/auth_helpers.sql`) has zero callers anywhere in `supabase/schemas/` — not even in an RLS policy (unlike its two siblings, which are used once by `tasks_policies.sql`). It appears to already be dead code today, independent of the refactor. Confirm before deleting in case something outside `supabase/schemas/` (e.g., an Edge Function or ad-hoc query) calls it directly. → **Resolved 2.7.2.**
3. **`auto_score_timeout_referee()`** (trigger `on_judgements_timeout_score_referee`, fires on *every* `judgements` UPDATE with no `WHEN` clause) inserts the same "negative rating on review_timeout" row that `settle_review_timeout()` already inserts on the status transition into `review_timeout`. Both are protected by `ON CONFLICT (judgement_id, rating_type) DO NOTHING`, so behavior is currently correct, but the redundancy means there are two independent code paths asserting the same business rule. Worth deciding whether to fold this into one path when porting to Go, or preserve both intentionally. → **Resolved 2.7.3.**
4. **`handle_new_user()` / `on_auth_user_created`**: classified as category 3 (business orchestration) → move-to-Go, *not* category 6 (obsolete/delete), even though the trigger mechanism itself (`AFTER INSERT ON auth.users`) is Supabase-Auth-specific and disappears entirely under Firebase Auth + internal UUID. The distinction matters: the *provisioning logic* (create profile, notification_settings, user_ratings, point_wallet, trial_point_wallet with config-driven initial grant) is real business logic that needs a Go-side home (e.g., an explicit "create user" step invoked after first-seen Firebase-authenticated request), not something to simply drop. Confirm this framing matches the intended Go onboarding design. → **Resolved 2.7.4.**
5. **`get_payout_topup_metrics(text)`**: `service_role`-only ops/admin query (no `anon`/`authenticated` grant), likely backing an internal metrics view rather than the app. Classified as stay-in-Postgres (category 2) as a low-priority item, but confirm whether it should instead move to Go alongside `prepare_monthly_payouts` if there's a Go admin surface being planned, or just be queried ad hoc post-migration. → **Resolved 2.7.5.**
6. **RLS defense-in-depth candidates**: the RLS summary proposes retiring all 63 policies to Go authz, with wallet/ledger tables (point, trial_point, reward) as possible keep-as-defense-in-depth candidates. This is a design recommendation, not a decision — confirm with the operator during Go-implementation design, not here. → **Open, see 2.7.6.**

## 3. Launch-Blocker Register

> Synthesized from `docs/superpowers/plans/phase0-parts/01b-edge-functions.md`
> (the `payout-request` orphan) and the financial-integrity risks surfaced
> by §5's critical-journey behavior catalog, which the operator adjudicated
> into this register as candidates on 2026-07-22.

### 3.1 `payout-request` — confirmed launch blocker

**Status:** Confirmed bug, fix planned.

**Evidence:**
- `supabase/functions/` contains no `payout-request` directory. `ls
  supabase/functions/ | grep -i payout` returns only
  `execute-pending-payouts`, `payout-setup`, and `recommend-payout-topup` —
  no `payout-request`.
- Yet Flutter calls it:
  `peppercheck_flutter/lib/features/payout/data/stripe_payout_repository.dart:93`
  invokes `_supabase.functions.invoke('payout-request', ...)` inside
  `stripe_payout_repository.dart`'s payout-request method.
- Calling this today hits Supabase's default 404 for an unregistered
  function name — the referee-initiated "request my payout now" action in
  the app has no working backend. Program design doc §17 (line 482) already
  records this exact finding: `**payout-request** (called by Flutter, no
  edge fn exists) → **Phase-0 bug**; implement as a Go payout endpoint`.

**Proposed fix:** Implement a Go payout endpoint (`POST /payouts` or
similar) as part of the Go API's payout surface, alongside the ported
`payout-setup` and `create-express-dashboard-link` endpoints. Since
`execute-pending-payouts` already contains the actual Stripe `Transfer` +
wallet-deduction logic (as a batch job over `reward_payouts` rows with
`status='pending'`), the new endpoint's likely job is simply to insert a
`reward_payouts` row with `status='pending'` (i.e., "request" a payout that
the worker will later execute) rather than duplicate the money-movement
logic — but confirm the intended UX (immediate transfer vs. queued-for-
next-run) during the owning phase's design.

**Owning phase:** Phase 5 — "Financial & subscription" (program §22:
"point/trial-point, reward/payout; ... keep Stripe Connect payouts").
Confirmed against the §22 roadmap table, the correct home for the
payout-request implementation work alongside
`payout-setup`/`create-express-dashboard-link`/`execute-pending-payouts`.

### 3.2 T7 financial-integrity risks — operator-adjudicated candidates

> **Adjudication basis note (applies to all three items below):** these
> findings are reasoned from reading the current Supabase implementation
> (SQL functions/triggers, Edge Functions) as documented in §5's critical-
> journey behavior catalog — they are **not test-confirmed**. Phase 0 does
> not write executable characterization tests against the system being
> deleted (Phase 0 spec §2, "Tests" scoping row). The Go rewrite must build
> the corresponding safeguard per program design §11 (payout/webhook
> idempotency — "Stripe account/event IDs protected by unique constraints"),
> §14 (account-deletion saga — "idempotent, persisted deletion state"), and
> §24 (testing strategy — ledger/payout idempotency and deletion-retry
> tests). All three are already on the program's §23 "never-defer" safety-
> valve list ("ledger + payout idempotency; in-app + web account
> deletion") — so closing them is not optional schedule-pressure scope.

#### T7-1 — Payout idempotency gaps

**Status:** Candidate — verify in owning phase.

**Evidence** (from §5, flow (c) Payout — Invariants and Edge cases):
- `execute-pending-payouts` does not claim rows before working them: it
  `SELECT`s `status='pending'` rows and only flips status to
  `success`/`failed` *after* the Stripe call — there is no `FOR UPDATE SKIP
  LOCKED` claim step (contrast with `detect_auto_confirms`, which does use
  `FOR UPDATE SKIP LOCKED`). If the cron's HTTP call overlaps with itself
  (e.g., a slow run still executing when the next 30-minute trigger fires),
  two concurrent invocations could both fetch the same pending row. Stripe's
  deterministic idempotency key means the *Transfer* itself is not
  duplicated, but `deduct_reward_for_payout` could still be attempted twice
  for the same row concurrently — the atomic `WHERE balance >= amount`
  update means only one succeeds and the other raises (logged as
  `CRITICAL: Deduct failed`), which does not roll back the already-`success`
  payout row.
- `reward_payouts.stripe_transfer_id` has **no `UNIQUE` constraint**
  (`supabase/schemas/reward/tables/reward_payouts.sql`). The "applied at
  most once" property for a given payout row currently rests entirely on
  (a) Stripe's own idempotency-key deduplication and (b)
  `deduct_reward_for_payout`'s optimistic-concurrency check — not on a DB
  constraint that would catch, e.g., two *different* `reward_payouts` rows
  accidentally referencing the same real-world transfer.

**Proposed fix:** In the Go worker's job-claiming pattern, use a durable
row-claim with `FOR UPDATE SKIP LOCKED` (per program §12) before attempting
each payout's Stripe transfer, closing the concurrent-fetch gap. Add a
`UNIQUE` constraint on the Go-era schema's payout/transfer-id column so a
second row cannot silently reference the same real-world transfer.

**Owning phase:** Phase 5 — Financial & subscription (payout execution is
built in this phase; the idempotency safeguard is a program §23 never-defer
item within it).

#### T7-2 — Judgement double-confirm race

**Status:** Candidate — verify in owning phase.

**Evidence** (from §5, flow (d) Judgement state machine — Edge cases):
`confirm_judgement_and_rate_referee` does `SELECT ... INTO v_judgement FROM
judgements j JOIN ...` with **no `FOR UPDATE`**, then later checks
`is_confirmed` and settles. Two near-simultaneous calls (e.g. a double-tap
firing two RPCs) could both read `is_confirmed=false` before either
commits, and both proceed to call
`route_consume_points`/`route_referee_reward`. Whether this actually
double-spends depends on wallet headroom: `consume_points` itself takes
`SELECT ... FOR UPDATE` on the wallet, so if the tasker's `locked` balance
has *only* this judgement's lock, the second call's `locked` check fails
safely — but if the tasker has other unrelated locked amounts providing
headroom, the second call's wallet check could pass, double-consuming
points. The transaction would only be caught downstream, when the second
call's `INSERT INTO rating_histories` hits the
`unique_rating_per_judgement UNIQUE (judgement_id, rating_type)` constraint
and the entire function's transaction rolls back — meaning the current
design is likely safe today, but by **incidental** protection from a unique
constraint placed *after* the money-moving calls, not by an explicit lock.
A future code change (e.g., reordering the rating insert earlier, or
removing it) would silently remove this protection. Not covered by any
existing pgTAP test — the existing idempotency tests
(`test_confirm_judgement.sql` Test 2, `test_reward_system.sql` Test 9) are
sequential (call, assert, call again), not concurrent.

**Proposed fix:** Add an explicit row lock (`SELECT ... FOR UPDATE` on
`judgements`) in the Go port's equivalent flow, or a `WHERE is_confirmed =
false` guard on the final UPDATE combined with checking the affected row
count — rather than relying on the incidental unique-constraint ordering
that happens to protect today's implementation.

**Owning phase:** Phase 5 — Financial & subscription (per the operator's
explicit assignment; this finding touches the point/reward ledger settlement
path even though the state-machine code itself is judgement-domain work
landing in Phase 4).

#### T7-3 — Account-deletion fund-loss

**Status:** Candidate — verify in owning phase.

**Evidence** (from §5, flow (e) Account deletion — Invariants and Edge
cases):
- `reward_wallets.user_id` is `ON DELETE CASCADE` to `auth.users(id)`
  (`supabase/schemas/reward/tables/reward_wallets.sql`) — a reward wallet,
  and any un-paid-out balance it holds, is deleted outright (not orphaned or
  preserved) when the owning account is deleted.
- `force=true` bypasses the payout-must-succeed gate in `delete-account`'s
  step 3 entirely (skips the step altogether) — a user with a positive
  reward balance who forces deletion loses that balance, since nothing pays
  it out or otherwise preserves it before the cascade fires.
- Separately, if step 3 (payout) succeeds but step 7
  (`auth.admin.deleteUser`) later fails for an unrelated reason (e.g. a
  transient Admin API error), the user's reward balance is now gone even
  though their account was **not** deleted — there is no durable, persisted
  "payout done, deletion not yet done" resume state; a retry of the whole
  saga infers this only indirectly (`reward_wallets.balance = 0` on retry,
  which happens to skip step 3 again correctly, but only by accident of the
  balance-zero check, not by a designed idempotency/resume mechanism).

**Proposed fix:** Build the account-deletion saga with idempotent, persisted
deletion state per program design §14 — each external step (including the
reward payout) is its own durable, retryable unit with an explicit resume
state, so a step-7 failure after a step-3 payout is representable and
recoverable rather than inferred after the fact. Separately, get an explicit
product decision on whether `force=true` should still attempt payout (or
block deletion) before the reward-wallet cascade fires, rather than
silently losing the balance as today's implementation does.

**Owning phase:** Phase 6 — Account deletion & cleanup (program §22: "idempotent
deletion saga across Firebase/RC/Stripe/R2/DB").

## 4. Flutter API-Surface Map

> Source: `docs/superpowers/plans/phase0-parts/04-flutter-api-surface.md`.
> Every place `peppercheck_flutter/lib/` talks to Supabase directly:
> PostgREST table calls (`.from(`), Postgres RPC calls (`.rpc(`), and Edge
> Function invocations (`.functions.invoke`), plus the small set of Supabase
> Auth calls that don't fit those three kinds but are needed for full file
> coverage.

### 4.1 Grep-count reconciliation (baseline vs. actual)

The baseline grep commands and their literal counts:

```
grep -rn "\.from(" peppercheck_flutter/lib/       → 31 lines
grep -rn "\.rpc(" peppercheck_flutter/lib/        → 19 lines
grep -rn "\.functions\.invoke" peppercheck_flutter/lib/ → 7 lines
grep -rln "supabase_flutter\|Supabase\.instance\|SupabaseClient" peppercheck_flutter/lib/ → 24 files
```

All four raw counts match the stated baseline exactly. However, two of the
three counts include noise or undercounts once inspected line-by-line:

#### `.from(` — 31 raw hits, only **18 are real Supabase calls**

`grep "\.from("` also matches Dart's built-in `Map<K, V>.from(...)` and
`List<T>.from(...)` collection constructors, which are unrelated to
`SupabaseQueryBuilder.from('table_name')`. Of the 31 hits:

- **18** are genuine `SupabaseClient.from('table_name')` PostgREST calls (see table below).
- **13** are Dart `Map.from(...)` / `List.from(...)` false positives:
  `notification/application/fcm_service.dart:151`;
  `task/data/task_repository.dart:107,114,118,136,221,227,231,248` (8 hits);
  `task/presentation/widgets/task_creation/matching_strategy_selection_section.dart:45,57`;
  `account/data/account_repository.dart:37`;
  `billing/presentation/widgets/plan_selection_bottom_sheet.dart:44`.

This matters for the refactor headcount: the real PostgREST surface is 18
call sites over 9 tables, not 31.

#### `.rpc(` — 19 vs. 21: the independent reviewer's 21 is correct

`grep "\.rpc("` requires the literal substring `.rpc(` — no characters
between `rpc` and `(`. It misses **generic-typed** calls of the form
`_supabase.rpc<String>('function_name', ...)`, because `<String>` sits
between `rpc` and `(`. Two call sites use this generic form and were
silently dropped by the baseline grep:

- `peppercheck_flutter/lib/features/matching/data/matching_repository.dart:43` — `_supabase.rpc<String>('create_referee_available_time_slot', ...)`
- `peppercheck_flutter/lib/features/matching/data/matching_repository.dart:90` — `_supabase.rpc<String>('create_referee_blocked_date', ...)`

**Reconciled count: 21 `.rpc(` call sites, 21 distinct function names, zero
duplicates** (verified by extracting every function-name string literal
immediately following `.rpc(`/`.rpc<...>(` — no name repeats). The 19-vs-21
discrepancy is a **miss in the original grep pattern** (it doesn't tolerate
a generic type argument), not duplicate call sites collapsing to fewer
function names. A pattern like `grep -E "\.rpc(<[^>]+>)?\("` would have
caught all 21 in one pass. This closes program design doc §28's "reconcile
exact Flutter RPC count (measured 19; reviewer 21)" item: **21 is correct.**

#### `.functions.invoke` — 7 call sites, 6 distinct functions (confirmed)

`generate-upload-url` is invoked from two features (`evidence` and
`profile`), sharing one Edge Function; the other 5 invocations are each
1:1 with a distinct function name. 7 call sites / 6 distinct names matches
the stated baseline exactly — no discrepancy here.

### 4.2 Call-site table

`kind` is one of `from`, `rpc`, `invoke`. A supplementary `auth` group (5
sites, 4 files) is appended after — these are Supabase Auth SDK calls
(client init, sign-in, sign-out, auth-state stream) that don't fit
`from`/`rpc`/`invoke` but are part of the same migration surface and are
needed to account for all 24 Supabase-importing files.

#### `from` (PostgREST) — 18 call sites

| kind | symbol/table | file:line | feature | maps to (Go endpoint) |
|---|---|---|---|---|
| from | `referee_available_time_slots` (select, eq user_id) | `peppercheck_flutter/lib/features/matching/data/matching_repository.dart:22` | matching | `GET /api/v1/matching/availability` |
| from | `referee_blocked_dates` (select, order) | `peppercheck_flutter/lib/features/matching/data/matching_repository.dart:76` | matching | `GET /api/v1/matching/blocked-dates` |
| from | `user_fcm_tokens` (upsert onConflict:token) | `peppercheck_flutter/lib/features/notification/data/notification_repository.dart:30` | notification | `POST /api/v1/notifications/fcm-tokens` |
| from | `user_fcm_tokens` (delete eq token) | `peppercheck_flutter/lib/features/notification/data/notification_repository.dart:49` | notification | `DELETE /api/v1/notifications/fcm-tokens/{token}` |
| from | `profiles` (select, eq id, single — `fetchProfile`) | `peppercheck_flutter/lib/features/profile/data/profile_repository.dart:24` | profile | `GET /api/v1/me` (per design doc §"Identity & client boundary") |
| from | `profiles` (update timezone — `updateTimezone`) | `peppercheck_flutter/lib/features/profile/data/profile_repository.dart:38` | profile | `PATCH /api/v1/me` — TBD (feature phase) whether one combined PATCH or field-specific endpoints |
| from | `profiles` (update username — `updateUsername`) | `peppercheck_flutter/lib/features/profile/data/profile_repository.dart:50` | profile | `PATCH /api/v1/me` — TBD (feature phase); note current code also has bespoke unique-username (`23505`) error handling to preserve |
| from | `profiles` (update avatar_url — `updateAvatar`) | `peppercheck_flutter/lib/features/profile/data/profile_repository.dart:102` | profile | `PATCH /api/v1/me` — TBD (feature phase); paired with `generate-upload-url` invoke below |
| from | `tasks` (select, nested joins — list own tasks) | `peppercheck_flutter/lib/features/task/data/task_repository.dart:87` | task | `GET /api/v1/tasks` |
| from | `tasks` (select, nested joins — `getTask(id)`) | `peppercheck_flutter/lib/features/task/data/task_repository.dart:204` | task | `GET /api/v1/tasks/{id}` |
| from | `reports` (insert — `submitReport`) | `peppercheck_flutter/lib/features/report/data/report_repository.dart:25` | report | `POST /api/v1/reports` |
| from | `reports` (select id, eq reporter_id+task_id, maybeSingle — `hasReported`) | `peppercheck_flutter/lib/features/report/data/report_repository.dart:39` | report | `GET /api/v1/reports/exists?task_id=...` — TBD (feature phase) exact shape |
| from | `currencies` (select, eq code, single) | `peppercheck_flutter/lib/features/currency/data/currency_repository.dart:29` | currency | `GET /api/v1/currencies/{code}` |
| from | `user_subscriptions` (select subset, maybeSingle) | `peppercheck_flutter/lib/features/billing/data/billing_repository.dart:24` | billing | `GET /api/v1/billing/subscription` |
| from | `point_wallets` (select balance, maybeSingle) | `peppercheck_flutter/lib/features/billing/data/billing_repository.dart:45` | billing (point) | `GET /api/v1/points/wallet` |
| from | `trial_point_wallets` (select balance/locked/is_active, maybeSingle) | `peppercheck_flutter/lib/features/billing/data/billing_repository.dart:63` | billing (point) | `GET /api/v1/points/trial-wallet` |
| from | `stripe_accounts` (select charges/payouts_enabled+requirements, maybeSingle) | `peppercheck_flutter/lib/features/payout/data/stripe_payout_repository.dart:23` | payout | `GET /api/v1/payout/account` |
| from | `stripe_accounts` (select pm_brand/last4/exp, single) | `peppercheck_flutter/lib/features/billing/data/stripe_billing_repository.dart:41` | billing | Resolved by §1.1 Finding 3 — this file is confirmed dead code alongside `billing-setup`; not ported |

#### `rpc` (Postgres RPC) — 21 call sites, 21 distinct functions

| kind | symbol/table | file:line | feature | maps to (Go endpoint) |
|---|---|---|---|---|
| rpc | `create_referee_available_time_slot` (generic `.rpc<String>(`) | `peppercheck_flutter/lib/features/matching/data/matching_repository.dart:43` | matching | `POST /api/v1/matching/availability` (§2.3 #5, move-to-Go) |
| rpc | `update_referee_available_time_slot` | `peppercheck_flutter/lib/features/matching/data/matching_repository.dart:56` | matching | `PATCH /api/v1/matching/availability/{id}` (§2.3 #2, move-to-Go) |
| rpc | `delete_referee_available_time_slot` | `peppercheck_flutter/lib/features/matching/data/matching_repository.dart:68` | matching | `DELETE /api/v1/matching/availability/{id}` (§2.3 #13, move-to-Go) |
| rpc | `create_referee_blocked_date` (generic `.rpc<String>(`) | `peppercheck_flutter/lib/features/matching/data/matching_repository.dart:90` | matching | `POST /api/v1/matching/blocked-dates` (§2.3 #10, move-to-Go) |
| rpc | `update_referee_blocked_date` | `peppercheck_flutter/lib/features/matching/data/matching_repository.dart:107` | matching | `PATCH /api/v1/matching/blocked-dates/{id}` (§2.3 #16, move-to-Go) |
| rpc | `delete_referee_blocked_date` | `peppercheck_flutter/lib/features/matching/data/matching_repository.dart:119` | matching | `DELETE /api/v1/matching/blocked-dates/{id}` (§2.3 #15, move-to-Go) |
| rpc | `cancel_referee_assignment` | `peppercheck_flutter/lib/features/matching/data/matching_repository.dart:123` | matching | `POST /api/v1/matching/assignments/{id}/cancel` (§2.3 #11, move-to-Go) |
| rpc | `get_payment_summary` | `peppercheck_flutter/lib/features/payment_dashboard/data/payment_summary_repository.dart:18` | payment_dashboard | `GET /api/v1/payments/summary` (§2.3 #14, move-to-Go) |
| rpc | `judge_evidence` | `peppercheck_flutter/lib/features/judgement/data/judgement_repository.dart:20` | judgement | `POST /api/v1/judgements/judge` (§2.3 #31, move-to-Go) |
| rpc | `confirm_judgement_and_rate_referee` | `peppercheck_flutter/lib/features/judgement/data/judgement_repository.dart:40` | judgement | `POST /api/v1/judgements/{id}/confirm` (§2.3 #36, move-to-Go; see §3 T7-2) |
| rpc | `confirm_review_timeout` | `peppercheck_flutter/lib/features/judgement/data/judgement_repository.dart:56` | judgement | `POST /api/v1/judgements/{id}/confirm-review-timeout` (§2.3 #33, move-to-Go) |
| rpc | `submit_evidence` | `peppercheck_flutter/lib/features/evidence/data/evidence_repository.dart:94` | evidence | `POST /api/v1/evidence` (§2.3 #41, move-to-Go) |
| rpc | `update_evidence` | `peppercheck_flutter/lib/features/evidence/data/evidence_repository.dart:128` | evidence | `PATCH /api/v1/evidence/{id}` (§2.3 #40, move-to-Go) |
| rpc | `resubmit_evidence` | `peppercheck_flutter/lib/features/evidence/data/evidence_repository.dart:164` | evidence | `POST /api/v1/evidence/{id}/resubmit` (§2.3 #39, move-to-Go) |
| rpc | `confirm_evidence_timeout` | `peppercheck_flutter/lib/features/evidence/data/evidence_repository.dart:182` | evidence | `POST /api/v1/evidence/confirm-timeout` (§2.3 #32, move-to-Go) |
| rpc | `create_task` | `peppercheck_flutter/lib/features/task/data/task_repository.dart:32` | task | `POST /api/v1/tasks` (§2.3 #58, move-to-Go) |
| rpc | `update_task` | `peppercheck_flutter/lib/features/task/data/task_repository.dart:56` | task | `PATCH /api/v1/tasks/{id}` (§2.3 #59, move-to-Go) |
| rpc | `delete_task` | `peppercheck_flutter/lib/features/task/data/task_repository.dart:65` | task | `DELETE /api/v1/tasks/{id}` (§2.3 #60, move-to-Go) |
| rpc | `get_active_referee_tasks` | `peppercheck_flutter/lib/features/task/data/task_repository.dart:155` | task | `GET /api/v1/tasks/active` (§2.3 #12, move-to-Go) |
| rpc | `check_account_deletable` | `peppercheck_flutter/lib/features/account/data/account_repository.dart:17` | account | `GET /api/v1/account/deletable` (§2.3 #68, move-to-Go; also called from the `delete-account` Edge Function per §1.3) |
| rpc | `get_point_for_matching_strategy` | `peppercheck_flutter/lib/features/billing/data/billing_repository.dart:72` | billing (point) | TBD (feature phase) — §2.3 #9 keeps this **stay-in-Postgres** (shared with retained triggers) and says moved callers should get a **duplicated constant in Go** rather than call through; exact Go endpoint shape undecided |

#### `invoke` (Edge Function) — 7 call sites, 6 distinct functions

| kind | symbol/table | file:line | feature | maps to (Go endpoint) |
|---|---|---|---|---|
| invoke | `generate-upload-url` | `peppercheck_flutter/lib/features/evidence/data/evidence_repository.dart:39` | evidence | `POST /api/v1/uploads/presign` (per §1.3: Go endpoint, R2 presigned upload; shared with profile) |
| invoke | `generate-upload-url` | `peppercheck_flutter/lib/features/profile/data/profile_repository.dart:72` | profile | same as above — shared Edge Function, one Go endpoint |
| invoke | `delete-account` | `peppercheck_flutter/lib/features/account/data/account_repository.dart:27` | account | `POST /api/v1/account/delete` (per §1.3: Go endpoint + worker, idempotent saga — also called from webapp; see §3 T7-3) |
| invoke | `payout-setup` | `peppercheck_flutter/lib/features/payout/data/stripe_payout_repository.dart:57` | payout | `POST /api/v1/payout/setup` (per §1.3: Go endpoint, Stripe Connect onboarding) |
| invoke | `create-express-dashboard-link` | `peppercheck_flutter/lib/features/payout/data/stripe_payout_repository.dart:72` | payout | `POST /api/v1/payout/dashboard-link` (per §1.3: Go endpoint, Stripe Connect passthrough) |
| invoke | `payout-request` | `peppercheck_flutter/lib/features/payout/data/stripe_payout_repository.dart:92` | payout | **No Edge Function exists today** — confirmed launch-blocker, see §3.1. Needs a net-new Go endpoint, not a straight port. |
| invoke | `billing-setup` | `peppercheck_flutter/lib/features/billing/data/stripe_billing_repository.dart:22` | billing | Per §1.3: **Drop — currently unused** (dead pre-IAP billing flow); do not port. Its only caller, `stripe_billing_repository.dart`, is dormant legacy code per that doc's disposition. |

#### `auth` (Supabase Auth SDK, non-CRUD) — 5 call sites, 4 files

Not part of the `{from, rpc, invoke}` kinds, but included for completeness
and because they are exactly the surface the design doc's identity-
migration phase replaces.

| kind | symbol/table | file:line | feature | maps to (Go endpoint) |
|---|---|---|---|---|
| auth | `Supabase.initialize(...)` (client bootstrap) | `peppercheck_flutter/lib/app/app_startup.dart:69` | app (startup) | N/A — replaced by Firebase Auth SDK init + Go API base-URL config (design doc, Phase 2 "Identity & client boundary") |
| auth | `Supabase.instance.client.auth.onAuthStateChange` | `peppercheck_flutter/lib/features/authentication/data/auth_state_provider.dart:8` | authentication | N/A — replaced by Firebase Auth state stream |
| auth | `Supabase.instance.client.auth.signInWithIdToken(...)` | `peppercheck_flutter/lib/features/authentication/data/authentication_repository.dart:30` | authentication | N/A — replaced by Firebase Auth sign-in + `GET /api/v1/me` token exchange (design doc login flow) |
| auth | `Supabase.instance.client.auth.signOut()` | `peppercheck_flutter/lib/features/authentication/data/authentication_repository.dart:44` | authentication | N/A — replaced by Firebase Auth sign-out |
| auth | `Supabase.instance.client.auth.onAuthStateChange.listen(...)` | `peppercheck_flutter/lib/features/notification/application/fcm_service.dart:55` | notification | N/A — FCM (un)registration should hang off the new Firebase Auth state stream instead |

### 4.3 `presentation/` clean-arch violations

`grep -rln "supabase\|Supabase" peppercheck_flutter/lib/features/*/presentation/`
returns **7 files** — 2 more than the design doc's already-flagged 5
(evidence submission, judgement section, task-detail info, report menu
button, withdraw-matching button). The 2 additional hits are
`task_detail_screen.dart` (the screen itself, not just its
`task_detail_info_section.dart` sub-widget) and
`in_app_purchase_controller.dart`.

Every single hit is the same pattern: `Supabase.instance.client.auth.currentUser?.id`
— reading the current user's ID directly from the Supabase SDK inside a
`presentation/` widget/controller instead of getting it from a repository or
an app-level current-user provider. No `.from(`/`.rpc(`/`.invoke` calls leak
into `presentation/`; the violation is scoped entirely to auth-state access.

| feature | file:line | call |
|---|---|---|
| billing | `peppercheck_flutter/lib/features/billing/presentation/in_app_purchase_controller.dart:61` | `Supabase.instance.client.auth.currentUser?.id` |
| evidence | `peppercheck_flutter/lib/features/evidence/presentation/widgets/evidence_submission_section.dart:81` | `Supabase.instance.client.auth.currentUser?.id` |
| judgement | `peppercheck_flutter/lib/features/judgement/presentation/widgets/judgement_section.dart:56` | `Supabase.instance.client.auth.currentUser?.id` |
| judgement | `peppercheck_flutter/lib/features/judgement/presentation/widgets/judgement_section.dart:65` | `Supabase.instance.client.auth.currentUser?.id` |
| report | `peppercheck_flutter/lib/features/report/presentation/widgets/report_menu_button.dart:22` | `Supabase.instance.client.auth.currentUser?.id` |
| task | `peppercheck_flutter/lib/features/task/presentation/task_detail_screen.dart:65` | `Supabase.instance.client.auth.currentUser?.id` (equality check) |
| task | `peppercheck_flutter/lib/features/task/presentation/task_detail_screen.dart:90` | `Supabase.instance.client.auth.currentUser?.id` |
| task | `peppercheck_flutter/lib/features/task/presentation/task_detail_screen.dart:110` | `Supabase.instance.client.auth.currentUser?.id` |
| task | `peppercheck_flutter/lib/features/task/presentation/widgets/task_detail/task_detail_info_section.dart:158` | `Supabase.instance.client.auth.currentUser?.id` |
| task | `peppercheck_flutter/lib/features/task/presentation/widgets/task_detail/withdraw_matching_button.dart:31` | `Supabase.instance.client.auth.currentUser?.id` |

**10 individual call sites across 7 files.** All fixable the same way: expose
the current-user ID via the app-level current-user provider the design doc
already calls for ("other features must not import `firebase_auth` or read
an SDK singleton" — design doc, identity section), rather than reaching into
the Supabase (soon Firebase) SDK from `presentation/`.

### 4.4 Verification

```
$ comm -23 <(sort -u /tmp/pc-sbfiles.txt) <(grep -oE "peppercheck_flutter/lib/[^ :]+\.dart" 04-flutter-api-surface.md | sort -u)
(empty)
```

Empty output confirms all 24 Supabase-importing files are represented
somewhere in the source investigation (19 in the `from`/`rpc`/`invoke`
tables + `auth` table = 23 distinct data/auth files, plus `presentation/`
violation files already counted among those 23 where they overlap — every
file in the Supabase-importing set appears at least once).

### 4.5 Concerns for Phase 0 sign-off

- The `.from(` Go-endpoint mappings above (`/api/v1/...`) are this
  investigation's coarse proposals, not confirmed design-doc routes — the
  design doc only fixes `/api/v1/me` explicitly. Treat every route in this
  section except `/api/v1/me` as a naming suggestion to revisit in the
  owning feature phase (Phase 3 profile/reports/notifications, Phase 4
  task/matching/evidence/judgement, Phase 5 billing/points/payout), not a
  locked contract.
- `stripe_billing_repository.dart:41` (`.from('stripe_accounts')` reading
  card-on-file info) — resolved by §1.1 Finding 3: confirmed dead code,
  deleted alongside `billing-setup`, not ported.
- `payout-request` (invoke) is a confirmed pre-existing bug — see §3.1;
  repeated here only because this table would otherwise imply it maps
  cleanly like its sibling payout calls.
- The `presentation/` violation count (7 files, 10 call sites) is larger than
  the 5 files the design doc names. All 10 are the same trivial
  `currentUser?.id` pattern, so the fix is mechanical and low-risk, but scope
  the fix-it task to all 7 files, not just the 5 originally flagged.

## 5. Critical Journey & Behavior Catalog

> Source: `docs/superpowers/plans/phase0-parts/05-journey-catalog.md`.
> Documents the **expected behavior** of five high-risk flows as acceptance
> specs, grounded in the current Supabase implementation (SQL
> functions/triggers + Edge Functions + Flutter repositories), so the future
> Go rewrite can be validated against the same invariants. These are **not
> executable tests** — they are read-only characterizations of behavior that
> already exists, plus the pgTAP tests that already assert it. Where the
> target Go/Firebase design changes behavior (chiefly auth — Apple is
> net-new), that is called out explicitly as "today" vs. "target." Three
> edge cases surfaced here are promoted to launch-blocker candidates in §3
> (T7-1, T7-2, T7-3) — cross-referenced inline below.

Flows covered: (a) auth (Google today, Apple net-new), (b) point/trial-point
ledger, (c) payout (Stripe Connect), (d) judgement state machine, (e) account
deletion.

### 5(a) Auth — Google (current) + Apple (net-new)

#### Code paths
- Flutter: `peppercheck_flutter/lib/features/authentication/data/authentication_repository.dart`
  (`signInWithGoogle()`, `signOut()`), `auth_state_provider.dart` (auth-state
  stream).
- DB: `supabase/schemas/auth/functions/handle_new_user.sql` +
  `supabase/schemas/auth/triggers/on_auth_user_created.sql` (`AFTER INSERT ON
  auth.users`).
- Target (design doc §10, §22 Phase 2): Firebase Auth (Google + Apple) →
  `users` + `user_identities(issuer, subject)` tables; Go token verification;
  `GET /api/v1/me`.

#### Preconditions
- **Today**: Supabase Auth is the sole identity provider. Only Google is
  wired up — `signInWithIdToken(provider: OAuthProvider.google, idToken:
  ...)` is the only sign-in path in the repo; there is no `sign_in_with_apple`
  dependency in `peppercheck_flutter/pubspec.yaml` and no Apple-related code
  under `features/authentication/`. Apple is confirmed net-new, not a
  refactor of existing code.
- **Target**: Firebase Auth Google + Apple both live; a verified Firebase ID
  token resolves via `(issuer, subject)` → `user_identities` → internal
  `users.id`. All 13 domain FKs re-point to `users.id`, never to a provider
  UID (design doc §10).

#### Steps (today — Google only)
1. `GoogleSignIn.instance.authenticate()` obtains a Google ID token.
2. Flutter calls `Supabase.instance.client.auth.signInWithIdToken(provider:
   google, idToken: idToken)`.
3. Supabase Auth verifies the token and upserts a row in `auth.users`
   (inserts on first sign-in for this Google identity).
4. `on_auth_user_created` fires `handle_new_user()` in the same transaction
   as the `auth.users` insert: generates a unique `user_<8-hex>` username
   (retries on `unique_violation`, hard-fails after 5 attempts), then inserts
   `profiles`, `notification_settings`, `user_ratings`, `point_wallets`
   (balance=0, locked=0), and — only if
   `trial_point_config.initial_grant_amount > 0` — a `trial_point_wallets`
   row seeded with that balance plus one `trial_point_ledger` row
   (`reason='initial_grant'`).
5. Client receives a Supabase session; `auth_state_provider.dart`'s
   `onAuthStateChange` stream drives app navigation past login.
6. Sign-out: `authentication_repository.dart:signOut()` calls
   `_googleSignIn.signOut()` and `Supabase.instance.client.auth.signOut()`
   via `Future.wait([...])` — both must succeed or the combined future
   rethrows; there is no compensating rollback if one succeeds and the other
   throws.

#### Steps (target — Firebase Google + Apple, design doc §10/§22 Phase 2)
1. Firebase client SDK performs Google or Apple sign-in.
2. Firebase performs provider unification, not the Go backend: under
   *one-account-per-email*, Firebase may auto-link trusted verified-email
   providers, or raise `account-exists-with-different-credential` (e.g.
   custom/Workspace domains), which requires the app to re-authenticate with
   the existing provider and call `linkWithCredential`. The app must handle
   both paths.
3. Go API verifies the Firebase ID token, looks up `(issuer, subject)` in
   `user_identities`; on first sighting, creates the `users` row and runs the
   Go-side equivalent of `handle_new_user()`'s provisioning (profile +
   wallets + notification_settings + user_ratings, config-driven initial
   trial grant) as an explicit onboarding step — this is business logic that
   moves, the `AFTER INSERT ON auth.users` **mechanism** is what disappears
   (§2.7.4, resolved).
4. `GET /api/v1/me` returns the resolved profile.

#### Expected behavior
- Sign-in with an already-known identity resolves to the *same* internal
  user; it never creates a duplicate.
- New-user provisioning is all-or-nothing: a user must never end up with an
  `auth.users`/`users` row but a missing `profiles`, `point_wallets`, or
  `user_ratings` row. Today this is guaranteed structurally because
  `handle_new_user()` runs inside the same trigger transaction as the
  `auth.users` INSERT — a provisioning failure (e.g. exhausting the 5
  username-collision retries) raises an exception that aborts the whole
  signup, including the `auth.users` row itself.
- Initial trial-point grant is config-driven
  (`trial_point_config.initial_grant_amount`) and applied exactly once, at
  account creation.
- Same *verified* email via Google vs. Apple converges to **one** account via
  Firebase account linking (auto- or explicit). PepperCheck must never merge
  users purely on an email-string match performed in application code.
- Apple **Hide My Email** relay addresses are per-app/per-user and differ
  from the user's real email; such accounts stay **separate** from an
  existing Google account unless the user explicitly links with re-auth —
  they must not be silently merged on the relay address, and revealing the
  real email later does not retroactively trigger a merge.

#### Invariants
- One internal `users.id` per `(issuer, subject)` pair (target:
  `UNIQUE(issuer, subject)` on `user_identities`, design doc §10).
- Provisioning is transactional/all-or-nothing (see above).
- Username uniqueness is enforced with bounded retry (5 attempts today) and
  a hard failure beyond that — the Go port must not let an unbounded retry
  loop or a silent skip replace this.

#### Edge cases
- `account-exists-with-different-credential`: user signed up with Google,
  later attempts Apple sign-in with the same verified email but Firebase
  does not auto-link (e.g., a Workspace/custom domain) — the app must catch
  this and drive re-auth + `linkWithCredential`, not fail silently or create
  a second account.
- Username collision storm at signup: current retry cap is 5; confirm the Go
  port keeps an equivalent (or better) bound rather than an unbounded loop.
- Partial sign-out failure: `Future.wait([_googleSignIn.signOut(),
  Supabase...signOut()])` — if one leg throws, the other has already been
  invoked but the combined future still rethrows without confirming both
  actually completed; the Firebase-SDK port should confirm both local
  provider sign-out and Firebase sign-out are handled (or made idempotent to
  retry) rather than inheriting this partial-failure ambiguity.
- Apple Hide-My-Email churn: user disables the relay later (reveals real
  email) — must not trigger a retroactive auto-merge with an existing
  separate account.

#### pgTAP evidence
No pgTAP test exercises `handle_new_user()`/`on_auth_user_created` directly
by name — auth itself is Supabase Auth's responsibility today, out of pgTAP's
reach. The closest indirect coverage is `supabase/tests/test_trial_points.sql`
**Test 1** ("`handle_new_user` creates trial wallet"), which inserts a raw
`auth.users` row and asserts the trigger produced `trial_point_wallets`
`balance=3, locked=0, is_active=true` plus exactly one
`trial_point_ledger` row — i.e., it validates the *conditional trial-grant*
side effect of `handle_new_user()`, not username generation or the other
provisioned rows. **Gap:** no test asserts `profiles`/`notification_settings`/
`user_ratings`/`point_wallets` are also created, or that a username-collision
retry succeeds/exhausts correctly.

### 5(b) Point / trial-point ledger

#### Code paths
- DB (all `stay-in-Postgres`, category 1, per §2.3 #17–23, #49–52):
  `supabase/schemas/point/functions/{lock,consume,unlock}_points.sql`,
  `supabase/schemas/trial_point/functions/{lock,consume,unlock}_trial_points.sql`,
  `deactivate_trial_points.sql`, and routing dispatchers
  `route_consume_points.sql` / `route_unlock_points.sql` / `route_referee_reward.sql`.
- Callers (move-to-Go): `create_task_referee_requests_from_json.sql` (locks),
  `settle_evidence_timeout()`/`settle_review_timeout()` triggers (consume/
  unlock), `confirm_judgement_and_rate_referee.sql` (consume), `detect_auto_confirms.sql`
  (consume).
- Flutter reads: `billing_repository.dart` (`point_wallets`,
  `trial_point_wallets` balance reads).

#### Preconditions
- A `point_wallets` row and (conditionally) a `trial_point_wallets` row exist
  per user, created by `handle_new_user()` at signup.
- A `task_referee_requests.point_source` column (`'trial'` vs. regular)
  decides which ledger a given request routes through — set at request
  creation, read by `route_consume_points`/`route_unlock_points`.

#### Steps (lock → consume/unlock lifecycle)
1. **Lock** (`lock_points`/`lock_trial_points`): `SELECT ... FOR UPDATE` the
   wallet row, verify `(balance - locked) >= amount`, increment `locked`
   (balance unchanged), insert a ledger row with `amount = -p_amount`.
2. **Consume** (`consume_points`/`consume_trial_points`, settle path):
   `SELECT ... FOR UPDATE`, verify `balance >= amount` **and** `locked >=
   amount`, decrement both `balance` and `locked` by `amount`, insert a
   ledger row with `amount = -p_amount`. `consume_trial_points` additionally
   inserts one `referee_obligations` row per point consumed (loop over
   `p_amount`, typically 1).
3. **Unlock/release** (`unlock_points`/`unlock_trial_points`, timeout/refund
   path): `SELECT ... FOR UPDATE`, verify `locked >= amount`, decrement
   `locked` only (balance unchanged — points return to available), insert a
   ledger row with `amount = +p_amount`.
4. Routing: `route_consume_points`/`route_unlock_points` read
   `task_referee_requests.point_source` and dispatch to the trial or regular
   variant; `route_referee_reward` reads `task_referee_requests.is_obligation`
   — if true, it fulfills the oldest pending `referee_obligations` row
   (FIFO, `FOR UPDATE`) instead of calling `grant_reward` (no reward points
   for obligation fulfillment).
5. Trial-specific: `deactivate_trial_points` idempotently flips
   `is_active=false` on subscription start (a no-op if already inactive or
   if no wallet exists), preserving balance for audit; a `0`-amount ledger
   row records the event.

#### Expected behavior
- Lock increases `locked` without touching `balance`; consume decreases both
  by the same amount; unlock decreases only `locked`. Every mutation writes
  exactly one ledger row whose sign matches the direction (negative for
  lock/consume, positive for unlock).
- `route_consume_points`/`route_unlock_points`/`route_referee_reward` are
  pure dispatchers with no wallet math of their own — behavior is fully
  determined by the retained wallet functions they call.
- Trial points, once deactivated, cannot be locked again
  (`lock_trial_points` raises if `is_active=false`); `deactivate_trial_points`
  is safe to call multiple times.

#### Invariants
- **DB-level, not just app-level**: `point_wallets` and `trial_point_wallets`
  both carry `CHECK (balance >= 0)`, `CHECK (locked >= 0)`, and `CHECK
  (balance >= locked)`. No lock/consume/unlock path can violate these — the
  functions' own pre-checks (`(balance - locked) < amount` for lock,
  `balance < amount OR locked < amount` for consume, `locked < amount` for
  unlock) are enforced *before* the CHECK constraints would ever fire, but
  the constraints are the DB-level backstop.
- **Sum is conserved across lock → consume → release**: for any given
  lock amount `A`, exactly one of {consume(A), unlock(A)} settles it — a
  judgement's terminal state (approved/rejected/evidence_timeout →
  `route_consume_points`; review_timeout → `route_unlock_points`) determines
  which. A lock cannot be both consumed and unlocked (each reduces `locked`
  once; a second attempt on an already-settled amount would either fail the
  `locked >= amount` guard, once other locks aren't propping it up, or — if
  headroom from unrelated locks exists — silently double-settle; see Edge
  cases).
- **A lock cannot be double-consumed by construction of the call graph**:
  the only two callers that settle a given judgement's lock
  (`settle_evidence_timeout`/`settle_review_timeout` triggers, and
  `confirm_judgement_and_rate_referee`/`detect_auto_confirms`) are gated by
  the judgement's `status` and `is_confirmed` — see flow (d) for exactly how,
  and for the one identified gap (no explicit row lock on `judgements`
  outside `detect_auto_confirms`; see §3 T7-2).
- All wallet mutations use `SELECT ... FOR UPDATE` on the wallet row itself,
  serializing concurrent lock/consume/unlock calls **for the same user** —
  but this only protects the wallet row; it does not by itself prevent a
  caller from invoking `consume_points` twice for the same judgement if the
  caller-side idempotency check is racy (see flow (d)).

#### Edge cases
- `consume_trial_points`: obligation creation loops `1..p_amount` — today
  `p_amount` is always 1 in practice (one point per matching strategy per
  the current cost table), but the function itself has no upper bound; a
  caller passing a large `p_amount` would create that many obligation rows
  in one call.
- `route_referee_reward` for an obligation request with no pending
  obligation (`v_obligation_id IS NULL`): the function silently no-ops — no
  reward, no obligation update, no error. Confirm this is intended (referee
  fulfilled all obligations already) rather than a swallowed bug.
- `deactivate_trial_points` on a user with no trial wallet (pre-feature-launch
  user) returns silently (`v_is_active IS NULL → RETURN`) — correct no-op,
  but worth an explicit Go-side unit test since it's easy to instead treat
  `NULL` as falsy and skip the early return.
- `get_point_for_matching_strategy` (category 2, stays in Postgres) is a
  hardcoded lookup (`'standard' → 1`) shared by retained triggers; per §2.3
  #9, Go callers get a **duplicated constant** rather than calling through —
  this is a real drift risk if the lookup table ever grows past the single
  hardcoded case; flagged, not silently duplicate-and-forget.

#### pgTAP evidence
- `supabase/tests/test_reward_system.sql`: Tests 1–5 cover `lock_points`
  (locks without reducing balance; fails on insufficient available),
  `unlock_points` (returns to available), `consume_points` (settles both
  columns; fails on insufficient locked). Test 8 ("Full confirm flow") walks
  lock → confirm → settle → reward end-to-end. Test 9 explicitly asserts
  **idempotency — second confirm does not double-spend** (balance/reward
  unchanged on a second `confirm_judgement_and_rate_referee` call for an
  already-confirmed judgement).
- `supabase/tests/test_trial_points.sql`: Tests 2–8 cover the trial-point
  mirror of the above (`lock_trial_points`, `consume_trial_points` +
  obligation creation, `unlock_trial_points`, `deactivate_trial_points`
  idempotency and post-deactivation lock failure). Tests 9–10 cover
  `route_referee_reward`'s FIFO obligation-fulfillment vs. normal-reward
  branches.
- `supabase/tests/test_trial_point_settlement.sql`: end-to-end trial-funded
  request settlement (Test 1), `route_consume_points` dispatch correctness
  for the regular-source branch (Test 2), and full obligation
  fulfillment cycle (Test 4).
- **Gap**: no pgTAP test exercises true *concurrent* double-lock/double-
  consume via two simultaneously-open transactions (e.g. `pgbench` or two
  psql sessions racing on the same wallet) — existing tests are sequential
  (call, assert, call again, assert). The `FOR UPDATE` row lock is real
  protection, but it is asserted here by code reading, not by a concurrency
  test.

### 5(c) Payout (Stripe Connect)

#### Code paths
- DB (stay-in-Postgres, category 1): `supabase/schemas/reward/functions/grant_reward.sql`,
  `deduct_reward_for_payout.sql`; (move-to-Go worker, category 3):
  `prepare_monthly_payouts.sql`.
- Edge Functions: `supabase/functions/payout-setup/` (onboarding —
  Stripe Express Connect account get-or-create + `accountLinks`),
  `create-express-dashboard-link/` (Express login link),
  `execute-pending-payouts/` (batch Stripe Transfer execution, cron-driven).
- **Missing**: `payout-request` — Flutter calls
  `stripe_payout_repository.dart:92` (`_supabase.functions.invoke('payout-request', ...)`)
  but no `supabase/functions/payout-request/` directory exists; this 404s in
  production today (confirmed launch-blocker, §3.1).
- Cron: `supabase/schemas/reward/cron/cron_prepare_monthly_payouts.sql`
  (`0 15 28-31 * *`, guarded to actual last day), `cron_execute_pending_payouts.sql`
  (every 30 min, `net.http_post` → `execute-pending-payouts`).

#### Preconditions
- Referee has a `reward_wallets.balance > 0` and a `stripe_accounts` row with
  `stripe_connect_account_id` set and `payouts_enabled = true` (refreshed by
  `payout-setup` via Stripe `accountLinks` onboarding).

#### Steps (monthly batch payout)
1. `prepare_monthly_payouts('JPY')` runs on the actual last day of the
   month (date-computed guard, not a fixed day-of-month cron pattern alone).
   It looks up the active `reward_exchange_rates` row for the currency,
   checks idempotency (`EXISTS (... WHERE batch_date = today AND currency =
   ...)` — a second same-day call is a no-op), then for every
   `reward_wallets` row with `balance > 0`: inserts a `reward_payouts` row
   with `status='pending'` (if Connect-ready) or `status='skipped'` +
   `error_message` (if not, plus a `notify_event` reminder). `currency_amount
   = balance * rate_per_point`, and `rate_per_point` is snapshotted onto the
   row at prepare time.
2. `execute-pending-payouts` (cron every 30 min) fetches up to 100
   `status='pending'` rows (oldest first), and per row: looks up the
   referee's `stripe_accounts.stripe_connect_account_id`, calls
   `stripe.transfers.create(...)` with `idempotencyKey: "payout-${payout.id}"`,
   marks the row `status='success'` + `stripe_transfer_id`, then calls
   `deduct_reward_for_payout` (atomic `UPDATE ... SET balance = balance -
   amount WHERE balance >= amount`, raises if insufficient, logs a
   `reward_ledger` row with `reason='payout'`, `amount = -amount`).
   On any failure mid-row it marks `status='failed'` + `error_message` and
   fires a `notification_payout_failed_referee` notification; it does not
   retry within the same invocation.
3. Account-deletion payout (a second, near-duplicate code path): `delete-account`'s
   step 3 (unless `force=true`) independently computes a payout for any
   positive reward balance — inserts its own `reward_payouts` row, calls
   `stripe.transfers.create` with `idempotencyKey: "deletion-payout-${payoutId}"`,
   marks success, then calls the same `deduct_reward_for_payout` RPC.

#### Expected behavior
- A payout is prepared **at most once per (batch_date, currency)** —
  enforced by the `EXISTS` idempotency check in `prepare_monthly_payouts`,
  confirmed by pgTAP Test 7 below.
- Stripe `Transfer` creation is retried safely: the idempotency key is
  deterministic per `reward_payouts.id` (`payout-${id}` /
  `deletion-payout-${id}`), so re-invoking the same row's transfer call
  (e.g. after a crash mid-request) returns Stripe's cached response for that
  key rather than creating a second transfer.
- Wallet deduction is guarded by an atomic conditional UPDATE
  (`WHERE balance >= amount`) rather than a prior `SELECT ... FOR UPDATE` —
  Postgres's row-level locking on the UPDATE itself still serializes
  concurrent calls; a second call after the first already deducted the
  balance sees the reduced balance and fails the `WHERE` clause, raising
  `Insufficient reward balance`.

#### Invariants
- A `reward_payouts` row transitions `pending → {success, failed}` (or
  `skipped` at creation, terminal) — never back to `pending` and never
  processed twice by `execute-pending-payouts` under its own idempotency
  key.
- `deduct_reward_for_payout` cannot take a wallet negative — doubly
  guaranteed: `reward_wallets.balance` carries `CHECK (balance >= 0)`
  (`supabase/schemas/reward/tables/reward_wallets.sql`), and the function's
  own atomic `WHERE balance >= p_amount` + `RAISE EXCEPTION` on `NOT FOUND`
  rejects an under-funded deduction before the CHECK would ever be tested.
- `reward_wallets.user_id` is `ON DELETE CASCADE` to `auth.users(id)` — a
  reward wallet (and any un-paid-out balance it holds) is deleted outright,
  not orphaned or preserved, when the owning account is deleted. This is
  directly relevant to flow (e)'s `force=true` edge case below, and to §3
  T7-3.
- Stripe transfer id **is not protected by a DB unique constraint**:
  `reward_payouts.stripe_transfer_id` (`supabase/schemas/reward/tables/reward_payouts.sql`)
  has no `UNIQUE` constraint. The "applied at most once" property for a
  given payout row currently rests entirely on (a) Stripe's own
  idempotency-key deduplication and (b) the `deduct_reward_for_payout`
  optimistic-concurrency check — not on a DB constraint that would catch,
  e.g., two *different* `reward_payouts` rows accidentally referencing the
  same real-world transfer. **See §3 T7-1.**

#### Edge cases
- **`execute-pending-payouts` does not claim rows before working them**: it
  `SELECT`s `status='pending'` rows and only flips status to
  `success`/`failed` *after* the Stripe call — there is no `FOR UPDATE SKIP
  LOCKED` claim step (contrast with `detect_auto_confirms`, flow (d), which
  does use `FOR UPDATE SKIP LOCKED`). If the cron's HTTP call overlaps with
  itself (e.g., a slow run still executing when the next 30-minute trigger
  fires), two concurrent invocations could both fetch the same pending row.
  Stripe's deterministic idempotency key means the *Transfer* itself is not
  duplicated, but `deduct_reward_for_payout` could still be attempted twice
  for the same row concurrently — the atomic `WHERE balance >= amount`
  update means only one succeeds and the other raises, which is logged as
  `CRITICAL: Deduct failed` but does not roll back the already-`success`
  payout row. **See §3 T7-1** — confirm the Go worker's job-claiming
  pattern (durable row/`FOR UPDATE SKIP LOCKED` per §12) closes this gap
  rather than inheriting it.
- **`payout-request` is a confirmed 404 today** — the referee-initiated
  "request payout now" action in the Flutter app has no working backend.
  This is a Phase-0 launch-blocker, see §3.1; the Go implementation needs to
  decide UX (immediate transfer vs. queue a `pending` row for the next
  worker run) before porting.
- **Two independent Stripe-transfer + wallet-deduct code paths**
  (`execute-pending-payouts` and `delete-account`'s inline payout step) —
  both call `deduct_reward_for_payout` after their own `stripe.transfers.create`,
  but are otherwise unrelated implementations. A behavior difference between
  them (e.g., account-deletion payout has no retry/backoff, is inline in an
  HTTP request instead of a worker) is a real product-behavior gap to
  reconcile, not just a code-duplication cleanup, when porting to Go
  (§1.3 already flags this for consolidation).
- Exchange-rate change mid-batch: `rate_per_point` is snapshotted onto each
  `reward_payouts` row at prepare time, so a rate change between prepare and
  execute does not retroactively affect already-prepared amounts — but
  confirm this is the intended business behavior (vs. rate-at-execution)
  during the owning phase's design.

#### pgTAP evidence
`supabase/tests/test_reward_payout.sql` — Test 1 (month-end guard), Test 3/4
(pending vs. skipped disposition by Connect readiness), Test 5 (zero-balance
users excluded), Test 6 (currency amount = balance × rate, rate snapshot),
**Test 7 (idempotency — second `prepare_monthly_payouts` call same day
returns `skipped`, no new rows)**, Test 8/9 (`deduct_reward_for_payout`
deducts balance + writes ledger entry), **Test 10 (insufficient-balance
double-deduct raises `Insufficient reward balance`)**, Test 11 (missing
exchange rate raises). `supabase/tests/test_reward_system.sql` Tests 6–7
cover `grant_reward` (creates wallet on first grant, accumulates on repeat).
**Gap**: no pgTAP test simulates the `execute-pending-payouts` Edge
Function's Stripe-call-then-deduct sequence (it can't — Stripe calls aren't
mockable from pgTAP), and no test covers the two-concurrent-workers race
described above.

### 5(d) Judgement state machine

#### Code paths
- Table: `supabase/schemas/judgement/tables/judgements.sql` — `status` enum
  `{awaiting_evidence, in_review, approved, rejected, review_timeout,
  evidence_timeout}`, plus `is_confirmed`, `is_auto_confirmed`,
  `reopen_count`.
- Transition functions: `judge_evidence.sql` (`in_review` →
  `approved`/`rejected`), `submit_evidence.sql`/`resubmit_evidence.sql`
  (`awaiting_evidence`/`rejected` → `in_review`), `detect_and_handle_evidence_timeouts.sql`
  (`awaiting_evidence` → `evidence_timeout`), `detect_and_handle_review_timeouts.sql`
  (`in_review` → `review_timeout`).
- Confirm functions: `confirm_judgement_and_rate_referee.sql` (approved/
  rejected → confirmed, with settlement), `confirm_evidence_timeout.sql`,
  `confirm_review_timeout.sql` (their respective timeout states →
  confirmed, no further settlement — already settled by the timeout
  trigger), `detect_auto_confirms.sql` (any unconfirmed terminal state, past
  `due_date + 3 days`, → auto-confirmed, with settlement for
  approved/rejected only).
- Settlement triggers: `on_evidence_timeout_settle.sql`,
  `on_review_timeout_settle.sql` (fire on the timeout transition itself, not
  on confirm).
- Notification triggers: `on_judgements_status_changed.sql`,
  `on_judgement_confirmed.sql`, `on_judgement_confirmed_notify.sql`.
- Flutter: `judgement_repository.dart` (`judge_evidence`,
  `confirm_judgement_and_rate_referee`, `confirm_review_timeout`),
  `evidence_repository.dart` (`submit_evidence`, `update_evidence`,
  `resubmit_evidence`, `confirm_evidence_timeout`).

#### Preconditions
- A `judgements` row exists 1:1 with its `task_referee_requests` row
  (`judgements.id` is both PK and FK to `task_referee_requests.id`),
  created in `awaiting_evidence` status.

#### Steps — full state map
```
awaiting_evidence
  --submit_evidence (tasker, assets required)-->            in_review
  --detect_and_handle_evidence_timeouts (due_date passed,
    no evidence)-->                                          evidence_timeout
in_review
  --judge_evidence (referee, approve)-->                     approved
  --judge_evidence (referee, reject)-->                      rejected
  --detect_and_handle_review_timeouts (due_date+3h passed)--> review_timeout
rejected
  --resubmit_evidence (tasker, reopen_count<1, due_date
    not passed, not yet confirmed)-->                        in_review (reopen_count+1)
approved | rejected
  --confirm_judgement_and_rate_referee (tasker)-->            is_confirmed=true (+settle: consume tasker points, reward referee, insert rating)
  --detect_auto_confirms (past due_date+3d, unconfirmed)-->   is_confirmed=true, is_auto_confirmed=true (+ same settlement)
evidence_timeout
  (settled immediately by on_evidence_timeout_settle trigger on the transition itself)
  --confirm_evidence_timeout (tasker)-->                      is_confirmed=true (no further settlement — already done)
  --detect_auto_confirms (past due_date+3d)-->                is_confirmed=true, is_auto_confirmed=true (no further settlement)
review_timeout
  (settled immediately by on_review_timeout_settle trigger: unlock points, negative rating)
  --confirm_review_timeout (tasker)-->                        is_confirmed=true (no further settlement)
  --detect_auto_confirms (past due_date+3d)-->                is_confirmed=true, is_auto_confirmed=true (no further settlement)
```
`is_confirmed=true` is terminal — no function transitions a confirmed
judgement's `status` or flips `is_confirmed` back to `false`.

#### Expected behavior
- `judge_evidence`: only the assigned referee (`trr.matched_referee_id =
  auth.uid()`), only from `in_review`, requires a non-empty (trimmed)
  comment, status must be exactly `approved`/`rejected`.
- `confirm_judgement_and_rate_referee`: only the tasker
  (`t.tasker_id = auth.uid()`), only from `approved`/`rejected`,
  **idempotent** — a second call on an already-`is_confirmed=true` judgement
  returns without re-running settlement or re-inserting a rating (checked by
  `IF v_judgement.is_confirmed = TRUE THEN RETURN`). Settlement = consume
  tasker's locked points (`route_consume_points`) + reward referee
  (`route_referee_reward`, which redirects to obligation-fulfillment for
  trial-funded requests) + insert one `rating_histories` row, all before the
  final `UPDATE ... SET is_confirmed = TRUE`.
- `confirm_evidence_timeout`/`confirm_review_timeout`: same tasker-only +
  idempotent pattern, but these **do not settle points** — settlement
  already happened synchronously in the timeout trigger
  (`on_evidence_timeout_settle`/`on_review_timeout_settle`) at the moment the
  status flipped to the timeout state. These confirm functions exist purely
  to let the tasker acknowledge and close out the task
  (`on_all_judgements_confirmed_close_task` trigger fires once every
  judgement on a task is confirmed).
- `resubmit_evidence`: capped at one resubmission (`reopen_count < 1`),
  requires the judgement still be `rejected`, `is_confirmed=false`, and the
  task's `due_date` not yet passed; updates evidence *before* flipping the
  judgement back to `in_review` so the status-changed trigger sees the
  correct `reopen_count` for its resubmission-vs-new-review branch.
- `detect_auto_confirms`: batch-claims eligible judgements with `FOR UPDATE
  OF j SKIP LOCKED` (safe under concurrent worker instances), settles
  approved/rejected the same way manual confirm does, and sets both
  `is_auto_confirmed=true` and `is_confirmed=true` in one UPDATE — it never
  touches `status` itself, only the confirm flags.

#### Invariants
- **State transitions are one-way and gated by current status**: every
  transition function checks `v_current_status` (or the trigger's `WHEN`
  clause) before mutating — e.g. `judge_evidence` rejects anything not
  `in_review`; `confirm_evidence_timeout` rejects anything not
  `evidence_timeout`. There is no function that transitions a judgement
  "backwards" except the single explicit `rejected → in_review` resubmission
  path, itself capped at one use.
- **A settled/confirmed judgement cannot re-open or re-settle**: the
  `is_confirmed` idempotency check in all three confirm functions
  (`confirm_judgement_and_rate_referee`, `confirm_evidence_timeout`,
  `confirm_review_timeout`) plus `detect_auto_confirms`'s `WHERE
  j.is_confirmed = false` filter together mean a confirmed judgement is
  never re-processed by any of the four confirm paths.
- **Settlement runs exactly once per judgement** in the common case, but
  this is enforced by two *different* mechanisms depending on the path: (1)
  for timeout states, settlement is tied to the trigger firing on the
  `status` transition itself (`WHEN (NEW.status = 'evidence_timeout' AND OLD
  IS DISTINCT FROM NEW)`), which Postgres guarantees fires once per UPDATE
  that actually changes status; (2) for manual/auto confirm of
  approved/rejected, settlement is guarded by the `is_confirmed` flag check
  in application code, **without** a `SELECT ... FOR UPDATE` lock on the
  `judgements` row in `confirm_judgement_and_rate_referee` (unlike
  `detect_auto_confirms`, which does lock via `FOR UPDATE OF j SKIP LOCKED`).
  See Edge cases for the resulting race and why it is likely — but not
  certainly — still safe today. **See §3 T7-2.**
- `reopen_count` is monotonic and capped (`< 1` guard means at most one
  resubmission ever, going forward from `0` to `1`).

#### Edge cases
- **Concurrent double-confirm race in `confirm_judgement_and_rate_referee`**:
  the function does `SELECT ... INTO v_judgement FROM judgements j JOIN ...`
  with no `FOR UPDATE`, then later checks `is_confirmed` and settles. Two
  near-simultaneous calls (e.g. a double-tap that fires two RPCs) could both
  read `is_confirmed=false` before either commits, and both proceed to call
  `route_consume_points`/`route_referee_reward`. Whether this actually
  double-spends depends on wallet headroom: `consume_points` itself takes
  `SELECT ... FOR UPDATE` on the wallet, so the second caller blocks until
  the first commits, then re-checks `locked >= amount` — if the tasker's
  `locked` balance has *only* this judgement's lock, the second call's
  `locked` check fails and raises, safely aborting. But if the tasker has
  other unrelated locked amounts providing headroom, the second call's
  wallet check could pass, double-consuming points — and the transaction
  would only be caught downstream, when the second call's `INSERT INTO
  rating_histories` hits the `unique_rating_per_judgement UNIQUE
  (judgement_id, rating_type)` constraint and the **entire function's
  transaction rolls back**, undoing the double-consume along with it (a
  single RPC call is one transaction). This means the current design is
  likely safe today, but by *incidental* protection from a unique
  constraint placed after the money-moving calls, not by an explicit lock —
  a future code change (e.g., reordering the rating insert earlier, or
  removing it) would silently remove this protection. **Registered as a
  launch-blocker candidate, §3 T7-2** — recommend the Go port add an
  explicit row lock (or a `WHERE is_confirmed = false` guard on the final
  UPDATE combined with checking `ROW_COUNT`) rather than relying on this
  incidental ordering. Not covered by any existing pgTAP test — the
  existing idempotency tests (`test_confirm_judgement.sql` Test 2,
  `test_reward_system.sql` Test 9) are sequential (call, assert, call
  again), not concurrent.
- The same class of gap exists in `confirm_evidence_timeout`/
  `confirm_review_timeout`, though lower-stakes since they don't move money
  — a concurrent double-call could at most trigger
  `on_all_judgements_confirmed_close_task` redundantly (itself idempotent,
  since it's a status check + UPDATE).
- `resubmit_evidence` due-date race: the check `t.due_date > v_now` is
  evaluated once at the start; if `due_date` passes between validation and
  the final UPDATE (e.g., due to slow client-side asset upload in between),
  there's no re-check immediately before the status flip — theoretically a
  resubmission could land microseconds after the deadline. Low-severity
  given the timescale, but worth a note for the Go port's transaction
  design.
- `auto_score_timeout_referee()` (trigger `on_judgements_timeout_score_referee`,
  fires on every `judgements` UPDATE with no `WHEN` clause) inserts the same
  negative rating that `settle_review_timeout()` already inserts — both are
  guarded by `ON CONFLICT (judgement_id, rating_type) DO NOTHING`, so
  today's behavior is correct despite the duplication — **resolved by
  operator adjudication, §2.7.3** (move-to-Go with dedup).

#### pgTAP evidence
- `supabase/tests/test_judge_evidence.sql`: approve/reject happy paths,
  comment trimming, non-referee rejection, empty-comment rejection, invalid-
  status rejection, wrong-current-status rejection (Tests 1–7).
- `supabase/tests/test_confirm_judgement.sql`: confirm approved/rejected
  with rating (Tests 1, 3), **idempotency — repeat confirm is a no-op**
  (Test 2), non-tasker blocked (Test 4), cannot confirm `in_review` (Test 5),
  confirm closes the referee request and then the task once all requests
  are closed (Tests 6–7), confirm without a comment (Test 8).
- `supabase/tests/test_auto_confirm.sql`: auto-confirm settles
  approved/rejected (Tests 1–2) but **not** review_timeout/evidence_timeout
  (Tests 3–4, asserting wallet balances are unchanged since those were
  already settled by the timeout trigger), does not fire within the grace
  period (Test 5), **idempotency — running detection twice does not
  double-process** (Test 6), and skips already-manually-confirmed
  judgements (Test 7).
- `supabase/tests/test_evidence_timeout_settlement.sql`: timeout detection
  flips status (Test 1), the settlement trigger consumes points + grants
  reward + writes both ledger rows atomically with the status change (Test
  2), auto-closes the referee request (Test 3) while the task stays open
  until the tasker confirms (Test 4), tasker confirm closes the task (Test
  5), **confirm idempotency** (Test 6), unaffected tasks with evidence
  submitted are untouched by detection (Test 7), normal (non-timeout)
  confirm flow regression-checked (Test 8), referee RLS read access
  preserved after timeout (Test 9).
- **Gap**: as noted above, no test exercises the concurrent double-confirm
  race in `confirm_judgement_and_rate_referee` (§3 T7-2).

### 5(e) Account deletion

#### Code paths
- DB: `supabase/schemas/account/functions/check_account_deletable.sql`.
- Edge Function: `supabase/functions/delete-account/index.ts` (multi-step
  saga).
- Flutter: `peppercheck_flutter/lib/features/account/data/account_repository.dart`
  (`checkDeletable()`, `deleteAccount({force})`).
- Web: `peppercheck-webapp/src/app/[locale]/account/delete/page.tsx` also
  calls the same `delete-account` function (per §1.3).
- Target (design doc §14, §22 Phase 6): idempotent, persisted deletion
  state; each external step independently retryable; covers Firebase user
  deletion/token revocation, RevenueCat customer, Stripe Connect, R2, FCM
  tokens, legal retention/anonymization.

#### Preconditions
- User is authenticated; `check_account_deletable()` has no blocking
  conditions (see below), or the caller passes `force=true` to skip the
  reward-payout step (but not the precondition check itself — `force` only
  gates step 3, not step 2, in `delete-account/index.ts`).

#### Steps (today — `delete-account` Edge Function, in order)
1. Authenticate the caller via their own Supabase session (not the admin
   client) so `auth.uid()` resolves inside `check_account_deletable()`.
2. Call `check_account_deletable()`: blocks if the user has any `tasks` with
   `status='open'` as tasker (`open_tasks`), or any
   `task_referee_requests` with `status IN ('matched', 'accepted',
   'payment_processing')` as the matched referee (`active_referee_requests`).
   If blocked, returns HTTP 200 with `{error: 'not_deletable', reasons:
   [...]}` — a soft failure, not an exception.
3. **If `!force` and `reward_wallets.balance > 0`**: requires a ready Stripe
   Connect account (`stripe_connect_account_id` set + `payouts_enabled`); if
   not ready, returns `{error: 'payout_failed', reward_balance, message}`
   (soft failure — deletion does not proceed). If ready: inserts a
   `reward_payouts` row, calls `stripe.transfers.create` (idempotency key
   `deletion-payout-${payoutId}`), marks it `success`, calls
   `deduct_reward_for_payout`. Any exception in this block also returns
   `{error: 'payout_failed', ...}` without proceeding.
4. Cancel any active Stripe subscription (`prorate: false`) —
   **best-effort**: failure is logged, not surfaced, deletion continues.
5. Deauthorize the Stripe Connect account (`stripe.accounts.del`) —
   **best-effort**, same pattern.
6. Delete R2 avatar objects under `avatar/<userId>/` — **best-effort**, same
   pattern (also gated on R2 env vars being configured at all; if not,
   silently skipped with a warning log).
7. `supabaseAdmin.auth.admin.deleteUser(userId)` — deletes the `auth.users`
   row. DB `ON DELETE CASCADE`/`ON DELETE SET NULL` foreign keys handle
   everything downstream (see Invariants).
8. Return `{success: true}`.

#### Expected behavior
- Steps 4–6 (subscription cancel, Connect deauth, R2 cleanup) are
  **best-effort and non-blocking** — their failure is logged to
  `console.error` but does not stop the saga or roll back earlier steps.
  Only steps 2 (precondition) and 3 (payout, when `!force`) can stop
  deletion before it reaches step 7.
- Once step 7 (`auth.admin.deleteUser`) succeeds, the user is gone from
  `auth.users` and the CASCADE/SET NULL network fires atomically as part of
  that single DB operation.
- `force=true` bypasses the payout-must-succeed gate entirely (skips step 3
  altogether — a user with a positive reward balance who forces deletion
  loses that balance, since nothing pays it out or otherwise preserves it).
  **See §3 T7-3.**

#### Invariants
- **CASCADE deletes**: `profiles`, `point_wallets` (and, by extension,
  everything FK'd to `profiles`/`auth.users` with `ON DELETE CASCADE`) are
  removed atomically with the `auth.users` row — confirmed by
  `supabase/tests/database/account_deletion.test.sql` Test 4.
- **SET NULL, record retained**: `tasks.tasker_id`,
  `task_referee_requests.matched_referee_id`, `rating_histories.rater_id`,
  `judgement_threads.sender_id`, `reward_payouts.user_id` are all set to
  `NULL` rather than cascading — the historical row survives with its
  identity link severed. Confirmed by Tests 5–8 of the same file. This is
  the mechanism by which a deleted user's finished business (a task someone
  else can still see the history of, a payout record for accounting) stays
  intact without pointing at a live account.
- **A partially-deleted account must not resume normal activity**: today
  this is only *partially* true — because steps 4–6 are best-effort and
  step 7 either fully succeeds (deleting the account) or fully fails
  (leaving the account fully intact, since `auth.admin.deleteUser` is a
  single atomic call), there is no state today where the account is
  "half-deleted but still usable." The risk is narrower but real: if step 3
  succeeds (reward paid out, wallet zeroed) but step 7 later fails for an
  unrelated reason (e.g. a transient Admin API error), the user's reward
  balance is now gone even though their account was **not** deleted — a
  retry of the whole saga would see `reward_wallets.balance = 0` and skip
  step 3 the second time (correct), but the user experienced a real-money
  side effect from a deletion attempt that ultimately failed. The design
  doc's target of "idempotent, persisted deletion state" (§14) is meant to
  close exactly this gap by making each external step its own durable,
  retryable unit rather than an in-line all-in-one HTTP handler. **See §3
  T7-3.**
- **Each external step is retryable — but only weakly so today**: none of
  Stripe transfer, Stripe subscription cancel, Stripe Connect deauth, or R2
  deletion carry an idempotency mechanism that survives *across separate
  invocations* of `delete-account` except the Stripe transfer's
  `deletion-payout-${payoutId}` key (which is only deterministic if
  `payoutId` — a freshly generated `crypto.randomUUID()` — is reused across
  retries, which it is **not**: a second `delete-account` call after a
  first payout succeeded would see `reward_wallets.balance = 0` and skip
  the payout block entirely, so this is a non-issue in practice, but by
  accident of the balance-zero check, not by an idempotency key design).
  Subscription cancel and Connect deauth are naturally idempotent
  (canceling an already-canceled subscription / deleting an already-deleted
  Connect account both fail harmlessly and are already caught/logged, not
  surfaced). R2 deletion is naturally idempotent (deleting already-deleted
  objects is a no-op).

#### Edge cases
- **`force=true` with a positive reward balance**: money is left
  un-paid-out and disappears when the wallet's owning account is deleted.
  Confirmed: `reward_wallets.user_id` is `ON DELETE CASCADE` to
  `auth.users(id)` (`supabase/schemas/reward/tables/reward_wallets.sql`), so
  the wallet row — and the un-paid-out balance it holds — is deleted
  outright with the account, not orphaned or preserved for later payout.
  Confirm this is accepted product behavior (user explicitly forcing past a
  payout failure accepts losing the balance), not an accidental fund-loss
  bug, before porting as-is. **See §3 T7-3.**
- **Retry after a step-7 failure with step-3 already applied**: as described
  in Invariants — the account survives (not deleted) but the user has
  already lost their reward balance to a payout that happened during a
  deletion attempt that ultimately didn't complete. This is the sharpest
  edge case for the Go port's "idempotent, persisted deletion state" design
  to close: the saga needs a way to represent "payout done, deletion not
  yet done" as a durable, resumable state rather than inferring it after
  the fact from `balance == 0`.
- **Two callers, one function**: both the Flutter app and the webapp invoke
  the same `delete-account` function — any behavior change must be
  validated against both call sites (design doc explicitly calls for
  "in-app and web paths validated," §14).
- **No test coverage of the external-side-effect ordering or retry
  behavior**: `account_deletion.test.sql` only exercises
  `check_account_deletable()` and the DB-level CASCADE/SET NULL network
  after a **direct** `DELETE FROM auth.users` — it does not (and, being
  pgTAP, cannot easily) exercise the Edge Function's Stripe/R2 steps, their
  ordering, or a simulated mid-saga failure and retry. This is the biggest
  test gap of the five flows in this catalog, and matches §1.3's framing of
  `delete-account` as "best-effort/non-transactional... exactly the gap §14
  flags for the Go port."

#### pgTAP evidence
`supabase/tests/database/account_deletion.test.sql` (13 assertions): Test 1
(`check_account_deletable` returns deletable with no blockers), Tests 2–3
(blocked by `open_tasks` / `active_referee_requests`, with reasons
populated, then unblocked once those clear), Test 4 (CASCADE removes
`profiles` + `point_wallets` on `auth.users` deletion), Tests 5–8 (SET NULL
on `tasks.tasker_id`, `task_referee_requests.matched_referee_id`,
`rating_histories.rater_id`, `judgement_threads.sender_id`,
`reward_payouts.user_id`, with the historical row retained). No pgTAP
coverage of the `delete-account` Edge Function itself (out of reach for
pgTAP — it's Deno/TypeScript with live Stripe/R2 calls).

### 5.1 Verification

All five flows above have at least a `Preconditions`, `Steps`, `Expected
behavior`, `Invariants`, and `Edge cases` subsection, and each cites the
pgTAP test file(s) that characterize it today (or explicitly notes the gap
where no pgTAP test reaches the flow, as with parts of (a) and all of the
external-side-effect portion of (e)). The three edge cases promoted to
launch-blocker candidates (§3 T7-1, T7-2, T7-3) are cross-referenced inline
above at their source location in flows (c), (d), and (e) respectively.

## 6. Reduced Web Route Table

> Source: `docs/superpowers/plans/phase0-parts/06-web-routes.md`. Source of
> truth for target disposition: program design doc §9 "Web Frontend (Go +
> htmx)," cross-referenced with the milestone table in §22 and the
> testing/risk notes in §24/§27. Enumerates every App Router route file in
> `peppercheck-webapp` (`page.tsx`, `page.ts`, `route.ts`, excluding
> `node_modules` and `.next`) as of 2026-07-22, and every file in the webapp
> that imports the `@supabase` npm packages directly.

### 6.1 Route table

| Route (URL pattern) | File | Disposition | Target / redirect-to | Note |
|---|---|---|---|---|
| `/`, `/{locale}` | `src/app/[locale]/page.tsx` | **Keep** | — | Marketing homepage. Bare `/` (no locale prefix) 307-redirects to `/{defaultLocale}` (`en`) via the `next-intl` middleware — `routing.ts` does not override `localePrefix`, so it defaults to `'always'`. §9 lists `/` explicitly as kept. No Supabase usage. |
| `/{locale}/legal/privacy` | `src/app/[locale]/legal/privacy/page.tsx` | **Keep** | — | Static content, server component. §9: legal pages "must be updated to reflect actual providers" (Firebase Auth, RevenueCat, R2, VPS/Postgres operator, Stripe Connect, backup storage) as compliance content, not generated from architecture assumptions. No Supabase usage. |
| `/{locale}/legal/terms` | `src/app/[locale]/legal/terms/page.tsx` | **Keep** | — | Static content, server component. Same provider-accuracy note as privacy. No Supabase usage. |
| `/{locale}/legal/refund` | `src/app/[locale]/legal/refund/page.tsx` | **Keep** | — | Static content. Same provider-accuracy note as privacy. No Supabase usage (verified via Step 2 whole-webapp grep; not individually re-read). |
| `/{locale}/legal/tokushoho` | `src/app/[locale]/legal/tokushoho/page.tsx` | **Keep** | — | Static content (特定商取引法 disclosure). Same provider-accuracy note as privacy. No Supabase usage (verified via Step 2 grep; not individually re-read). |
| `/{locale}/account/delete` | `src/app/[locale]/account/delete/page.tsx` | **Keep** | — | Provider-neutral account + data deletion request page, per §9 ("any user, Google or Apple, without reinstalling") and §14. **Uses Supabase directly**: `supabase.auth.getUser()`, `supabase.rpc('check_account_deletable')`, `supabase.functions.invoke('delete-account', ...)` via `createClient` from `@/lib/supabase/client`. This dependency is *not* caught by the literal `@supabase` grep in 6.2 (it imports the local wrapper, not the npm package by name), but it is real and must be re-pointed at Firebase Auth + the Go API when this route is ported to Go/htmx. Flagged as a concern below. |
| `/{locale}/stripe/connect/return` | `src/app/[locale]/stripe/connect/return/page.tsx` | **Keep** | — | Renders `<StaticInfoPage translationNamespace="StripeConnect.return" />`. No Supabase usage. Stripe Connect (Express) onboarding-return landing page; unchanged per §11 ("Money out — payouts → Stripe Connect (Express), unchanged"). |
| `/{locale}/stripe/connect/refresh` | `src/app/[locale]/stripe/connect/refresh/page.tsx` | **Keep** | — | Renders `<StaticInfoPage translationNamespace="StripeConnect.refresh" />`. No Supabase usage. Same disposition as return page. |
| `/{locale}/auth/callback` | `src/app/[locale]/auth/callback/route.ts` | **Remove** | *(none — see note)* | Supabase OAuth callback handler: reads `?code=`, calls `supabase.auth.exchangeCodeForSession(code)`, then redirects to `?next=` (default `/dashboard`) or, on error, to `/{locale}/auth/auth-code-error` (that error page does not exist in the current tree — dead link already). Not a page a user bookmarks or links to; it is only ever reached mid-flow from `login/page.tsx`'s `signInWithOAuth`. Once web login is removed, nothing in the app initiates this flow, so §9's "removed Next.js URLs must 301-redirect" arguably doesn't require a replacement target here — but flagged as **needs program confirmation** (see Concerns) rather than asserted. |
| `/{locale}/login` | `src/app/[locale]/login/page.tsx` | **Redirect** | `/` (homepage) | Web login (Supabase `signInWithOAuth`, Google only). §9 explicit remove target ("web login"). Auth moves entirely in-app (Firebase, §10). §9 does not specify a literal redirect target for this URL; `/` is proposed here per the general "old URLs redirect" policy in §22's milestone table and §27 — **needs program confirmation**. |
| `/{locale}/dashboard` | `src/app/[locale]/dashboard/page.tsx` | **Redirect** | `/` (homepage) | Subscription dashboard: reads `user_subscriptions` (joined to `subscription_plans`) via the Supabase server client, redirects unauthenticated users to `/login`. §9 explicit remove target ("subscription dashboard"). Subscription state moves to RevenueCat, viewed in-app. Redirect target proposed, not specified in §9 — **needs program confirmation**. |
| `/{locale}/pricing` | `src/app/[locale]/pricing/page.tsx` | **Redirect** | `/` (homepage) | Web pricing/checkout page: reads current subscription via Supabase server client, renders `<SubscribeButton>`. §9 explicit remove target ("web pricing/checkout"). Purchase moves to the in-app IAP paywall. Redirect target proposed, not specified in §9 — **needs program confirmation**. |

**Totals: 12 route files found → 8 keep / 1 remove / 3 redirect.**

#### Non-route removal target named in §9

`src/components/SubscribeButton.tsx` — client component (`'use client'`),
rendered only by `pricing/page.tsx`. Uses `createClient` from
`@/lib/supabase/client` to check `auth.getUser()` before starting checkout.
§9 names it explicitly as a remove target. It is **not** a route file (no
`page.tsx`/`route.ts`/`page.ts`), so it does not get a row in the table above
or count toward the route-file totals — listed here only for completeness
against §9's remove list.

#### Middleware (not a route file, but load-bearing for the redirect design)

`src/middleware.ts` (site-wide Next.js middleware) wraps two concerns in one
function: `next-intl`'s `createMiddleware(routing)` (locale detection /
prefixing) and `updateSession()` from `src/lib/supabase/middleware.ts`
(Supabase SSR session refresh — §9's explicit "Supabase SSR middleware"
remove target). When the Supabase half is removed, the locale-routing half
must be preserved independently (or reimplemented equivalently in Go/htmx)
for the kept routes to keep working. This file is excluded from the route
table by pattern (not `page`/`route`), so it has no row above; flagged as a
concern below since it's directly relevant to §9's scope.

#### Support/contact route

Not present in the current tree as of 2026-07-22 (`find` for `*contact*` /
`*support*` under `peppercheck-webapp` returned no route files). §9 lists a
support/contact route as conditional: "a support/contact route if needed."
Today, contact information lives as an embedded "Contact Us" section (via the
`ObfuscatedEmail` component) inside `legal/privacy`, `legal/terms`, and
`legal/tokushoho` — not a standalone route. No table row, since no
corresponding file was found.

### 6.2 Supabase usage in the webapp

Files matching `grep -rln "@supabase" peppercheck-webapp --include="*.ts" --include="*.tsx"` (excluding `node_modules`, `.next`) — i.e. files that import the `@supabase/*` npm packages directly:

| File | Purpose | Consumers (purpose category) |
|---|---|---|
| `peppercheck-webapp/src/lib/supabase/server.ts` | Server-side (SSR) Supabase client factory (`createClient`), used in React Server Components / route handlers. | `dashboard/page.tsx` (dashboard — subscription query, `auth.getUser`), `pricing/page.tsx` (pricing — current-subscription check), `auth/callback/route.ts` (callback — `exchangeCodeForSession`). |
| `peppercheck-webapp/src/lib/supabase/middleware.ts` | `updateSession()` — refreshes/validates the Supabase auth session cookie on every request. | Invoked from `src/middleware.ts`, the site-wide middleware (see note above); underpins auth gating for login/dashboard/account-deletion. |
| `peppercheck-webapp/src/lib/supabase/client.ts` | Browser-side Supabase client factory (`createClient`), used in `'use client'` components. | `login/page.tsx` (login — `signInWithOAuth` Google), `components/SubscribeButton.tsx` (subscribe — checkout auth check), `account/delete/page.tsx` (account-deletion — `auth.getUser`, `rpc('check_account_deletable')`, `functions.invoke('delete-account')`). |

**3 files match `@supabase` directly.** All three are thin client-factory
wrappers under `src/lib/supabase/`; the actual Supabase calls (`.auth.*`,
`.from(...)`, `.rpc(...)`, `.functions.invoke(...)`) live in the consumer
pages/components listed in the "Consumers" column, which import these
wrappers via the `@/lib/supabase/...` path alias — a string that does not
contain the literal substring `@supabase`, so those consumer files correctly
do **not** appear in the grep match set even though they are Supabase
consumers. This is why `account/delete/page.tsx` (a **kept** route) is called
out separately in 6.1: it depends on Supabase indirectly and needs a
Firebase Auth + Go API rework despite not showing up in this list.

### 6.3 Verification

- Every route file found (12 files) appears exactly once in the route table
  above, each with a disposition. Confirmed by construction — table built
  directly from the enumerated file list.
- Every `@supabase`-matching file (3 files) appears in the Supabase-usage
  list above. Confirmed by construction — same set, no additions or
  omissions.

### 6.4 Concerns / open questions for the program

1. **Redirect targets for `login`, `dashboard`, `pricing` are proposed, not
   specified.** §9 only says removed URLs "must 301-redirect"; it does not
   name a target. All three are proposed here as redirecting to `/`
   (homepage) as the simplest safe default. Needs explicit program
   confirmation before implementation, especially if any of these URLs are
   indexed/linked externally (App Store/Play listing, ads, old emails) and
   a more specific landing page would serve users better than the bare
   homepage.
2. **`auth/callback` disposition (remove, no redirect) is inferred, not
   stated.** It is technically a "removed" URL, but functionally it is a
   machine-to-machine OAuth callback with no bookmark/link value once web
   login is gone. Recommend explicit sign-off that it does not need a 301,
   given §9's "removed Next.js URLs must 301-redirect" is otherwise
   unconditional in its wording.
3. **`account/delete/page.tsx` (kept) has a live Supabase dependency** not
   visible to a literal `@supabase` grep (see 6.1 and 6.2 above). Any future
   automated check for "webapp still has Supabase deps" that greps for the
   npm package name only will miss this; recommend also grepping for
   `@/lib/supabase` (the local alias) or, better, doing the actual Go/htmx
   port of this page before relying on grep-based verification that
   Supabase is fully removed from the webapp.
4. **`src/middleware.ts` is a load-bearing file not captured by the
   route-file patterns.** It's the only place `next-intl` locale routing and
   the Supabase SSR session refresh currently intersect; removing the latter
   (§9's explicit "Supabase SSR middleware" target) requires preserving or
   reimplementing the former for every kept route to continue resolving
   `/{locale}/...` correctly. Worth a line item in whatever plan implements
   §9, not just a route-by-route port.
5. **`auth/callback/route.ts` already redirects to a nonexistent page**
   (`/{locale}/auth/auth-code-error` has no matching file in the current
   tree) on the Supabase error path. Pre-existing dead link, unrelated to
   this refactor's scope but noted in case it causes confusion when reading
   the route's behavior.

## 7. Unused Code / Schema Drop Candidates (D8)

> Source: `docs/superpowers/plans/phase0-parts/07-drop-candidates.md`.
> Cross-references: program design doc §15 "Opportunistic Refactor Scope
> (bounded)," §17 "Edge Function → Go Mapping" (`billing-setup` row), §28 "To
> Confirm During Phase 0" (D8 candidates); §2 (T3 schema dead-code flags);
> §1.3 (`billing-setup` disposition); §4 (`stripe_billing_repository.dart:41`
> flag).

This is a **candidate list only** — nothing here has been deleted. Every row
below carries the grep evidence used to conclude "no caller," and every §2
schema candidate is explicitly marked "verify before drop" per the source
investigation's own hedge (also now reflected as the operator's resolution
in §2.7.1 / §2.7.2).

**Explicit exclusion:** the **trial-point** system (`lock_trial_points`,
`consume_trial_points`, `route_*`, and the Flutter domain/data/presentation
code that reads `point_wallets`/`trial_point_wallets`/`user_subscriptions`,
including files that happen to live under the legacy `features/billing/`
directory name) is **active, production code and stays**. It is a different
system from the dormant Stripe user-billing set below, despite sharing a
directory. See MEMORY note "Billing → Point Rename": `features/billing/` is a
legacy name; trial-point code belongs there for now and is out of scope for
this drop list.

### 7.A. Dormant Stripe user-billing set (Flutter) — not mounted, safe-to-drop candidate

Design doc §17 states `BillingSetupSection` is not mounted on any screen.
Re-verified independently: the whole call graph (widget → controller →
repository → domain types → edge function) is a closed, self-contained
subgraph with **zero inbound references from anywhere else in the app**.

| artifact | evidence it is unused | drop in phase | risk |
|---|---|---|---|
| `peppercheck_flutter/lib/features/billing/presentation/widgets/billing_setup_section.dart` (`BillingSetupSection` widget) | `grep -rn "BillingSetupSection" peppercheck_flutter/lib/` → only the class declaration itself (line 11). `grep -rn "billing_setup_section" peppercheck_flutter/lib/` (filename/import search) → **zero hits outside the file itself** — no screen imports or mounts it. | Phase 5 (Financial & subscription) — same area as the rest of `features/billing/` | Low. No caller anywhere; deleting cannot break another screen. |
| `peppercheck_flutter/lib/features/billing/presentation/billing_controller.dart` (+ `.g.dart`) | `grep -rln "billing_controller\.dart'" peppercheck_flutter/lib/` → only imported by `billing_setup_section.dart` (dead per above) and its own generated file. `billingControllerProvider` has no `ref.watch`/`ref.read` call sites outside `billing_setup_section.dart`. | Phase 5 | Low. Sole consumer is already-dead widget. |
| `peppercheck_flutter/lib/features/billing/data/stripe_billing_repository.dart` (+ `.g.dart`) | `grep -rln "stripe_billing_repository" peppercheck_flutter/lib/` → only `billing_controller.dart` (dead per above) and its own generated file import it. Calls `_supabase.functions.invoke('billing-setup')` (dormant edge fn, see 7.D) and reads `stripe_accounts.{pm_brand,pm_last4,pm_exp_month,pm_exp_year}` (dead columns, see 7.B). | Phase 5 | Low. Transitively dead; confirmed no other repository reads these columns (see 7.B). |
| `peppercheck_flutter/lib/features/billing/domain/stripe_billing_setup_session.dart` (+ `.freezed.dart`, `.g.dart`) | Only referenced from `stripe_billing_repository.dart` (dead per above); `grep -rln "StripeBillingSetupSession\|stripeBillingSetupSession"` returns only this domain file's own 3 generated/source files. | Phase 5 | Low. Pure DTO with one dead caller. |
| `peppercheck_flutter/lib/features/billing/domain/default_billing_method.dart` (+ `.freezed.dart`, `.g.dart`) | `grep -rln "DefaultBillingMethod"` → only `stripe_billing_repository.dart` and `billing_controller.dart` (both dead per above) plus its own generated files. | Phase 5 | Low. Pure DTO with only dead callers. |

**Note on phase timing:** §15 scopes opportunistic cleanup to "areas already
being migrated." `features/billing/` is touched in Phase 5 (point/subscription
work), so that is the natural drop point. Because this subgraph requires zero
Go-side work (pure deletion, no replacement needed), the operator may also
choose to pull it forward into Phase 0/1 as a zero-risk pre-cleanup — flagging
as an option, not asserting a phase change.

### 7.B. Dormant Stripe user-billing set (schema) — orphaned `stripe_accounts` columns

These columns back the same abandoned "off-session card registration" feature
as 7.A. Verified independently: **never written by any function or Edge
Function**, and (once 7.A is confirmed) never read either.

| artifact | evidence it is unused | drop in phase | risk |
|---|---|---|---|
| `stripe_accounts.default_payment_method_id`, `.pm_brand`, `.pm_last4`, `.pm_exp_month`, `.pm_exp_year` (`supabase/schemas/stripe/tables/stripe_accounts.sql:9-13`) | `grep -rn "pm_brand\|pm_last4\|pm_exp_month\|pm_exp_year\|default_payment_method_id" supabase/functions/billing-setup/index.ts supabase/functions/handle-stripe-webhook/index.ts` → no hits in either function (the two Stripe-account-touching Edge Functions never write these fields). Only reader is `stripe_billing_repository.dart:42` (dead, 7.A). `stripe_accounts_policies.sql` has no column-specific policy referencing them. | Phase 5 (same Atlas pass that touches `stripe/` schema for Connect payout work) | Low-medium. Columns are always NULL today (never written) so dropping loses no data; medium only in that this is a physical schema change (needs an Atlas migration) vs. the pure-deletion Flutter rows above. Confirm no out-of-repo tool (admin script, BI query) reads these columns before dropping. |

**Not a candidate:** the `stripe_accounts` **table** itself stays — it backs
the active Stripe Connect payout flow (`stripe_connect_account_id`,
`charges_enabled`, `payouts_enabled`, `connect_requirements` are read/written
by `prepare_monthly_payouts()`, `stripe_payout_repository.dart`,
`payout-setup`, `create-express-dashboard-link`, `execute-pending-payouts`,
`handle-stripe-webhook`, `delete-account`). Only the 5 card-on-file columns
above are dead.

### 7.C. §2 schema dead-code candidates — independently re-verified, "verify before drop"

Per the assembly brief, these are **not asserted for removal** — re-running
the §2 grep independently, scoped to the current `supabase/schemas/`
(declarative source of truth; `supabase/migrations/` is historical and out
of scope per §2's own scoping note).

| artifact | evidence it is unused | drop in phase | risk |
|---|---|---|---|
| `detect_and_handle_referee_timeouts()` (`supabase/schemas/matching/functions/detect_referee_timeouts.sql`) | `grep -rn "detect_and_handle_referee_timeouts" supabase/ peppercheck_flutter/lib/ peppercheck-webapp/src` → only hits are the function's own definition (`matching/functions/detect_referee_timeouts.sql`, `CREATE OR REPLACE FUNCTION` + `COMMENT ON FUNCTION`) and its historical `CREATE OR REPLACE` in two old migration files (`20251005123145_init.sql`, `20260124153250_...sql`) — no call site anywhere, ever, in any migration or schema file. Confirmed separately: `grep -rn "detect_and_handle_referee_timeouts" $(find supabase/schemas -path "*/cron/*" -name "*.sql")` → no hits in any of the 10 cron files (it has no `cron.schedule` entry, unlike its judgement-domain duplicate `detect_and_handle_review_timeouts()`, which is scheduled). | Phase 4 (Core task lifecycle — matching domain) | **Verify before drop** — resolved by operator adjudication, §2.7.1. Zero callers/cron entries confirmed independently. §2's own ambiguous-item #1 flags this could have been *meant* to be wired to a cron schedule that was never added, rather than intentionally dead — confirm intent with the operator before dropping, don't assume it's safe to silently drop the underlying business rule (referee timeout detection) along with the function. |
| `is_task_tasker(task_uuid, user_uuid)` (`supabase/schemas/profile/functions/auth_helpers.sql:37`) | `grep -rn "is_task_tasker" supabase/schemas/` → only its own definition, `ALTER FUNCTION`, and `COMMENT ON FUNCTION` (3 hits, all in `auth_helpers.sql` itself); **zero calls** from any current RLS policy or function in `supabase/schemas/`. Note: `grep -rn "is_task_tasker" supabase/migrations/` **does** show call sites in 3 historical migrations (`20251005123145_init.sql`, `20260123091601_refactor_judgements_table.sql`, `20260213051955_remove_judgements_view.sql`) — the function *was* called by earlier versions of judgement-related policies/functions that have since been refactored to drop the call. This corroborates rather than contradicts §2: the current schema state (source of truth) has zero callers; the historical trail explains *why* it looks vestigial rather than never-used. | Phase 4 (task/judgement domain — matches the file's historical callers) or Phase 3 if `profile/functions/auth_helpers.sql` as a whole is swept when the `profile` feature migrates; either is defensible, operator's call. | **Verify before drop** — resolved by operator adjudication, §2.7.2. Its two siblings in the same file — `is_task_referee()` and `is_task_referee_candidate()` — are **not** drop candidates: both are actively called once each from `task/policies/tasks_policies.sql` (confirmed by `grep -rn "is_task_referee\b\|is_task_referee_candidate" supabase/schemas/`), and their disposition is tied to the broader "retire all 63 RLS policies to Go authz" plan (§2.6 RLS summary), not to today's dead-code list. Do not conflate the three `auth_helpers.sql` functions. |

### 7.D. Cross-reference: `billing-setup` Edge Function (already flagged in §1.3)

Not re-tabulated in full here — §1.3 already classifies `billing-setup` as
**"Drop — currently unused"** and this section's 7.A independently confirms
its only caller (`stripe_billing_repository.dart`) is itself dead code with
zero upstream callers. Both findings agree: drop the `billing-setup` Edge
Function together with the Flutter subgraph in 7.A, in the same PR, so the
client and server sides of the dead feature are removed atomically.

### 7.E. Summary

| Group | Count | Disposition |
|---|---|---|
| A — Flutter dormant Stripe billing set | 5 files (+ 5 generated siblings) | Drop candidate, Phase 5 (or earlier as zero-risk pre-cleanup) |
| B — `stripe_accounts` orphaned columns | 5 columns on 1 table | Drop candidate, Phase 5 |
| C — §2 schema dead functions | 2 functions | Verify before drop (resolved, §2.7.1/2.7.2), Phase 3/4 |
| D — `billing-setup` Edge Function | 1 function | Already flagged in §1.3; drop together with A |
| Excluded | trial-point + subscription/point/IAP code in `features/billing/` | **Stays** — active production code, not evaluated for removal |

No other unused-code candidates were found within this task's grep scope
(Flutter dormant-billing verification + §2 schema corroboration). A broader
open-ended dead-code sweep of the rest of the codebase was not performed —
out of scope per §15's "bounded" cleanup rule (opportunistic cleanup only in
areas already being migrated, not a general audit).

## 8. Decisions Ledger

> Source: `docs/superpowers/plans/phase0-parts/08a-decisions-ledger.md`
> (ledger) and `docs/superpowers/plans/phase0-parts/08b-revenuecat-cost.md`
> (D4 cost verification detail). **D2 and D4 are accepted by the operator as
> of 2026-07-22** — the source part file's "Proposed — awaiting operator
> acceptance" status is superseded below.

### 8.1 Accepted

| # | Decision | Basis | Status |
|---|----------|-------|--------|
| D2 | Firebase Auth for authentication; PepperCheck owns an internal `users.id` UUID as the FK anchor + RevenueCat App User ID; `user_identities(issuer, subject)` maps Firebase → internal; provider unification via Firebase account linking; never use Firebase UID as a domain PK. | Program design §10, D2. | **Accepted** (operator sign-off 2026-07-22) |
| D4 | RevenueCat for subscription entitlement (durable deduplicated reconciled webhook); Stripe Connect retained for payouts; web Stripe Checkout + `billing-setup` dropped. | Program design §11, D4. RevenueCat cost verified (8.2 below): webhooks **and** REST API are included in the RevenueCat Pro plan, **free up to $2,500 MTR** (1% of tracked revenue thereafter). **D4 stands as-is; no cost note needed.** | **Accepted** (operator sign-off 2026-07-22) |

### 8.2 D4 cost verification detail (RevenueCat webhook/REST API cost)

> Source: `08b-revenuecat-cost.md`. Verifies, from official
> `revenuecat.com` sources only, whether a durable webhook and the REST API
> used for server-side reconciliation require a paid RevenueCat tier, and
> the monthly tracked revenue (MTR) threshold at which RevenueCat billing
> begins. Research only — no pricing asserted from memory.

#### Finding

**Both webhooks and the REST API are included in RevenueCat's single current
plan ("Pro"), which is free of charge up to $2,500 MTR.** There is no
separate paid gate specifically for webhook or REST API access beyond the
platform's overall revenue-share threshold.

##### Webhooks

The official webhooks doc states plainly:

> "Webhooks are available on our Pro plan. If you are on one of our legacy
> plans without access to webhooks, migrate to our new Pro plan to get
> access."
>
> — https://www.revenuecat.com/docs/integrations/webhooks (retrieved
> 2026-07-22)

The official pricing page lists "Real-time event notifications via webhooks"
as one of the standard features bundled into the (single, current) **Pro**
plan:

> — https://www.revenuecat.com/pricing (retrieved 2026-07-22)

Read together: RevenueCat consolidated its old Free/Starter/Pro tier split
into one plan, called "Pro," that is free up to the MTR threshold. The
"legacy plans without access to webhooks" language refers to old,
pre-consolidation plans that some existing customers may still be grandfathered
into — it is not a currently-purchasable tier. For a new integration (this
project's case), the only plan available is Pro, and it includes webhooks
from the start, at $0, below the MTR threshold.

Webhook delivery/durability characteristics also confirmed on the same page
(relevant to D4's "durable, deduplicated" webhook design, not a pricing
point): at-least-once delivery, retries up to 5 times over 5/10/20/40/80
minutes, 60-second response timeout, and an explicit note that duplicate
delivery can happen — "recommending idempotent processing using event IDs to
prevent duplicate handling."

##### REST API

The pricing page lists "Comprehensive REST API" as a standard Pro-plan
feature (https://www.revenuecat.com/pricing, retrieved 2026-07-22). The
REST API v2 documentation page
(https://www.revenuecat.com/docs/api-v2, retrieved 2026-07-22) contains no
pricing-tier or paid-plan gate language at all — it covers only
authentication, endpoints, permissions, and rate limits. No official source
found that restricts REST API access to a higher/separate paid tier.

##### MTR threshold

RevenueCat's Pro plan is **free up to $2,500 in monthly tracked revenue
(MTR)**. Above that threshold, RevenueCat charges **1% of MTR** (gross
tracked revenue, not net-of-store-commission).

> — https://www.revenuecat.com/pricing (retrieved 2026-07-22)

This is also corroborated by RevenueCat's own blog post on the pricing
change, which frames the new $2,500 threshold as a change from a prior
$1,000 threshold on some legacy plans, and confirms the 1% rate applies once
crossed:

> — https://www.revenuecat.com/blog/company/navigating-revenuecats-new-pricing-for-existing-users/
>   (retrieved 2026-07-22)

#### Sources (official revenuecat.com only)

| URL | Retrieved | What it confirms |
|---|---|---|
| https://www.revenuecat.com/pricing | 2026-07-22 | Single "Pro" plan, free to $2,500 MTR then 1%; webhooks + REST API listed as standard included features |
| https://www.revenuecat.com/docs/integrations/webhooks | 2026-07-22 | "Webhooks are available on our Pro plan" (the only current plan); delivery/retry/idempotency behavior |
| https://www.revenuecat.com/docs/api-v2 | 2026-07-22 | REST API v2 reference; no tier/paid-plan gate language present |
| https://www.revenuecat.com/blog/company/navigating-revenuecats-new-pricing-for-existing-users/ | 2026-07-22 | Confirms $2,500 MTR threshold (up from a prior $1,000 on some legacy plans) and 1% rate; explains legacy-plan migration context for the webhooks doc's wording |

Third-party pricing aggregators (spotsaas.com, costbench.com, etc.) surfaced
in search were **not** used as sources of record — they broadly agree with
the above ($2,500 MTR, 1%, webhooks included) but are not authoritative and
are omitted from the cited findings per the research constraint.

#### Implication for D4

**D4 stands as-is.** A durable webhook plus REST-API-based reconciliation is
available on RevenueCat's only current plan at **$0 cost** for this project
while MTR stays under $2,500/month. There is no separate fee gating webhook
or reconciliation-API access specifically — the only cost trigger is the
platform-wide 1% MTR revenue share once the project's tracked revenue
crosses $2,500/month, which is a revenue-share cost of using RevenueCat at
all (any feature), not an incremental cost of the webhook/reconciliation
design in D4. No cost note is required in D4 for pre-$2,500-MTR operation;
once the project approaches that MTR level, the 1%-of-MTR fee should be
budgeted as a standard cost of the RevenueCat integration overall (out of
scope for this webhook-specific check).

#### Concerns / caveats

- RevenueCat's webhooks doc references "legacy plans without access to
  webhooks." No official page enumerates what those legacy plans are, when
  they closed to new signups, or whether a brand-new RevenueCat account
  created today could somehow land on one. Everything else on the official
  pricing page indicates the only currently-offered plan is Pro, so this is
  treated as reassurance/context rather than a live risk — but it was not
  possible to find an official source stating explicitly "new signups can
  only choose Pro."
- The 1% MTR fee is stated as gross tracked revenue in RevenueCat's own
  materials; no official page was found that further breaks down whether
  "tracked revenue" for MTR-threshold purposes includes revenue RevenueCat
  cannot itself observe (irrelevant to the webhook/API cost question, noted
  only for completeness).
- Enterprise-tier terms (volume discounts, custom SLAs) are explicitly
  "custom pricing" per the official pricing page — no numbers are published,
  so nothing further can be confirmed there. Not relevant to D4 at this
  project's scale.

### 8.3 Open decisions (decide-by phase)

| Decision | Options / notes | Decide-by phase |
|----------|-----------------|-----------------|
| RPO/RTO target | Daily dump ⇒ up to 24 h data loss. If unacceptable, add WAL/PITR or use managed Postgres (program §20). | Phase 7 (Staging/release) |
| VPS provider / region / size | Initial ~2 GB RAM working hypothesis; re-estimate if staging+production share one VPS (§18). | Phase 7 |
| staging + production co-location | Same VPS (separate Compose project/network/volume/secrets) vs separate hosts. | Phase 7 |
| Monitoring / alert provider | Managed uptime/log alerting acceptable; custom platform out of scope (§21). | Phase 7 |
| B2 retention count + encryption | 7–30 generations; encrypt (pg_dump is not encrypted) (§20). | Phase 7 |
| Domains / DNS | Per-environment domains (§18). | Phase 7 |
| Concrete dates + code freeze | Set after the Phase 0 velocity check (§23), not now. | End of Phase 0 |

### 8.4 Deferred, not open (recorded to close program §28)

- **RevenueCat product/entitlement mapping** → Phase 5 implementation detail (config/DB data, program §11), not a Phase 0 blocker.
- **Point / trial-point reset behavior** → **already decided**: points reset on renewal, not accumulate (PR #339). Cite, do not re-litigate.

## 9. Seed / Tester-Data Policy

> Source: `docs/superpowers/plans/phase0-parts/09-seed-policy.md`.

### 9.1 Go-live data strategy (program D9)

The Go-live DB is built **fresh** from Atlas migrations + reference seed data. **No
historical migration, no dual-write.** Testers re-create their account via normal
Firebase login (a new internal `users.id` UUID); old profile rows are not imported
(identity mismatch under §10 — a few testers re-enter their profile).

### 9.2 Current seed state (measured)

- `supabase/config.toml` `[db.seed]` references `sql_paths = ["./seed.sql"]`, but
  **no `supabase/seed.sql` exists** — there is no persistent row-seed today.
- Reference data is expressed as schema DDL: enum types
  (`matching`, `trial_point`, `subscription`, `point`, … `tables/enums.sql`) and
  any singleton config tables (`BOOLEAN PK DEFAULT true` pattern).

### 9.3 Seed subset for the fresh DB (to build during the Atlas baseline, Phase 1)

| Data | Kept? | Note |
|------|-------|------|
| Enum types | Yes (DDL) | Part of the schema; recreated by migrations. |
| Singleton config rows (e.g. deadline/point config) | Yes | Enumerate during Atlas baseline; seed as reference rows. |
| Product-to-plan / entitlement mapping | Yes (Phase 5) | Config/DB data for RevenueCat; not needed until Phase 5. |
| Tester accounts / profiles | **No** | Recreate via login (D9). |
| Historical tasks / ledgers / payouts | **No** | Disposable internal-test data (D9). |

**Tester data worth keeping: none** (default per D9). The old Supabase env may stay
read-only briefly for **comparison only** — never rollback, never in the runtime path.

---

## Done Checklist

> Per Phase 0 spec §7. Each item ticked with the section of this baseline
> that satisfies it.

- [x] Every external integration has an owner/disposition (§16 table
      complete). → **§1** (21-row master dependency inventory, §1.2,
      completeness-verified in §1.4; plus the 12-row edge function detail in
      §1.3).
- [x] 68 functions / 15 business triggers / 10 cron classified
      move / stay / delete. → **§2** (§2.3 Functions table, 68 rows, tally
      23/41/4; §2.4 Business triggers table, 15 rows, tally 5 stay + 10
      move + 21 housekeeping; §2.5 Cron table, 10 rows, all move-to-Go
      worker). Ambiguities resolved in §2.7.
- [x] All launch-blockers identified (incl. `payout-request` fix plan), each
      assigned an owning phase. → **§3** (§3.1 `payout-request`, owning
      phase Phase 5; §3.2 T7-1/T7-2/T7-3, owning phases Phase 5, Phase 5,
      Phase 6 respectively, each with evidence + proposed fix).
- [x] High-risk journey behavior catalog complete. → **§5** (5 flows —
      auth, point/trial-point ledger, payout, judgement state machine,
      account deletion — each with preconditions, steps, expected behavior,
      invariants, edge cases, and pgTAP evidence or an explicit test gap;
      verified complete in §5.1).
- [x] Web routes finalized as keep / remove / redirect. → **§6** (§6.1,
      12 routes: 8 keep / 1 remove / 3 redirect, verified in §6.3).
- [x] Unused-code drop candidates concretely listed. → **§7** (§7.A–7.D:
      5 Flutter files + generated siblings, 5 orphaned schema columns, 2
      schema dead functions marked verify-before-drop, 1 Edge Function;
      summarized in §7.E).
- [x] Identity (D2) and subscription (D4) decisions accepted; RevenueCat
      cost verified. → **§8** (§8.1: D2 and D4 both **Accepted**,
      operator sign-off 2026-07-22; §8.2: RevenueCat webhook + REST API
      cost verified from official sources — $0 below $2,500 MTR, 1%
      thereafter, no separate paid gate).
- [x] Open decisions recorded with a decide-by phase. → **§8.3** (RPO/RTO,
      VPS provider/region/size, staging+production co-location,
      monitoring/alert provider, B2 retention+encryption, domains/DNS,
      concrete dates+code freeze — all recorded with a decide-by phase,
      mostly Phase 7).

**No gaps.** All eight Done-checklist items are satisfied by this baseline.
The deliverable definition in Phase 0 spec §3 also calls for a Flutter
API-surface map (§4 here) and a seed/tester-data policy (§9 here); both are
included even though the Done checklist doesn't name them as separate line
items — they are covered implicitly by "every external integration has an
owner/disposition" (§4 is the Flutter-side view of the same inventory) and
are not themselves gating criteria per §7 of the Phase 0 spec.

