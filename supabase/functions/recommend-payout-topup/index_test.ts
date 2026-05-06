import { assertEquals } from '@std/assert'
import { subtractBusinessDays } from './index.ts'
import { verifyOperatorSecret } from './index.ts'
import { computeRecommendation } from './index.ts'

Deno.test('subtractBusinessDays: subtracts 7 weekdays from a Sunday', () => {
  // 2026-05-31 is a Sunday. 7 weekdays back = 2026-05-21 (Thursday).
  const from = new Date('2026-05-31T15:00:00Z')
  const result = subtractBusinessDays(from, 7)
  assertEquals(result.toISOString().slice(0, 10), '2026-05-21')
})

Deno.test('subtractBusinessDays: zero days returns same date', () => {
  const from = new Date('2026-05-15T00:00:00Z')
  const result = subtractBusinessDays(from, 0)
  assertEquals(result.toISOString().slice(0, 10), '2026-05-15')
})

Deno.test('subtractBusinessDays: skips a single weekend', () => {
  // 2026-05-15 is Friday. Subtract 1 business day → Thursday 2026-05-14.
  const from = new Date('2026-05-15T00:00:00Z')
  const result = subtractBusinessDays(from, 1)
  assertEquals(result.toISOString().slice(0, 10), '2026-05-14')
})

Deno.test('subtractBusinessDays: crosses a month boundary', () => {
  // 2026-06-02 is Tuesday. Subtract 5 business days:
  //   Tue 6/2 → Mon 6/1 → Fri 5/29 → Thu 5/28 → Wed 5/27 → Tue 5/26.
  const from = new Date('2026-06-02T00:00:00Z')
  const result = subtractBusinessDays(from, 5)
  assertEquals(result.toISOString().slice(0, 10), '2026-05-26')
})

Deno.test('verifyOperatorSecret: returns true when header matches env', () => {
  Deno.env.set('OPERATOR_API_SECRET', 'matching-secret')
  const req = new Request('http://localhost/', {
    method: 'POST',
    headers: { 'X-Operator-Secret': 'matching-secret' },
  })
  assertEquals(verifyOperatorSecret(req), true)
})

Deno.test('verifyOperatorSecret: returns false when header is missing', () => {
  Deno.env.set('OPERATOR_API_SECRET', 'matching-secret')
  const req = new Request('http://localhost/', { method: 'POST' })
  assertEquals(verifyOperatorSecret(req), false)
})

Deno.test('verifyOperatorSecret: returns false when header mismatches', () => {
  Deno.env.set('OPERATOR_API_SECRET', 'matching-secret')
  const req = new Request('http://localhost/', {
    method: 'POST',
    headers: { 'X-Operator-Secret': 'wrong-secret' },
  })
  assertEquals(verifyOperatorSecret(req), false)
})

Deno.test('verifyOperatorSecret: returns false when env is unset', () => {
  Deno.env.delete('OPERATOR_API_SECRET')
  const req = new Request('http://localhost/', {
    method: 'POST',
    headers: { 'X-Operator-Secret': 'anything' },
  })
  assertEquals(verifyOperatorSecret(req), false)
})

Deno.test('computeRecommendation: matches sanity check at D=1', () => {
  // Steady-state: 30-day month, rate=50, carry=400, monthly earnings 3000.
  // D=1, MtD = 100, current_balance = 500.
  const r = computeRecommendation({
    stripeBalanceJpy: 0,
    totalObligationJpy: 500,
    monthToDateEarningsJpy: 100,
    bufferMultiplier: 1.3,
    dayOfMonth: 1,
    lastDayOfMonth: 30,
  })
  assertEquals(r.extrapolatedRemainingEarningsJpy, 2900)
  assertEquals(r.projectedBalanceAtMonthEndJpy, 3400)
  assertEquals(r.recommendedBalanceJpy, 4420)
  assertEquals(r.recommendedTopupJpy, 4420)
})

Deno.test('computeRecommendation: matches sanity check at D=15', () => {
  const r = computeRecommendation({
    stripeBalanceJpy: 0,
    totalObligationJpy: 1900,
    monthToDateEarningsJpy: 1500,
    bufferMultiplier: 1.3,
    dayOfMonth: 15,
    lastDayOfMonth: 30,
  })
  assertEquals(r.extrapolatedRemainingEarningsJpy, 1500)
  assertEquals(r.projectedBalanceAtMonthEndJpy, 3400)
  assertEquals(r.recommendedBalanceJpy, 4420)
  assertEquals(r.recommendedTopupJpy, 4420)
})

Deno.test('computeRecommendation: clamps extrapolation when D >= L', () => {
  const r = computeRecommendation({
    stripeBalanceJpy: 0,
    totalObligationJpy: 3400,
    monthToDateEarningsJpy: 3000,
    bufferMultiplier: 1.3,
    dayOfMonth: 31,
    lastDayOfMonth: 30, // late edge case; D > L
  })
  assertEquals(r.extrapolatedRemainingEarningsJpy, 0)
  assertEquals(r.projectedBalanceAtMonthEndJpy, 3400)
})

Deno.test('computeRecommendation: recommended_topup is never negative', () => {
  const r = computeRecommendation({
    stripeBalanceJpy: 100000,
    totalObligationJpy: 1900,
    monthToDateEarningsJpy: 1500,
    bufferMultiplier: 1.3,
    dayOfMonth: 15,
    lastDayOfMonth: 30,
  })
  assertEquals(r.recommendedTopupJpy, 0)
})

Deno.test('computeRecommendation: matches the spec example (May 20, 31-day month)', () => {
  const r = computeRecommendation({
    stripeBalanceJpy: 87500,
    totalObligationJpy: 23500,
    monthToDateEarningsJpy: 18000,
    bufferMultiplier: 1.3,
    dayOfMonth: 20,
    lastDayOfMonth: 31,
  })
  assertEquals(r.extrapolatedRemainingEarningsJpy, 9900)
  assertEquals(r.projectedBalanceAtMonthEndJpy, 33400)
  assertEquals(r.recommendedBalanceJpy, 43420)
  assertEquals(r.recommendedTopupJpy, 0)
})

import { handler } from './index.ts'
import type { SupabaseClient } from '@supabase/supabase-js'
import type Stripe from 'stripe'

function makeMockSupabase(metrics: Record<string, unknown>): SupabaseClient {
  return {
    rpc: (_fn: string, _args: unknown) => Promise.resolve({ data: metrics, error: null }),
  } as unknown as SupabaseClient
}

function makeMockStripe(balanceJpy: number): Stripe {
  return {
    balance: {
      retrieve: () =>
        Promise.resolve({
          available: [{ amount: balanceJpy, currency: 'jpy' }],
          pending: [],
        }),
    },
  } as unknown as Stripe
}

const validMetrics = {
  currency: 'JPY',
  rate_per_point: 50,
  total_obligation_jpy: 23500,
  month_to_date_earnings_jpy: 18000,
  buffer_multiplier: 1.3,
}

Deno.test('handler: returns 401 when X-Operator-Secret is missing', async () => {
  Deno.env.set('OPERATOR_API_SECRET', 'shh')
  const req = new Request('http://localhost/', { method: 'POST' })
  const res = await handler(req, {
    supabaseAdmin: makeMockSupabase(validMetrics),
    stripe: makeMockStripe(87500),
    now: new Date('2026-05-20T00:00:00+09:00'),
  })
  assertEquals(res.status, 401)
})

Deno.test('handler: returns 401 when X-Operator-Secret mismatches', async () => {
  Deno.env.set('OPERATOR_API_SECRET', 'shh')
  const req = new Request('http://localhost/', {
    method: 'POST',
    headers: { 'X-Operator-Secret': 'nope' },
  })
  const res = await handler(req, {
    supabaseAdmin: makeMockSupabase(validMetrics),
    stripe: makeMockStripe(87500),
    now: new Date('2026-05-20T00:00:00+09:00'),
  })
  assertEquals(res.status, 401)
})

Deno.test('handler: returns 200 with full JSON payload on valid request', async () => {
  Deno.env.set('OPERATOR_API_SECRET', 'shh')
  const req = new Request('http://localhost/', {
    method: 'POST',
    headers: { 'X-Operator-Secret': 'shh' },
  })
  const res = await handler(req, {
    supabaseAdmin: makeMockSupabase(validMetrics),
    stripe: makeMockStripe(87500),
    now: new Date('2026-05-20T00:00:00+09:00'),
  })
  assertEquals(res.status, 200)
  const body = await res.json()
  assertEquals(body.stripe_balance_jpy, 87500)
  assertEquals(body.current_total_obligation_jpy, 23500)
  assertEquals(body.month_to_date_earnings_jpy, 18000)
  assertEquals(body.day_of_month, 20)
  assertEquals(body.last_day_of_month, 31)
  assertEquals(body.extrapolated_remaining_earnings_jpy, 9900)
  assertEquals(body.projected_balance_at_month_end_jpy, 33400)
  assertEquals(body.buffer_multiplier, 1.3)
  assertEquals(body.recommended_balance_jpy, 43420)
  assertEquals(body.recommended_topup_jpy, 0)
})

Deno.test('handler: returns 503 when SQL helper raises (no exchange rate)', async () => {
  Deno.env.set('OPERATOR_API_SECRET', 'shh')
  const req = new Request('http://localhost/', {
    method: 'POST',
    headers: { 'X-Operator-Secret': 'shh' },
  })
  const errorSupabase = {
    rpc: () =>
      Promise.resolve({
        data: null,
        error: { message: 'No active exchange rate for currency: JPY' },
      }),
  } as unknown as SupabaseClient
  const res = await handler(req, {
    supabaseAdmin: errorSupabase,
    stripe: makeMockStripe(87500),
    now: new Date('2026-05-20T00:00:00+09:00'),
  })
  assertEquals(res.status, 503)
})
