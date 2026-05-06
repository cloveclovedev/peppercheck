import { assertEquals } from '@std/assert'
import { subtractBusinessDays } from './index.ts'

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
