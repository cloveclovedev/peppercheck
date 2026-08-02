# Delete Avatar from R2 on Account Deletion

**Date:** 2026-05-06
**Issue:** #391

## Problem

The privacy policy (effective 2026-05-05, key `retention.body` in `peppercheck-webapp/messages/{ja,en}.json`) commits to prompt deletion of personally identifying data on account deletion. Avatar images are explicitly enumerated in that list.

The `delete-account` Edge Function relies on Postgres `ON DELETE CASCADE` for cleanup, but R2 objects are not subject to CASCADE — avatars survive account deletion. The privacy claim and implementation are out of sync.

## Design

### Approach

Extend `supabase/functions/delete-account/index.ts` to delete all R2 objects under the user's avatar prefix before calling `auth.admin.deleteUser`. Best-effort: log on failure and proceed with account deletion. R2 outages must not block users from deleting their own account.

### R2 Key Layout (current)

`generate-upload-url/index.ts` writes avatars to:

```
avatar/<userId>/<uuid>.<ext>
```

Each avatar upload generates a new UUID; the previous object is left in place. Therefore a single user prefix may contain multiple historical objects. The cleanup operates on the entire prefix rather than on the URL stored in `profiles.avatar_url`, so historical orphans from prior avatar updates are removed at account deletion time as well.

### Placement in delete-account flow

The current flow:

1. Authenticate user
2. Parse `force` flag
3. `check_account_deletable` RPC
4. Reward payout (if not `force`)
5. Cancel Stripe subscription
6. Deauthorize Stripe Connect
7. `auth.admin.deleteUser`

New step inserts between current 6 and 7:

> **6.5. Delete avatar objects from R2** (new) — list and delete all objects under `avatar/<userId>/`. Best-effort.

This matches the issue's guidance to delete `before calling auth.admin.deleteUser`. Placing it after Stripe Connect deauthorization (which is also best-effort) keeps the per-step ordering consistent: external-system cleanup happens before the irreversible `deleteUser` call.

### Deletion Logic

```typescript
const r2Prefix = `avatar/${userId}/`

try {
  const list = await s3Client.send(new ListObjectsV2Command({
    Bucket: r2BucketName,
    Prefix: r2Prefix,
  }))

  if (list.Contents && list.Contents.length > 0) {
    await s3Client.send(new DeleteObjectsCommand({
      Bucket: r2BucketName,
      Delete: {
        Objects: list.Contents.map(({ Key }) => ({ Key: Key! })),
      },
    }))
  }
} catch (r2Error) {
  console.error("Avatar R2 cleanup failed:", r2Error)
  // Do not block account deletion.
}
```

Pagination is intentionally not handled. A single user accumulating more than 1000 avatar objects (the `ListObjectsV2` / `DeleteObjects` page limit) is not realistic, and the orphan-sweep follow-up below will catch any leftovers.

### R2 Client Initialization

Same environment variables as `generate-upload-url`:

- `CLOUDFLARE_ACCOUNT_ID`
- `R2_ACCESS_KEY_ID`
- `R2_SECRET_ACCESS_KEY`
- `R2_BUCKET_NAME`

The `S3Client` is instantiated locally in `delete-account/index.ts` rather than extracted to a shared helper. The shared-helper extraction is deferred until #390 lands a third R2 consumer; with only two call sites today it would be premature.

When R2 environment variables are missing, log a warning and skip the deletion (continue with `auth.admin.deleteUser`). This keeps local development workable when R2 is not configured.

### Failure Handling

Best-effort, per the issue's acceptance criteria:

- R2 list/delete errors → `console.error` and continue.
- The function's existing `try/catch` for unexpected errors is preserved.

A strict reading of the prompt-deletion claim means a permanent R2 outage during account deletion would leave an orphaned avatar. This is mitigated by the orphan-sweep work tracked in Follow-up Work below, which provides a safety net independent of per-request success.

### Testing

No automated tests are added in this PR. Edge Function unit tests are not currently part of the test suite, and adding harness scaffolding is out of scope.

Manual verification on staging:

1. Create a test user, upload an avatar, confirm `avatar/<userId>/<uuid>.<ext>` exists in R2.
2. Run account deletion via the Flutter app.
3. Confirm the `avatar/<userId>/` prefix returns zero objects in the R2 console.
4. Repeat with a user that has no avatar — confirm the function succeeds (no-op deletion path).
5. Confirm with multi-version history: upload avatar A, upload avatar B (creating one orphan), then delete account. Confirm both A and B are gone from R2.

### Privacy Policy / Docs

The privacy policy already discloses prompt avatar deletion (effective 2026-05-05). No copy or doc changes are required — this PR is a code-only change to align implementation with the existing claim.

## Out of Scope

The following are intentionally deferred and tracked as separate work:

- **Avatar update orphans.** Each avatar upload leaves the prior object in R2 because `profile_repository.dart:65-111` only updates `profiles.avatar_url` without deleting the predecessor. UUID-per-upload is retained (it solves CDN/edge cache busting, which a fixed-name overwrite would break), and orphan cleanup will be addressed separately.
- **R2 orphan-sweep cron.** A scheduled sweep that lists R2 prefixes and deletes objects without a corresponding live database row provides a safety net for failed per-request deletions and is the intended long-term mechanism for honoring the prompt-deletion claim under failure modes.

## Follow-up Work

Two new GitHub issues will be filed during implementation, both to be designed alongside #390:

1. **Avatar orphan cleanup on update** — delete the previous R2 object when a user uploads a new avatar.
2. **R2 orphan-sweep cron** — periodic sweep covering evidence files (#390), avatar orphans from `delete-account` failures, and potentially the update-time orphans from item 1.

Both will be sequenced after #391 ships so the per-request best-effort path is in place first.
