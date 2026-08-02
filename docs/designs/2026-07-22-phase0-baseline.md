# Phase 0 Baseline — Supabase → Go API + VPS Refactor (Merged Draft)

> Status: **Single canonical Phase 0 baseline.** This document merges the two
> Phase 0 baselines that existed in parallel —
> `docs/designs/2026-07-22-phase0-baseline.md` (the detailed,
> already-max-Go baseline; canonical/base document for this merge) and
> `docs/designs/2026-07-22-go-api-vps-phase-0-baseline-design.md`
> (the supplement, source of the operational decisions, subscription
> baseline, exit criteria, measurements, and Phase 1 handoff) — into one
> deliverable. The supplement's content is absorbed here; the supplement
> file itself is left uncommitted/superseded once this draft is reviewed and
> promoted to `docs/designs/`.
>
> Parent documents:
> - Program strategy: `docs/designs/2026-07-22-supabase-to-go-vps-refactor-design.md`
> - Phase 0 spec (defines this deliverable's shape + Done checklist):
>   `docs/designs/2026-07-22-phase0-freeze-baseline-design.md`
>
> Merged: 2026-07-23. Sources: `2026-07-22-phase0-baseline.md` (~2,531
> lines, assembled from nine investigation part files in
> `docs/development/go-vps-plans/phase0-parts/`) and
> `2026-07-22-go-api-vps-phase-0-baseline-design.md` (~570 lines).
>
> **Historical-decision note (2026-08-02):** this baseline records the Phase 0
> decision to retain `handle_updated_at`. The program strategy later superseded
> that implementation choice: Go is the sole write boundary, mutable Store SQL
> explicitly sets `updated_at = now()`, and the target schema starts with no
> functions or triggers. The inventory and original rationale below remain
> unchanged as historical evidence.
>
> **Provenance note on inline citations.** Long evidence passages below are
> carried over from the canonical baseline largely verbatim (per the merge
> brief's instruction to preserve SQL citations, file:line references, and
> grep results without watering them down). Inline citations inside that
> prose — e.g. `§2.3 #24`, `see 2.9`, `§3 T7-2`, `§7.A` — refer to the
> **canonical source document's own internal section numbers**, not to this
> merged document's section numbers, unless a citation explicitly says
> "this document." Where a function or trigger is cited by number (e.g.
> `#24`), that number matches **Appendix A**'s numbering below, which
> preserves the canonical source's original 1–68 numbering unchanged. A
> handful of sentences that stated a now-superseded position (`payout-request`
> as an unresolved launch-blocker to implement; cron logic staying callable
> via RPC; DB-functions "staying in Postgres") have been corrected in place
> per the merge brief; those edits are called out inline where they occur.

## Operator adjudications folded into this baseline

1. **D2 (identity) and D4 (subscription/RevenueCat) are ACCEPTED**, not
   pending — see §12.
2. **T3 DB-logic ambiguities are resolved** — see §4 "Operator resolutions."
3. **Three financial-integrity risks surfaced by the journey catalog (§6)
   are added to the launch-blocker register (§5)** as "candidate — verify
   in owning phase," each assigned an owning phase (Phase 5 ×2, Phase 6
   ×1).
4. **DB-logic classification refined to a "max-Go" rule (2026-07-23).** The
   classification in §4 is derived by decomposing each function: logic /
   routing / orchestration / validation / derived-state → Go; only the
   irreducible atomic statement stays as SQL, issued inside a Go-owned
   transaction. No business PL/pgSQL function or trigger survives as a
   callable stored function — only `handle_updated_at` (housekeeping)
   remains DB-side.
5. **Merged with the parallel supplement 2026-07-23; operational decisions
   adopted.** The supplement's accepted recovery/VPS/monitoring/release-timing
   decisions (§12), subscription baseline (§8), exit criteria (§1),
   reproducible measurements (§2), and Phase 1 handoff (§13) are folded into
   this single canonical document. Where the supplement and the canonical
   baseline disagreed only in framing (e.g. "open decision" vs. "accepted
   decision"), the accepted/resolved framing wins per this adjudication.

---

## 1. Goal & Exit Criteria

> Source: supplement §1–2.

Freeze the current Supabase-dependent system as a reproducible inventory
before the Go migration starts. Every current integration, database
routine, trigger, cron job, public route, and high-risk user journey must
have a target owner and disposition.

Phase 0 does not add the Go runtime. It removes ambiguity so Phase 1 can
create the provider-independent foundation without rediscovering current
behavior.

### Exit Criteria

- [x] Flutter and web Supabase calls measured and assigned to target features.
- [x] All 68 schema functions classified.
- [x] All 36 schema triggers classified.
- [x] All 10 cron schedules classified.
- [x] All 12 Edge Functions and the orphaned `payout-request` call classified.
- [x] Firebase, Stripe, R2, IAP, webhook, web-hosting, backup, and monitoring
      integrations have a target owner or an explicit removal decision.
- [x] Reduced web routes and redirects fixed.
- [x] Tester-profile migration decision and reference-data seed set fixed.
- [x] Identity and subscription model inherited from the parent strategy.
- [x] Existing high-risk characterization coverage recorded with migration gates.
- [x] Owner accepts the recovery, VPS/environment, and monitoring decisions
      (§12).
- [x] Release timing is intentionally milestone-based; no calendar date is
      required to exit Phase 0.

All boxes are checked — this baseline satisfies the Phase 0 spec's exit
criteria in full.

## 2. Reproducible Measurements

> Source: supplement §3.

Run:

```bash
scripts/audit_go_api_vps_phase0.sh
```

The script exists at `scripts/audit_go_api_vps_phase0.sh` (confirmed
present in the repository, executable). The 2026-07-22 snapshot is:

| Measurement | Count | Interpretation |
|---|---:|---|
| Flutter files importing `supabase_flutter` | 24 | Includes auth and presentation-layer violations. |
| Raw Flutter `.from(` matches | 31 | Textual count only. |
| Verified Flutter PostgREST table calls | 18 | The other 13 raw matches are Dart `List.from` / `Map.from` conversions. |
| Flutter RPC calls | 21 | Two `.rpc<String>` calls were omitted by the earlier 19-call measurement. |
| Distinct Flutter RPC functions | 21 | No duplicate RPC target in the current call sites. |
| Flutter Edge Function calls | 7 | `generate-upload-url` has two callers. |
| Distinct Flutter Edge Function targets | 6 | Includes missing `payout-request`. |
| Declarative schema functions | 68 | Current schema only; historical migrations excluded. |
| Declarative schema triggers | 36 | 21 housekeeping and 15 business triggers. |
| Declarative schema cron jobs | 10 | All are business or external-side-effect jobs. |
| Edge Function source directories | 12 | Current source only; historical deletions excluded. |

**The 19→21 RPC correction.** The earlier reviewer count of 21 RPC calls was
correct; the program strategy has been corrected from 19 to 21. The root
cause (§3's own §4.1 detail, carried into this document's §3.6): the
literal-substring grep `\.rpc(` misses generic-typed calls of the form
`.rpc<String>(...)`, where a type argument sits between `rpc` and `(`. Two
call sites in `matching_repository.dart` use this generic form. See §3.6 for
the full reconciliation.

## 3. Dependency Inventory

> Source: canonical §1 (`docs/development/go-vps-plans/phase0-parts/01a-dependency-inventory.md`
> + `01b-edge-functions.md`), enriched at §3.6 with the supplement's
> per-feature Flutter/webapp call view (supplement §4). Synthesizes program
> design doc §16 (dependency inventory skeleton), §11 (billing vs. payouts),
> §17 (Edge Function → Go mapping), §13 (logic classification), §12
> (background work).

### 3.1 Stripe Connect vs. Stripe Billing separation

Program §11 requires this split explicitly before any shared Stripe code is
deleted. Investigation of `supabase/schemas/stripe/` (only table:
`stripe_accounts`) plus its callers shows the split is **not clean at the
code level today** — two places interleave Connect (keep) and Billing
(drop) concerns in the same object:

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
`stripe_accounts`). The edge-function inventory describes this function as
one unit ("port as a signature-verified Go endpoint") without flagging the
internal split. Per §11 ("Money in" moves to RevenueCat; "Money out" keeps
`handle-stripe-webhook`), **the Go port should drop the 3 Billing case-handlers
and keep only the Connect `account.updated` handler** — this is a scope
narrowing that isn't visible from the function-level table alone.

#### Finding 3: `stripe_billing_repository.dart` is confirmed dead code

The Flutter API-surface investigation (Appendix C) flagged
`stripe_billing_repository.dart:41`'s read of `stripe_accounts` as having an
"unresolved dependency" on the unused `billing-setup` function. This
investigation resolves it: `grep -rn "BillingSetupSection(" peppercheck_flutter/lib/`
returns **only the widget's own class declaration** — it is never
instantiated by any screen. Both of `StripeBillingRepository`'s methods
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
opportunistic-refactor drop candidate worth flagging alongside it (see §10).

#### Conclusion

Stripe **Connect** (payouts — keep, port to Go): `stripe_accounts`'s 4
Connect columns, `payout-setup`, `create-express-dashboard-link`,
`execute-pending-payouts`, `payout-request` (dead/unmounted — remove, §5.1),
`handle-stripe-webhook`'s `account.updated` case only, `recommend-payout-topup`
(operator tool).

Stripe **Billing** (subscription/card — drop, do not port): `stripe_accounts`'s
6 Billing columns, `billing-setup`, `create-stripe-checkout`,
`handle-stripe-webhook`'s 3 subscription-event cases, Flutter
`stripe_billing_repository.dart` + `billing_setup_section.dart` (confirmed
dead), webapp `SubscribeButton.tsx`/`pricing`/`dashboard` routes (already
flagged for removal by §9).

### 3.2 Master dependency inventory table

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
| Go replacement | Self-hosted Postgres on the VPS (§12) — same engine, re-platformed |
| data/config conversion | Drop `auth.users`/`auth.uid()` coupling (16 references, §4); ownership FKs move to an internal `users.id` (§8 baseline); connection config moves from Supabase's pooler to VPS-local Postgres |
| temporary coexistence | None — see umbrella answer; fresh Atlas-baselined DB at go-live (D9) |
| disposition | **Keep, re-platform** |

#### Supabase Auth

| Column | Value |
|---|---|
| used-by feature | authentication (Flutter), webapp `login`/`auth/callback` (both removal targets, §9) |
| direct-client-call? | Yes — 5 Supabase Auth SDK call sites / 4 files (Appendix C's `auth` table: `Supabase.initialize`, `onAuthStateChange` ×2, `signInWithIdToken`, `signOut`), plus webapp's `signInWithOAuth`/`exchangeCodeForSession`/`updateSession` via `src/lib/supabase/{client,server,middleware}.ts` (§9) |
| Go replacement | Firebase Auth + internal-UUID identity (§8, §12) |
| data/config conversion | `auth.users` table (and everything FK'd to it) replaced by an internal `users` table; the 10 `presentation/`-layer `currentUser?.id` reads across 7 files (Appendix C) must move to an app-level current-user provider |
| temporary coexistence | None — testers re-create accounts via Firebase login (D9); no dual-auth period |
| disposition | **Replace** — Firebase Auth |

#### PostgREST (`.from`)

| Column | Value |
|---|---|
| used-by feature | matching, notification, profile, task, report, currency, billing (point), payout — see Appendix C's full 18-row call-site table |
| direct-client-call? | Yes — the raw grep baseline is 31; Appendix C reconciled this to **18 real call sites over 9 tables** (13 of 31 are Dart `Map.from`/`List.from` false positives, not Supabase calls) |
| Go replacement | Per-table `/api/v1/...` Go endpoints; only `GET /api/v1/me` is design-doc-fixed today, the rest are Appendix C's naming proposals pending feature-phase confirmation |
| data/config conversion | RLS-scoped `eq('user_id', ...)` filters become explicit authenticated-user scoping in Go handlers; webapp's SSR reads of `user_subscriptions` (`dashboard`/`pricing`) are dropped with those routes (§9), not ported |
| temporary coexistence | None — Flutter's Supabase repositories are replaced by `ApiXxxRepository` at cutover, no side-by-side period |
| disposition | **Replace** — Go API endpoints |

#### RLS

| Column | Value |
|---|---|
| used-by feature | All 13 policy domains (evidence, judgement, matching, notification, point, profile, rating, report, reward, stripe, subscription, task, trial_point), 63 policies across 30 files |
| direct-client-call? | No — enforced transparently by Postgres/PostgREST; not a call site |
| Go replacement | Go service-layer authorization (§12); Firebase-verified JWT + application-layer checks |
| data/config conversion | **Retire all 63 policies**; wallet/ledger-adjacent policies (point, trial_point, reward) flagged as possible defense-in-depth keepers — a Go-implementation decision, not decided here (remains open, §4.6) |
| temporary coexistence | None — RLS stays enforced on the old DB until cutover; no dual-authz period on the new stack |
| disposition | **Replace** — Go authz layer (narrow defense-in-depth RLS possibly retained, TBD) |

#### Storage

| Column | Value |
|---|---|
| used-by feature | n/a — zero usage confirmed: no `storage.buckets`/`storage.objects` reference in `supabase/schemas/`, `peppercheck_flutter/lib/`, or `peppercheck-webapp/src` |
| direct-client-call? | No |
| Go replacement | n/a — object storage is already R2 today (see R2 row), never Supabase Storage |
| data/config conversion | None needed |
| temporary coexistence | None |
| disposition | **No — unused** (confirms design doc §16) |

#### Realtime

| Column | Value |
|---|---|
| used-by feature | n/a for the client — zero `.channel(`/`RealtimeChannel`/`.stream(` usage in `peppercheck_flutter/lib/`; MEMORY.md's subscription-refresh design already specifies polling, not Realtime |
| direct-client-call? | No |
| Go replacement | n/a — polling per existing subscription-refresh design |
| data/config conversion | `supabase/schemas/subscription/tables/realtime.sql` still runs `ALTER PUBLICATION supabase_realtime ADD TABLE public.user_subscriptions`, with a comment claiming it's "so Flutter clients can detect subscription status changes" — but no client code consumes it. Dead schema config; flag as an opportunistic-refactor drop candidate during Atlas baselining |
| temporary coexistence | None |
| disposition | **No — unused** (confirms design doc §16); one dead schema object to clean up |

#### Edge Functions — Go endpoint only (4 of 12)

| Column | Value |
|---|---|
| Functions | `create-express-dashboard-link`, `payout-setup`, `handle-stripe-webhook` (Connect scope only — see 3.1 Finding 2), `generate-upload-url` |
| used-by feature | payout (Flutter `stripe_payout_repository.dart`), evidence + profile (`generate-upload-url`, shared) |
| direct-client-call? | Yes for 3 of 4 (`create-express-dashboard-link`, `payout-setup`, `generate-upload-url` — via `.functions.invoke`); No for `handle-stripe-webhook` (external Stripe Dashboard webhook registration only) |
| Go replacement | Straightforward Go endpoints behind app auth middleware / signature verification (§3.3) |
| data/config conversion | Stripe secret key + webhook signing secret move from Supabase Vault to Go config/secret store; R2 credentials move similarly for `generate-upload-url` |
| temporary coexistence | None; Stripe webhook endpoint URL must be **re-registered** in the Stripe Dashboard at cutover — a one-time flip, not a coexistence period |
| disposition | **Port to Go endpoint** |

#### Edge Functions — Go endpoint + worker (2 of 12)

| Column | Value |
|---|---|
| Functions | `delete-account`, `send-notification` |
| used-by feature | account (Flutter + webapp, both callers per §3.3); notification (reached only via DB's `notify_event`, no direct client caller) |
| direct-client-call? | Yes for `delete-account` (Flutter `account_repository.dart:28` + webapp `account/delete/page.tsx:52`); No for `send-notification` (Postgres → `notify_event` → `pg_net` only) |
| Go replacement | `delete-account` → Go endpoint + worker, idempotent saga (§5.2.3); `send-notification` → Go endpoint + worker (FCM) — needs an equivalent trigger point since Postgres stops calling out over HTTP |
| data/config conversion | `delete-account`'s current implementation is best-effort/non-transactional across Stripe transfer, subscription cancel, Connect deauth, R2 cleanup — the Go port must convert this to persisted, retryable deletion state; `send-notification`'s Firebase Admin credentials move to Go config |
| temporary coexistence | None; both callers of `delete-account` (Flutter + webapp) must be re-pointed together at cutover |
| disposition | **Port to Go endpoint + worker** |

#### Edge Functions — Go worker only (2 of 12)

| Column | Value |
|---|---|
| Functions | `execute-pending-payouts`, `sweep-r2-stale-objects` |
| used-by feature | reward/payout; common (R2 hygiene) |
| direct-client-call? | No — both reached only via Postgres cron (`net.http_post`), never from Flutter/webapp |
| Go replacement | Go worker jobs (durable) — the `pg_net` HTTP hop is dropped entirely, becoming an in-process worker call |
| data/config conversion | `execute-pending-payouts` and `delete-account`'s reward-payout step share near-duplicate Stripe-transfer + `deduct_reward_for_payout` logic — recommend consolidating into one Go domain function during the port |
| temporary coexistence | None |
| disposition | **Port to Go worker** |

#### Edge Functions — Drop, unused legacy (1 of 12)

| Column | Value |
|---|---|
| Function | `billing-setup` |
| used-by feature | billing (Flutter `stripe_billing_repository.dart:22`) — **confirmed dead**, see 3.1 Finding 3 |
| direct-client-call? | Yes in code, but unreachable in practice (no mounted UI caller) |
| Go replacement | None — not ported |
| data/config conversion | n/a — delete Flutter caller alongside (`stripe_billing_repository.dart`, `billing_setup_section.dart`, `billing_controller.dart`'s billing-setup wiring) |
| temporary coexistence | None |
| disposition | **Drop** |

#### Edge Functions — Dropped, feature removed (1 of 12)

| Column | Value |
|---|---|
| Function | `create-stripe-checkout` |
| used-by feature | webapp `SubscribeButton.tsx` (removal target, §9) |
| direct-client-call? | Yes, webapp only — no Flutter caller |
| Go replacement | None — web subscribe checkout is removed per §9/§11 of the program design, not ported |
| data/config conversion | n/a |
| temporary coexistence | None |
| disposition | **Dropped** (web subscribe removed) |

#### Edge Functions — Removed, replaced externally (1 of 12)

| Column | Value |
|---|---|
| Function | `handle-google-play-rtdn` |
| used-by feature | subscription — see the dedicated Google Play RTDN row below |
| direct-client-call? | No — external Google Cloud Pub/Sub push only |
| Go replacement | None on our side — RevenueCat ingests RTDN directly (program §11) |
| data/config conversion | See Google Play RTDN row |
| temporary coexistence | None |
| disposition | **Removed** |

#### Edge Functions — Operator tool (1 of 12)

| Column | Value |
|---|---|
| Function | `recommend-payout-topup` |
| used-by feature | operator only — no automated caller found (no cron entry, no app invocation); auth via `X-Operator-Secret` |
| direct-client-call? | No (not app-facing); manual operator invocation only |
| Go replacement | **Go operator endpoint** (resolved by operator adjudication — the ambiguity between "endpoint or standalone operator script" is closed in favor of the endpoint) |
| data/config conversion | `OPERATOR_AUTH_TOKEN` moves to Go config |
| temporary coexistence | None |
| disposition | **Port as a Go operator endpoint** (resolved) |

**Edge Functions reconciliation:** 4 (endpoint) + 2 (endpoint+worker) + 2
(worker) + 1 (drop, unused) + 1 (dropped, feature removed) + 1 (removed,
externally replaced) + 1 (operator tool) = **12 of 12**, matching §3.3's
totals line exactly ("2 dropped, 1 removed, 1 operator tool, 2 → worker, 6 →
endpoint [4 endpoint-only + 2 endpoint+worker]"). Separately, `payout-request`
(Appendix C, §3.3) was investigated: Flutter calls
`.functions.invoke('payout-request')` but no such Edge Function exists — the
whole call path is **dead/unmounted code** (zero callers of the Flutter
method, its dialog is never mounted), not a reachable launch-blocker. **No
Go endpoint is built for it.** The dead client code is removed in the Phase 5
payout migration. See §5.1 and §10.F for the full resolution and evidence.
*(This corrects an earlier framing in the canonical source, which described
`payout-request` at this point as needing "a net-new Go payout endpoint, not
a port" — that framing was superseded by the source's own later §3.1/§7.F
investigation and is not carried forward here.)*

#### DB Functions (68)

| Column | Value |
|---|---|
| used-by feature | All — full per-function table in Appendix A |
| direct-client-call? | Mixed — 21 of 68 called directly from Flutter via `.rpc()`/`.rpc<T>()` (Appendix C's rpc table, 21 call sites = 21 distinct functions, zero duplicates); the rest are internal (triggers, other functions, or Edge Functions only) |
| Go replacement | Every function is decomposed into its logic/routing/orchestration/validation component (→ Go) and its irreducible atomic statement, if any (→ store SQL issued inside a Go-owned transaction). See §4 for the full 5-way classification: **DB invariant/helper 1 · Store query 4 · Go transaction 38 · Go service/worker 21 · Drop 4 = 68** (Go-managed = 63 of 68). `auth.uid()`-gated functions (14) become explicit user-scoped SQL called from Go with an app-supplied user id; `get_point_for_matching_strategy` becomes a single Go constant — all its callers move to Go, so no Postgres copy is retained; `handle_new_user` is a special case — its trigger *mechanism* dies with Supabase Auth, but its provisioning logic (profile/notification_settings/user_ratings/point_wallet/trial_point_wallet creation) needs an explicit Go-side "create user" onboarding step, not a drop |
| data/config conversion | See Go replacement above; Appendix A carries the full per-function evidence |
| temporary coexistence | None; store-owned SQL statements for locking/ledger operations live behind the Go store post-cutover, not as callable Postgres stored functions |
| disposition | **Split** — see §4/Appendix A for the per-function classification; no business function stays as a Postgres stored function; the sole DB-side survivor is the `handle_updated_at` housekeeping trigger helper |

*(The canonical source's original text for this row described a "Go 48 /
Go-tx SQL 15 / DB trigger 1 / delete 4" split and, in an earlier framing
retained from before its own max-Go refinement, described "integrity-atomicity
/ query-set (23) → stay in Postgres" — that "stay in Postgres" framing
described a pre-refinement categorization and is a business-function
staying-in-Postgres statement the merge brief requires not be carried
forward. This row instead cites §4's operator-approved 5-way tally
directly.)*

#### Triggers (36)

| Column | Value |
|---|---|
| used-by feature | matching, judgement, evidence, rating, task, auth (onboarding) for the 15 business triggers; all domains with `updated_at` columns for the 21 housekeeping triggers |
| direct-client-call? | No — fire on DB writes only, never called directly |
| Go replacement | 21 housekeeping (`set_updated_at`) stay as minimal DB triggers, all calling `handle_updated_at`; **all 15 business triggers dissolve into Go** — some as plain Go orchestration logic, others as a single atomic SQL statement Go issues inside the same transaction as the write that used to fire the trigger. See §4/Appendix B for the per-trigger mechanism. |
| data/config conversion | The Go-side equivalents for the dissolved business triggers become explicit calls inside the same business-orchestration functions that already move to Go (e.g., `settle_evidence_timeout`'s notify step folds into the Go evidence-settlement flow) |
| temporary coexistence | None — new schema ships without the 15 business triggers from day one |
| disposition | **Split** — 21 housekeeping stay as DB triggers; **all 15 business triggers → Go** (matches Appendix B's tally: 15 + 21 = 36) |

#### Cron (10)

| Column | Value |
|---|---|
| used-by feature | matching (1), judgement (3), notification (3), reward (2), common/R2 (1) — full table in §4.3 |
| direct-client-call? | No — internal `pg_cron` schedule, unreachable by any client |
| Go replacement | Go `worker`'s internal scheduler; supercronic/ticker as periodic enqueue trigger; **all 10** business jobs move — none of the 10 is pure DB-internal maintenance, so nothing stays as `pg_cron` |
| data/config conversion | 2 of 10 (`sweep-r2-stale-objects`, `execute-pending-payouts`) already call out via `pg_net`/`net.http_post` to Edge Functions today — these become direct in-process Go worker jobs, dropping the HTTP hop. The SQL underlying 3 of 10 (`detect_and_handle_review_timeouts`, `detect_auto_confirms`, `detect_and_handle_evidence_timeouts`) is issued directly by the Go worker as Go-owned/store-SQL statements each tick, state directly against Postgres — **not** as a call to a retained stored function, and not via RPC. |
| temporary coexistence | None — `pg_cron` schedule entries retire with the old DB |
| disposition | **Move to Go worker** — all 10 |

*(The canonical source's original text for this row stated that the SQL for
those 3 cron jobs "can remain Postgres functions the worker calls via RPC
rather than being rewritten" — that framing is exactly the "cron may remain
a Postgres function called via RPC" statement the merge brief requires not
be carried forward, and was itself superseded within the canonical source's
own later revision (§4.3 below, "no RPC needed"). This row reflects the
corrected, final position: all cron logic is Go-issued SQL, not a stored
function invoked over RPC.)*

#### Stripe Connect (payouts)

| Column | Value |
|---|---|
| used-by feature | payout (Flutter `stripe_payout_repository.dart`), reward/payout cron+worker |
| direct-client-call? | Yes — `payout-setup`, `create-express-dashboard-link` via `.functions.invoke`; `payout-request` is referenced in code but its call path is dead/unmounted (never reachable — §5.1); `execute-pending-payouts` reached only by DB cron, never by a client |
| Go replacement | Go endpoints for onboarding / dashboard-link; Go worker for `execute-pending-payouts`; `handle-stripe-webhook`'s `account.updated` handler only (3.1 Finding 2). **`payout-request` gets no Go endpoint — its manual-payout path is dead/unmounted and is removed (§5.1, §10.F)** |
| data/config conversion | `stripe_accounts`'s 4 Connect columns (`stripe_connect_account_id`, `charges_enabled`, `payouts_enabled`, `connect_requirements`) carry over as-is (3.1 Finding 1); Stripe API key + Connect webhook signing secret move from Supabase Vault to Go config/secret store; webapp's static `stripe/connect/return`/`refresh` pages must keep resolving post-webapp-migration (§9) |
| temporary coexistence | None; Stripe webhook endpoint URL re-registration in the Stripe Dashboard is a one-time cutover flip |
| disposition | **Keep — port to Go** (money-out, unchanged per program §11); `payout-request` is **not** a blocker — the manual-payout path is dead/unmounted, disposition **remove** (§5.1, §10.F) |

#### Stripe Billing (subscription / card-on-file)

| Column | Value |
|---|---|
| used-by feature | billing (Flutter `stripe_billing_repository.dart` — **confirmed dead**, 3.1 Finding 3), webapp `SubscribeButton.tsx`/`pricing`/`dashboard` (removal targets, §9) |
| direct-client-call? | Yes in code but dead in practice — `billing-setup` has no mounted UI caller; `create-stripe-checkout`'s only caller (`SubscribeButton.tsx`) is itself a removal target |
| Go replacement | **None** — subscription entitlement moves to RevenueCat (program §11 "Money in"); Stripe Billing is dropped outright, not ported |
| data/config conversion | n/a — being deleted; `stripe_accounts`'s 6 Billing-only columns become dead columns, drop during Atlas baselining rather than carry into the new schema; `handle-stripe-webhook`'s 3 subscription-event handlers drop from the Go port (3.1 Finding 2) |
| temporary coexistence | None — dropped, no port, no coexistence |
| disposition | **Drop** — `billing-setup` (unused legacy) + `create-stripe-checkout` (web subscribe removed); Flutter's `stripe_billing_repository.dart` + `billing_setup_section.dart` should be deleted, not ported (3.1 Finding 3) |

#### Google Play RTDN

| Column | Value |
|---|---|
| used-by feature | subscription — server-to-server only, no Flutter/webapp caller |
| direct-client-call? | No — external Google Cloud Pub/Sub push subscription, OIDC-token-verified |
| Go replacement | **None on our side** — RevenueCat ingests Google Play RTDN directly (program §11); `handle-google-play-rtdn` is removed outright, not ported |
| data/config conversion | Google Play Developer Console's Pub/Sub topic/RTDN target must be repointed from our Supabase function URL to RevenueCat's ingestion endpoint — RC-side setup, not app code. **Not explicitly called out as a step in any Phase 0/5 roadmap text reviewed for this investigation; worth confirming it's on the RevenueCat setup checklist** before Phase 5 |
| temporary coexistence | None — cutover is a config change on Google's/RevenueCat's side, not a code coexistence period |
| disposition | **Removed** — RevenueCat takes over (confirms program §11/§16) |

#### R2

| Column | Value |
|---|---|
| used-by feature | evidence (photo uploads), profile (avatar uploads), common (stale-object sweep), account (best-effort avatar cleanup on deletion) |
| direct-client-call? | No — Flutter never talks to R2 directly; it calls `generate-upload-url` and receives a presigned PUT URL, consistent with the engineering policy of never handing R2 keys to the client |
| Go replacement | Go endpoint issues the presigned URL (replaces `generate-upload-url`); Go worker runs the stale-object sweep (replaces `sweep-r2-stale-objects`) — both already covered under the Edge Function rows above |
| data/config conversion | R2 itself is unchanged — already the object store, already S3-compatible, already presigned-URL-based; only the presign-issuing process moves from a Supabase Edge Function to a Go endpoint; R2 credentials move from Supabase function env vars to Go's config/secret store |
| temporary coexistence | None — the R2 bucket/objects are not migrating data, only the presign-issuer changes |
| disposition | **Keep, re-point issuer** — R2 stays; only the Go-vs-Edge-Function presign issuer changes. Note the separate launch-blocker (§5.3): evidence objects today are designed around a public R2 domain and must move to a private bucket + authorized presigned downloads (Phase 4). |

#### FCM

| Column | Value |
|---|---|
| used-by feature | notification — `user_fcm_tokens` table + `notification_repository.dart`'s register/unregister; dispatch reached via `notify_event()` → `send-notification`, called from many DB triggers/RPCs across the schema |
| direct-client-call? | Yes for token registration (2 `.from('user_fcm_tokens')` call sites, Appendix C); No for dispatch (server-side only) |
| Go replacement | Go endpoint for token registration (covered under PostgREST row); Go endpoint + worker for dispatch (covered under Edge Function "endpoint + worker" row) — the Go port needs an equivalent trigger point (synchronous Go-API call vs. worker-consumed outbox) since Postgres stops calling out via `pg_net` |
| data/config conversion | Firebase Admin SDK credentials move from Supabase function env vars to Go's config/secret store; the Go notification-dispatch functions (§4) become the new call sites feeding FCM dispatch, replacing `notify_event`'s `pg_net` hop |
| temporary coexistence | None |
| disposition | **Keep provider, replace dispatch path** — FCM itself unchanged; Postgres→`pg_net`→Edge-Function dispatch replaced by Go-native dispatch (endpoint or worker/outbox) |

### 3.3 Edge Function detail table

> Source of truth for target disposition: program design doc §17 "Edge
> Function → Go Mapping." Enumerates every directory under
> `supabase/functions/` (excluding dotfiles and `.env`/`.env.staging`, which
> were not opened) as of 2026-07-22. For each function: purpose (from its
> `index.ts` entrypoint), caller(s) (Flutter, webapp, or internal Postgres
> cron/trigger), the §17 Go destination, and a disposition summary.

| Edge function | Purpose | Caller(s) | Go destination (§17) | Disposition |
|---|---|---|---|---|
| `billing-setup` | Creates/fetches a Stripe `Customer` and issues a `SetupIntent` + ephemeral key for off-session card registration. | `peppercheck_flutter/lib/features/billing/data/stripe_billing_repository.dart:22` (`_supabase.functions.invoke('billing-setup')`). | **Drop — currently unused.** | Callable code path exists in Flutter, but its UI (`BillingSetupSection`) is not mounted on any screen — dead legacy flow from a pre-IAP billing design. Remove with the dormant Stripe billing UI/repo (D8); do not port. |
| `create-stripe-checkout` | Resolves/creates a Stripe `Customer`, looks up a `Price` by lookup key or explicit `price_id`, creates a Stripe Checkout `Session` (subscription or one-off) and returns its URL. | `peppercheck-webapp/src/components/SubscribeButton.tsx:36`. | **Dropped** (web subscribe removed). | Only caller is the webapp's web-pricing/checkout flow, which §9 marks as a remove target (purchase moves to in-app IAP). Consistent with the design doc; drop entirely, no Go port. |
| `create-express-dashboard-link` | Authenticates the user, looks up their `stripe_accounts.stripe_connect_account_id`, and creates a Stripe Express **login link** to the connected account's dashboard. | `peppercheck_flutter/lib/features/payout/data/stripe_payout_repository.dart:73` (`invoke('create-express-dashboard-link')`). | Go endpoint (Stripe Connect). | Straightforward auth + Stripe Connect passthrough; port as a Go endpoint behind the app's auth middleware. |
| `payout-setup` | Gets-or-creates a `stripe_accounts` row + Stripe Express Connect account for the user, refreshes `charges_enabled`/`payouts_enabled`/`connect_requirements`, and returns a Stripe `accountLinks` onboarding URL (`refresh_url`/`return_url` point at `peppercheck-webapp/.../stripe/connect/{refresh,return}`). | `peppercheck_flutter/lib/features/payout/data/stripe_payout_repository.dart:57` (`invoke('payout-setup')`). | Go endpoint (Stripe Connect onboarding). | Port as a Go endpoint; note the coupling to the webapp's static `stripe/connect/return`/`refresh` pages (kept per §9) — those return/refresh URLs must keep resolving after the webapp migrates. |
| `execute-pending-payouts` | Batch job: fetches up to 100 `reward_payouts` rows with `status='pending'`, creates an idempotent Stripe `Transfer` per row to the referee's Connect account, marks each payout success/failed, and deducts the reward wallet via the `deduct_reward_for_payout` RPC. On per-row failure, calls `notify_event` with `notification_payout_failed_referee`. | Postgres cron, not a client. `supabase/schemas/reward/cron/cron_execute_pending_payouts.sql:4,8` schedules a `net.http_post` to `.../functions/v1/execute-pending-payouts`. | Go **worker** (durable). | Money-moving batch job; §17 explicitly routes it to the durable Go worker rather than an HTTP endpoint. No Flutter/webapp caller — only reachable via the DB cron. See §5.2.1 (T7-1) for an idempotency gap in this function. |
| `recommend-payout-topup` | Operator-only report: reads `get_payout_topup_metrics` RPC + live Stripe balance, computes a recommended Stripe balance top-up (JPY) to cover projected referee payout obligations through month end, and returns the recommendation with a "transfer-initiate deadline" (7 JP business days before the next scheduled payout run). Auth via constant-time `X-Operator-Secret` header check against `OPERATOR_AUTH_TOKEN`. | No caller found in `peppercheck_flutter/lib/`, `peppercheck-webapp/src`, or `supabase/schemas` cron/trigger SQL — only referenced in `supabase/functions/.env.example` (env var docs) and `supabase/config.toml` (function registration). Invoked manually by the operator (`X-Operator-Secret` design confirms this). | **Operator tool.** | Not app-facing and not cron-scheduled. **Resolved by operator adjudication**: port to a **Go operator endpoint** — the ambiguity between "endpoint or standalone operator script" is closed in favor of the endpoint. |
| `handle-stripe-webhook` | Verifies the Stripe webhook signature and handles `checkout.session.completed`, `customer.subscription.{updated,deleted}`, `invoice.payment_succeeded`, and `account.updated` — upserts `user_subscriptions`, resets subscription points via `reset_subscription_points` RPC, deactivates trial points, and syncs `stripe_accounts.{charges_enabled,payouts_enabled,connect_requirements}` on Connect account changes. | External: registered as a webhook endpoint URL in the Stripe Dashboard, not invoked from app code. No caller found in `peppercheck_flutter/lib/` or `peppercheck-webapp/src`; `supabase/snippets/setup_stripe_account_webhook_test.sql` is manual test setup only. | Go endpoint (signed, idempotent). | Port as a signature-verified Go endpoint; must stay idempotent given Stripe's at-least-once delivery. Re-register the endpoint URL with Stripe as part of cutover. **Scope narrowing**: per 3.1 Finding 2, the Go port keeps only the `account.updated` (Connect) case — the 3 Billing case-handlers are dropped, not carried over by default. |
| `handle-google-play-rtdn` | Verifies a Google Pub/Sub push OIDC token, decodes the RTDN envelope, and on subscription notifications fetches Play `subscriptionsv2` state, upserts `user_subscriptions`, resets points, and deactivates trial points. Always returns HTTP 200 (even on internal failure) to avoid Pub/Sub retry storms. | External: registered as a Google Cloud Pub/Sub push subscription endpoint, not invoked from app code. No caller found in `peppercheck_flutter/lib/` or `peppercheck-webapp/src`; only referenced in `supabase/functions/.env.example` and `supabase/config.toml`. | **Removed** (RevenueCat ingests RTDN). | RevenueCat takes over Google Play RTDN ingestion, so this function is dropped outright, not ported. |
| `generate-upload-url` | Authenticates the user, validates `content_type`/extension/file size, verifies task ownership (for `kind='evidence'`) or scopes to the caller (`kind='avatar'`), derives a namespaced R2 key, and returns an R2 (S3-compatible) presigned `PUT` URL plus the eventual public URL. | `peppercheck_flutter/lib/features/evidence/data/evidence_repository.dart:40` and `peppercheck_flutter/lib/features/profile/data/profile_repository.dart:73` (both `invoke('generate-upload-url')`). | Go endpoint (R2 presigned upload). | Port as a Go endpoint; per the global engineering policy the Go API should keep issuing presigned URLs rather than handing R2 keys to the client — this function already does that. Note the private-bucket launch-blocker (§5.3). |
| `delete-account` | Multi-step account-deletion saga: checks `check_account_deletable` RPC, (unless `force`) pays out any positive reward wallet balance via a Stripe `Transfer` before deletion, best-effort cancels an active Stripe subscription and deauthorizes the Connect account, best-effort deletes R2 avatar objects, then calls `auth.admin.deleteUser` (DB `CASCADE`/`SET NULL` handles the rest). | `peppercheck_flutter/lib/features/account/data/account_repository.dart:28` (`invoke('delete-account')`) and `peppercheck-webapp/src/app/[locale]/account/delete/page.tsx:52` (same function, web account-deletion page — kept per §9). | Go endpoint + worker (idempotent saga). | Two callers (Flutter + webapp), both must be re-pointed at the Go endpoint. The Go port needs an idempotent saga design — the current implementation is best-effort/non-transactional across several external side effects (Stripe transfer, subscription cancel, Connect deauth, R2 cleanup). See §5.2.3 (T7-3). |
| `send-notification` | Looks up FCM tokens for a set of `user_ids`, sends a localized multicast push (Android + APNs loc-key payloads) via Firebase Admin, and prunes tokens FCM reports as invalid/unregistered. | Postgres, not a client. `supabase/schemas/notification/functions/notify_event.sql:55,70` (`notify_event()` calls `net.http_post` to the `send-notification` Edge Function). `notify_event` itself is called from many DB triggers/RPCs across the schema (out of scope for this table). | Go endpoint + worker (FCM). | No direct Flutter/webapp caller — reached only via the DB's `notify_event` helper. Go port needs an equivalent trigger point (either the Go API calling out synchronously, or a worker consuming an outbox/queue) rather than Postgres calling out over HTTP via `pg_net`. |
| `sweep-r2-stale-objects` | Cron sweep: deletes evidence-photo R2 objects under `evidence/<date>/` older than 90 days, and deletes orphaned/stale `avatar/<userId>/` objects (any object that isn't the user's current `avatar_url`, with a 10-minute grace period to avoid racing fresh uploads). Supports `dry_run`. | Postgres cron, not a client. `supabase/schemas/common/cron/cron_sweep_r2_stale_objects.sql:8,12` schedules a `net.http_post` to `.../functions/v1/sweep-r2-stale-objects`. | Go **worker**. | No Flutter/webapp caller — only reachable via the DB cron, same pattern as `execute-pending-payouts`. Both stale-object sweep and payout execution route to the durable Go worker. |

**Totals: 12 edge function directories found → 12 rows.** 2 dropped
(`billing-setup`, `create-stripe-checkout`), 1 removed (`handle-google-play-rtdn`),
1 operator tool (`recommend-payout-topup`), 2 → Go worker (`execute-pending-payouts`,
`sweep-r2-stale-objects`), 6 → Go endpoint (`create-express-dashboard-link`,
`payout-setup`, `handle-stripe-webhook`, `generate-upload-url`, `delete-account`,
`send-notification`; the latter two are endpoint **+** worker).

Verification:

```
$ ls -1 supabase/functions/ | grep -v '^\.' | wc -l
      12
```

Confirms exactly 12 edge function directories, matching the 12 rows above.

> `payout-request` (Flutter calls a nonexistent Edge Function) was
> investigated and resolved as dead/unmounted code — see §5.1 for the full
> evidence and disposition (remove, not implement). *(The canonical source's
> original note here promised "proposed fix and owning phase" as if it were
> still an open blocker; that framing is corrected — the resolution is
> "remove," not "fix and ship.")*

### 3.4 Completeness verification

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

**Every edge-function disposition matches §3.3.** Reconciled: 4 (endpoint) +
2 (endpoint+worker) + 2 (worker) + 1 (drop) + 1 (dropped) + 1 (removed) + 1
(operator tool) = 12 of 12, matching §3.3's totals line exactly. Separately,
`payout-request` was investigated and resolved as dead code (not a
launch-blocker) — see §5.1.

**DB-logic disposition summary matches §4's tally.** DB Functions row: DB
invariant/helper 1 / Store query 4 / Go transaction 38 / Go service/worker
21 / Drop 4 = 68 — copied from §4's function tally, not re-derived. Triggers
row: 21 housekeeping stay / all 15 business → Go — copied from §4/Appendix
B's trigger tally. Cron row: 10/10 move to Go worker — copied from §4.3's
cron table.

**No empty disposition cells.** All 21 rows in 3.2 carry an explicit
disposition value (Keep/Replace/Split/Drop/Removed/Port/etc.).

### 3.5 Concerns for Phase 0 sign-off

1. **`stripe_accounts` needs an explicit split decision before the Atlas
   baseline is drafted** — this document identifies which columns are
   Connect vs. Billing (3.1 Finding 1), but whether the new schema keeps
   one table with the Billing columns dropped, or splits into two tables, is
   a schema-design decision for whoever drafts the Atlas baseline, not
   decided here.
2. **`handle-stripe-webhook`'s scope narrowing (3.1 Finding 2) is a
   correction to the naive "one porting unit" framing.** Flag this explicitly
   to whoever executes the Edge Function → Go port so the 3 Billing
   case-handlers aren't carried over by default.
3. **Recommend deleting `stripe_billing_repository.dart` +
   `billing_setup_section.dart` + their controller wiring as one PR**, now
   that 3.1 Finding 3 confirms `BillingSetupSection` has zero mount
   points — delete, don't port.
4. **`profiles.stripe_connect_account_id` (bonus finding) and the dead
   `ALTER PUBLICATION supabase_realtime` statement (Realtime row) are both
   schema debris outside §4's function/trigger/cron scope** — neither is a
   function, trigger, or cron entry, so neither could have been caught by
   that inventory's grep methodology. Worth a broader one-time schema-debris
   sweep during Atlas baselining rather than assuming §4's 68/36/10 counts
   are the complete list of things to clean up.
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
   ultimately calls `notify_event` → `send-notification`; that fan-out would
   need its own inventory if the Go port changes the trigger point (e.g.,
   moving from synchronous `pg_net` calls to a worker-consumed outbox).
8. This document reuses the underlying investigation's findings verbatim per
   the assembly brief's instruction ("do not re-derive counts — cite them")
   — any correction to the underlying counts should be made in the source
   investigation, then this baseline re-assembled.

### 3.6 Per-feature quick reference (from supplement)

> Source: supplement §4. A feature-oriented view of the same call-site
> inventory as Appendix C, useful as a quick-reference table; the master
> table above (§3.2) and Appendix C remain the fuller/authoritative sources
> for column detail and per-call-site Go endpoint mapping.

#### Flutter direct data calls by feature

| Feature | Current direct calls | Target owner and disposition |
|---|---|---|
| account | `check_account_deletable`; `delete-account` | `account` Go service and deletion worker. |
| authentication | Supabase auth state, Google ID-token exchange, sign-out | Firebase Auth adapter; app-level auth contract; `/api/v1/me`. |
| billing/subscription | `user_subscriptions`, `point_wallets`, `trial_point_wallets`, `get_point_for_matching_strategy` | `subscription` and `point` API endpoints; RevenueCat client gateway. |
| dormant Stripe billing | `billing-setup`, `stripe_accounts` payment-method fields | Drop repository, controller, widget, and domain types. Stripe Billing is not Stripe Connect. |
| currency | `currencies` | Reference-data API or embedded cache seeded from the Go database. |
| evidence | `generate-upload-url`; submit/update/resubmit; timeout confirmation | `evidence` API plus private R2 upload/download intents. |
| judgement | judge, confirm, review-timeout confirmation | `judgement` API and transactional store operations. |
| matching | availability/blocked-date reads and seven RPC mutations | `matching` API; durable worker for automatic matching and timeouts. |
| notification | FCM token upsert/delete; Supabase auth listener | `notification` API and app-level auth listener. |
| payment dashboard | `get_payment_summary` | `payment_summary` query endpoint. |
| payout | Connect status; onboarding; dashboard link; dead `payout-request` | `payout` API for Connect. Drop manual payout request; retain monthly batch payout. |
| profile | profile reads/updates; avatar upload | `profile` API plus avatar upload intent. |
| report | report insert/read | `report` API with internal-user authorization. |
| task | create/update/delete, task queries, active-referee query | `task` API with contract DTOs; remove PostgREST-shaped response mapping. |

The 24 Supabase-importing files are the removal checklist. Presentation code
must stop reading `Supabase.instance.client.auth.currentUser`; only the
authentication feature may depend on Firebase SDK types.

#### Flutter RPC targets (21)

`cancel_referee_assignment`, `check_account_deletable`,
`confirm_evidence_timeout`, `confirm_judgement_and_rate_referee`,
`confirm_review_timeout`, `create_referee_available_time_slot`,
`create_referee_blocked_date`, `create_task`,
`delete_referee_available_time_slot`, `delete_referee_blocked_date`,
`delete_task`, `get_active_referee_tasks`,
`get_payment_summary`, `get_point_for_matching_strategy`, `judge_evidence`,
`resubmit_evidence`, `submit_evidence`,
`update_evidence`, `update_referee_available_time_slot`,
`update_referee_blocked_date`, and `update_task`.

#### Webapp Supabase use

| Current route/component | Supabase use | Disposition |
|---|---|---|
| account deletion | Auth, `check_account_deletable`, `delete-account` | Replace with provider-neutral support request; in-app deletion remains primary. |
| auth callback and login | Supabase OAuth/session | Remove. |
| dashboard | Auth and subscription query | Remove. |
| pricing and `SubscribeButton` | Auth, plan query, Stripe Checkout Edge Function | Remove. |
| Tokushoho page | Plan-price query | Keep page; render reviewed legal/config data without client DB access. |
| Supabase browser/server/middleware helpers | Supabase SSR | Remove with Next.js. |

## 4. DB Logic Classification

> Sources: supplement §5 intro (5-way taxonomy definitions), supplement §5/§6/§7
> (per-function/trigger/cron assignment), canonical §2 (evidence, per-domain
> insight subsections, refined max-Go criterion). Full per-function and
> per-trigger tables live in **Appendix A** and **Appendix B**; this section
> holds the taxonomy, the tally, a per-domain summary, and the notable
> cross-function implications.

### 4.1 The 5-way taxonomy

Every schema function and business trigger is assigned exactly one of:

- **DB invariant/helper** — retain only a constraint or minimal
  invariant/housekeeping trigger helper in Postgres. Duplicate user-facing
  validation in Go when needed for stable API errors.
- **Store query** — remove the callable database function. Keep typed,
  explicit SQL in the Go Postgres store, pass the internal user ID as a
  parameter, and assemble API DTOs in Go.
- **Go transaction** — remove the callable database function. Go owns the
  business decision and transaction boundary; store statements use the
  minimum required locks, conditional DML, constraints, and ledger inserts.
- **Go service/worker** — remove the callable database function. Go owns
  validation, authorization, scheduling, orchestration, or external side
  effects and uses ordinary store queries or a narrower Go-owned
  transaction.
- **Drop** — obsolete provider/support code with no target equivalent.

Atomicity alone is not a reason to retain a stored function. The default is
a Go-owned transaction with pure Go tests for domain rules and
real-Postgres tests for locking, concurrency, idempotency, and constraints.
A callable business stored function is an exception and requires a
documented set-based or measured performance reason; none of the current 68
functions has that exception at the Phase 0 baseline.

This taxonomy is deliberately compatible with the canonical baseline's
separately-derived "max-Go" refinement (§4.1a below): "Go transaction" and
"Go service/worker" both correspond to cases where the canonical baseline's
finer-grained pass calls out an irreducible atomic statement as **Go-tx
SQL** — i.e., store SQL issued by the Go store inside a Go-owned
transaction, with the surrounding checks/branches in Go. Where Appendix A's
evidence notes say "Go-tx SQL" or "atomic store SQL," read that as the SQL
half of a "Go transaction"/"Go service/worker" classification under this
5-way taxonomy — not as a retained callable stored function.

### 4.1a Classification criterion (refined, max-Go, operator-adopted 2026-07-23)

**Crux:** atomicity comes from the *transaction + row lock*, which the Go
store controls — not from the code living in a PL/pgSQL stored function.
Because the Go API becomes the **single write boundary**, moving a
lock/consume/derived-state routine into a Go-owned transaction loses
**zero** atomicity and gains testability (checks become unit-testable Go;
the tx is exercised by real-Postgres integration tests). Triggers that
enforce invariants across arbitrary write paths are no longer load-bearing
once Go is the only writer. Lean to Go for testability.

Under this rule almost no *business* PL/pgSQL function stays as a stored
function. Something stays in the DB only with a concrete justification
written against the actual SQL — and, at this baseline, only
`handle_updated_at` has that justification.

### 4.2 Function tally

Assigning each of the 68 functions its class from the supplement's §5
per-function assignment, then applying three operator-approved resolutions
(§4.6), yields:

| Disposition | Count |
|---|---:|
| DB invariant/helper | 1 |
| Store query | 4 |
| Go transaction | 38 |
| Go service/worker | 21 |
| Drop | 4 |
| **Total** | **68** |

**Go-managed = 63 of 68** (Go transaction + Go service/worker). The single
DB invariant is `handle_updated_at` — trivial `NEW.updated_at = NOW()`
housekeeping with no business logic and no atomicity concern; it is the one
function the refined rule explicitly carves out as staying DB-side (it may
equally validly move to the Go data layer instead — noted as "either" in
Appendix A).

**This is the tally required by the merge brief, and it is exact**: DB
invariant/helper 1 · Store query 4 · Go transaction 38 · Go service/worker
21 · Drop 4 = 68.

### 4.3 Cron tally

All 10 cron schedules move to the Go worker's own scheduler, issuing state
directly against Postgres (Go-owned SQL statements, or calls into the
already-Go-classified functions above) — **not** via RPC to a retained
stored function:

| # | schedule name | frequency | job | worker target |
|---|---|---|---|---|
| 1 | `process-pending-requests` | hourly (`0 * * * *`) | `matching/cron/cron_process_pending_requests.sql` → `process_pending_requests()` | Matching expiry/rematch job (Go service/worker, Appendix A #1). |
| 2 | `detect-review-timeouts` | every 5 min | `judgement/cron/cron_detect_review_timeout.sql` → `detect_and_handle_review_timeouts()` | Review-timeout job. The Go worker issues the underlying `UPDATE ... FROM` statement directly each tick (Appendix A #35) — no stored function, no RPC. |
| 3 | `detect-auto-confirms` | hourly | `judgement/cron/cron_detect_auto_confirm.sql` → `detect_auto_confirms()` | Judgement auto-confirm job (Go service/worker, Appendix A #34): a `FOR UPDATE SKIP LOCKED` claim query plus several Go-issued mutations per claimed row. |
| 4 | `detect-evidence-timeouts` | every 5 min | `judgement/cron/cron_detect_evidence_timeout.sql` → `detect_and_handle_evidence_timeouts()` | Evidence-timeout job. Same pattern as row 2 — the SQL is issued directly by the worker (Appendix A #42); no RPC needed. |
| 5 | `detect-auto-confirm-deadline-warnings` | every minute | `notification/cron/cron_detect_auto_confirm_deadline_warnings.sql` → `detect_auto_confirm_deadline_warnings()` | Notification reminder job. |
| 6 | `detect-evidence-deadline-warnings` | every minute | `notification/cron/cron_detect_evidence_deadline_warnings.sql` → `detect_evidence_deadline_warnings()` | Notification reminder job. |
| 7 | `detect-judgement-deadline-warnings` | every minute | `notification/cron/cron_detect_judgement_deadline_warnings.sql` → `detect_judgement_deadline_warnings()` | Notification reminder job. |
| 8 | `sweep-r2-stale-objects` | daily 18:00 UTC | `common/cron/cron_sweep_r2_stale_objects.sql` → `net.http_post` | R2 cleanup job. |
| 9 | `prepare-monthly-payouts` | `0 15 28-31 * *` | `reward/cron/cron_prepare_monthly_payouts.sql` → `prepare_monthly_payouts('JPY')` | Monthly payout preparation job. |
| 10 | `execute-pending-payouts` | every 30 min | `reward/cron/cron_execute_pending_payouts.sql` → `net.http_post` | Stripe payout execution job. See §5.2.1 (T7-1) for a job-claiming gap in this function. |

The worker owns scheduling, persistent job rows, retries, idempotency keys,
and `FOR UPDATE SKIP LOCKED` claiming. The API only persists webhook inbox
events and commands.

### 4.4 Trigger tally

| Disposition | Count |
|---|---:|
| DB trigger — housekeeping (`handle_updated_at`, 1 summary row = 21 triggers) | 21 |
| Go (business, dissolves into Go orchestration logic or Go-issued atomic SQL) | 15 |
| **Total** | **36** |

All 21 housekeeping triggers call `handle_updated_at()` and remain minimal
database housekeeping. **All 15 business triggers dissolve into Go** —
zero business triggers remain a literal Postgres `CREATE TRIGGER`. See
Appendix B for the full per-trigger mapping (which function each replaces,
and whether it dissolves into plain Go logic or a single Go-issued atomic
SQL statement).

### 4.5 Per-domain summary

| Domain | Functions | Business triggers | Notable dispositions |
|---|---:|---:|---|
| Account / identity / common | 4 (Appendix A #43, #53, #68, plus `handle_new_user`'s trigger) | 1 (`on_auth_user_created`) | `handle_updated_at` is the sole DB invariant; `handle_new_user`'s provisioning logic moves to Go, only its Supabase-Auth trigger mechanism dies. |
| Evidence | 5 (#37–#41) | 3 (due-date guards ×2, upsert-notify) | `validate_evidence_due_date` reclassified DB invariant → Go service/worker (§4.6, resolution 1) since it's a cross-table check. |
| Judgement | 12 (#25–#36) | 7 | Four call sites that set `is_confirmed=true` must each explicitly re-run the cascade the dissolved triggers used to fire automatically — see §4.7. |
| Matching | 15 (#1–#11 and others) | 2 (`process_matching` triggers) | `trigger_process_matching` reclassified Drop → Go service/worker (§4.6, resolution 3); `detect_and_handle_referee_timeouts` reclassified Go service/worker → Drop (§4.6, resolution 2). |
| Notification / summaries / points / RLS helpers | 13 (#44–#52 notification+point, #54–#56 RLS helpers) | 0 (RLS helpers are not triggers) | 3 RLS helper functions are pure Drop candidates (RLS retirement, not today's dead-code list). |
| Rating / reward / task / trial points | 19 (#57–#67 and trial-point functions) | 2 (rating recompute, task-close) | Wallet/ledger functions all decompose into a Go check + an irreducible Go-issued atomic SQL statement (lock/consume/unlock, grant/deduct). |

(Counts above are grouped for readability; Appendix A is the authoritative
per-function source and Appendix B the authoritative per-trigger source.)

### 4.6 Operator-approved resolutions applied to the supplement's classification

The supplement's §5 per-function pass (5-way taxonomy) is the base
assignment for every function. Three resolutions, approved by the operator,
are layered on top to produce the §4.2 tally:

1. **`validate_evidence_due_date`: DB invariant → Go service/worker.** Move
   to Go; it is a cross-table check (`tasks.due_date` read from an
   `task_evidences` write), so it cannot become a same-table `CHECK`
   constraint. Go is the sole write path once the API is the only writer,
   so no atomicity is lost by moving the guard into Go's pre-write
   validation.
2. **`detect_and_handle_referee_timeouts`: → Drop.** Currently
   unused/unscheduled (zero callers, zero cron entries — see Appendix A
   #4). If ever needed, design it as a new Go worker requirement, not a
   port of this dead function.
3. **`trigger_process_matching`: → Go service/worker.** The SQL wrapper
   itself is deleted (it is a thin trigger-function wrapper around
   `process_matching`), but the matching behavior it invokes moves to Go as
   a service/worker responsibility — "Go service/worker" is a more accurate
   disposition than "Drop," since the underlying capability (processing a
   matching request) is very much still needed, just invoked explicitly by
   the API/worker instead of fired by a trigger.

Beyond these three, additional ambiguous items carried from the canonical
baseline's own investigation remain recorded for the owning feature phase
(not Phase 0 blockers):

- `is_task_tasker` — delete candidate, verify before drop (its siblings
  `is_task_referee`/`is_task_referee_candidate` are **not** drop
  candidates — both are actively called from `task/policies/tasks_policies.sql`
  and are tied to the broader RLS retirement, not today's dead-code list).
- `auto_score_timeout_referee()` + `settle_review_timeout()` insert a
  redundant negative rating — both are Go-classified with dedup recommended
  (see §4.7).
- `get_payout_topup_metrics(text)` — the four read-only `SELECT`s need
  cross-statement consistency; that comes from one Go-owned read
  transaction, not a PL/pgSQL wrapper. The *access path* (Go operator
  endpoint, not a Supabase Edge Function) is unchanged.
- RLS defense-in-depth candidates (wallet/ledger-adjacent policies in
  point, trial_point, reward domains) — remains an open Go-implementation
  decision, not resolved here.

### 4.7 Shared post-confirm orchestration: four call sites, one cascade

> Carried from canonical §2.9.

Reading the actual trigger definitions surfaces something the disposition
table alone doesn't show: **four separate triggers currently fire off the
exact same condition** — `AFTER UPDATE ON judgements ... WHEN (NEW.is_confirmed
= true AND OLD.is_confirmed = false)` (or the equivalent `IS NULL OR ... =
false` form):

- `on_judgement_confirmed_notify` → `notify_judgement_confirmed()` (Appendix A #25, Go)
- `on_judgement_confirmed_close_request` → `close_referee_request_on_confirmed()` (Appendix A #26, Go — atomic SQL)
- `on_judgement_confirmed` → `handle_judgement_confirmed()` (Appendix A #27, Go)
- `on_all_judgements_confirmed_close_task` → `close_task_if_all_judgements_confirmed()` (Appendix A #57, Go — atomic SQL)

Plus, separately, every write that inserts a `rating_histories` row today
fires `on_rating_histories_change_update_user_ratings` → `update_user_ratings()`
(Appendix A #24, Go — atomic SQL).

Once Go becomes the sole writer and these 5 triggers are dropped, **the four
call sites that currently set `judgements.is_confirmed = TRUE` must each
explicitly perform the work the triggers used to cascade automatically**:

| Call site (Appendix A #) | Sets `is_confirmed=true` | Inserts `rating_histories` | Must now explicitly run |
|---|---|---|---|
| `confirm_judgement_and_rate_referee` (#36) | yes | yes | #24, #26, #57 (atomic SQL), #25/#27 (Go, notify) |
| `confirm_evidence_timeout` (#32) | yes | no | #26, #57 (atomic SQL), #25/#27 (Go, notify) |
| `confirm_review_timeout` (#33) | yes | no | #26, #57 (atomic SQL), #25/#27 (Go, notify) |
| `detect_auto_confirms` (#34) | yes | yes | #24, #26, #57 (atomic SQL), #25/#27 (Go, notify) |

**Recommendation for the owning feature phase (not decided here):** implement
one shared Go orchestration helper (e.g. `onJudgementConfirmed(tx, judgementID)`)
that all four call sites invoke inside their transaction, rather than
re-implementing the same four-to-five-statement sequence independently at
each site. This mirrors — and extends — the dedup already approved for the
`auto_score_timeout_referee`/`settle_review_timeout` redundant rating insert
(§4.6): once triggers no longer provide the "fires everywhere automatically"
guarantee, that guarantee has to be re-created deliberately in Go, and a
single shared helper is the natural place to do it. Flagged for
operator/implementer awareness, not a Phase 0 blocker.

### 4.8 Two fragility notes surfaced by the classification pass

> Carried from canonical §2.10.

1. **`reset_subscription_points`'s idempotency key is a `description` string
   match, not a real constraint.** The guard is
   `SELECT id FROM point_ledger WHERE user_id=$1 AND reason='plan_renewal'
   AND description = 'Subscription renewal: ' || p_invoice_id LIMIT 1` — a
   free-text column doing duplicate-detection work. It works today, but it's
   fragile (whitespace/formatting changes to the description silently break
   idempotency). **Not classified as a DB constraint here** because doing so
   would require a schema change (e.g. a dedicated `related_id`/invoice-id
   column with a `UNIQUE (user_id, reason, related_id)` constraint) that's a
   real design decision, not a reclassification of existing SQL. Flagged
   for the owning phase (point domain), not resolved here.
2. **`get_point_for_matching_strategy`'s hardcoded `'standard' → 1` mapping**
   becomes a single Go constant with no remaining Postgres copy (Appendix A
   #9). Because every caller moves to Go under the max-Go refinement, there
   is only one copy (Go) — the drift risk a duplicated-constant framing
   would otherwise carry is resolved by elimination, not by discipline.

### 4.9 RLS (unaffected by the function/trigger reclassification)

63 `CREATE POLICY` statements across 30 files, 13 policy domains. Disposition
unchanged: **retire all 63** to Go application-layer authz, with
wallet/ledger-adjacent policies (point, trial_point, reward) as possible
defense-in-depth candidates — a Go-implementation decision, remaining open
(§4.6).

## 5. Launch-Blocker Register

> Union of the canonical baseline's launch-blocker register (§3, incl. the
> `payout-request` investigation and the T7-1/T7-2/T7-3 financial-integrity
> candidates surfaced by the journey catalog) and the supplement's §12.3
> launch-blocker assignments table. The canonical baseline's deep evidence
> is preserved verbatim for the financial-integrity items; the supplement's
> shorter items are added without re-deriving evidence not already gathered.

| # | Finding | Owning phase |
|---|---|---|
| 1 | `payout-request` dead manual-payout path — **resolved: remove, not implement** | Phase 5 cleanup |
| 2 | Payout idempotency gaps (`execute-pending-payouts` lacks `FOR UPDATE SKIP LOCKED`; `reward_payouts.stripe_transfer_id` has no `UNIQUE` constraint) | Phase 5 |
| 3 | Judgement double-confirm race (`confirm_judgement_and_rate_referee` has no row lock) | Phase 5 |
| 4 | Account deletion is not a persisted, provider-neutral, re-runnable saga | Phase 6 |
| 5 | Evidence objects are designed around a public R2 domain | Phase 4 |
| 6 | Stripe webhook env-var name mismatch (`STRIPE_WEBHOOK_SIGNING_SECRET` vs `STRIPE_WEBHOOK_SECRET`) | Phase 5 |
| 7 | Premium price discrepancy (Google seed JPY 2,580 vs. later design JPY 2,480) | Phase 5 |
| 8 | Firebase Auth + Sign in with Apple absent | Phase 2 |
| 9 | RevenueCat entitlement + durable reconciliation absent | Phase 5 |
| 10 | No rehearsed off-VPS restore/PITR path | Phase 1 skeleton + Phase 7 rehearsal |

Items 1–4 are reasoned-not-test-confirmed for the current code (Phase 0
does not write executable characterization tests against the system being
deleted); the Go rewrite must build the corresponding safeguards per program
design §11 (payout/webhook idempotency), §14 (account-deletion saga), and
§24 (testing strategy). All three are already on the program's §23
"never-defer" safety-valve list ("ledger + payout idempotency; in-app + web
account deletion") — closing them is not optional schedule-pressure scope.

### 5.1 `payout-request` — investigated, NOT a launch blocker (dead path)

**Status:** Resolved 2026-07-23. The manual-payout path is **dead/unmounted
code**; disposition is **remove** (drop candidate, §10.F), not implement.
Not a launch blocker.

> **This is the authoritative disposition.** Anywhere else in the
> underlying investigation that once described `payout-request` as a
> "launch-blocker" or a net-new Go endpoint to build has been corrected
> in-place in this merged document (see §3.2's Edge Functions reconciliation
> and Stripe Connect row, and §3.3's edge-function-detail closing note) — do
> not carry forward the earlier "implement it" framing.

**Evidence:**
- `supabase/functions/` contains no `payout-request` directory (`ls
  supabase/functions/ | grep -i payout` → only `execute-pending-payouts`,
  `payout-setup`, `recommend-payout-topup`).
- Flutter references it at `stripe_payout_repository.dart:93`
  (`_supabase.functions.invoke('payout-request', ...)` inside the repo's
  `requestPayout()` method).
- **But the whole path is unreachable** (verified 2026-07-23):
  - `grep -rn "\.requestPayout(" peppercheck_flutter/lib/` → **zero callers** of
    the repo method.
  - `PayoutAmountDialog` — the only UI that would trigger it — is **never
    instantiated**: `grep -rn "PayoutAmountDialog(" ...` returns only its own
    constructor declaration; nothing mounts it via `showDialog`; and
    `payout_amount_dialog.dart` is **imported by no other file**.

  So `payout-request` can never be invoked by a user and cannot 404 in
  practice. It is a remnant of the removed `payout_jobs`-era manual-payout
  architecture; the approved payout flow is the monthly `reward_payouts`
  batch (`prepare_monthly_payouts` → `execute-pending-payouts`).

**Disposition:** Remove the dead manual-payout path — Flutter
`payout_amount_dialog.dart`, `stripe_payout_repository.requestPayout()` + its
`PayoutRequestResponse` DTO, and the unused `dashboard.requestPayout` /
`dashboard.payoutRequested` i18n keys (§10.F). No Go endpoint is built. The
earlier "launch-blocker → implement in Phase 5" reading was based only on the
missing-function grep, before the mounting/caller check. Removal lands whenever
the payout feature is migrated (Phase 5 cleanup).

### 5.2 T7 financial-integrity risks — operator-adjudicated candidates

> **Adjudication basis note (applies to all three items below):** these
> findings are reasoned from reading the current Supabase implementation
> (SQL functions/triggers, Edge Functions) as documented in §6's critical-
> journey behavior catalog — they are **not test-confirmed**. Phase 0 does
> not write executable characterization tests against the system being
> deleted. The Go rewrite must build the corresponding safeguard per program
> design §11 (payout/webhook idempotency — "Stripe account/event IDs
> protected by unique constraints"), §14 (account-deletion saga —
> "idempotent, persisted deletion state"), and §24 (testing strategy —
> ledger/payout idempotency and deletion-retry tests). All three are already
> on the program's §23 "never-defer" safety-valve list ("ledger + payout
> idempotency; in-app + web account deletion") — so closing them is not
> optional schedule-pressure scope.

#### T7-1 — Payout idempotency gaps

**Status:** Candidate — verify in owning phase.

**Evidence** (from §6, flow (c) Payout — Invariants and Edge cases):
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

**Evidence** (from §6, flow (d) Judgement state machine — Edge cases):
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

**Evidence** (from §6, flow (e) Account deletion — Invariants and Edge
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

**Owning phase:** Phase 6 — Account deletion & cleanup (program §22:
"idempotent deletion saga across Firebase/RC/Stripe/R2/DB").

### 5.3 Additional launch-blockers (from the supplement)

> Source: supplement §12.3. Shorter items not independently re-derived with
> deep SQL evidence by the canonical investigation; carried here at the
> supplement's own level of detail.

| Finding | Assigned phase |
|---|---|
| Evidence objects are currently designed around a public R2 domain | Phase 4: private bucket access and authorized presigned downloads. |
| Firebase Auth and Sign in with Apple are absent | Phase 2. |
| RevenueCat and durable reconciliation are absent | Phase 5. |
| Premium price differs between current Google seed and later design (JPY 2,580 vs. JPY 2,480) | Phase 5/store-console verification. See §8 for the full subscription-baseline framing. |
| No rehearsed off-VPS restore/PITR path | Phase 1 skeleton and Phase 7 rehearsal. See §12.1 for the accepted recovery decisions this gates against. |
| Stripe webhook unit test sets `STRIPE_WEBHOOK_SIGNING_SECRET` while runtime uses `STRIPE_WEBHOOK_SECRET` | Replace in Go tests; production config consistently uses `STRIPE_WEBHOOK_SECRET`. |

(Account deletion's persisted-saga gap and the dead `payout-request` path
are the supplement's remaining two §12.3 rows; both are already covered in
full above as T7-3 and §5.1 respectively, so they are not repeated in this
table.)

## 6. Critical Journey & Behavior Catalog

> Source: canonical §5. Documents the **expected behavior** of five
> high-risk flows as acceptance specs, grounded in the current Supabase
> implementation (SQL functions/triggers + Edge Functions + Flutter
> repositories), so the future Go rewrite can be validated against the same
> invariants. These are **not executable tests** — they are read-only
> characterizations of behavior that already exists, plus the pgTAP tests
> that already assert it. Where the target Go/Firebase design changes
> behavior (chiefly auth — Apple is net-new), that is called out explicitly
> as "today" vs. "target." Three edge cases surfaced here were promoted to
> launch-blocker candidates in §5 (T7-1, T7-2, T7-3) — cross-referenced
> inline below. §6.6 appends the supplement's characterization-asset →
> migration-gate table.

Flows covered: (a) auth (Google today, Apple net-new), (b) point/trial-point
ledger, (c) payout (Stripe Connect), (d) judgement state machine, (e) account
deletion.

### 6(a) Auth — Google (current) + Apple (net-new)

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
   (§4.6, resolved).
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

### 6(b) Point / trial-point ledger

#### Code paths
- DB access (refined max-Go, Appendix A #17–23, #49–52): the wallet
  lock/consume/unlock are Go-issued atomic SQL inside a Go-owned
  transaction; the `route_*` dispatchers become plain Go — none remain
  stored functions:
  `supabase/schemas/point/functions/{lock,consume,unlock}_points.sql`,
  `supabase/schemas/trial_point/functions/{lock,consume,unlock}_trial_points.sql`,
  `deactivate_trial_points.sql`, and routing dispatchers
  `route_consume_points.sql` / `route_unlock_points.sql` / `route_referee_reward.sql`.
- Callers (Go): `create_task_referee_requests_from_json.sql` (locks),
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
  outside `detect_auto_confirms`; see §5.2 T7-2).
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
- `get_point_for_matching_strategy` is a hardcoded lookup (`'standard' → 1`)
  shared by the callers that move to Go (Appendix A #9); under max-Go it
  becomes a single Go constant with no remaining Postgres copy — see §4.8
  for why the drift risk this previously flagged is resolved by elimination.

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

### 6(c) Payout (Stripe Connect)

#### Code paths
- DB access (now Go-issued atomic SQL, Appendix A #65–66):
  `supabase/schemas/reward/functions/grant_reward.sql`,
  `deduct_reward_for_payout.sql`; (Go worker): `prepare_monthly_payouts.sql`.
- Edge Functions: `supabase/functions/payout-setup/` (onboarding —
  Stripe Express Connect account get-or-create + `accountLinks`),
  `create-express-dashboard-link/` (Express login link),
  `execute-pending-payouts/` (batch Stripe Transfer execution, cron-driven).
- **Missing**: `payout-request` — Flutter calls
  `stripe_payout_repository.dart:92` (`_supabase.functions.invoke('payout-request', ...)`)
  but no `supabase/functions/payout-request/` directory exists; **resolved as
  dead/unmounted code, not a launch blocker** (§5.1) — the call path is
  unreachable, so this does not 404 in production against any real user
  action.
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
  directly relevant to flow (e)'s `force=true` edge case below, and to §5.2
  T7-3.
- Stripe transfer id **is not protected by a DB unique constraint**:
  `reward_payouts.stripe_transfer_id` (`supabase/schemas/reward/tables/reward_payouts.sql`)
  has no `UNIQUE` constraint. The "applied at most once" property for a
  given payout row currently rests entirely on (a) Stripe's own
  idempotency-key deduplication and (b) the `deduct_reward_for_payout`
  optimistic-concurrency check — not on a DB constraint that would catch,
  e.g., two *different* `reward_payouts` rows accidentally referencing the
  same real-world transfer. **See §5.2 T7-1.**

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
  payout row. **See §5.2 T7-1** — confirm the Go worker's job-claiming
  pattern (durable row/`FOR UPDATE SKIP LOCKED`) closes this gap rather than
  inheriting it.
- **`payout-request` has no working backend** — the referee-initiated
  "request payout now" action in the Flutter app was investigated and found
  unreachable (§5.1): its only caller has zero call sites and its dialog is
  never mounted. It cannot 404 in practice because a user can never trigger
  it. No Go implementation decision is needed here beyond confirming removal.
- **Two independent Stripe-transfer + wallet-deduct code paths**
  (`execute-pending-payouts` and `delete-account`'s inline payout step) —
  both call `deduct_reward_for_payout` after their own `stripe.transfers.create`,
  but are otherwise unrelated implementations. A behavior difference between
  them (e.g., account-deletion payout has no retry/backoff, is inline in an
  HTTP request instead of a worker) is a real product-behavior gap to
  reconcile, not just a code-duplication cleanup, when porting to Go (§3.2
  already flags this for consolidation).
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

### 6(d) Judgement state machine

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
  certainly — still safe today. **See §5.2 T7-2.**
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
  launch-blocker candidate, §5.2 T7-2** — recommend the Go port add an
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
  operator adjudication, §4.6** (Go with dedup).

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
  race in `confirm_judgement_and_rate_referee` (§5.2 T7-2).

### 6(e) Account deletion

#### Code paths
- DB: `supabase/schemas/account/functions/check_account_deletable.sql`.
- Edge Function: `supabase/functions/delete-account/index.ts` (multi-step
  saga).
- Flutter: `peppercheck_flutter/lib/features/account/data/account_repository.dart`
  (`checkDeletable()`, `deleteAccount({force})`).
- Web: `peppercheck-webapp/src/app/[locale]/account/delete/page.tsx` also
  calls the same `delete-account` function.
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
  **See §5.2 T7-3.**

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
  retryable unit rather than an in-line all-in-one HTTP handler. **See §5.2
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
  bug, before porting as-is. **See §5.2 T7-3.**
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
  test gap of the five flows in this catalog, and matches §3.3's framing of
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

### 6.5 Verification

All five flows above have at least a `Preconditions`, `Steps`, `Expected
behavior`, `Invariants`, and `Edge cases` subsection, and each cites the
pgTAP test file(s) that characterize it today (or explicitly notes the gap
where no pgTAP test reaches the flow, as with parts of (a) and all of the
external-side-effect portion of (e)). The three edge cases promoted to
launch-blocker candidates (§5.2 T7-1, T7-2, T7-3) are cross-referenced
inline above at their source location in flows (c), (d), and (e)
respectively.

### 6.6 Existing characterization assets → migration gates

> Source: supplement §12.2.

| Journey/invariant | Existing baseline | Migration gate |
|---|---|---|
| profile bootstrap/username | `profile_username.test.sql` | Port to identity integration tests with internal UUID. |
| task deletion/authz | `delete_task.test.sql` | Add create/update and cross-user API cases. |
| matching/availability/refunds | `test_referee_availability.sql` | Add concurrent claim and worker-retry cases. |
| active referee ordering | `get_active_referee_tasks.test.sql` | Preserve ordering in API DTO integration test. |
| evidence update/resubmit | `update_evidence.test.sql`, `resubmit_evidence.test.sql` | Add private-object authorization and finalize/cleanup cases. |
| judgement and confirmation | `test_judge_evidence.sql`, `test_confirm_judgement.sql` | Port status, authz, idempotency, and close-flow cases. |
| evidence/review/auto-confirm timeouts | timeout and auto-confirm SQL suites | Port to fake-clock worker + real-Postgres tests. |
| point/trial settlement | trial/point SQL suites | Retain real-Postgres atomicity and add concurrent mutation tests. |
| subscription point reset | `reset_subscription_points.test.sql` | Add duplicate RevenueCat event and reconciliation tests. |
| reward payout | `test_reward_payout.sql`; payout metrics pgTAP | Add duplicate job/Stripe retry and crash-between-transfer-and-ledger cases. |
| Stripe webhook | small mocked Edge tests | Replace with raw-body signature, duplicate inbox, Connect `account.updated`, and retry tests. |
| R2 cleanup | helper tests only | Add upload/download ownership tests and staging cleanup rehearsal. |
| reports | `reports.test.sql` | Add API cross-user/duplicate tests. |
| account deletion | `account_deletion.test.sql` | Add persisted saga retry for every external step. |
| reminders | `deadline_reminders.test.sql` | Port deduplication and timezone cases to worker tests. |
| payment summary | `get_payment_summary.test.sql` | Preserve empty, trial, reward, payout, and date projections. |

Do not expand tests for code already classified **Drop**. Preserve the
current SQL tests until the equivalent Go/Postgres tests pass, then relocate
retained pgTAP coverage to `db/tests/`.

## 7. Edge Function & Webhook Disposition

> Source: supplement §8, reconciled with canonical §1.3/§3.3 (identical
> dispositions — the fuller per-function purpose/caller narrative lives in
> §3.3 above; this section is the concise operational summary).

| Current function/path | Caller/trigger | Disposition and Go owner |
|---|---|---|
| `billing-setup` | Dormant Flutter code | Drop with obsolete Stripe Billing UI. |
| `create-stripe-checkout` | Web pricing | Drop; subscriptions are store IAP through RevenueCat. |
| `create-express-dashboard-link` | Flutter | `payout` authenticated endpoint. |
| `delete-account` | Flutter and web | `account` endpoint + persisted deletion worker. |
| `execute-pending-payouts` | cron | `payout` worker with Stripe idempotency. |
| `generate-upload-url` | Evidence and profile | `evidence`/`profile` endpoints backed by shared R2 adapter. |
| `handle-google-play-rtdn` | Google Pub/Sub | Drop after RevenueCat receives store notifications. |
| `handle-stripe-webhook` | Stripe | Signed webhook inbox; retain Connect events, remove Checkout subscription logic. |
| `payout-setup` | Flutter | `payout` Connect-onboarding endpoint. |
| `recommend-payout-topup` | Operator secret | Go operator endpoint or CLI; keep outside public API. |
| `send-notification` | `pg_net`/database functions | FCM adapter consumed by notification worker. |
| `sweep-r2-stale-objects` | cron | R2 cleanup worker. |
| missing `payout-request` | Dead Flutter method | Drop caller and unmounted dialog; do not port (§5.1). |

**Reconciliation with §3.3.** This table's 12 rows (plus the separately
tracked `payout-request` dead path) match §3.3's per-function purpose/caller
detail row-for-row and disposition-for-disposition — no discrepancy was
found between the two source documents on Edge Function disposition. §3.3
is the fuller reference for exact caller file:line evidence; this table is
the quick-reference summary.

### 7.1 Webhook rules

- RevenueCat: authorization header + HMAC over the raw body, durable inbox,
  duplicate event-ID guard, prompt response, then subscriber reconciliation.
- Stripe: signature verification over the raw body, durable inbox, unique
  event ID, prompt response, worker processing.
- Sandbox and production endpoints/config are separated.

### 7.2 RevenueCat webhook cost (short form)

RevenueCat currently documents webhooks as a Pro integration. The Pro plan
is free up to USD 2,500 monthly tracked revenue and then charges 1% of
tracked revenue. That is accepted for the pre-launch scale. Sources:
[pricing](https://www.revenuecat.com/pricing/) and
[webhook security/retries](https://www.revenuecat.com/docs/integrations/webhooks).

A deeper, independently-sourced verification of this cost claim (confirming
both webhooks *and* the REST API used for server-side reconciliation are
covered by the same free-to-$2,500-MTR plan) is carried in full at §12.2,
alongside the rest of the D4 (subscription/RevenueCat) decision record.

## 8. Subscription Baseline

> Source: supplement §10, verbatim. **Framing note:** the product IDs,
> point allocations, and prices below live in the app-store consoles and
> RevenueCat dashboard, not in the declarative Postgres schema — they are
> **store-console-authoritative** and must be verified against both
> consoles (and reconciled with the legal/pricing display) in Phase 5,
> not assumed frozen by this document.

Inherited identity decision: RevenueCat App User ID is the internal PepperCheck
UUID, never Firebase UID, email, or an anonymous RevenueCat ID.

| Plan | Store product ID (Apple and Google) | Monthly points |
|---|---|---:|
| Light | `light_monthly` | 5 |
| Standard | `standard_monthly` | 10 |
| Premium | `premium_monthly` | 20 |

- One entitlement, `peppercheck_subscription`, represents paid access.
- The default offering exposes three custom packages keyed by plan.
- A database/config product map resolves platform + product ID to plan and
  points; webhook code never derives a plan by trimming a string suffix.
- Initial purchase and every renewal reset available subscription points to
  the plan allocation, preserve locked points, and expire unused available
  points.
- Event/transaction identity deduplicates each reset.
- First paid activation permanently deactivates remaining trial points.
  Expiry or cancellation does not reactivate them; outstanding referee
  obligations survive.
- The store and RevenueCat dashboards are authoritative for price display.
  The repository contains a known Premium discrepancy: the current Google
  seed is JPY 2,580 while the later cross-platform design specifies JPY
  2,480. **Phase 5 must reconcile both store consoles and the legal display
  before sandbox tests** (also tracked as a launch-blocker register item,
  §5.3).

## 9. Web Route Freeze

> Source: supplement §11, reconciled with the canonical baseline's
> route-by-route audit. Production stays on `peppercheck.dev`; staging stays
> on `staging.peppercheck.dev`. JSON API routes share the same origins under
> `/api/v1`, avoiding another public hostname.

| Route | Decision |
|---|---|
| `/` and `/{locale}` | Keep marketing home; preserve locale redirect behavior. |
| `/{locale}/legal/privacy` | Keep and update providers/data handling. |
| `/{locale}/legal/terms` | Keep. |
| `/{locale}/legal/refund` | Keep and align with IAP. |
| `/{locale}/legal/tokushoho` | Keep; render reviewed product/legal data. |
| `/{locale}/account/delete` | Keep as provider-neutral deletion/support resource. |
| `/{locale}/stripe/connect/return` | Keep. |
| `/{locale}/stripe/connect/refresh` | Keep. |
| support/contact route | Add if the deletion resource cannot reuse an existing contact channel. |
| `/{locale}/auth/callback` | 301 to localized home. |
| `/{locale}/login` | 301 to localized home. |
| `/{locale}/dashboard` | 301 to localized home. |
| `/{locale}/pricing` | 301 to localized home or an IAP explanation section. |

**Totals:** 8 keep / 1 conditional-add (support/contact) / 4 redirect
(`auth/callback`, `login`, `dashboard`, `pricing`, all → localized home or an
IAP explanation section).

### 9.1 Reconciliation with the canonical route audit

The canonical baseline's independent route-by-route audit (12 route files
enumerated from `peppercheck-webapp`) reaches the **same 8 keep / 4
redirect** split, with one framing difference the operator resolves here:
the canonical audit treated `/{locale}/auth/callback` as a plain **Remove**
(no redirect target), flagging "does this need a 301 at all?" as an open
question, since it is a machine-to-machine OAuth callback with no
bookmark/link value once web login is gone. This document adopts the
supplement's more concrete decision — **redirect `auth/callback` to the
localized home, uniformly with `login`/`dashboard`/`pricing`** — closing
that open question with the simpler, uniform rule (every removed
Supabase-auth/subscription URL 301s to the localized home) rather than
carving out an exception.

Additional context preserved from the canonical audit, not restated as
open questions:

- `src/components/SubscribeButton.tsx` is a non-route removal target
  (client component rendered only by `pricing/page.tsx`); it has no route
  file of its own and is deleted alongside the `pricing` route.
- `src/middleware.ts` intersects two concerns: `next-intl` locale routing
  and the Supabase SSR session-refresh (`updateSession()`). Removing the
  Supabase half (this refactor's whole point) requires preserving or
  reimplementing the locale-routing half for every kept route to keep
  resolving `/{locale}/...` correctly — a line item for whoever implements
  this section's routes, not just a route-by-route port.
- `/{locale}/account/delete` (kept) has a **live Supabase dependency** not
  visible to a literal `@supabase` package-name grep: it imports the local
  `@/lib/supabase/client` wrapper (`supabase.auth.getUser()`,
  `supabase.rpc('check_account_deletable')`,
  `supabase.functions.invoke('delete-account')`). Any future automated
  check for "webapp still has Supabase deps" must also grep for
  `@/lib/supabase`, not just the npm package name — or, better, do the
  actual Go/htmx port of this page before relying on grep-based
  verification.
- `auth/callback/route.ts`'s existing Supabase-error path already redirects
  to a nonexistent page (`/{locale}/auth/auth-code-error` has no matching
  file in the current tree) — a pre-existing dead link, unrelated to this
  refactor's scope, noted only to avoid confusion when reading the route's
  current behavior.
- Only 3 webapp files match a literal `@supabase` import
  (`src/lib/supabase/{server,client,middleware}.ts`); all Supabase calls in
  consumer pages/components go through these thin wrappers via the
  `@/lib/supabase/...` path alias, which is why `account/delete/page.tsx`
  doesn't show up in a plain `@supabase` grep despite being a real Supabase
  consumer (see previous bullet).

## 10. Unused Code / Schema Drop Candidates (D8)

> Source: canonical §7. Cross-references: program design doc §15
> "Opportunistic Refactor Scope (bounded)," §17 "Edge Function → Go Mapping"
> (`billing-setup` row), §28 "To Confirm During Phase 0" (D8 candidates); §4
> (schema dead-code flags); §7 (`billing-setup` disposition); Appendix C
> (`stripe_billing_repository.dart:41` flag).

This is a **candidate list only** — nothing here has been deleted. Every row
below carries the grep evidence used to conclude "no caller," and every
schema candidate is explicitly marked "verify before drop" per the source
investigation's own hedge (also reflected as the operator's resolution in
§4.6).

**Explicit exclusion:** the **trial-point** system (`lock_trial_points`,
`consume_trial_points`, `route_*`, and the Flutter domain/data/presentation
code that reads `point_wallets`/`trial_point_wallets`/`user_subscriptions`,
including files that happen to live under the legacy `features/billing/`
directory name) is **active, production code and stays**. It is a different
system from the dormant Stripe user-billing set below, despite sharing a
directory. See MEMORY note "Billing → Point Rename": `features/billing/` is
a legacy name; trial-point code belongs there for now and is out of scope
for this drop list.

### 10.A. Dormant Stripe user-billing set (Flutter) — not mounted, safe-to-drop candidate

Design doc §17 states `BillingSetupSection` is not mounted on any screen.
Re-verified independently: the whole call graph (widget → controller →
repository → domain types → edge function) is a closed, self-contained
subgraph with **zero inbound references from anywhere else in the app**.

| artifact | evidence it is unused | drop in phase | risk |
|---|---|---|---|
| `peppercheck_flutter/lib/features/billing/presentation/widgets/billing_setup_section.dart` (`BillingSetupSection` widget) | `grep -rn "BillingSetupSection" peppercheck_flutter/lib/` → only the class declaration itself (line 11). `grep -rn "billing_setup_section" peppercheck_flutter/lib/` (filename/import search) → **zero hits outside the file itself** — no screen imports or mounts it. | Phase 5 (Financial & subscription) — same area as the rest of `features/billing/` | Low. No caller anywhere; deleting cannot break another screen. |
| `peppercheck_flutter/lib/features/billing/presentation/billing_controller.dart` (+ `.g.dart`) | `grep -rln "billing_controller\.dart'" peppercheck_flutter/lib/` → only imported by `billing_setup_section.dart` (dead per above) and its own generated file. `billingControllerProvider` has no `ref.watch`/`ref.read` call sites outside `billing_setup_section.dart`. | Phase 5 | Low. Sole consumer is already-dead widget. |
| `peppercheck_flutter/lib/features/billing/data/stripe_billing_repository.dart` (+ `.g.dart`) | `grep -rln "stripe_billing_repository" peppercheck_flutter/lib/` → only `billing_controller.dart` (dead per above) and its own generated file import it. Calls `_supabase.functions.invoke('billing-setup')` (dormant edge fn, see 10.D) and reads `stripe_accounts.{pm_brand,pm_last4,pm_exp_month,pm_exp_year}` (dead columns, see 10.B). | Phase 5 | Low. Transitively dead; confirmed no other repository reads these columns (see 10.B). |
| `peppercheck_flutter/lib/features/billing/domain/stripe_billing_setup_session.dart` (+ `.freezed.dart`, `.g.dart`) | Only referenced from `stripe_billing_repository.dart` (dead per above); `grep -rln "StripeBillingSetupSession\|stripeBillingSetupSession"` returns only this domain file's own 3 generated/source files. | Phase 5 | Low. Pure DTO with one dead caller. |
| `peppercheck_flutter/lib/features/billing/domain/default_billing_method.dart` (+ `.freezed.dart`, `.g.dart`) | `grep -rln "DefaultBillingMethod"` → only `stripe_billing_repository.dart` and `billing_controller.dart` (both dead per above) plus its own generated files. | Phase 5 | Low. Pure DTO with only dead callers. |

**Note on phase timing:** §15 scopes opportunistic cleanup to "areas already
being migrated." `features/billing/` is touched in Phase 5 (point/subscription
work), so that is the natural drop point. Because this subgraph requires zero
Go-side work (pure deletion, no replacement needed), the operator may also
choose to pull it forward into Phase 0/1 as a zero-risk pre-cleanup — flagging
as an option, not asserting a phase change.

### 10.B. Dormant Stripe user-billing set (schema) — orphaned `stripe_accounts` columns

These columns back the same abandoned "off-session card registration" feature
as 10.A. Verified independently: **never written by any function or Edge
Function**, and (once 10.A is confirmed) never read either.

| artifact | evidence it is unused | drop in phase | risk |
|---|---|---|---|
| `stripe_accounts.default_payment_method_id`, `.pm_brand`, `.pm_last4`, `.pm_exp_month`, `.pm_exp_year` (`supabase/schemas/stripe/tables/stripe_accounts.sql:9-13`) | `grep -rn "pm_brand\|pm_last4\|pm_exp_month\|pm_exp_year\|default_payment_method_id" supabase/functions/billing-setup/index.ts supabase/functions/handle-stripe-webhook/index.ts` → no hits in either function (the two Stripe-account-touching Edge Functions never write these fields). Only reader is `stripe_billing_repository.dart:42` (dead, 10.A). `stripe_accounts_policies.sql` has no column-specific policy referencing them. | Phase 5 (same Atlas pass that touches `stripe/` schema for Connect payout work) | Low-medium. Columns are always NULL today (never written) so dropping loses no data; medium only in that this is a physical schema change (needs an Atlas migration) vs. the pure-deletion Flutter rows above. Confirm no out-of-repo tool (admin script, BI query) reads these columns before dropping. |

**Not a candidate:** the `stripe_accounts` **table** itself stays — it backs
the active Stripe Connect payout flow (`stripe_connect_account_id`,
`charges_enabled`, `payouts_enabled`, `connect_requirements` are read/written
by `prepare_monthly_payouts()`, `stripe_payout_repository.dart`,
`payout-setup`, `create-express-dashboard-link`, `execute-pending-payouts`,
`handle-stripe-webhook`, `delete-account`). Only the 5 card-on-file columns
above are dead.

### 10.C. Schema dead-code candidates — independently re-verified, "verify before drop"

Per the assembly brief, these are **not asserted for removal** — re-running
the grep independently, scoped to the current `supabase/schemas/`
(declarative source of truth; `supabase/migrations/` is historical and out
of scope per that inventory's own scoping note).

| artifact | evidence it is unused | drop in phase | risk |
|---|---|---|---|
| `detect_and_handle_referee_timeouts()` (`supabase/schemas/matching/functions/detect_referee_timeouts.sql`) | `grep -rn "detect_and_handle_referee_timeouts" supabase/ peppercheck_flutter/lib/ peppercheck-webapp/src` → only hits are the function's own definition (`matching/functions/detect_referee_timeouts.sql`, `CREATE OR REPLACE FUNCTION` + `COMMENT ON FUNCTION`) and its historical `CREATE OR REPLACE` in two old migration files (`20251005123145_init.sql`, `20260124153250_...sql`) — no call site anywhere, ever, in any migration or schema file. Confirmed separately: `grep -rn "detect_and_handle_referee_timeouts" $(find supabase/schemas -path "*/cron/*" -name "*.sql")` → no hits in any of the 10 cron files (it has no `cron.schedule` entry, unlike its judgement-domain duplicate `detect_and_handle_review_timeouts()`, which is scheduled). | Phase 4 (Core task lifecycle — matching domain) | **Verify before drop** — resolved by operator adjudication (§4.6, and reclassified Drop under the merged 5-way tally, §4.2/Appendix A #4). Zero callers/cron entries confirmed independently. This could have been *meant* to be wired to a cron schedule that was never added, rather than intentionally dead — confirm intent with the operator before dropping, don't assume it's safe to silently drop the underlying business rule (referee timeout detection) along with the function. |
| `is_task_tasker(task_uuid, user_uuid)` (`supabase/schemas/profile/functions/auth_helpers.sql:37`) | `grep -rn "is_task_tasker" supabase/schemas/` → only its own definition, `ALTER FUNCTION`, and `COMMENT ON FUNCTION` (3 hits, all in `auth_helpers.sql` itself); **zero calls** from any current RLS policy or function in `supabase/schemas/`. Note: `grep -rn "is_task_tasker" supabase/migrations/` **does** show call sites in 3 historical migrations (`20251005123145_init.sql`, `20260123091601_refactor_judgements_table.sql`, `20260213051955_remove_judgements_view.sql`) — the function *was* called by earlier versions of judgement-related policies/functions that have since been refactored to drop the call. This corroborates rather than contradicts the current state: the current schema state (source of truth) has zero callers; the historical trail explains *why* it looks vestigial rather than never-used. | Phase 4 (task/judgement domain — matches the file's historical callers) or Phase 3 if `profile/functions/auth_helpers.sql` as a whole is swept when the `profile` feature migrates; either is defensible, operator's call. | **Verify before drop** — resolved by operator adjudication (§4.6). Its two siblings in the same file — `is_task_referee()` and `is_task_referee_candidate()` — are **not** drop candidates: both are actively called once each from `task/policies/tasks_policies.sql` (confirmed by `grep -rn "is_task_referee\b\|is_task_referee_candidate" supabase/schemas/`), and their disposition is tied to the broader "retire all 63 RLS policies to Go authz" plan (§4.9), not to today's dead-code list. Do not conflate the three `auth_helpers.sql` functions. |

### 10.D. Cross-reference: `billing-setup` Edge Function (already flagged in §3.3/§7)

Not re-tabulated in full here — §3.3/§7 already classify `billing-setup` as
**"Drop — currently unused"** and this section's 10.A independently confirms
its only caller (`stripe_billing_repository.dart`) is itself dead code with
zero upstream callers. Both findings agree: drop the `billing-setup` Edge
Function together with the Flutter subgraph in 10.A, in the same PR, so the
client and server sides of the dead feature are removed atomically.

### 10.E. Summary

| Group | Count | Disposition |
|---|---|---|
| A — Flutter dormant Stripe billing set | 5 files (+ 5 generated siblings) | Drop candidate, Phase 5 (or earlier as zero-risk pre-cleanup) |
| B — `stripe_accounts` orphaned columns | 5 columns on 1 table | Drop candidate, Phase 5 |
| C — schema dead functions | 2 functions | Verify before drop (resolved, §4.6), Phase 3/4 |
| D — `billing-setup` Edge Function | 1 function | Already flagged in §3.3/§7; drop together with A |
| F — dead manual-payout path | `payout_amount_dialog.dart` + `requestPayout()` + DTO + i18n keys | Resolved (§5.1, §10.F); remove in the payout migration (Phase 5) |
| Excluded | trial-point + subscription/point/IAP code in `features/billing/` | **Stays** — active production code, not evaluated for removal |

No other unused-code candidates were found within this task's grep scope
(Flutter dormant-billing verification + schema corroboration). A broader
open-ended dead-code sweep of the rest of the codebase was not performed —
out of scope per §15's "bounded" cleanup rule (opportunistic cleanup only in
areas already being migrated, not a general audit).

### 10.F. Dead manual-payout path (`payout-request`)

The referee "request payout now" feature is fully dead/unmounted code (full
investigation and evidence at §5.1):

| artifact | evidence it is unused | drop in phase | risk |
|---|---|---|---|
| `peppercheck_flutter/lib/features/payout/presentation/widgets/payout_amount_dialog.dart` (`PayoutAmountDialog`) | `grep -rn "PayoutAmountDialog(" peppercheck_flutter/lib/` → only its own constructor declaration; nothing mounts it via `showDialog`; `payout_amount_dialog` imported by no other file. | Phase 5 (payout migration) | Low. Never shown; deleting cannot break a reachable screen. |
| `stripe_payout_repository.dart` `requestPayout()` + `PayoutRequestResponse` DTO | `grep -rn "\.requestPayout(" peppercheck_flutter/lib/` → **0 callers**. Invokes the nonexistent `payout-request` Edge Function. | Phase 5 | Low. Sole would-be caller is the dead dialog. |
| unused i18n keys `dashboard.requestPayout` / `dashboard.payoutRequested` | Only referenced by the dead dialog. | Phase 5 | Low. Localization-only. |

Remnant of the removed `payout_jobs`-era manual-payout architecture; the
approved flow is the monthly `reward_payouts` batch. Remove rather than
port — see §5.1.

## 11. Data Seed & Tester-Data Policy

> Source: canonical §9, enriched with the supplement's §12.1 itemized
> reference/config seed list.

### 11.1 Go-live data strategy (program D9)

The Go-live DB is built **fresh** from Atlas migrations + reference seed
data. **No historical migration, no dual-write.** Testers re-create their
account via normal Firebase login (a new internal `users.id` UUID); old
profile rows are not imported (identity mismatch under §8 — a few testers
re-enter their profile).

- No tester profile, auth identity, task, evidence, judgement, wallet,
  ledger, subscription, payout, report, notification, or R2 object is
  migrated.
- Testers sign in through Firebase and receive a new internal UUID and
  generated username, then re-enter optional profile data.
- Never copy profile rows from Supabase because their IDs are Supabase Auth
  IDs.

### 11.2 Current seed state (measured)

- `supabase/config.toml` `[db.seed]` references `sql_paths = ["./seed.sql"]`,
  but **no `supabase/seed.sql` exists** — there is no persistent row-seed
  today.
- Reference data is expressed as schema DDL: enum types
  (`matching`, `trial_point`, `subscription`, `point`, … `tables/enums.sql`)
  and any singleton config tables (`BOOLEAN PK DEFAULT true` pattern).

### 11.3 Seed subset for the fresh DB (built per owning feature phase)

> **Reconciled 2026-07-23:** the Phase 1 Foundation plan scopes Phase 1 to the
> identity core (`users`, `user_identities`) + durable-job/webhook-inbox
> primitives only — it deliberately does **not** create the reference/config
> tables. Those tables and their seed rows are therefore built in their
> **owning feature phases** (currencies/matching config/notification defaults →
> Phase 3; subscription plans + platform product mapping + reward/payout config
> → Phase 5), not during the Phase 1 Atlas baseline. The itemized set below is
> the complete list to seed across those phases; the "build during the Atlas
> baseline, Phase 1" framing of an earlier draft is superseded by this split.

Reference/config seed set for the new database (itemized, supplement §12.1):

- currencies;
- matching strategy cost/config and matching-time config;
- Light/Standard/Premium plans and platform product mapping (see §8 for the
  store-console-authoritative caveat);
- trial-point initial grant config;
- reward exchange rate;
- payout top-up config;
- notification-setting defaults and any stable template keys.

| Data | Kept? | Note |
|------|-------|------|
| Enum types | Yes (DDL) | Part of the schema; recreated by migrations. |
| Singleton config rows (matching config, trial-point grant config, reward exchange rate, payout top-up config, notification defaults) | Yes | Enumerate during Atlas baseline; seed as reference rows. |
| Currencies | Yes | Reference data. |
| Product-to-plan / entitlement mapping | Yes (Phase 5) | Config/DB data for RevenueCat; not needed until Phase 5. |
| Tester accounts / profiles | **No** | Recreate via login (D9). |
| Historical tasks / ledgers / payouts | **No** | Disposable internal-test data (D9). |

**Tester data worth keeping: none** (default per D9). The old Supabase env
may stay read-only briefly for **comparison only** — never rollback, never
in the runtime path.

No real user identifier or provider credential belongs in seed data.

## 12. Accepted Operational Decisions

> Source: supplement §13, verbatim, plus the canonical baseline's accepted
> D2 (identity) and D4 (subscription/RevenueCat) decisions and the full D4
> cost-verification investigation (§12.2). **These decisions replace any
> earlier "open decision / decide-by Phase 7" framing** for RPO/RTO, VPS
> provider/region/size, monitoring/alerting, domains, or release dates — an
> earlier draft of the canonical baseline recorded these as open
> (decide-by-Phase-7) items; that framing is superseded by the accepted
> decisions below and is not carried forward.

**Accepted 2026-07-23.** These choices define implementation defaults but do
not by themselves purchase or change external services.

### 12.1 Recovery

- **RPO: 15 minutes. RTO: 4 hours.** A 24-hour loss window is unacceptable
  once point/reward/payout state exists.
- Start with the 15-minute RPO. Reassess a 5-minute target and then a
  1-minute target after measuring WAL archive lag, archive volume/cost, and
  restore reliability. Do not claim the shorter target until restore drills
  demonstrate it consistently.
- Recurring encrypted physical base backups plus continuous WAL archiving to
  B2 provide point-in-time recovery. A custom-format `pg_dump` is retained
  as an independent daily logical fallback; it is not part of WAL replay.
- Keep recoverable physical backup sets and all dependent WAL needed for
  30-day point-in-time recovery, plus 30 daily logical dumps.
- Encrypt client-side with an `age` recipient; the backup container only has
  the public recipient. Also enable B2 SSE-B2.
- Use a private B2 bucket with 30-day governance Object Lock and a
  lifecycle policy after the lock expires. B2 documents both
  [Object Lock](https://www.backblaze.com/docs/cloud-storage-object-lock) and
  [server-side encryption](https://www.backblaze.com/docs/cloud-storage-server-side-encryption).
- Restore monthly into a separate database and run authenticated API smoke
  tests.

R2 objects use unique, non-overwritten keys. R2 does not provide S3 bucket
versioning, although it has retention bucket locks. Because account
deletion must eventually purge user data, copy referenced objects daily to a
separate B2 backup prefix with the same 30-day disclosed retention instead
of indefinitely locking the delivery bucket. Cloudflare documents
[bucket locks](https://developers.cloudflare.com/r2/buckets/bucket-locks/) and
the unsupported S3 `PutBucketVersioning` operation in its
[compatibility matrix](https://developers.cloudflare.com/r2/api/s3/api/).

This directly gates the launch-blocker register's "no rehearsed off-VPS
restore/PITR path" item (§5.3): the accepted decisions above define what the
Phase 1 skeleton must implement and what the Phase 7 rehearsal must
exercise.

### 12.2 VPS and environments

**Accepted 2026-07-23.**

- Provider/region: DigitalOcean Basic Droplets in Singapore (`sgp1`). The
  operator's existing familiarity reduces operational risk, and the stack
  stays portable with no DigitalOcean-specific API in application packages.
- Production starts on a dedicated 1 GiB RAM / 1 vCPU / 25 GiB SSD Droplet.
  It runs only Caddy, the Go API, worker, PostgreSQL, and backup
  components. Images are built in CI rather than on the VPS, and logs are
  size-limited.
- Staging runs on a separate Droplet and starts at 1 GiB unless measured
  integration workloads require more. It has independent Compose state,
  PostgreSQL data, credentials, and external-provider configuration.
- Only Caddy exposes ports 80/443 on either host. Production uses
  `peppercheck.dev`; staging uses `staging.peppercheck.dev`.
- Re-measure memory, disk, latency, and restore time before enabling
  production. Resize production to 2 GiB after any OOM, recurring swap use,
  sustained memory pressure, or failure to meet the four-hour restore
  target. DigitalOcean documents current
  [Basic Droplet pricing](https://www.digitalocean.com/pricing/droplets),
  [regional availability](https://docs.digitalocean.com/platform/regional-availability/),
  and [vertical resizing](https://docs.digitalocean.com/products/droplets/how-to/resize/).

### 12.3 Monitoring

- Better Stack is the default provider-neutral external monitoring service
  for PepperCheck and future services: public liveness/readiness, TLS,
  response time, and critical worker/backup heartbeats. Paid use is
  acceptable when shared visibility and alerting exceed the free
  allowance: [pricing](https://betterstack.com/pricing).
- DigitalOcean Monitoring remains the default host-level source for Droplet
  CPU, load, memory, disk usage/I/O, and bandwidth alerts. Do not duplicate
  these metrics in Better Stack without an application-level use case.
- Better Stack telemetry is opt-in per service, not an automatic full-volume
  export. Start with short retention, warning/error logs, low-cardinality
  application metrics, and sampled traces. Configure usage/spend alerts
  before increasing volume or retention.
- Alert by email first; add paid phone/SMS escalation after real on-call
  demand.
- The application remains vendor-neutral: structured stdout logs and
  Prometheus-compatible/OpenTelemetry telemetry, with no Better Stack types
  in feature packages.

### 12.4 Milestone-based release timing

No release or code-freeze date is fixed during Phase 0. This is a
solo-operated business without an external calendar commitment, so quality
and recovery gates take precedence over an aspirational date.

Review effort after Phases 1, 2, and 4 without turning those reviews into
release commitments. After Phase 6 and the Phase 7 staging, restore, and
release-journey gates pass, select the store-submission date and begin an
approximately one-week blocker-only freeze. Never shorten the plan by
dropping the non-deferrable controls listed in the parent strategy.

### 12.5 Identity (D2) and Subscription (D4) — accepted

> Source: canonical §8.1.

| # | Decision | Basis | Status |
|---|----------|-------|--------|
| D2 | Firebase Auth for authentication; PepperCheck owns an internal `users.id` UUID as the FK anchor + RevenueCat App User ID; `user_identities(issuer, subject)` maps Firebase → internal; provider unification via Firebase account linking; never use Firebase UID as a domain PK. | Program design §10, D2. | **Accepted** (operator sign-off 2026-07-22) |
| D4 | RevenueCat for subscription entitlement (durable deduplicated reconciled webhook); Stripe Connect retained for payouts; web Stripe Checkout + `billing-setup` dropped. | Program design §11, D4. RevenueCat cost verified (§12.6 below): webhooks **and** REST API are included in the RevenueCat Pro plan, **free up to $2,500 MTR** (1% of tracked revenue thereafter). **D4 stands as-is; no cost note needed.** | **Accepted** (operator sign-off 2026-07-22) |

### 12.6 D4 cost verification detail (RevenueCat webhook/REST API cost)

> Source: canonical §8.2. Verifies, from official `revenuecat.com` sources
> only, whether a durable webhook and the REST API used for server-side
> reconciliation require a paid RevenueCat tier, and the monthly tracked
> revenue (MTR) threshold at which RevenueCat billing begins. Research
> only — no pricing asserted from memory.

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
pre-consolidation plans that some existing customers may still be
grandfathered into — it is not a currently-purchasable tier. For a new
integration (this project's case), the only plan available is Pro, and it
includes webhooks from the start, at $0, below the MTR threshold.

Webhook delivery/durability characteristics also confirmed on the same page
(relevant to D4's "durable, deduplicated" webhook design, not a pricing
point): at-least-once delivery, retries up to 5 times over 5/10/20/40/80
minutes, 60-second response timeout, and an explicit note that duplicate
delivery can happen — "recommending idempotent processing using event IDs
to prevent duplicate handling."

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
  "custom pricing" per the official pricing page — no numbers are
  published, so nothing further can be confirmed there. Not relevant to D4
  at this project's scale.

### 12.7 Deferred, not open

- **RevenueCat product/entitlement mapping** → Phase 5 implementation
  detail (config/DB data, program §11), not a Phase 0 blocker.
- **Point / trial-point reset behavior** → **already decided**: points
  reset on renewal, not accumulate (PR #339). Cite, do not re-litigate.

## 13. Phase 1 Handoff

> Source: supplement §14.

Phase 0 is complete. The Phase 1 implementation plan must use this baseline
to create:

1. the Go module and API/worker lifecycle;
2. provider-independent Atlas schema with internal user IDs;
3. local Compose/Caddy/Postgres skeleton;
4. migration/runtime DB role separation;
5. durable job and webhook inbox primitives;
6. backup/WAL skeleton matching the accepted RPO/RTO (§12.1);
7. CI gates for Go, Atlas, Postgres, and image builds.

**No Phase 1 code should port a feature RPC, Edge Function, or web route
yet.**

---

## Done Checklist

> Each item ticked with the section of this merged baseline that satisfies
> it.

- [x] Flutter and web Supabase calls measured and assigned to target
      features. → **§2** (reproducible measurements) + **§3** (dependency
      inventory, §3.2 master table + §3.6 per-feature view) + **Appendix C**
      (full Flutter API-surface map).
- [x] All 68 schema functions classified. → **§4** (5-way taxonomy, tally
      DB invariant/helper 1 / Store query 4 / Go transaction 38 / Go
      service/worker 21 / Drop 4 = 68, with the 3 operator resolutions
      applied) + **Appendix A** (full per-function table with evidence).
- [x] All 36 schema triggers classified. → **§4.4** (21 housekeeping stay /
      15 business → Go) + **Appendix B** (full per-trigger table).
- [x] All 10 cron schedules classified. → **§4.3** (all 10 → Go worker,
      issuing state directly, not via RPC).
- [x] All 12 Edge Functions and the orphaned `payout-request` call
      classified. → **§3.3** (12-row detail table) + **§7** (concise
      disposition table) + **§5.1** (`payout-request` investigation and
      resolution).
- [x] Firebase, Stripe, R2, IAP, webhook, web-hosting, backup, and
      monitoring integrations have a target owner or an explicit removal
      decision. → **§3.2** (master table, all 21 rows) + **§7** (webhook
      rules) + **§12** (accepted recovery/VPS/monitoring decisions).
- [x] Reduced web routes and redirects fixed. → **§9** (8 keep / 1
      conditional-add / 4 redirect, reconciled with the canonical audit).
- [x] Tester-profile migration decision and reference-data seed set fixed.
      → **§11** (fresh-DB strategy + itemized seed set).
- [x] Identity and subscription model inherited from the parent strategy.
      → **§12.5** (D2 identity, D4 subscription, both accepted) + **§8**
      (subscription baseline detail).
- [x] Existing high-risk characterization coverage recorded with migration
      gates. → **§6** (five journey flows with pgTAP evidence) + **§6.6**
      (characterization-asset → migration-gate table).
- [x] Owner accepts the recovery, VPS/environment, and monitoring
      decisions. → **§12.1–§12.4** (all accepted 2026-07-23).
- [x] Release timing is intentionally milestone-based; no calendar date is
      required to exit Phase 0. → **§12.4**.
- [x] All launch-blockers identified, each assigned an owning phase. →
      **§5** (10-item union register: `payout-request` resolved as dead
      code, not a blocker; T7-1/T7-2/T7-3 financial-integrity candidates
      with deep evidence; 6 additional supplement-sourced items).
- [x] Unused-code drop candidates concretely listed. → **§10** (10.A–10.F:
      5 Flutter files + generated siblings, 5 orphaned schema columns, 2
      schema dead functions marked verify-before-drop, 1 Edge Function, 1
      dead manual-payout path).

**No gaps.** Every Done-checklist item carried by either source document is
satisfied by this merged baseline.

---

## Appendix A — Full SQL function classification (68)

> Per-function 5-way classification (§4's taxonomy, supplement §5 base
> assignment + the 3 operator-approved resolutions from §4.6), with the
> canonical baseline's SQL-cited evidence note preserved per function.
> Numbering (#1–68) matches the canonical baseline's own numbering and is
> the numbering referenced by `#N` citations throughout this document.
> **Δ** marks the 3 functions whose disposition changed under the §4.6
> resolutions relative to the supplement's original assignment.

| # | function | file | class (5-way) | evidence note |
|---|---|---|---|---|
| 1 | `process_pending_requests()` | `matching/functions/process_pending_requests.sql` | Go service/worker | Cron orchestrator: expires stale pending requests (refunds via `route_unlock_points`, now Go — dissolved, see #23), retries `process_matching` for the rest. |
| 2 | `update_referee_available_time_slot(...)` | `matching/functions/update_referee_available_time_slot.sql` | Go service/worker | `auth.uid()`-gated single-row CRUD + overlap validation. |
| 3 | `create_matching_request(...)` | `matching/functions/create_matching_request.sql` | Go transaction | Locks points (`lock_points`, now Go-issued atomic SQL, see #51) then inserts request; hardcoded strategy→cost table (TODO comment in source already flags this). |
| 4 | `detect_and_handle_referee_timeouts()` | `matching/functions/detect_referee_timeouts.sql` | **Drop** Δ | Dead code, unscheduled/unreferenced (zero callers, zero cron entries — see §10.C). Resolution: currently unused/unscheduled; if ever needed, design as a new Go worker requirement, not a port. |
| 5 | `create_referee_available_time_slot(...)` | `matching/functions/create_referee_available_time_slot.sql` | Go service/worker | `auth.uid()`-gated CRUD + overlap validation. |
| 6 | `auto_score_timeout_referee()` [trigger fn] | `matching/functions/auto_score_timeout_referee.sql` | Go transaction | Inserts negative referee rating on `review_timeout` confirm. Once ported, must also invoke #24's recompute statement (rating_histories write) — see §4.7. Dedup with #29 per §4.6. |
| 7 | `process_matching(uuid)` | `matching/functions/process_matching.sql` | Go service/worker | Core matching algorithm + 2 `notify_event` calls. |
| 8 | `trigger_process_matching()` [trigger fn] | `matching/functions/process_matching.sql` (L265) | **Go service/worker** Δ | Thin wrapper invoking `process_matching`. Resolution: the SQL wrapper itself is deleted, but the matching behavior it invokes moves to Go — "Go service/worker" is more accurate than "Drop" since the underlying capability is still needed, just invoked explicitly instead of trigger-fired. |
| 9 | `get_point_for_matching_strategy(strategy)` | `matching/functions/get_point_for_matching_strategy.sql` | Go service/worker | Pure stateless lookup with no table access (`IF p_strategy = 'standard' THEN RETURN 1; ELSE RAISE EXCEPTION...`). No atomicity to lose. Every remaining caller (#28, #29, #34) itself moves off Postgres, so there is no retained-Postgres caller requiring a shared copy — single Go constant, no cross-language drift risk (see §4.8). |
| 10 | `create_referee_blocked_date(...)` | `matching/functions/create_referee_blocked_date.sql` | Go service/worker | `auth.uid()`-gated CRUD. |
| 11 | `cancel_referee_assignment(uuid)` | `matching/functions/cancel_referee_assignment.sql` | Go transaction | Multi-step: cancel request, delete judgement, insert re-match request, notify. |
| 12 | `get_active_referee_tasks()` | `matching/functions/get_active_referee_tasks.sql` | Store query | `auth.uid()`-scoped read, UI-shaped `jsonb` assembly. |
| 13 | `delete_referee_available_time_slot(uuid)` | `matching/functions/delete_referee_available_time_slot.sql` | Go service/worker | `auth.uid()`-gated delete. |
| 14 | `get_payment_summary()` | `payment_summary/functions/get_payment_summary.sql` | Store query | `auth.uid()`-scoped dashboard aggregate read; UI-shaped response. |
| 15 | `delete_referee_blocked_date(uuid)` | `matching/functions/delete_referee_blocked_date.sql` | Go service/worker | `auth.uid()`-gated delete. |
| 16 | `update_referee_blocked_date(...)` | `matching/functions/update_referee_blocked_date.sql` | Go service/worker | `auth.uid()`-gated CRUD. |
| 17 | `lock_trial_points(...)` | `trial_point/functions/lock_trial_points.sql` | Go transaction | Bundles the availability check (`IF (v_balance - v_locked) < p_amount THEN RAISE EXCEPTION`) with `SELECT ... FOR UPDATE`, `locked = locked + p_amount`, and the ledger `INSERT`. Check → Go; lock+mutation+ledger-insert is the irreducible atomic sequence (backed by the existing `trial_point_wallets_balance_gte_locked` / `locked >= 0` CHECK constraints as a DB-level backstop). |
| 18 | `deactivate_trial_points(uuid)` | `trial_point/functions/deactivate_trial_points.sql` | Go transaction | The `IF v_is_active IS NULL` / `IF NOT v_is_active` idempotency short-circuits collapse into one guarded statement: `UPDATE trial_point_wallets SET is_active=false WHERE user_id=$1 AND is_active=true` + the informational ledger `INSERT`. Zero rows affected is the no-op case — no separate Go branch needed. |
| 19 | `route_consume_points(...)` | `trial_point/functions/route_consume_points.sql` | Go transaction | Pure routing dispatcher — `SELECT point_source FROM task_referee_requests` (unlocked read) then `IF v_point_source = 'trial' ... ELSE ...` branches to `consume_trial_points`/`consume_points`. No wallet mutation of its own; dissolves entirely into a Go branch calling #22/#50's atomic SQL. |
| 20 | `unlock_trial_points(...)` | `trial_point/functions/unlock_trial_points.sql` | Go transaction | Same shape as #17: `IF v_locked < p_amount THEN RAISE EXCEPTION` → Go; `SELECT ... FOR UPDATE` + `locked = locked - p_amount` + ledger `INSERT` → atomic store SQL. |
| 21 | `route_referee_reward(...)` | `trial_point/functions/route_referee_reward.sql` | Go transaction | `SELECT is_obligation FROM task_referee_requests` then branches. Obligation path: `SELECT ... FOR UPDATE` on oldest pending `referee_obligations` row + `UPDATE ... SET status='fulfilled'` (atomic SQL). Non-obligation path calls `grant_reward` (#66). The branch itself is Go; it issues one of two atomic SQL statements depending on `is_obligation`. |
| 22 | `consume_trial_points(...)` | `trial_point/functions/consume_trial_points.sql` | Go transaction | `IF v_balance < p_amount` / `IF v_locked < p_amount` checks → Go. `SELECT ... FOR UPDATE`, the `balance/locked` mutation, the ledger `INSERT`, and the fixed-count `FOR v_i IN 1..p_amount LOOP INSERT INTO referee_obligations` are the atomic sequence (the loop is a batch insert, not a decision). |
| 23 | `route_unlock_points(...)` | `trial_point/functions/route_unlock_points.sql` | Go transaction | Identical shape to #19 — pure `point_source` routing dispatcher to `unlock_trial_points`/`unlock_points`, no mutation of its own. |
| 24 | `update_user_ratings()` [trigger fn] | `rating/functions/update_user_ratings.sql` | Go transaction | No branching beyond `TG_OP = 'DELETE'` (picks `OLD`/`NEW`). Each recompute is one set-based statement: `UPDATE user_ratings SET tasker_positive_count = agg.pos, ... FROM (SELECT count(*) FILTER(...), count(*) FROM rating_histories WHERE ratee_id=$1 AND rating_type='tasker') agg WHERE user_id=$1` (and the referee equivalent) — textbook single set-based `UPDATE … FROM`. The `AFTER INSERT OR DELETE OR UPDATE` trigger dissolves: Go is the sole writer of `rating_histories` (via #6, #29, #34, #36), so Go runs these two statements in the same transaction as every `rating_histories` write instead of relying on a trigger firing on arbitrary paths. See §4.7. |
| 25 | `notify_judgement_confirmed()` [trigger fn] | `judgement/triggers/on_judgement_confirmed_notify.sql` | Go transaction | Push-notification dispatch (2x `notify_event`) on auto-confirm. Fires on the same `is_confirmed: false→true` transition as #26/#27/#57 — see §4.7 for the unified Go orchestration point. |
| 26 | `close_referee_request_on_confirmed()` [trigger fn] | `judgement/triggers/on_judgement_confirmed_close_request.sql` | Go transaction | Single-statement, PK-scoped `UPDATE task_referee_requests SET status='closed' WHERE id=NEW.id`, no branching beyond the trigger's own `WHEN` filter. The filter is subsumed by the caller's control flow (Go already knows it just flipped `is_confirmed`) — collapses to one atomic statement issued in the same transaction as the judgement-confirm write. See §4.7. |
| 27 | `handle_judgement_confirmed()` [trigger fn] | `judgement/triggers/on_judgement_confirmed.sql` | Go transaction | Push-notification dispatch on manual confirm; skips if `is_auto_confirmed`. Same transition as #25/#26/#57 — see §4.7. |
| 28 | `settle_evidence_timeout()` [trigger fn] | `judgement/triggers/on_evidence_timeout_settle.sql` | Go transaction | Mixed: wallet settlement via `route_consume_points`/`route_referee_reward` (both Go, #19/#21) + close request (atomic SQL, see #26) + 2x `notify_event`. Classified by its externally-visible side effect; the sub-calls are Go orchestration calling atomic SQL, not separate Postgres RPCs. |
| 29 | `settle_review_timeout()` [trigger fn] | `judgement/triggers/on_review_timeout_settle.sql` | Go transaction | Same pattern as #28: unlock points (`route_unlock_points`, #23) + negative rating insert (feeds #24's recompute) + close (see #26/#57) + 2x notify. Redundant rating insert with #6 — resolved by operator adjudication, §4.6. |
| 30 | `on_judgements_status_changed()` [trigger fn] | `judgement/triggers/on_judgements_status_changed.sql` | Go transaction | Status-change → notification key mapping + dispatch. |
| 31 | `judge_evidence(...)` | `judgement/functions/judge_evidence.sql` | Go transaction | `auth.uid()`-gated single state transition (approve/reject). |
| 32 | `confirm_evidence_timeout(uuid)` | `judgement/functions/confirm_evidence_timeout.sql` | Go transaction | `auth.uid()`-gated idempotent confirm; sets `is_confirmed = TRUE` (source comment: "triggers `on_all_judgements_confirmed_close_task`"). With that trigger dissolved (#57), the Go port of this handler must now explicitly issue #57's (and #26's, #25's, #27's) sequence in the same transaction — see §4.7. |
| 33 | `confirm_review_timeout(uuid)` | `judgement/functions/confirm_review_timeout.sql` | Go transaction | Same shape and same implication as #32 — sets `is_confirmed = TRUE`, source comment references the now-dissolved close-task trigger. See §4.7. |
| 34 | `detect_auto_confirms()` | `judgement/functions/detect_auto_confirms.sql` | Go service/worker | Not a single atomic statement. Decomposes into: the `FOR ... FOR UPDATE OF j SKIP LOCKED` eligibility+claim query (claims a batch of rows); the per-row `IF v_rec.status IN ('approved','rejected')` branch (Go); calls into `get_point_for_matching_strategy` (#9), `route_consume_points` (#19 → #50), `route_referee_reward` (#21 → #66); the `INSERT INTO rating_histories ... ON CONFLICT (judgement_id, rating_type) DO NOTHING` (backed by the existing `unique_rating_per_judgement` constraint); and the final `UPDATE judgements SET is_auto_confirmed=true, is_confirmed=true` which — with #25/#26/#27/#57 dissolved — must be immediately followed by Go explicitly invoking those in the same transaction (see §4.7). Overall: Go worker orchestration issuing five distinct atomic-SQL statements per claimed row. |
| 35 | `detect_and_handle_review_timeouts()` | `judgement/functions/detect_review_timeouts.sql` | Go service/worker | Exactly one statement, no branching: `UPDATE judgements j SET status='review_timeout' ... FROM task_referee_requests trr JOIN tasks t ... WHERE j.status='in_review' AND v_now > (t.due_date + INTERVAL '3 hours')` — textbook single set-based `UPDATE … FROM`, issued verbatim by the Go worker each tick; no stored function needed. |
| 36 | `confirm_judgement_and_rate_referee(...)` | `judgement/functions/confirm_judgement_and_rate_referee.sql` | Go transaction | Multi-step: settle wallet + grant reward + insert rating + confirm, all `auth.uid()`-gated. Inserts `rating_histories` (feeds #24's recompute) and sets `is_confirmed=TRUE` (must now explicitly invoke #26/#57's atomic SQL and #25/#27's Go logic — see §4.7). See §5.2 T7-2 — no explicit row lock; a race is possible under wallet headroom. |
| 37 | `on_task_evidences_upserted_notify_referee()` [trigger fn] | `evidence/triggers/on_task_evidences_upserted_notify_referee.sql` | Go transaction | Notification dispatch on evidence insert/update. |
| 38 | `validate_evidence_due_date()` [trigger fn] | `evidence/functions/validate_evidence_due_date.sql` | **Go service/worker** Δ | Pure read-only guard: `SELECT t.due_date ... IF v_now > v_due_date THEN RAISE EXCEPTION`. No mutation, no lock. Needs `tasks.due_date` (another table), so it cannot become a same-table CHECK constraint. Moves to Go as a pre-write validation in the evidence create/resubmit handlers — no atomicity lost, since nothing else contends on a single evidence row's due-date check. Resolution: move to Go; cross-table so not a same-table CHECK; Go is the sole write path. |
| 39 | `resubmit_evidence(...)` | `evidence/functions/resubmit_evidence.sql` | Go transaction | Multi-table: evidence update, asset add/remove, judgement status transition, `auth.uid()`-gated. |
| 40 | `update_evidence(...)` | `evidence/functions/update_evidence.sql` | Go transaction | `auth.uid()`-gated evidence + asset CRUD. |
| 41 | `submit_evidence(...)` | `evidence/functions/submit_evidence.sql` | Go transaction | Multi-table: evidence insert, asset insert, judgement status transition, `auth.uid()`-gated. |
| 42 | `detect_and_handle_evidence_timeouts()` | `evidence/functions/detect_evidence_timeouts.sql` | Go service/worker | Same shape as #35: one `UPDATE judgements j SET status='evidence_timeout' ... FROM task_referee_requests trr JOIN tasks t ... LEFT JOIN task_evidences te ... WHERE j.status='awaiting_evidence' AND v_now > t.due_date AND te.id IS NULL`, no branching. |
| 43 | `handle_new_user()` [trigger fn] | `auth/functions/handle_new_user.sql` | Go transaction | Provisions profile + notification_settings + user_ratings + point_wallet + trial_point_wallet on signup. Business logic moves; trigger mechanism (Supabase `auth.users`) is what's obsolete. Confirmed D2 provisioning path. |
| 44 | `notify_event(...)` | `notification/functions/notify_event.sql` | Go service/worker | Reads Vault secrets, calls `net.http_post`. External side effect. |
| 45 | `send_deadline_reminder(...)` | `notification/functions/send_deadline_reminder.sql` | Go service/worker | Idempotency log insert + `notify_event` dispatch. |
| 46 | `detect_judgement_deadline_warnings()` | `notification/functions/detect_judgement_deadline_warnings.sql` | Go service/worker | Scans + dispatches reminders. |
| 47 | `detect_evidence_deadline_warnings()` | `notification/functions/detect_evidence_deadline_warnings.sql` | Go service/worker | Same pattern as #46. |
| 48 | `detect_auto_confirm_deadline_warnings()` | `notification/functions/detect_auto_confirm_deadline_warnings.sql` | Go service/worker | Same pattern as #46; default OFF. |
| 49 | `reset_subscription_points(...)` | `point/functions/reset_subscription_points.sql` | Go transaction | Multiple business decisions: the idempotency check (`SELECT id FROM point_ledger WHERE reason='plan_renewal' AND description=v_description` — a fragile description-string idempotency key, flagged in §4.8), the wallet-not-found fallback (`INSERT ... IF NOT FOUND`), and the "record expiry of unused points" decision (`IF v_available > 0`) are Go branches. The atomic reads/writes (`SELECT ... FOR UPDATE`, the two possible `INSERT`s, the reset `UPDATE`) are store SQL statements Go issues once it has picked a branch. |
| 50 | `consume_points(...)` | `point/functions/consume_points.sql` | Go transaction | Same pattern as #22 minus the obligation loop: `IF v_balance < p_amount` / `IF v_locked < p_amount` → Go; `SELECT ... FOR UPDATE`, the `balance/locked` `UPDATE`, and the ledger `INSERT` → store SQL. |
| 51 | `lock_points(...)` | `point/functions/lock_points.sql` | Go transaction | `IF (v_balance - v_locked) < p_amount THEN RAISE EXCEPTION` (availability check) → Go; `SELECT ... FOR UPDATE`, `locked = locked + p_amount`, and the ledger `INSERT` are the irreducible store-SQL sequence. |
| 52 | `unlock_points(...)` | `point/functions/unlock_points.sql` | Go transaction | Same shape as #51/#20: `IF v_locked < p_amount` → Go; `SELECT ... FOR UPDATE` + `locked = locked - p_amount` + ledger `INSERT` → store SQL. |
| 53 | `handle_updated_at()` [trigger fn] | `common/functions/handle_updated_at.sql` | **DB invariant/helper** | Trivial `NEW.updated_at = NOW()`, no business logic, no atomicity concern. Kept as a DB trigger for the 21 housekeeping call sites (Appendix B); equally valid for the Go store to set `updated_at` explicitly on every `UPDATE` instead. The one function the refined rule explicitly carves out as DB-side — the sole DB invariant/helper in the tally. |
| 54 | `is_task_referee(task_uuid, user_uuid)` | `profile/functions/auth_helpers.sql` (L1) | Drop | RLS-only helper; tied to the broader RLS retirement, not today's dead-code list. |
| 55 | `is_task_referee_candidate(task_uuid, user_uuid)` | `profile/functions/auth_helpers.sql` (L19) | Drop | Same note as #54. |
| 56 | `is_task_tasker(task_uuid, user_uuid)` | `profile/functions/auth_helpers.sql` (L37) | Drop | Fully unreferenced (verify before drop, §10.C). |
| 57 | `close_task_if_all_judgements_confirmed()` [trigger fn] | `task/triggers/on_all_judgements_confirmed_close_task.sql` | Go transaction | The three-statement body (`SELECT trr.task_id`, `PERFORM ... FOR UPDATE` lock, `IF NOT EXISTS (...) THEN UPDATE tasks SET status='closed'`) collapses into one atomic statement: `UPDATE tasks SET status='closed' WHERE id=$1 AND status <> 'closed' AND NOT EXISTS (SELECT 1 FROM judgements j JOIN task_referee_requests trr ON j.id=trr.id WHERE trr.task_id=$1 AND j.is_confirmed=false)`. No separate lock step needed, no business branching left. See §4.7. |
| 58 | `create_task(...)` | `task/functions/create_task.sql` | Go transaction | Multi-step: validate inputs, validate open-requirements, insert task, create referee requests (locks points). |
| 59 | `update_task(...)` | `task/functions/update_task.sql` | Go transaction | Same multi-step pattern as #58, plus ownership + status-transition checks. |
| 60 | `delete_task(uuid)` | `task/functions/delete_task.sql` | Go transaction | `auth.uid()`-gated ownership + status check + single delete. |
| 61 | `validate_task_inputs(...)` | `task/functions/utils/validate_task_inputs.sql` | Go service/worker | Pure business-rule validation. |
| 62 | `create_task_referee_requests_from_json(...)` | `task/functions/utils/create_task_referee_requests_from_json.sql` | Go transaction | Multi-step: cost calc, trial-vs-regular point-source decision, loop insert + lock (calls `lock_trial_points`/`lock_points`, atomic SQL, #17/#51). |
| 63 | `validate_task_open_requirements(...)` | `task/functions/utils/validate_task_open_requirements.sql` | Go transaction | Business-rule validation: due-date minimum, point-balance sufficiency. |
| 64 | `prepare_monthly_payouts(...)` | `reward/functions/prepare_monthly_payouts.sql` | Go service/worker | Batch orchestration: last-day-of-month guard, exchange-rate lookup, Stripe Connect readiness check, payout row insert, notify. |
| 65 | `deduct_reward_for_payout(...)` | `reward/functions/deduct_reward_for_payout.sql` | Go transaction | Optimistic-concurrency single statement, no `FOR UPDATE` needed: `UPDATE reward_wallets SET balance=balance-p_amount WHERE user_id=$1 AND balance >= p_amount`; `IF NOT FOUND THEN RAISE EXCEPTION` is Go's zero-rows-affected handling, not a separate decision. Plus the ledger `INSERT`. |
| 66 | `grant_reward(...)` | `reward/functions/grant_reward.sql` | Go transaction | Single `INSERT ... ON CONFLICT (user_id) DO UPDATE SET balance = reward_wallets.balance + p_amount` upsert, no branching, plus the ledger `INSERT`. |
| 67 | `get_payout_topup_metrics(text)` | `reward/functions/get_payout_topup_metrics.sql` | Store query | Read-only, but the four `SELECT`s (active exchange rate, sum of wallet balances, month-to-date ledger earnings, singleton `payout_topup_config`) need a consistent snapshot across statements while payouts are being processed concurrently elsewhere — that consistency comes from one Go-owned (read) transaction, not a PL/pgSQL wrapper. The SQL dissolves into a plain store query set behind the same Go operator endpoint. |
| 68 | `check_account_deletable()` | `account/functions/check_account_deletable.sql` | Store query | `auth.uid()`-gated read-only precondition check. |

### Function tally (confirms §4.2)

| Disposition | Count | Of which changed by §4.6 resolutions |
|---|---:|---:|
| DB invariant/helper | 1 | 0 |
| Store query | 4 | 0 |
| Go transaction | 38 | 0 |
| Go service/worker | 21 | +1 (#38), −1 (#4), +1 (#8) net +1 |
| Drop | 4 | +1 (#4), −1 (#8) net 0 |
| **Total** | **68** | |

(Net effect of the 3 resolutions vs. the supplement's unmodified assignment:
DB invariant/helper 2→1, Drop 4→4 unchanged in count but different members
[`trigger_process_matching` leaves, `detect_and_handle_referee_timeouts`
enters], Go service/worker 20→21. Store query and Go transaction are
untouched by the resolutions. See §4.2/§4.6 for the full derivation.)

## Appendix B — Full trigger classification (36)

> 21 housekeeping (keep, DB-side) + 15 business (→ Go), from the
> supplement's §6 base table + the canonical baseline's §2.4 per-trigger
> evidence.

### B.1 Housekeeping triggers — keep (21)

All call `handle_updated_at` (Appendix A #53) and remain minimal database
housekeeping:

| Trigger | Table |
|---|---|
| `on_task_evidences_update_set_updated_at` | `task_evidences` |
| `on_judgement_threads_update_set_updated_at` | `judgement_threads` |
| `on_judgements_update_set_updated_at` | `judgements` |
| `on_matching_config_update_set_updated_at` | `matching_config` |
| `on_referee_available_time_slots_update_set_updated_at` | `referee_available_time_slots` |
| `on_referee_blocked_dates_update_set_updated_at` | `referee_blocked_dates` |
| `on_task_referee_requests_update_set_updated_at` | `task_referee_requests` |
| `on_user_fcm_tokens_update_set_updated_at` | `user_fcm_tokens` |
| `on_point_wallets_update_set_updated_at` | `point_wallets` |
| `on_profiles_update_set_updated_at` | `profiles` |
| `on_user_ratings_update_set_updated_at` | `user_ratings` |
| `on_reports_update_set_updated_at` | `reports` |
| `on_payout_topup_config_update_set_updated_at` | `payout_topup_config` |
| `on_reward_exchange_rates_update_set_updated_at` | `reward_exchange_rates` |
| `on_reward_payouts_update_set_updated_at` | `reward_payouts` |
| `on_reward_wallets_update_set_updated_at` | `reward_wallets` |
| `on_stripe_accounts_update_set_updated_at` | `stripe_accounts` |
| `on_user_subscriptions_update_set_updated_at` | `user_subscriptions` |
| `on_tasks_update_set_updated_at` | `tasks` |
| `on_trial_point_config_update_set_updated_at` | `trial_point_config` |
| `on_trial_point_wallets_update_set_updated_at` | `trial_point_wallets` |

### B.2 Business triggers — all dissolve into Go (15)

| # | trigger | file | function called (Appendix A #) | disposition | mechanism |
|---|---|---|---|---|---|
| 1 | `on_task_referee_requests_update_process_matching` | `matching/triggers/on_task_referee_requests_update_process_matching.sql` | `trigger_process_matching()` (#8) | → Go | Trigger dissolves; matching processing is invoked explicitly by the API/worker instead of trigger-fired (§4.6 resolution 3). |
| 2 | `on_task_referee_requests_insert_process_matching` | `matching/triggers/on_task_referee_requests_insert_process_matching.sql` | `trigger_process_matching()` (#8) | → Go | Same as row 1, second call site (insert). |
| 3 | `on_rating_histories_change_update_user_ratings` | `rating/triggers/on_rating_histories_change_update_user_ratings.sql` | `update_user_ratings()` (#24) | → Go | Trigger dissolves entirely (no `CREATE TRIGGER` remains); Go issues the two recompute `UPDATE ... FROM` statements in the same transaction as every Go-initiated `rating_histories` write. |
| 4 | `on_judgement_confirmed_notify` | `judgement/triggers/on_judgement_confirmed_notify.sql` | `notify_judgement_confirmed()` (#25) | → Go | Push-notification dispatch folds into the shared post-confirm orchestration, §4.7. |
| 5 | `on_judgement_confirmed_close_request` | `judgement/triggers/on_judgement_confirmed_close_request.sql` | `close_referee_request_on_confirmed()` (#26) | → Go | Trigger dissolves; Go issues the single PK-scoped `UPDATE task_referee_requests SET status='closed'` right after it writes `is_confirmed=true`, in the same transaction. |
| 6 | `on_evidence_timeout_settle` | `judgement/triggers/on_evidence_timeout_settle.sql` | `settle_evidence_timeout()` (#28) | → Go | Wallet settlement + close + notify fold into Go orchestration calling atomic SQL. |
| 7 | `on_judgements_timeout_score_referee` | `judgement/triggers/on_judgements_timeout_score_referee.sql` | `auto_score_timeout_referee()` (#6) | → Go | Negative-rating insert on review-timeout confirm; dedup with #29 per §4.6. |
| 8 | `on_judgements_status_changed` | `judgement/triggers/on_judgements_status_changed.sql` | `on_judgements_status_changed()` (#30) | → Go | Status-change → notification key mapping + dispatch. |
| 9 | `on_review_timeout_settle` | `judgement/triggers/on_review_timeout_settle.sql` | `settle_review_timeout()` (#29) | → Go | Unlock points + rating insert + close + notify fold into Go orchestration. |
| 10 | `on_judgement_confirmed` | `judgement/triggers/on_judgement_confirmed.sql` | `handle_judgement_confirmed()` (#27) | → Go | Push-notification dispatch on manual confirm; skips if auto-confirmed. |
| 11 | `on_task_evidences_insert_validate_due_date` | `evidence/triggers/on_task_evidences_insert_validate_due_date.sql` | `validate_evidence_due_date()` (#38) | → Go | Trigger dissolves; the pre-write due-date guard runs as Go validation in the evidence-create handler (§4.6 resolution 1). |
| 12 | `on_task_evidences_upserted_notify_referee` | `evidence/triggers/on_task_evidences_upserted_notify_referee.sql` | `on_task_evidences_upserted_notify_referee()` (#37) | → Go | Notification dispatch on evidence insert/update. |
| 13 | `on_task_evidences_update_validate_due_date` | `evidence/triggers/on_task_evidences_update_validate_due_date.sql` | `validate_evidence_due_date()` (#38) | → Go | Same function, second call site (evidence-resubmit handler); trigger dissolves. |
| 14 | `on_auth_user_created` | `auth/triggers/on_auth_user_created.sql` | `handle_new_user()` (#43) | → Go | Mechanism (Supabase `auth.users` trigger) deleted; provisioning logic ported to an explicit Go onboarding step, D2. |
| 15 | `on_all_judgements_confirmed_close_task` | `task/triggers/on_all_judgements_confirmed_close_task.sql` | `close_task_if_all_judgements_confirmed()` (#57) | → Go | Trigger dissolves into one conditional `UPDATE tasks ... WHERE NOT EXISTS (...)` statement issued by Go. |

**Notable result:** under the max-Go rule, **zero of the 15 business
triggers remain a literal Postgres `CREATE TRIGGER`.** Several (rows 3, 5,
15, and the two `validate_evidence_due_date` call sites at rows 11/13)
dissolve into a single Go-issued atomic SQL statement; the rest dissolve
into ordinary Go orchestration/notification logic. This matches the max-Go
crux — "triggers that enforce invariants across arbitrary write paths are
no longer load-bearing once Go is the only writer" — and creates the
orchestration implication documented at §4.7 (four call sites must each
explicitly re-run the cascade these triggers used to fire automatically).

### Trigger tally (confirms §4.4)

| Disposition | Count |
|---|---:|
| DB trigger — housekeeping (1 summary row = 21 triggers) | 21 |
| Go (business, all 15 dissolve) | 15 |
| **Total** | **36** |

## Appendix C — Full Flutter API-surface map

> Source: canonical §4 (`docs/development/go-vps-plans/phase0-parts/04-flutter-api-surface.md`).
> Every place `peppercheck_flutter/lib/` talks to Supabase directly:
> PostgREST table calls (`.from(`), Postgres RPC calls (`.rpc(`), and Edge
> Function invocations (`.functions.invoke`), plus the small set of Supabase
> Auth calls that don't fit those three kinds but are needed for full file
> coverage, plus the `presentation/`-layer clean-arch violations. The
> reconciliation of the raw grep counts against the verified counts (18
> `.from`, 21 `.rpc`, 7 `.invoke`) is covered in §2 above; this appendix is
> the full call-site detail.

### C.1 `from` (PostgREST) — 18 call sites

| kind | symbol/table | file:line | feature | maps to (Go endpoint) |
|---|---|---|---|---|
| from | `referee_available_time_slots` (select, eq user_id) | `peppercheck_flutter/lib/features/matching/data/matching_repository.dart:22` | matching | `GET /api/v1/matching/availability` |
| from | `referee_blocked_dates` (select, order) | `peppercheck_flutter/lib/features/matching/data/matching_repository.dart:76` | matching | `GET /api/v1/matching/blocked-dates` |
| from | `user_fcm_tokens` (upsert onConflict:token) | `peppercheck_flutter/lib/features/notification/data/notification_repository.dart:30` | notification | `POST /api/v1/notifications/fcm-tokens` |
| from | `user_fcm_tokens` (delete eq token) | `peppercheck_flutter/lib/features/notification/data/notification_repository.dart:49` | notification | `DELETE /api/v1/notifications/fcm-tokens/{token}` |
| from | `profiles` (select, eq id, single — `fetchProfile`) | `peppercheck_flutter/lib/features/profile/data/profile_repository.dart:24` | profile | `GET /api/v1/me` (design-doc-fixed) |
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
| from | `stripe_accounts` (select pm_brand/last4/exp, single) | `peppercheck_flutter/lib/features/billing/data/stripe_billing_repository.dart:41` | billing | Resolved by §3.1 Finding 3 — this file is confirmed dead code alongside `billing-setup`; not ported |

### C.2 `rpc` (Postgres RPC) — 21 call sites, 21 distinct functions

| kind | symbol/table | file:line | feature | maps to (Go endpoint) |
|---|---|---|---|---|
| rpc | `create_referee_available_time_slot` (generic `.rpc<String>(`) | `peppercheck_flutter/lib/features/matching/data/matching_repository.dart:43` | matching | `POST /api/v1/matching/availability` (Appendix A #5) |
| rpc | `update_referee_available_time_slot` | `peppercheck_flutter/lib/features/matching/data/matching_repository.dart:56` | matching | `PATCH /api/v1/matching/availability/{id}` (Appendix A #2) |
| rpc | `delete_referee_available_time_slot` | `peppercheck_flutter/lib/features/matching/data/matching_repository.dart:68` | matching | `DELETE /api/v1/matching/availability/{id}` (Appendix A #13) |
| rpc | `create_referee_blocked_date` (generic `.rpc<String>(`) | `peppercheck_flutter/lib/features/matching/data/matching_repository.dart:90` | matching | `POST /api/v1/matching/blocked-dates` (Appendix A #10) |
| rpc | `update_referee_blocked_date` | `peppercheck_flutter/lib/features/matching/data/matching_repository.dart:107` | matching | `PATCH /api/v1/matching/blocked-dates/{id}` (Appendix A #16) |
| rpc | `delete_referee_blocked_date` | `peppercheck_flutter/lib/features/matching/data/matching_repository.dart:119` | matching | `DELETE /api/v1/matching/blocked-dates/{id}` (Appendix A #15) |
| rpc | `cancel_referee_assignment` | `peppercheck_flutter/lib/features/matching/data/matching_repository.dart:123` | matching | `POST /api/v1/matching/assignments/{id}/cancel` (Appendix A #11) |
| rpc | `get_payment_summary` | `peppercheck_flutter/lib/features/payment_dashboard/data/payment_summary_repository.dart:18` | payment_dashboard | `GET /api/v1/payments/summary` (Appendix A #14) |
| rpc | `judge_evidence` | `peppercheck_flutter/lib/features/judgement/data/judgement_repository.dart:20` | judgement | `POST /api/v1/judgements/judge` (Appendix A #31) |
| rpc | `confirm_judgement_and_rate_referee` | `peppercheck_flutter/lib/features/judgement/data/judgement_repository.dart:40` | judgement | `POST /api/v1/judgements/{id}/confirm` (Appendix A #36; see §5.2 T7-2) |
| rpc | `confirm_review_timeout` | `peppercheck_flutter/lib/features/judgement/data/judgement_repository.dart:56` | judgement | `POST /api/v1/judgements/{id}/confirm-review-timeout` (Appendix A #33) |
| rpc | `submit_evidence` | `peppercheck_flutter/lib/features/evidence/data/evidence_repository.dart:94` | evidence | `POST /api/v1/evidence` (Appendix A #41) |
| rpc | `update_evidence` | `peppercheck_flutter/lib/features/evidence/data/evidence_repository.dart:128` | evidence | `PATCH /api/v1/evidence/{id}` (Appendix A #40) |
| rpc | `resubmit_evidence` | `peppercheck_flutter/lib/features/evidence/data/evidence_repository.dart:164` | evidence | `POST /api/v1/evidence/{id}/resubmit` (Appendix A #39) |
| rpc | `confirm_evidence_timeout` | `peppercheck_flutter/lib/features/evidence/data/evidence_repository.dart:182` | evidence | `POST /api/v1/evidence/confirm-timeout` (Appendix A #32) |
| rpc | `create_task` | `peppercheck_flutter/lib/features/task/data/task_repository.dart:32` | task | `POST /api/v1/tasks` (Appendix A #58) |
| rpc | `update_task` | `peppercheck_flutter/lib/features/task/data/task_repository.dart:56` | task | `PATCH /api/v1/tasks/{id}` (Appendix A #59) |
| rpc | `delete_task` | `peppercheck_flutter/lib/features/task/data/task_repository.dart:65` | task | `DELETE /api/v1/tasks/{id}` (Appendix A #60) |
| rpc | `get_active_referee_tasks` | `peppercheck_flutter/lib/features/task/data/task_repository.dart:155` | task | `GET /api/v1/tasks/active` (Appendix A #12) |
| rpc | `check_account_deletable` | `peppercheck_flutter/lib/features/account/data/account_repository.dart:17` | account | `GET /api/v1/account/deletable` (Appendix A #68; also called from the `delete-account` Edge Function) |
| rpc | `get_point_for_matching_strategy` | `peppercheck_flutter/lib/features/billing/data/billing_repository.dart:72` | billing (point) | TBD (feature phase) — Appendix A #9 makes this a **single Go constant** (all callers move to Go under the max-Go refinement; no Postgres copy retained); the value is served by the owning Go endpoint, not a standalone RPC |

### C.3 `invoke` (Edge Function) — 7 call sites, 6 distinct functions

| kind | symbol/table | file:line | feature | maps to (Go endpoint) |
|---|---|---|---|---|
| invoke | `generate-upload-url` | `peppercheck_flutter/lib/features/evidence/data/evidence_repository.dart:39` | evidence | `POST /api/v1/uploads/presign` (§3.3: Go endpoint, R2 presigned upload; shared with profile) |
| invoke | `generate-upload-url` | `peppercheck_flutter/lib/features/profile/data/profile_repository.dart:72` | profile | same as above — shared Edge Function, one Go endpoint |
| invoke | `delete-account` | `peppercheck_flutter/lib/features/account/data/account_repository.dart:27` | account | `POST /api/v1/account/delete` (§3.3: Go endpoint + worker, idempotent saga — also called from webapp; see §5.2 T7-3) |
| invoke | `payout-setup` | `peppercheck_flutter/lib/features/payout/data/stripe_payout_repository.dart:57` | payout | `POST /api/v1/payout/setup` (§3.3: Go endpoint, Stripe Connect onboarding) |
| invoke | `create-express-dashboard-link` | `peppercheck_flutter/lib/features/payout/data/stripe_payout_repository.dart:72` | payout | `POST /api/v1/payout/dashboard-link` (§3.3: Go endpoint, Stripe Connect passthrough) |
| invoke | `payout-request` | `peppercheck_flutter/lib/features/payout/data/stripe_payout_repository.dart:92` | payout | **Dead path — never reachable**: the calling `requestPayout()` has 0 callers and `PayoutAmountDialog` is never mounted. No Go endpoint needed; remove the dead code (§5.1, §10.F). |
| invoke | `billing-setup` | `peppercheck_flutter/lib/features/billing/data/stripe_billing_repository.dart:22` | billing | §3.3: **Drop — currently unused** (dead pre-IAP billing flow); do not port. Its only caller, `stripe_billing_repository.dart`, is dormant legacy code per that doc's disposition. |

### C.4 `auth` (Supabase Auth SDK, non-CRUD) — 5 call sites, 4 files

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

### C.5 `presentation/` clean-arch violations

`grep -rln "supabase\|Supabase" peppercheck_flutter/lib/features/*/presentation/`
returns **7 files** — 2 more than the program design doc's already-flagged
5 (evidence submission, judgement section, task-detail info, report menu
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

### C.6 Verification

```
$ comm -23 <(sort -u /tmp/pc-sbfiles.txt) <(grep -oE "peppercheck_flutter/lib/[^ :]+\.dart" 04-flutter-api-surface.md | sort -u)
(empty)
```

Empty output confirms all 24 Supabase-importing files are represented
somewhere in the source investigation (19 in the `from`/`rpc`/`invoke`
tables + `auth` table = 23 distinct data/auth files, plus `presentation/`
violation files already counted among those 23 where they overlap — every
file in the Supabase-importing set appears at least once).

### C.7 Concerns for Phase 0 sign-off

- The `.from(` Go-endpoint mappings above (`/api/v1/...`) are this
  investigation's coarse proposals, not confirmed design-doc routes — the
  design doc only fixes `/api/v1/me` explicitly. Treat every route in this
  section except `/api/v1/me` as a naming suggestion to revisit in the
  owning feature phase (Phase 3 profile/reports/notifications, Phase 4
  task/matching/evidence/judgement, Phase 5 billing/points/payout), not a
  locked contract.
- `stripe_billing_repository.dart:41` (`.from('stripe_accounts')` reading
  card-on-file info) — resolved by §3.1 Finding 3: confirmed dead code,
  deleted alongside `billing-setup`, not ported.
- `payout-request` (invoke) is a confirmed pre-existing bug — see §5.1;
  repeated here only because this table would otherwise imply it maps
  cleanly like its sibling payout calls.
- The `presentation/` violation count (7 files, 10 call sites) is larger than
  the 5 files the design doc names. All 10 are the same trivial
  `currentUser?.id` pattern, so the fix is mechanical and low-risk, but scope
  the fix-it task to all 7 files, not just the 5 originally flagged.
