# Phase 0 — Freeze & Baseline (Spec)

> Status: **Phase spec** for Phase 0 of the Supabase → Go API + VPS refactor.
> Parent program strategy:
> `docs/superpowers/specs/2026-07-22-supabase-to-go-vps-refactor-design.md`.
> This spec defines *what Phase 0 produces and how*; the substantive output is a
> separate **Phase 0 baseline** document filled in during implementation.
>
> Last updated: 2026-07-22.

---

## 1. Purpose

Phase 0 is **Freeze & baseline**: an investigation-and-decision phase, not a
coding phase. Per the program roadmap (§22), Phase 0 is "Done" when:

> Every integration has an owner/disposition; identity + subscription decisions
> accepted.

The goal is to remove uncertainty before Phase 1 (Foundation) starts: know every
Supabase/external dependency and its target, know which DB logic moves vs stays,
know the launch-blockers, and lock the decisions that gate downstream phases —
while explicitly deferring decisions that are not yet needed.

## 2. Scoping decisions (agreed in brainstorming, 2026-07-22)

| Axis | Decision | Consequence |
|------|----------|-------------|
| **Depth** | **Hybrid.** Inventory every integration down to owner/disposition (= the Done bar); classify the 68 functions / 15 business triggers / 10 cron only to the coarse **move-to-Go / stay-in-Postgres / delete** level. | Per-function detailed design is deferred to each feature's own phase spec. Phase 0 does not over-specify. |
| **Decisions** | **Resolve Phase-0 blockers only.** Formally accept the already-made identity (D2) and subscription (D4) decisions; verify RevenueCat webhook cost. Infra/ops decisions (RPO/RTO, VPS provider/region/size, staging co-location, monitoring provider, B2 retention, domains/DNS) are recorded as **open decisions with a decide-by phase**, not resolved now. | Local Docker Compose is the primary dev environment (program §19), so infra provider choices are not needed until Phase 7 (Staging). YAGNI. |
| **Tests** | **Behavior catalog only.** Document expected behavior, invariants, and edge cases for the high-risk flows as acceptance specs. | No executable characterization tests are written against the current Supabase system — it is being deleted (big-bang, fresh-start; program D5/D9). Executable tests are written in each Go feature phase per program §24. |

## 3. Deliverable

A single **Phase 0 baseline** document
(`docs/superpowers/specs/2026-07-22-phase0-baseline.md`, produced during
implementation), with these sections. A single source of truth is preferred over
split files for a solo operator.

1. **Dependency inventory** (program §16). Table: each integration
   (`.from` tables, RPCs, edge functions, DB functions, triggers, cron, RLS,
   auth, Stripe Connect, Google Play RTDN, R2, FCM) → used-by feature ·
   direct-client-call? · Go replacement · data/config conversion · temporary
   coexistence · disposition.
2. **DB logic classification** (program §13). The 68 functions / 15 business
   triggers / 10 cron each tagged with one of the six categories
   (integrity/atomicity · query/set · business orchestration · authorization ·
   external side effect · obsolete Supabase support) → coarse
   move-to-Go / stay-in-Postgres / delete. The 21 `set_updated_at` housekeeping
   triggers are noted as stay-in-DB en masse.
3. **Launch-blocker register.** The `payout-request` orphan
   (`stripe_payout_repository.dart:93` calls a non-existent edge function) plus
   any blockers found during the sweep. Each: evidence · proposed fix · owning
   phase.
4. **Flutter API-surface map.** Reconcile the RPC count (measured 19 vs reviewer
   21); enumerate every `.from` / `.rpc` / `.functions.invoke` call site → the
   Go endpoint it maps to; list the `presentation/` clean-arch violations that
   call the Supabase SDK directly.
5. **Critical journey + behavior catalog.** High-risk flows — auth (Google +
   Apple), point/trial-point ledger, payout, judgement state machine, account
   deletion — with expected behavior, invariants, and edge cases as acceptance
   specs.
6. **Reduced web route table** (program §9). keep / remove / redirect.
7. **Unused code/schema drop candidates.** The dormant Stripe user-billing set
   (`billing-setup`, `stripe_billing_repository`, `BillingSetupSection`,
   `billing_controller`, related `domain/` billing types) confirmed not mounted,
   plus any provably-unused schema found while inventorying.
8. **Decisions ledger.** (a) *Accepted:* identity model (D2), subscription /
   RevenueCat (D4), RevenueCat cost-verification result. (b) *Open, with
   decide-by phase:* RPO/RTO, VPS provider/region/size, staging+production
   co-location, monitoring/alert provider, B2 retention count + encryption,
   domains/DNS, concrete dates + code freeze.
9. **Seed / tester-data policy.** Reference/seed data subset; whether any tester
   data is kept (default: recreate via login per D9).

## 4. Execution approach

- **Fan-out investigation.** The sweep spans ~24 Flutter files, ~65 schema
  files, 12 edge functions, and the webapp. Read-only investigation sub-agents
  gather raw facts per area in parallel; the results are synthesized into the
  baseline. (Sub-agents are instructed not to read `.env*`, `*.jks`,
  `*.keystore`, `key.properties`, or any gitignored secret-bearing file, and to
  review only files tracked in git.)
- **Draft → review.** A complete draft baseline is produced, then reviewed with
  the operator. Classification calls and blocker fixes are confirmed before the
  baseline is finalized.
- **Blocker decisions with the operator.** Items in §5 that need the operator's
  judgement or an external fact are resolved during the review, not assumed.

## 5. Phase-0 blocker items to resolve now

- **`payout-request` orphan.** Confirm no edge function exists; define the fix as
  a Go payout endpoint and assign it to Phase 5 (Financial), noting it as a
  launch-blocker.
- **RPC count reconciliation.** Resolve 19 vs 21 by enumerating call sites.
- **RevenueCat webhook cost.** Verify whether a durable webhook requires a paid
  (Pro) tier for this project; record the result so D4 stands on a confirmed cost
  basis.
- **Identity (D2) & subscription (D4) acceptance.** Present both for explicit
  operator sign-off.

## 6. Out of scope for Phase 0

- Writing any Go/Flutter/pgTAP implementation code.
- Executable characterization tests against the current Supabase system.
- Detailed per-function move/stay design (deferred to feature phase specs).
- Selecting concrete infra providers/sizes or setting release dates (open
  decisions, deferred to their owning phase).

## 7. Done checklist

- [ ] Every external integration has an owner/disposition (§16 table complete).
- [ ] 68 functions / 15 business triggers / 10 cron classified
      move / stay / delete.
- [ ] All launch-blockers identified (incl. `payout-request` fix plan), each
      assigned an owning phase.
- [ ] High-risk journey behavior catalog complete.
- [ ] Web routes finalized as keep / remove / redirect.
- [ ] Unused-code drop candidates concretely listed.
- [ ] Identity (D2) and subscription (D4) decisions accepted; RevenueCat cost
      verified.
- [ ] Open decisions recorded with a decide-by phase.
