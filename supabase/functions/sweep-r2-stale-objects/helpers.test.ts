import { assertEquals } from 'jsr:@std/assert@1'

Deno.test('test runner smoke check', () => {
  assertEquals(1 + 1, 2)
})

import { parseEvidencePrefixDate } from './helpers.ts'

Deno.test('parseEvidencePrefixDate: valid date prefix returns UTC midnight', () => {
  const result = parseEvidencePrefixDate('evidence/2025-12-15/')
  assertEquals(result?.toISOString(), '2025-12-15T00:00:00.000Z')
})

Deno.test('parseEvidencePrefixDate: leap-year date is accepted', () => {
  const result = parseEvidencePrefixDate('evidence/2024-02-29/')
  assertEquals(result?.toISOString(), '2024-02-29T00:00:00.000Z')
})

Deno.test('parseEvidencePrefixDate: missing trailing slash returns null', () => {
  assertEquals(parseEvidencePrefixDate('evidence/2025-12-15'), null)
})

Deno.test('parseEvidencePrefixDate: non-date directory returns null', () => {
  assertEquals(parseEvidencePrefixDate('evidence/foo/'), null)
})

Deno.test('parseEvidencePrefixDate: invalid month returns null', () => {
  assertEquals(parseEvidencePrefixDate('evidence/2025-13-01/'), null)
})

Deno.test('parseEvidencePrefixDate: invalid day returns null', () => {
  assertEquals(parseEvidencePrefixDate('evidence/2025-02-30/'), null)
})

Deno.test('parseEvidencePrefixDate: empty string returns null', () => {
  assertEquals(parseEvidencePrefixDate(''), null)
})

import { isOlderThanDays } from './helpers.ts'

Deno.test('isOlderThanDays: exactly N days old is NOT older', () => {
  const now = new Date('2026-05-07T00:00:00Z')
  const date = new Date('2026-02-06T00:00:00Z') // 90 days before
  assertEquals(isOlderThanDays(date, 90, now), false)
})

Deno.test('isOlderThanDays: N+1 days old IS older', () => {
  const now = new Date('2026-05-07T00:00:00Z')
  const date = new Date('2026-02-05T00:00:00Z') // 91 days before
  assertEquals(isOlderThanDays(date, 90, now), true)
})

Deno.test('isOlderThanDays: same day is NOT older', () => {
  const now = new Date('2026-05-07T12:00:00Z')
  const date = new Date('2026-05-07T00:00:00Z')
  assertEquals(isOlderThanDays(date, 90, now), false)
})

Deno.test('isOlderThanDays: future date is NOT older', () => {
  const now = new Date('2026-05-07T00:00:00Z')
  const date = new Date('2026-06-07T00:00:00Z')
  assertEquals(isOlderThanDays(date, 90, now), false)
})

import { extractKeyFromAvatarUrl } from './helpers.ts'

Deno.test('extractKeyFromAvatarUrl: well-formed URL returns the key', () => {
  const url = 'https://files.peppercheck.com/avatar/abc-123/def-456.jpg'
  assertEquals(
    extractKeyFromAvatarUrl(url, 'files.peppercheck.com'),
    'avatar/abc-123/def-456.jpg',
  )
})

Deno.test('extractKeyFromAvatarUrl: mismatched host returns null', () => {
  const url = 'https://other.example.com/avatar/abc/def.jpg'
  assertEquals(
    extractKeyFromAvatarUrl(url, 'files.peppercheck.com'),
    null,
  )
})

Deno.test('extractKeyFromAvatarUrl: not a URL returns null', () => {
  assertEquals(
    extractKeyFromAvatarUrl('not-a-url', 'files.peppercheck.com'),
    null,
  )
})

Deno.test('extractKeyFromAvatarUrl: empty path returns null', () => {
  assertEquals(
    extractKeyFromAvatarUrl('https://files.peppercheck.com/', 'files.peppercheck.com'),
    null,
  )
})

import { isWithinGracePeriod } from './helpers.ts'

Deno.test('isWithinGracePeriod: 5 minutes ago, 10 min grace → within', () => {
  const now = new Date('2026-05-07T12:00:00Z')
  const lastModified = new Date('2026-05-07T11:55:00Z')
  assertEquals(isWithinGracePeriod(lastModified, now, 10 * 60_000), true)
})

Deno.test('isWithinGracePeriod: exactly 10 minutes ago, 10 min grace → NOT within (strict <)', () => {
  const now = new Date('2026-05-07T12:00:00Z')
  const lastModified = new Date('2026-05-07T11:50:00Z')
  assertEquals(isWithinGracePeriod(lastModified, now, 10 * 60_000), false)
})

Deno.test('isWithinGracePeriod: 20 minutes ago, 10 min grace → NOT within', () => {
  const now = new Date('2026-05-07T12:00:00Z')
  const lastModified = new Date('2026-05-07T11:40:00Z')
  assertEquals(isWithinGracePeriod(lastModified, now, 10 * 60_000), false)
})

Deno.test('isWithinGracePeriod: future timestamp → within (defensive)', () => {
  const now = new Date('2026-05-07T12:00:00Z')
  const lastModified = new Date('2026-05-07T12:01:00Z')
  assertEquals(isWithinGracePeriod(lastModified, now, 10 * 60_000), true)
})
