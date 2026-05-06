// Pure helpers used by the sweep-r2-stale-objects Edge Function.
// Kept separate from index.ts so they can be unit-tested in isolation.

const EVIDENCE_PREFIX_PATTERN = /^evidence\/(\d{4})-(\d{2})-(\d{2})\/$/

export function parseEvidencePrefixDate(prefix: string): Date | null {
  const match = prefix.match(EVIDENCE_PREFIX_PATTERN)
  if (!match) return null

  const [, yearStr, monthStr, dayStr] = match
  const year = Number(yearStr)
  const month = Number(monthStr)
  const day = Number(dayStr)

  // Reject obviously invalid components before constructing the Date.
  if (month < 1 || month > 12 || day < 1 || day > 31) return null

  const date = new Date(Date.UTC(year, month - 1, day))

  // Reject calendar-impossible dates (e.g., 2025-02-30 → JS rolls into March).
  if (
    date.getUTCFullYear() !== year ||
    date.getUTCMonth() !== month - 1 ||
    date.getUTCDate() !== day
  ) {
    return null
  }

  return date
}

const MS_PER_DAY = 24 * 60 * 60 * 1000

export function isOlderThanDays(date: Date, days: number, now: Date): boolean {
  const ageMs = now.getTime() - date.getTime()
  return ageMs > days * MS_PER_DAY
}

export function extractKeyFromAvatarUrl(
  url: string,
  publicDomain: string,
): string | null {
  let parsed: URL
  try {
    parsed = new URL(url)
  } catch {
    return null
  }
  if (parsed.host !== publicDomain) return null
  const key = parsed.pathname.replace(/^\//, '')
  return key.length > 0 ? key : null
}

export function isWithinGracePeriod(
  lastModified: Date,
  now: Date,
  graceMs: number,
): boolean {
  const ageMs = now.getTime() - lastModified.getTime()
  return ageMs < graceMs
}
