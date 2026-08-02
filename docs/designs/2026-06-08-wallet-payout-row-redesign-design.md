# Wallet Payout Row Redesign

## Problem

The wallet screen's payout area has two problems that surfaced during the
first real production payout:

1. **Visual inconsistency.** The recent-payout and next-payout rows
   (i18n keys `dashboard.recentPayout` and `dashboard.nextPayout`) use a
   private `_PayoutRow` widget with `bodySmall` non-bold text, while
   neighbouring rows (`dashboard.availablePoints`,
   `dashboard.rewardBalance`, `dashboard.totalEarned`) use `_CardLabel` +
   `_CardValue` with `bodyMedium` bold values. The payout rows visually
   fade out next to the surrounding rows.

2. **Misleading status language.** When `reward_payouts.status='success'`,
   the recent-payout row reads as "the bank deposit completed", but
   `success` only means the Stripe Transfer (platform balance →
   connected account balance) completed. The actual bank deposit happens
   through Stripe's separate Payout schedule, ~3–5 business days later.
   Users see the success state on Day 0, then expect money in their bank
   that day; it doesn't arrive until Day 3–4.

The two problems share the same row and are best fixed in one design.

## Goals

- Match payout rows to the existing card visual rhythm (same typography
  as `dashboard.availablePoints` and the other top-of-card rows).
- Stop the UI from over-claiming completion before the bank deposit lands.
- Give users a single tap to reach the source of truth for bank deposit
  timing (Stripe Express Dashboard), which is already accurate and live.
- Keep failure surfacing clear and unambiguous.

## Non-goals

- Building an in-app view of Stripe Payout status. Express Dashboard
  already shows arrival dates, balance breakdown, and per-payout status —
  duplicating it in-app adds API surface, caching, and webhook handling
  for marginal benefit. Deferred until user feedback or scale justifies it.
- Changing the visibility gating of the payout section. The existing rules
  (`hasRecentPayoutToShow`, `hasRewardBalance`, `isPayoutSetupComplete`)
  are intentional and unchanged. See
  `2026-05-03-payout-card-gating-design.md`.
- Reworking the underlying `reward_payouts` schema or the success/failed
  status semantics. The mismatch is in presentation, not in data.

## Design

### Row layout

```
[send-icon]      <recent-payout-label>   <date>   <amount>   <details-cta>
[calendar-icon]  <next-payout-label>                          <date>
```

- Single-line, left-aligned icon + label, right-aligned data block.
- Label typography matches `_CardLabel` (`bodySmall`, textSecondary).
- Amount typography matches `_CardValue` (`bodyMedium`, bold, textPrimary).
- Date is shown in muted secondary colour adjacent to the amount.
- For the recent-payout row, the `dashboard.payoutDetailsCta` tap target
  sits at the row's right edge and is the only tappable region.
- The `_PayoutRow` widget is removed. The payout rows are rebuilt with
  `_CardLabel` and `_CardValue` (or a small composable that internally
  uses them), so future style tweaks propagate consistently.

### Label change

Relabel `dashboard.recentPayout` so the label describes the platform-side
Transfer step (what `success` actually marks) rather than the
bank-deposit-completed step (which happens 3–5 business days later
through Stripe's separate Payout schedule). The previous wording was a
short generic phrase that, when read together with the status text,
implied "recently deposited to bank". The new wording maps to "recent
payout processing" — focused on the action the platform performed, not
the end state. `dashboard.nextPayout` is unchanged.

This rename intentionally avoids alternative phrasings that would map to
"recently deposited to bank". The chosen wording stays one step removed
from the bank-deposit-completed state because `success` only marks the
Stripe Transfer, not the bank deposit.

### Status display

- **success / pending**: no status text in the row. Common case stays quiet.
- **failed**: append the `payoutStatusFailed` text inline at the end of
  the data block (preserves the existing failure-surfacing pattern; same
  i18n key).
- **skipped**: row is hidden entirely (existing behaviour, unchanged).

Failure colour treatment stays minimal — text only, no row-level red — to
avoid an over-loud failure state on what is normally a quiet summary row.
Existing push notification (`notification_payout_failed_referee`) already
handles the active alerting path.

### Details-CTA tap target

- Tap calls a new Supabase Edge Function `create-express-dashboard-link`.
- Function calls `stripe.accounts.createLoginLink(connectAccountId)` for
  the caller's connected account and returns the one-time URL.
- Flutter opens the URL with `launchUrl` in the system browser (not
  in-app webview). One-time Stripe login URLs and Stripe's session cookies
  behave more predictably in the system browser.
- The Edge Function uses the caller's `Authorization` header to resolve
  the user, then looks up `stripe_accounts.stripe_connect_account_id` for
  that user. It does NOT accept a `connect_account_id` from the client.
- Errors (no Connect account, Stripe API failure, network) show a
  snackbar with a brief message. No retry; user taps again.

### Why not a BottomSheet middleman

We considered a BottomSheet that explains the bank deposit timing and
contains a "go to Stripe Dashboard" action button. Rejected because:

- The only content would be (a) a static delay-explanation paragraph and
  (b) a Dashboard link. That's not enough content to justify a middle
  screen.
- Stripe Express Dashboard already shows the exact arrival date,
  broken-out pending/available balance, and payout history — strictly
  more accurate and richer than anything we'd hand-write.
- The label rename (toward wording that describes the platform-side step,
  not the bank-deposit-completed step) carries most of the disambiguation
  work the explanation paragraph was meant to do.
- A direct tap → external link matches the user's mental model of
  "external Stripe info" better than a sheet that opens a sheet.

### Why not a `?` icon next to the recent-payout label

Other rows (`dashboard.availablePoints`, `dashboard.rewardBalance`,
`dashboard.totalEarned`) use `HelpIconButton` to explain a *concept*. The
recent-payout row exposes *time-series data* with a per-row action, which
is a different category. A `?` next to a data row that also has a tap
action would confuse two different interaction patterns. The whole row
is the surface; the `dashboard.payoutDetailsCta` label is the
clearly-tappable target.

## Implementation outline

Implementation details and ordering belong in the plan, not the spec. At
a high level the work is:

- i18n: relabel `dashboard.recentPayout`, add `dashboard.payoutDetailsCta`
  for the details-CTA tap label.
- Flutter: remove `_PayoutRow`; rebuild recent-payout and next-payout
  rows with `_CardLabel` + `_CardValue`; wire the details-CTA tap to the
  new Edge Function and `launchUrl`.
- Supabase: add Edge Function `create-express-dashboard-link` that wraps
  `stripe.accounts.createLoginLink` with auth.

## Out of scope (tracked elsewhere)

- #407 — double-payout risk in `execute-pending-payouts`
- #408 — cross-month overlap in `prepare_monthly_payouts`
- In-app bank-deposit timing UI (would be a follow-up if Express
  Dashboard proves insufficient)
