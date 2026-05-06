# Operator Payout Top-Up Advisor

**Date:** 2026-05-06
**Status:** Draft
**Issue:** [#351 chore: design fund flow from IAP revenue to Stripe balance for Connect payouts](https://github.com/mkuri/peppercheck/issues/351)

## Context

Subscription revenue moved to IAP-only (#342). IAP revenue flows: Google Play → Google payout → operator's bank account (monthly). Referee payouts still use Stripe Connect Transfers, which require funds in the platform's Stripe balance.

The operator must therefore move funds: bank account → Stripe balance. In Japan, Stripe Top-up uses a VBAN (virtual bank account) destination and the actual transfer is initiated from the operator's bank — Stripe cannot auto-pull from a Japanese bank account. The transfer takes 1–7 business days to arrive.

Existing schedule:
- `prepare_monthly_payouts` cron runs on the last day of the month at 00:00 JST and inserts `pending` rows into `reward_payouts` for users with `payouts_enabled = true`.
- `execute-pending-payouts` runs every 30 minutes and transfers funds from the platform Stripe balance to connected accounts.

So the platform Stripe balance must be funded **before** month-end, with enough lead time to absorb the 1-week wire transfer delay.

### Constraints (current scale)

- Solo operator (CloveClove); pre-launch.
- Initial monthly payout volume expected: low (¥thousands to low ¥hundred-thousands range).
- Operator manages bank UI manually; full automation of bank → Stripe transfer is not feasible.

## Decision

Build an **operator-only Edge Function** (`operator-payout-topup-advisor`) that, when invoked, returns the recommended top-up amount and current state. The operator invokes it from an external task management tool around day 20 of each month, then manually executes a furikomi (bank transfer) to the Stripe VBAN by ~day 21.

**This is operator tooling, not user-facing.** It exposes financial summary data (Stripe balance, outstanding obligations) and is protected by a dedicated shared secret.

### Why pull-based over push-based

- Eliminates email/notification infrastructure (operator's existing task tool already handles reminders).
- Edge Function becomes stateless and idempotent — easy to test, no delivery failure handling.
- Operator decides when to invoke; no risk of overlapping reminders or stale notifications.

## Architecture

```
[operator's task tool]
        │ scheduled task on day 20
        │ curl -H "X-Operator-Secret: ..." ...
        ▼
[supabase/functions/operator-payout-topup-advisor]
        │
        ├──▶ Stripe SDK: balance.retrieve()
        │      (current platform JPY balance)
        │
        └──▶ Postgres (service_role):
               • SUM(reward_wallets.balance) × rate
               • SUM(reward_ledger.amount) × rate
                 WHERE reason ∈ ('review_completed', 'evidence_timeout',
                                 'manual_adjustment')
                   AND amount > 0
                   AND created_at >= date_trunc('month', now())
               • payout_topup_config.buffer_multiplier
        │
        ▼
[JSON response with recommendation]
```

### New: `payout_topup_config` table

Singleton config table for runtime-tunable parameters. Located alongside other reward-domain tables (precedent: `trial_point_config` lives inside `supabase/schemas/trial_point/tables/`).

- Table definition: `supabase/schemas/reward/tables/payout_topup_config.sql`
- RLS policies: `supabase/schemas/reward/policies/payout_topup_config_policies.sql`

```sql
CREATE TABLE public.payout_topup_config (
    id boolean PRIMARY KEY DEFAULT true CHECK (id = true),
    buffer_multiplier numeric NOT NULL DEFAULT 1.3
        CHECK (buffer_multiplier >= 1.0),
    updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.payout_topup_config (id) VALUES (true);
```

Follows the existing singleton pattern (`BOOLEAN PK DEFAULT true CHECK (id = true)`). No upper bound on `buffer_multiplier` — quarterly or less frequent top-up cadences may require multipliers of 3× or 4×.

RLS: no SELECT/INSERT/UPDATE/DELETE policies — only `service_role` (used by the Edge Function) can access. Authenticated client roles have no policy granting access, so they are blocked by default.

### New: `operator-payout-topup-advisor` Edge Function

Created via `supabase functions new operator-payout-topup-advisor`. Standard project structure: `index.ts`, `deno.json`, optional `index_test.ts`.

#### Request

```
POST /functions/v1/operator-payout-topup-advisor
Headers:
  apikey: <supabase publishable key>             # required by Supabase gateway
  Authorization: Bearer <supabase publishable key>  # required by Supabase gateway
  X-Operator-Secret: <OPERATOR_API_SECRET>       # ← actual auth check
  Content-Type: application/json

Body: {} (none required)
```

#### Authentication

The function verifies `X-Operator-Secret` against `Deno.env.get('OPERATOR_API_SECRET')` using a constant-time comparison. The Supabase gateway-level `apikey`/`Authorization` headers are required by Supabase's edge runtime but provide no real access control — the publishable key is, by design, public.

The secret is generated once via `openssl rand -hex 32` and registered with `supabase secrets set OPERATOR_API_SECRET=...`. It is stored in the operator's task management tool only; it is never committed to git or exposed in client code.

If the header is missing or mismatched, the function returns `401 Unauthorized` with no body.

#### Response

```json
{
  "as_of": "2026-05-20T09:00:00+09:00",
  "stripe_balance_jpy": 87500,
  "current_total_obligation_jpy": 23500,
  "month_to_date_earnings_jpy": 18000,
  "day_of_month": 20,
  "last_day_of_month": 31,
  "extrapolated_remaining_earnings_jpy": 9900,
  "projected_balance_at_month_end_jpy": 33400,
  "buffer_multiplier": 1.3,
  "recommended_balance_jpy": 43420,
  "recommended_topup_jpy": 0,
  "next_payout_run_at": "2026-05-31T15:00:00Z",
  "transfer_initiate_deadline": "2026-05-21",
  "notes": [
    "Recommended top-up considers buffer_multiplier=1.3.",
    "Deadline is 7 weekdays before the payout run — JP public holidays are NOT auto-detected. If Golden Week, Obon, year-end/new-year, or other multi-day holidays fall in this window, initiate earlier."
  ]
}
```

Field semantics:

| Field | Meaning |
|---|---|
| `stripe_balance_jpy` | Current platform balance in JPY from Stripe API |
| `current_total_obligation_jpy` | `SUM(reward_wallets.balance) × rate_per_point` (all users) |
| `month_to_date_earnings_jpy` | Positive `reward_ledger` entries this calendar month, in JPY |
| `extrapolated_remaining_earnings_jpy` | `month_to_date_earnings × (L - D) / D` where L is the last day of the current month |
| `projected_balance_at_month_end_jpy` | `current_total_obligation + extrapolated_remaining_earnings` |
| `recommended_balance_jpy` | `projected × buffer_multiplier` |
| `recommended_topup_jpy` | `max(0, recommended_balance - stripe_balance)` |
| `transfer_initiate_deadline` | `next_payout_run_at` minus 7 **business days** (Mon–Fri, weekends only — JP public holidays not auto-detected), formatted as ISO date |

If `D >= L` (last day of month), `extrapolated_remaining_earnings_jpy` = 0 (clamp to non-negative).

If there is no active `reward_exchange_rates` row for `JPY`, return `503 Service Unavailable` with a clear error.

## Calculation Logic

```
D = current day of the month (1..31)
rate = SELECT rate_per_point FROM reward_exchange_rates WHERE currency='JPY' AND active=true

current_total_obligation_jpy =
  SUM(reward_wallets.balance) * rate

month_to_date_earnings_jpy =
  SUM(reward_ledger.amount) * rate
  WHERE reason IN ('review_completed', 'evidence_timeout', 'manual_adjustment')
    AND amount > 0
    AND created_at >= date_trunc('month', now() AT TIME ZONE 'Asia/Tokyo')

L = last day of the current month (28, 29, 30, or 31)

extrapolated_remaining_earnings_jpy =
  month_to_date_earnings_jpy * (L - D) / D     -- 0 when D >= L

projected_balance_at_month_end_jpy =
  current_total_obligation_jpy + extrapolated_remaining_earnings_jpy

recommended_balance_jpy =
  projected_balance_at_month_end_jpy * buffer_multiplier

recommended_topup_jpy =
  max(0, recommended_balance_jpy - stripe_balance_jpy)
```

### Why this formula

- **Baseline = current total balance** — already reflects carry-over from prior unpaid months (e.g., users without Connect set up); does not need to be re-projected.
- **Project only the future** — `(L - D) / D` extrapolates *additional* earnings expected from now to month-end at the current daily pace. The carry-over portion is not extrapolated. `L` adapts to the actual month length so February (28/29 days) and 31-day months don't introduce systematic bias.
- **Use `reward_ledger`, not wallet diffs** — wallet balance changes confound earning, payouts, and adjustments. Filtering ledger entries by positive earning reasons gives a clean rate.
- **Buffer multiplier** absorbs linear-projection noise (back-loaded months, sudden Connect activations of dormant balances). 1.3 is the default; can be tuned in `payout_topup_config`.

### Sanity check

Assume a 30-day month, `rate=50 JPY/pt`, carry-over balance = 400 JPY (8 pts), monthly earning ~3000 JPY (60 pts) at steady pace. So daily earnings ≈ 100 JPY, current-balance = carry-over + MtD earnings.

| D | MtD earned | Extrapolated remaining `(L-D)/D` | Projected end | × 1.3 |
|---|---|---|---|---|
| 1  | 100  | 100 × 29/1 = 2900 | (400+100) + 2900 = 3400 | 4420 |
| 15 | 1500 | 1500 × 15/15 = 1500 | (400+1500) + 1500 = 3400 | 4420 |
| 30 | 3000 | 3000 × 0/30 = 0 | (400+3000) + 0 = 3400 | 4420 |

Projection is internally consistent across the month under steady-state earning.

## Operational Workflow

1. Operator's external task management tool fires a recurring task on day 20 of each month at 09:00 JST.
2. The task invokes the Edge Function with `X-Operator-Secret`.
3. The response shows `recommended_topup_jpy` and `transfer_initiate_deadline`.
4. If `recommended_topup_jpy > 0`, the operator initiates a furikomi from their bank to the Stripe VBAN for that amount (rounded to a clean figure if desired).
5. The transfer arrives in the platform Stripe balance within 1–7 business days.
6. On the last day of the month, `prepare_monthly_payouts` and `execute-pending-payouts` run as scheduled.

If the operator misses a month, the buffer (defaulting to 30% over projected demand) provides a safety margin. The `recommended_topup_jpy` for the following month will naturally be larger to compensate.

### Deadline calculation

`transfer_initiate_deadline` is computed in TypeScript inside the Edge Function:

```ts
function subtractBusinessDays(date: Date, days: number): Date {
  const d = new Date(date);
  let remaining = days;
  while (remaining > 0) {
    d.setDate(d.getDate() - 1);
    const dow = d.getDay();  // 0 = Sun, 6 = Sat
    if (dow !== 0 && dow !== 6) remaining--;
  }
  return d;
}

const transferInitiateDeadline = subtractBusinessDays(nextPayoutRunAt, 7);
```

Returns the date 7 weekdays before `next_payout_run_at`. **Japanese public holidays are not detected.** During Golden Week, Obon, year-end/new-year, or other multi-day holiday clusters, the operator should initiate the transfer earlier than the displayed deadline. The static reminder in `notes` calls this out on every response.

## Out of Scope

- Auto top-up (Stripe pulling from bank automatically) — not supported for Japanese accounts.
- Email / push notifications — handled by the operator's existing task tool.
- Multi-currency support — JPY only for now.
- Slack/Discord webhook delivery of the recommendation — operator's task tool can render the JSON.
- A web dashboard for the operator — JSON response is sufficient at current scale.
- Historical recommendation tracking — each invocation is independent; no audit trail beyond Edge Function logs.
- Automatic creation of a `Top-up` object via Stripe API — Japan VBAN flow does not benefit from this; the actual fund movement is the bank-side furikomi.

## Future Considerations

- **Frequency reduction**: As payout volume grows, switching to bimonthly or quarterly top-ups reduces bank fees. The advisor formula is already date-agnostic — only the operator's task tool cadence changes.
- **Auto-tuning `buffer_multiplier`**: After several months of operation, observed (actual / projected) ratios can inform a data-driven multiplier.
- **Low balance alert**: A separate cron-driven Edge Function could push a warning to a notification channel if `stripe_balance_jpy` drops below `current_total_obligation_jpy × 0.5` between top-up cycles.
- **Stripe Top-up object integration**: If Japan ever supports auto-debit, the same advisor logic could pivot to automatically issuing top-ups via Stripe API.

## Testing

- Edge Function: unit test with mocked `Stripe.balance.retrieve()` and a stubbed Supabase client. Cover:
  - Missing/incorrect `X-Operator-Secret` → 401
  - Missing `OPERATOR_API_SECRET` env → 500
  - Empty wallets and zero earnings → recommended_topup = 0, no errors
  - Steady-state scenario matching the sanity-check table above
  - `D >= L` clamps `extrapolated_remaining_earnings_jpy` to 0
  - `subtractBusinessDays`: weekday inputs, weekend inputs, month-boundary crossings, deadline computed across multiple weekends (e.g. last day of month falls on a Sunday)
- DB: pgTAP test (`supabase/tests/database/`) for `payout_topup_config` constraints — singleton enforcement (second insert fails) and `buffer_multiplier >= 1.0` rejection.
