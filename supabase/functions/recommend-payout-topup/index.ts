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

Deno.serve(() => new Response('Not implemented', { status: 501 }))
