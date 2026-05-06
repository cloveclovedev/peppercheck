# R2 Stale-Object Sweep — Daily Cron for Evidence Lifecycle and Avatar Cleanup

**Date:** 2026-05-07
**Issues:** #390 (evidence lifecycle), #403 (avatar update orphan), #404 (R2 orphan-sweep cron)

## Terminology

"Stale objects" covers both:

- **Expired files** — evidence images past `due_date + 90 days` (the parent task still exists; retention has lapsed).
- **Orphan files** — avatar objects no longer referenced by any live `profiles` row (either the user has been deleted, or the object has been superseded by a newer avatar upload).

The function name is `sweep-r2-stale-objects` rather than `sweep-r2-orphans` because "orphan" strictly means "parent gone," which fits the avatar cases but not the evidence-lifecycle case (the parent task is still alive). "Stale" cleanly covers both. Issue #404 was filed under the "orphan-sweep" label, but its scope explicitly includes evidence lifecycle, hence the rename.

## Problem

Three related R2 cleanup gaps exist:

1. **Evidence files have no expiration.** The privacy policy (effective 2026-05-05, key `retention.evidenceFiles`) discloses that evidence images are deleted 90 days after the corresponding task's `due_date`. Not yet implemented.
2. **Avatar update leaves orphans.** Each avatar upload writes a new object at `avatar/<userId>/<uuid>.<ext>` and overwrites `profiles.avatar_url`. The previous object is left in place. UUID-per-upload is intentional (CDN cache busting), so the prior key cannot be deduced from the current `avatar_url`.
3. **Avatar deletion on account removal is best-effort.** `delete-account/index.ts` deletes the user's avatar prefix before `auth.admin.deleteUser`, but logs and continues on R2 failure. Persistent R2 outages would leave orphan objects despite the privacy policy's prompt-deletion claim.

A single periodic sweep can address all three.

## Design

### Approach

A new Edge Function `sweep-r2-stale-objects` runs daily via `pg_cron`, invoked through `pg_net` with credentials retrieved from Supabase Vault. The function performs three independent sweeps:

| Sub-task | Target | Source issue |
|---|---|---|
| Evidence prefix sweep | `evidence/<YYYY-MM-DD>/` directories where `today - prefix_date > 90 days` | #390 |
| Avatar dead-user sweep | `avatar/<userId>/` prefixes where `userId` is no longer in `profiles` | #404 (#391 best-effort safety net) |
| Avatar live-user orphan sweep | objects under `avatar/<userId>/` other than the one referenced by `profiles.avatar_url` | #403 |

Per-request avatar deletion (#403's literal acceptance criterion) is **not** implemented. The privacy policy's "速やかに削除" commitment applies only to account deletion, not avatar updates, so a daily sweep satisfies the actual policy obligations. Per-request deletion can be added later as a follow-up if needed; deferring it keeps Edge Function count and client-side surface lower.

### Naming

- Edge Function: `sweep-r2-stale-objects` (verb-first, matches dominant convention: `execute-pending-payouts`, `generate-upload-url`, `delete-account`)
- Cron job name: `sweep-r2-stale-objects` (matches function name)
- Cron SQL file: `cron_sweep_r2_stale_objects.sql`

### Cron schedule and invocation

```sql
SELECT cron.schedule(
    'sweep-r2-stale-objects',
    '0 18 * * *',  -- daily 18:00 UTC = 03:00 JST (off-peak)
    $$SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'supabase_url')
              || '/functions/v1/sweep-r2-stale-objects',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key')
        ),
        body := '{}'::jsonb,
        timeout_milliseconds := 300000
    )$$
);
```

The pattern matches `cron_execute_pending_payouts.sql`. Vault secrets `supabase_url` and `service_role_key` already exist from prior cron work — no new secret setup required.

`service_role_key` is used as the Bearer token (rather than `anon_key`) because the function performs admin-level reads (`SELECT id, avatar_url FROM profiles` across all users) that bypass RLS. Using `service_role_key` end-to-end keeps the gateway JWT verification (`verify_jwt = true`) and the in-function client consistent.

`timeout_milliseconds` is 5 minutes — longer than `execute-pending-payouts` (2 min) because the sweep iterates all R2 prefixes.

### Sweep logic

#### Evidence prefix sweep

```
1. ListObjectsV2(Prefix='evidence/', Delimiter='/')
   → CommonPrefixes contains 'evidence/2025-12-15/' style entries
2. For each CommonPrefix:
   - Parse YYYY-MM-DD via regex
   - On parse failure: log warn, do NOT delete (defensive — protects against unexpected directory names)
   - If (today - parsedDate) > 90 days:
       ListObjectsV2(Prefix=<full date prefix>) with pagination
       DeleteObjects in chunks of 1000
```

`generate-upload-url` derives the prefix from `task.due_date`, so the prefix name IS the due date. No DB lookup needed.

#### Avatar dead-user sweep

```
1. ListObjectsV2(Prefix='avatar/', Delimiter='/')
   → CommonPrefixes contains 'avatar/<userId>/' entries
2. Collect all userIds from prefix names
3. SELECT id FROM profiles WHERE id = ANY($1)  -- live users
4. Set difference: R2 userIds minus live userIds = dead users
5. For each dead user prefix:
   - ListObjectsV2(Prefix='avatar/<userId>/') with pagination
   - DeleteObjects in chunks of 1000
```

#### Avatar live-user orphan sweep

```
1. SELECT id, avatar_url FROM profiles WHERE avatar_url IS NOT NULL
2. For each user:
   - Extract current key from avatar_url (URL.pathname.slice(1))
   - ListObjectsV2(Prefix='avatar/<userId>/') with pagination
   - For each object:
       Skip if key === currentKey (keep current avatar)
       Skip if (now - LastModified) < 10 minutes (race protection — see below)
       Otherwise mark for deletion
   - DeleteObjects in chunks of 1000
```

**Race protection — `LastModified` grace period.** The avatar update flow in `profile_repository.dart:65-111` is:

```
1. generate-upload-url → new r2_key returned
2. PUT bytes to R2          ← new file appears in R2
3. UPDATE profiles.avatar_url ← DB row reflects new URL
```

A sweep running between steps 2 and 3 would see the OLD `avatar_url` while the R2 list contains the NEW file, causing the new file to be deleted as an "orphan." The window is normally <1 second but is not zero.

The grace period (10 minutes) excludes recently-uploaded objects from deletion, collapsing the race window. Orphans aged less than 10 minutes are simply carried over to the next day's sweep. The grace value gives a ~600× safety margin over the typical PUT→UPDATE latency.

This protection applies only to the live-user orphan sweep:
- Evidence sweep targets `due_date + 90 days` ago — no current uploads possible at that age.
- Dead-user sweep targets users that already passed `auth.admin.deleteUser` — no future uploads possible.

#### Implementation note: dead-user and live-user sweeps merged in code

The two avatar sweeps are described separately above for clarity, but in `index.ts` they share a single pass over `avatar/` prefixes. For each prefix's userId:
- If userId not in `profiles`: delete all objects under prefix.
- If userId in `profiles`: delete all objects under prefix except the current `avatar_url` key, applying the grace-period filter.

This avoids a duplicate `ListObjectsV2(Prefix='avatar/')` call.

### Edge Function structure

```
supabase/functions/sweep-r2-stale-objects/
  index.ts          # orchestration: HTTP entry, sweep coordination, summary response
  helpers.ts        # pure functions (date parsing, URL parsing, predicates)
  helpers.test.ts   # Deno.test unit tests for helpers
  deno.json
```

`index.ts` skeleton:

```typescript
Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 })

  // env validation, S3Client + supabase admin client init (same pattern as delete-account)

  const summary = {
    evidence: emptyResult(),
    avatar_dead_user: emptyResult(),
    avatar_live_orphan: emptyResult(),
  }

  try { await sweepEvidencePrefixes(s3, summary.evidence) } catch (e) { logAndRecord(e, summary.evidence) }
  try { await sweepAvatarPrefixes(s3, supabase, summary.avatar_dead_user, summary.avatar_live_orphan) } catch (e) { /* ... */ }

  return new Response(JSON.stringify(summary), { status: 200 })
})
```

The summary response is for manual debug invocation; pg_net does not consume it. Each sub-task records `{ prefixes_scanned, prefixes_deleted, objects_deleted, errors[] }`.

R2 client initialization mirrors `supabase/functions/delete-account/index.ts:248-257` and uses the existing env vars: `CLOUDFLARE_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET_NAME`, `R2_PUBLIC_DOMAIN`.

`config.toml` adds:

```toml
[functions.sweep-r2-stale-objects]
enabled = true
verify_jwt = true
import_map = "./functions/sweep-r2-stale-objects/deno.json"
```

### Pagination

Both `ListObjectsV2` and `DeleteObjects` cap at 1000 entries per call. Production data will exceed this. A shared helper handles list pagination:

```typescript
async function listAllObjects(s3: S3Client, params: ListObjectsV2CommandInput) {
  const contents: _Object[] = []
  const commonPrefixes: CommonPrefix[] = []
  let token: string | undefined
  do {
    const res = await s3.send(new ListObjectsV2Command({ ...params, ContinuationToken: token }))
    contents.push(...(res.Contents ?? []))
    commonPrefixes.push(...(res.CommonPrefixes ?? []))
    token = res.IsTruncated ? res.NextContinuationToken : undefined
  } while (token)
  return { contents, commonPrefixes }
}
```

Deletion chunks the to-delete keys into 1000-entry batches before each `DeleteObjectsCommand` send.

### Error handling

Three independence levels:

1. **Sub-task level.** The three sweeps each have a top-level try/catch. One failing does not block the others.
2. **Prefix level.** Within a sweep, each prefix's list/delete is wrapped in a try/catch. Errors push to `errors[]` and the loop continues to the next prefix.
3. **Object-batch level.** A failed `DeleteObjects` chunk does not abort the prefix; it is recorded and the next chunk proceeds.

`console.error` and `console.warn` produce structured logs visible in the Supabase Functions Dashboard. The summary JSON gives at-a-glance counts on manual invocation.

### Testing

**Pure-logic helpers** (`helpers.ts`) are covered by unit tests in `helpers.test.ts` using Deno's built-in test runner:

- `parseEvidencePrefixDate(prefix: string): Date | null` — valid date, malformed prefix, missing trailing slash, leap-year date.
- `isOlderThanDays(date: Date, days: number, now: Date): boolean` — exactly N days, N+1 days, future date.
- `extractKeyFromAvatarUrl(url: string, publicDomain: string): string | null` — well-formed URL, mismatched domain, malformed URL.
- `isWithinGracePeriod(lastModified: Date, now: Date, graceMs: number): boolean` — recent, exact boundary, old.

Run via:

```bash
cd supabase/functions/sweep-r2-stale-objects && deno test
```

**Orchestration code** (`index.ts`) is verified manually on staging. Mocking R2 / Postgres for orchestration tests has low fidelity for this kind of code, so the cost-benefit favors manual end-to-end checks over mocked tests.

Manual verification steps (staging):

1. Seed R2 with: an old `evidence/2024-01-01/` prefix (>90 days), an `avatar/<deletedUserId>/` prefix where the user is not in `profiles`, an `avatar/<liveUserId>/` prefix containing both the current avatar and an old UUID file.
2. Manually invoke `sweep-r2-stale-objects` (curl with service_role bearer or Supabase Functions Dashboard "Run").
3. Inspect the response summary — confirm non-zero deletion counts.
4. Inspect R2 console — confirm: old evidence prefix gone, dead-user prefix gone, live user retains current avatar only.
5. Re-invoke and confirm zero deletions (idempotence).

### Files changed

```
supabase/
  functions/
    sweep-r2-stale-objects/
      index.ts            # NEW
      helpers.ts          # NEW
      helpers.test.ts     # NEW
      deno.json           # NEW
  config.toml             # MODIFY: add [functions.sweep-r2-stale-objects]
  schemas/
    common/
      cron/
        cron_sweep_r2_stale_objects.sql  # NEW (directory + file)
  migrations/
    <generated>.sql       # NEW: via `supabase db diff`, then manually append cron.schedule DML
                          #      with `-- DML, not detected by schema diff` comment
```

`supabase/config.toml` `[db.migrations]` registers `common/cron/cron_sweep_r2_stale_objects.sql` so `db diff` picks up the new schema file.

## Issue closure

| Issue | Disposition |
|---|---|
| #390 (evidence lifecycle) | Close — acceptance criteria fully satisfied by evidence prefix sweep. |
| #404 (R2 orphan-sweep cron) | Close — this PR is the issue's body of work. |
| #403 (avatar update orphan) | Close as covered-by-sweep — daily cleanup satisfies the acceptance criterion ("After a second avatar upload, the first avatar object is no longer present") on a daily cadence. Per-request deletion can be filed as a new issue if immediate cleanup is desired in the future. |

## Out of scope

- **Per-request avatar deletion in the upload flow.** Documented in §Approach. May be added later as a small Edge Function + Flutter client call if daily cadence becomes insufficient.
- **Generic `invoke_edge_function(name text, body jsonb)` SQL helper.** With only two cron-invoked Edge Functions today (`execute-pending-payouts` and `sweep-r2-stale-objects`), inlining `net.http_post` in each cron file is below the rule-of-three threshold for extraction. To be reconsidered when a third cron-invoked Edge Function appears.
- **Automated end-to-end tests for the orchestration code.** Mocking R2 / Postgres for this kind of I/O-heavy function has low fidelity; manual staging verification is the chosen substitute.
- **Alarm / paging on sweep failures.** The function logs and returns a summary; observability beyond Functions Dashboard logs is deferred.
- **Reporting metrics (objects deleted, bytes reclaimed).** The summary response includes counts but they are not persisted or aggregated.
