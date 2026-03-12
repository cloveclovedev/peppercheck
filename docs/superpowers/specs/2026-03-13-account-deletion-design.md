# Account Deletion Feature Design

**Issue:** #293
**Date:** 2026-03-13

## Context

Google Play requires apps to allow users to request account and data deletion from within the app and via a web-based option. PepperCheck currently lacks this feature, blocking Google Play Store publication.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Deletion type | Hard delete (immediate) | Simpler implementation; soft delete uncommon and adds complexity |
| In-progress tasks | Block deletion | User must complete or cancel tasks/referee assignments first |
| Reward payout | Attempt immediate payout; allow force-skip | Prevents stuck state if Stripe payout fails permanently |
| Subscription cancellation | Immediate cancel, no refund | IAP (Google/Apple) doesn't support app-initiated prorated refunds. For IAP subscriptions, the app cannot cancel server-side — confirmation dialog instructs user to cancel via store settings |
| R2 evidence files | Retain (not deleted immediately) | Cleaned up by separate scheduled script based on task due_date; explained to user in confirmation dialog |
| Web deletion page | Required | Google Play Console Data Safety form requires a web-based deletion URL |
| Web auth | Supabase login (Google OAuth) | Existing webapp login infrastructure |

## Data Deletion Policy

### Deleted (CASCADE)

| Table | FK | Behavior |
|-------|----|----|
| `profiles` | `auth.users` (no ON DELETE = RESTRICT) | **Change to `ON DELETE CASCADE`** |
| `point_wallets` | `auth.users → CASCADE` | Deleted |
| `point_ledger` | `auth.users → CASCADE` | Deleted |
| `trial_point_wallets` | `auth.users → CASCADE` | Deleted |
| `trial_point_ledger` | `auth.users → CASCADE` | Deleted |
| `reward_wallets` | `auth.users → CASCADE` | Deleted |
| `reward_ledger` | `auth.users → CASCADE` | Deleted |
| `user_fcm_tokens` | `auth.users → CASCADE` | Deleted |
| `user_subscriptions` | `auth.users → CASCADE` | Deleted |
| `user_ratings` | `profiles → CASCADE` | Deleted |
| `stripe_accounts` | `profiles → CASCADE` | Deleted |
| `referee_available_time_slots` | `profiles → CASCADE` | Deleted |
| `referee_blocked_dates` | `profiles → CASCADE` | Deleted |
| `referee_obligations` | `auth.users → CASCADE` | Deleted |

### Anonymized (SET NULL) — retained for other users' history and audit

| Table | Column | Current FK | Required Change |
|-------|--------|-----------|-----------------|
| `tasks` | `tasker_id` | `profiles → SET NULL` | **Make column nullable** (`NOT NULL` conflicts with SET NULL) |
| `rating_histories` | `ratee_id` | `profiles → SET NULL` | No change needed |
| `rating_histories` | `rater_id` | `profiles` (no ON DELETE = RESTRICT) | **Change to `ON DELETE SET NULL`** |
| `judgement_threads` | `sender_id` | `profiles → SET NULL` | **Make column nullable** (`NOT NULL` conflicts with SET NULL) |
| `reward_payouts` | `user_id` | `auth.users` (no ON DELETE = RESTRICT) | **Change to `ON DELETE SET NULL`; make column nullable** |
| `task_referee_requests` | `matched_referee_id` | `profiles` (no ON DELETE = RESTRICT) | **Change to `ON DELETE SET NULL`** |
| `task_referee_requests` | `preferred_referee_id` | `profiles` (no ON DELETE = RESTRICT) | **Change to `ON DELETE SET NULL`** |

## Architecture

### Edge Function: `delete-account`

Single Edge Function handles all deletion logic including external API calls (Stripe).

```
POST /functions/v1/delete-account
Authorization: Bearer <JWT>
Body: { "force": false }
```

Parameters:
- `force: false` (default) — attempts reward payout before deletion
- `force: true` — skips payout, user forfeits unpaid rewards

Responses:
- `200 { success: true }` — deletion complete
- `409 { error: "not_deletable", reasons: ["open_tasks", ...] }` — blocked by pre-conditions
- `500 { error: "payout_failed", reward_balance: 1500, message: "..." }` — payout failed, client can retry with `force: true`

### Processing Steps

```
1. Extract user_id from JWT
2. check_account_deletable() → 409 if blocked (uses auth.uid() internally)
3. If force = false AND reward_wallets.balance > 0:
   → Execute Stripe Transfer (immediate payout)
   → Record in reward_payouts
   → On failure: return 500 with payout_failed (data unchanged, retryable)
4. Cancel active Stripe subscription (immediate, no refund)
   → Only applies to Stripe-billed subscriptions
   → IAP (Google/Apple) subscriptions cannot be cancelled server-side;
     user is instructed in confirmation dialog to cancel via store settings
5. Deauthorize Stripe Connect account (if exists)
6. supabase.auth.admin.deleteUser(user_id)
   → CASCADE / SET NULL handles all related data
   → Pending referee_obligations are CASCADE-deleted (forfeited, not blocked)
7. Return 200
```

Steps 3-5 are idempotent: already-cancelled subscriptions and already-deauthorized Connect accounts return success from Stripe API, so retries are safe.

### DB Function: `check_account_deletable()`

```sql
-- Returns: { deletable: boolean, reasons: text[] }
```

Checks:
| Condition | Query |
|-----------|-------|
| Open tasks as tasker | `tasks WHERE tasker_id = user_id AND status = 'open'` |
| Active referee requests | `task_referee_requests WHERE matched_referee_id = user_id AND status IN ('matched','accepted','payment_processing')` |

Note: A separate judgement check is unnecessary — in-progress judgements imply an active referee request (`accepted` status), which is already covered above.

Used in two places:
- **Flutter/Web UI:** Called on screen load to disable button and show reason when blocked
- **Edge Function:** Called before deletion as a race-condition guard

## Flutter UI

### ProfileScreen Changes

```
ProfileScreen
├── RefereeAvailabilitySection (existing)
├── RefereeBlockedDatesSection (existing)
└── AccountActionsSection (new)
    ├── "Sign out" button (future)
    └── "Delete account" button
        ├── Blocked → button disabled + reason displayed
        └── Not blocked → confirmation dialog flow
```

### Confirmation Flow (2-step)

**Dialog 1 — Explanation:**
- What gets deleted: profile, point balances, subscription, notification settings
- What gets anonymized: task history, rating history (personal info removed but data retained)
- What is retained: evidence files (auto-deleted after a period)
- Buttons: "Delete" / "Cancel"

**Dialog 2 — Final confirmation:**
- Warning: "This action cannot be undone"
- Buttons: "Delete" / "Cancel"

**Payout failure flow:**
- If Edge Function returns `payout_failed`: show dialog explaining that payout of ¥XXX failed and asking whether to forfeit unpaid rewards and proceed with deletion
- Buttons: "Delete" / "Cancel"
- "Delete" retries with `force: true`

**Post-deletion:**
- Show SnackBar confirming account deletion and navigate to login screen

## Web UI

### Route: `/[locale]/account/delete`

- Unauthenticated → redirect to login → return to `/account/delete`
- Authenticated → same flow as Flutter (block check → 2-step confirmation → Edge Function call)
- Post-deletion → show completion message + sign out

### Google Play Console

Register the web URL in Data Safety form under "Data deletion" section.
