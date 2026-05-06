import 'jsr:@supabase/functions-js@^2/edge-runtime.d.ts'

/**
 * Subtract N business days (Mon–Fri) from a date.
 * Note: Japanese public holidays are NOT detected.
 */
export function subtractBusinessDays(date: Date, days: number): Date {
  const d = new Date(date)
  let remaining = days
  while (remaining > 0) {
    d.setUTCDate(d.getUTCDate() - 1)
    const dow = d.getUTCDay() // 0 = Sun, 6 = Sat
    if (dow !== 0 && dow !== 6) {
      remaining--
    }
  }
  return d
}

/**
 * Constant-time comparison of the X-Operator-Secret header against OPERATOR_API_SECRET env.
 * Returns false if either side is missing or empty.
 */
export function verifyOperatorSecret(req: Request): boolean {
  const expected = Deno.env.get('OPERATOR_API_SECRET') ?? ''
  const provided = req.headers.get('X-Operator-Secret') ?? ''
  if (expected.length === 0 || provided.length === 0) return false
  if (expected.length !== provided.length) return false

  // Constant-time comparison
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

Deno.serve(() => new Response('Not implemented', { status: 501 }))
