import 'jsr:@supabase/functions-js@^2/edge-runtime.d.ts'

import { createClient, SupabaseClient } from '@supabase/supabase-js'
import {
  type _Object,
  type CommonPrefix,
  DeleteObjectsCommand,
  ListObjectsV2Command,
  type ListObjectsV2CommandInput,
  S3Client,
} from '@aws-sdk/client-s3'

import {
  extractKeyFromAvatarUrl,
  isOlderThanDays,
  isWithinGracePeriod,
  parseEvidencePrefixDate,
} from './helpers.ts'

const EVIDENCE_RETENTION_DAYS = 90
const AVATAR_GRACE_MS = 10 * 60 * 1000 // 10 minutes
const S3_BATCH_LIMIT = 1000

interface SweepResult {
  prefixes_scanned: number
  prefixes_deleted: number
  objects_deleted: number
  errors: string[]
}

function emptyResult(): SweepResult {
  return { prefixes_scanned: 0, prefixes_deleted: 0, objects_deleted: 0, errors: [] }
}

function recordError(result: SweepResult, context: string, err: unknown): void {
  // Pass the error object directly to console.error so Deno prints the class
  // name, stack trace, and any nested fields (e.g. PostgrestError.code,
  // S3ServiceException.$metadata). Without this, debugging cron failures
  // requires redeploying with extra logging.
  console.error(`[sweep-r2-stale-objects] ${context}:`, err)
  const message = err instanceof Error ? `${err.name}: ${err.message}` : String(err)
  result.errors.push(`${context}: ${message}`)
}

interface R2Env {
  bucket: string
  publicDomain: string
}

function buildS3Client(): { s3: S3Client; env: R2Env } | null {
  const accountId = Deno.env.get('CLOUDFLARE_ACCOUNT_ID')
  const accessKeyId = Deno.env.get('R2_ACCESS_KEY_ID')
  const secretAccessKey = Deno.env.get('R2_SECRET_ACCESS_KEY')
  const bucket = Deno.env.get('R2_BUCKET_NAME')
  const publicDomain = Deno.env.get('R2_PUBLIC_DOMAIN')

  if (!accountId || !accessKeyId || !secretAccessKey || !bucket || !publicDomain) {
    console.error(
      '[sweep-r2-stale-objects] R2 environment variables missing — aborting sweep.',
    )
    return null
  }

  const s3 = new S3Client({
    region: 'auto',
    endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
    credentials: { accessKeyId, secretAccessKey },
  })

  return { s3, env: { bucket, publicDomain } }
}

interface ListAllResult {
  contents: _Object[]
  commonPrefixes: CommonPrefix[]
}

async function listAllObjects(
  s3: S3Client,
  params: ListObjectsV2CommandInput,
): Promise<ListAllResult> {
  const contents: _Object[] = []
  const commonPrefixes: CommonPrefix[] = []
  let continuationToken: string | undefined
  do {
    const res = await s3.send(
      new ListObjectsV2Command({ ...params, ContinuationToken: continuationToken }),
    )
    contents.push(...(res.Contents ?? []))
    commonPrefixes.push(...(res.CommonPrefixes ?? []))
    continuationToken = res.IsTruncated ? res.NextContinuationToken : undefined
  } while (continuationToken)
  return { contents, commonPrefixes }
}

async function deleteObjectsInChunks(
  s3: S3Client,
  bucket: string,
  keys: string[],
  dryRun: boolean,
): Promise<number> {
  if (dryRun) return keys.length // pretend we deleted them all
  let deleted = 0
  for (let i = 0; i < keys.length; i += S3_BATCH_LIMIT) {
    const chunk = keys.slice(i, i + S3_BATCH_LIMIT)
    const res = await s3.send(
      new DeleteObjectsCommand({
        Bucket: bucket,
        Delete: { Objects: chunk.map((Key) => ({ Key })) },
      }),
    )
    deleted += res.Deleted?.length ?? 0
  }
  return deleted
}

async function sweepEvidencePrefixes(
  s3: S3Client,
  bucket: string,
  now: Date,
  dryRun: boolean,
  result: SweepResult,
): Promise<void> {
  const top = await listAllObjects(s3, {
    Bucket: bucket,
    Prefix: 'evidence/',
    Delimiter: '/',
  })

  for (const cp of top.commonPrefixes) {
    const prefix = cp.Prefix
    if (!prefix) continue
    result.prefixes_scanned += 1

    const date = parseEvidencePrefixDate(prefix)
    if (!date) {
      console.warn(
        `[sweep-r2-stale-objects] Skipping unrecognized evidence prefix: ${prefix}`,
      )
      continue
    }
    if (!isOlderThanDays(date, EVIDENCE_RETENTION_DAYS, now)) continue

    try {
      const { contents } = await listAllObjects(s3, { Bucket: bucket, Prefix: prefix })
      const keys = contents.map((c) => c.Key).filter((k): k is string => Boolean(k))
      if (keys.length === 0) continue

      const deleted = await deleteObjectsInChunks(s3, bucket, keys, dryRun)
      result.objects_deleted += deleted
      result.prefixes_deleted += 1
    } catch (err) {
      recordError(result, `evidence prefix ${prefix}`, err)
    }
  }
}

interface LiveUserAvatars {
  // userId → currentKey (or null when avatar_url IS NULL).
  live: Map<string, string | null>
  // Live users whose avatar_url was non-null but did not parse — defensively
  // excluded from any deletion so we never delete their real current avatar.
  skip: Set<string>
}

async function fetchLiveUserAvatars(
  supabase: SupabaseClient,
  publicDomain: string,
): Promise<LiveUserAvatars> {
  const { data, error } = await supabase
    .from('profiles')
    .select('id, avatar_url')
  if (error) throw error

  const live = new Map<string, string | null>()
  const skip = new Set<string>()
  for (const row of data ?? []) {
    const id = row.id as string
    const url = row.avatar_url as string | null
    if (!url) {
      live.set(id, null)
      continue
    }
    const key = extractKeyFromAvatarUrl(url, publicDomain)
    if (key === null) {
      console.warn(
        `[sweep-r2-stale-objects] Skipping user ${id}: avatar_url could not be parsed`,
      )
      skip.add(id)
      continue
    }
    live.set(id, key)
  }
  return { live, skip }
}

async function sweepAvatarPrefixes(
  s3: S3Client,
  supabase: SupabaseClient,
  bucket: string,
  publicDomain: string,
  now: Date,
  dryRun: boolean,
  result: SweepResult,
): Promise<void> {
  const { live, skip } = await fetchLiveUserAvatars(supabase, publicDomain)

  const top = await listAllObjects(s3, {
    Bucket: bucket,
    Prefix: 'avatar/',
    Delimiter: '/',
  })

  for (const cp of top.commonPrefixes) {
    const prefix = cp.Prefix
    if (!prefix) continue
    result.prefixes_scanned += 1

    // Extract userId from `avatar/<userId>/`.
    const match = prefix.match(/^avatar\/([^/]+)\/$/)
    if (!match) {
      console.warn(`[sweep-r2-stale-objects] Skipping unrecognized avatar prefix: ${prefix}`)
      continue
    }
    const userId = match[1]

    if (skip.has(userId)) {
      console.warn(
        `[sweep-r2-stale-objects] Skipping prefix ${prefix}: avatar_url unparseable`,
      )
      continue
    }

    const isLive = live.has(userId)
    const currentKey = isLive ? live.get(userId) ?? null : null

    try {
      const { contents } = await listAllObjects(s3, { Bucket: bucket, Prefix: prefix })

      const toDelete: string[] = []
      for (const obj of contents) {
        const key = obj.Key
        if (!key) continue
        if (isLive) {
          if (key === currentKey) continue
          // Race protection: skip recently-uploaded objects.
          if (obj.LastModified && isWithinGracePeriod(obj.LastModified, now, AVATAR_GRACE_MS)) {
            continue
          }
        }
        toDelete.push(key)
      }

      if (toDelete.length === 0) continue

      const deleted = await deleteObjectsInChunks(s3, bucket, toDelete, dryRun)
      result.objects_deleted += deleted
      result.prefixes_deleted += 1
    } catch (err) {
      recordError(result, `avatar prefix ${prefix}`, err)
    }
  }
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      { status: 405, headers: { 'Content-Type': 'application/json' } },
    )
  }

  let dryRun = false
  try {
    const body = await req.json()
    if (body && typeof body === 'object' && body.dry_run === true) {
      dryRun = true
    }
  } catch {
    // No body or invalid JSON — default to dryRun=false. The cron sends '{}',
    // which parses fine and naturally results in dryRun=false.
  }

  console.log(`[sweep-r2-stale-objects] starting sweep (dry_run=${dryRun})`)

  const r2 = buildS3Client()
  if (!r2) {
    return new Response(
      JSON.stringify({ error: 'R2 not configured' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    )
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  if (!supabaseUrl || !supabaseServiceRoleKey) {
    return new Response(
      JSON.stringify({ error: 'Supabase env not configured' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    )
  }
  const supabase = createClient(supabaseUrl, supabaseServiceRoleKey)

  const now = new Date()
  const summary = {
    evidence: emptyResult(),
    avatar: emptyResult(),
  }

  try {
    await sweepEvidencePrefixes(r2.s3, r2.env.bucket, now, dryRun, summary.evidence)
  } catch (err) {
    recordError(summary.evidence, 'evidence sweep top-level', err)
  }

  try {
    await sweepAvatarPrefixes(
      r2.s3,
      supabase,
      r2.env.bucket,
      r2.env.publicDomain,
      now,
      dryRun,
      summary.avatar,
    )
  } catch (err) {
    recordError(summary.avatar, 'avatar sweep top-level', err)
  }

  return new Response(
    JSON.stringify({ dry_run: dryRun, ...summary }),
    { status: 200, headers: { 'Content-Type': 'application/json' } },
  )
})
