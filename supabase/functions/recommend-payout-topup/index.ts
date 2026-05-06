import 'jsr:@supabase/functions-js@^2/edge-runtime.d.ts'
import { createClient, SupabaseClient } from '@supabase/supabase-js'
import Stripe from 'stripe'

/**
 * Subtract N business days (Mon–Fri) from a date.
 * Note: Japanese public holidays are NOT detected.
 */
export function subtractBusinessDays(date: Date, days: number): Date {
  const d = new Date(date)
  let remaining = days
  while (remaining > 0) {
    d.setUTCDate(d.getUTCDate() - 1)
    const dow = d.getUTCDay()
    if (dow !== 0 && dow !== 6) {
      remaining--
    }
  }
  return d
}

/**
 * Constant-time check of the X-Operator-Secret header against OPERATOR_API_SECRET env.
 */
export function verifyOperatorSecret(req: Request): boolean {
  const expected = Deno.env.get('OPERATOR_API_SECRET') ?? ''
  const provided = req.headers.get('X-Operator-Secret') ?? ''
  if (expected.length === 0 || provided.length === 0) return false
  if (expected.length !== provided.length) return false
  let diff = 0
  for (let i = 0; i < expected.length; i++) {
    diff |= expected.charCodeAt(i) ^ provided.charCodeAt(i)
  }
  return diff === 0
}

export interface RecommendationInput {
  stripeBalanceJpy: number
  totalObligationJpy: number
  monthToDateEarningsJpy: number
  bufferMultiplier: number
  dayOfMonth: number
  lastDayOfMonth: number
}

export interface Recommendation {
  extrapolatedRemainingEarningsJpy: number
  projectedBalanceAtMonthEndJpy: number
  recommendedBalanceJpy: number
  recommendedTopupJpy: number
}

export function computeRecommendation(input: RecommendationInput): Recommendation {
  const { dayOfMonth: D, lastDayOfMonth: L } = input
  const remainingFactor = D >= L ? 0 : (L - D) / D
  const extrapolatedRemainingEarningsJpy = Math.round(
    input.monthToDateEarningsJpy * remainingFactor,
  )
  const projectedBalanceAtMonthEndJpy = input.totalObligationJpy + extrapolatedRemainingEarningsJpy
  const recommendedBalanceJpy = Math.round(
    projectedBalanceAtMonthEndJpy * input.bufferMultiplier,
  )
  const recommendedTopupJpy = Math.max(
    0,
    recommendedBalanceJpy - input.stripeBalanceJpy,
  )
  return {
    extrapolatedRemainingEarningsJpy,
    projectedBalanceAtMonthEndJpy,
    recommendedBalanceJpy,
    recommendedTopupJpy,
  }
}

interface PayoutTopupMetrics {
  currency: string
  rate_per_point: number
  total_obligation_jpy: number | string
  month_to_date_earnings_jpy: number | string
  buffer_multiplier: number | string
}

interface JstDateParts {
  dayOfMonth: number
  lastDayOfMonth: number
  nextPayoutRunAt: Date
}

function jstDateParts(now: Date): JstDateParts {
  // Convert "now" to JST calendar fields
  const jstFmt = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Tokyo',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  })
  const parts = jstFmt.formatToParts(now)
  const year = parseInt(parts.find((p) => p.type === 'year')!.value, 10)
  const month = parseInt(parts.find((p) => p.type === 'month')!.value, 10)
  const day = parseInt(parts.find((p) => p.type === 'day')!.value, 10)

  // Last day of current JST month
  const lastDayOfMonth = new Date(Date.UTC(year, month, 0)).getUTCDate()

  // prepare_monthly_payouts cron: '0 15 28-31 * *' → only fires on actual last day of month.
  // The instant in UTC is 15:00 UTC of last_day_of_month, which equals 00:00 JST of last_day+1.
  const nextPayoutRunAt = new Date(Date.UTC(year, month - 1, lastDayOfMonth, 15, 0, 0))

  return { dayOfMonth: day, lastDayOfMonth, nextPayoutRunAt }
}

export interface Dependencies {
  supabaseAdmin?: SupabaseClient
  stripe?: Stripe
  now?: Date
}

export async function handler(req: Request, deps: Dependencies = {}): Promise<Response> {
  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 })
  }

  if (!verifyOperatorSecret(req)) {
    return new Response('Unauthorized', { status: 401 })
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  const stripeKey = Deno.env.get('STRIPE_SECRET_KEY') ?? ''

  const supabaseAdmin = deps.supabaseAdmin ?? createClient(supabaseUrl, serviceRoleKey)
  const stripe = deps.stripe ?? new Stripe(stripeKey, { apiVersion: '2025-11-17.clover' })
  const now = deps.now ?? new Date()

  const { data, error: rpcError } = await supabaseAdmin.rpc(
    'get_payout_topup_metrics',
    { p_currency: 'JPY' },
  )
  const metrics = data as PayoutTopupMetrics | null

  if (rpcError || !metrics) {
    return new Response(
      JSON.stringify({ error: rpcError?.message ?? 'metrics unavailable' }),
      { status: 503, headers: { 'Content-Type': 'application/json' } },
    )
  }

  const bufferMultiplier = Number(metrics.buffer_multiplier)
  if (!Number.isFinite(bufferMultiplier) || bufferMultiplier <= 0) {
    return new Response(
      JSON.stringify({ error: 'buffer_multiplier missing or invalid in metrics' }),
      { status: 503, headers: { 'Content-Type': 'application/json' } },
    )
  }

  const balance = await stripe.balance.retrieve()
  const jpyAvailable = balance.available.find((b) => b.currency === 'jpy')
  const stripeBalanceJpy = jpyAvailable?.amount ?? 0

  const { dayOfMonth, lastDayOfMonth, nextPayoutRunAt } = jstDateParts(now)

  const recommendation = computeRecommendation({
    stripeBalanceJpy,
    totalObligationJpy: Number(metrics.total_obligation_jpy ?? 0),
    monthToDateEarningsJpy: Number(metrics.month_to_date_earnings_jpy ?? 0),
    bufferMultiplier,
    dayOfMonth,
    lastDayOfMonth,
  })

  const transferInitiateDeadline = subtractBusinessDays(nextPayoutRunAt, 7)

  const body = {
    as_of: now.toISOString(),
    stripe_balance_jpy: stripeBalanceJpy,
    current_total_obligation_jpy: Number(metrics.total_obligation_jpy ?? 0),
    month_to_date_earnings_jpy: Number(metrics.month_to_date_earnings_jpy ?? 0),
    day_of_month: dayOfMonth,
    last_day_of_month: lastDayOfMonth,
    extrapolated_remaining_earnings_jpy: recommendation.extrapolatedRemainingEarningsJpy,
    projected_balance_at_month_end_jpy: recommendation.projectedBalanceAtMonthEndJpy,
    buffer_multiplier: bufferMultiplier,
    recommended_balance_jpy: recommendation.recommendedBalanceJpy,
    recommended_topup_jpy: recommendation.recommendedTopupJpy,
    next_payout_run_at: nextPayoutRunAt.toISOString(),
    transfer_initiate_deadline: transferInitiateDeadline.toISOString().slice(0, 10),
    notes: [
      `Recommended top-up considers buffer_multiplier=${bufferMultiplier}.`,
      'Deadline is 7 weekdays before the payout run — JP public holidays are NOT auto-detected. If Golden Week, Obon, year-end/new-year, or other multi-day holidays fall in this window, initiate earlier.',
    ],
  }

  return new Response(JSON.stringify(body), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  })
}

Deno.serve((req) => handler(req))
