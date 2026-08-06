# Freemium v1 Design

Related: [Epic: Freemium v1 (#70)](https://github.com/mkuri/peppercheck/issues/70)

## Overview

New users receive free trial points on registration, enabling them to create tasks and experience the tasker/referee flow without a subscription. In exchange, consuming trial points creates a referee obligation — the user must serve as a free referee (no reward points) for other users' tasks. This creates a self-sustaining freemium ecosystem that drives user acquisition.

## Core Concepts

### Trial Points

- Granted once on registration (configurable amount, default: 3)
- Managed separately from `point_wallets` in a dedicated `trial_point_wallets` table
- Follow the same lock/consume/unlock lifecycle as regular points
- Deactivated (not zeroed) when the user starts a subscription
- Never restored once deactivated

### Referee Obligations

- Created when trial points are **consumed** (settled), not when locked
- 1 trial point consumed = 1 referee obligation
- Obligations persist independently of subscription status (subscribing does NOT clear them)
- Fulfilled when the user completes a referee duty at the timing where reward points would normally be granted
- No reward points are granted for obligation-fulfilling referee sessions
- No expiration in v1

## Data Model

### `trial_point_wallets`

| Column     | Type        | Constraints                                    |
|------------|-------------|------------------------------------------------|
| user_id    | UUID PK     | FK → auth.users(id) ON DELETE CASCADE          |
| balance    | INT         | NOT NULL DEFAULT 0, CHECK >= 0                 |
| locked     | INT         | NOT NULL DEFAULT 0, CHECK >= 0                 |
| is_active  | BOOL        | NOT NULL DEFAULT true                          |
| created_at | TIMESTAMPTZ |                                                |
| updated_at | TIMESTAMPTZ |                                                |

Additional CHECK: `balance >= locked`

- `is_active`: Set to `false` on subscription start. Prevents new locks but allows in-flight consume/unlock.
- FK follows existing `point_wallets` pattern (references `auth.users`, not `profiles`).

### `trial_point_ledger`

| Column     | Type                   | Constraints                           |
|------------|------------------------|---------------------------------------|
| id         | UUID PK                |                                       |
| user_id    | UUID                   | FK → auth.users(id) ON DELETE CASCADE |
| amount     | INT                    | NOT NULL                              |
| reason     | trial_point_reason     | NOT NULL (ENUM type)                  |
| related_id | UUID                   | Nullable                              |
| created_at | TIMESTAMPTZ            |                                       |

`trial_point_reason` ENUM values (mirrors `point_reason` pattern):
- `initial_grant` — Registration grant
- `matching_lock` — Points locked for task open
- `matching_unlock` — Points unlocked on matching expiry (referee not found)
- `matching_settled` — Points consumed on judgement confirm / evidence timeout
- `matching_refund` — Points refunded on referee cancel / re-match
- `subscription_deactivation` — Event record when subscription starts (amount = 0)

`matching_unlock` vs `matching_refund`: Same wallet operation (decrement `locked`), different reasons. `matching_unlock` = system-initiated (matching expired, no referee found). `matching_refund` = referee-initiated (referee cancelled, new request created for re-match).

### `referee_obligations`

| Column             | Type                      | Constraints                              |
|--------------------|---------------------------|------------------------------------------|
| id                 | UUID PK                   |                                          |
| user_id            | UUID                      | FK → auth.users(id) ON DELETE CASCADE    |
| status             | referee_obligation_status  | NOT NULL DEFAULT 'pending' (ENUM type)   |
| source_request_id  | UUID                      | FK → task_referee_requests               |
| fulfill_request_id | UUID                      | FK → task_referee_requests, nullable     |
| created_at         | TIMESTAMPTZ               |                                          |
| fulfilled_at       | TIMESTAMPTZ               | Nullable                                 |

Index: `(user_id, status)` — used by matching priority and fulfillment queries.

`referee_obligation_status` ENUM values:
- `pending` — Obligation active, awaiting fulfillment
- `fulfilled` — Obligation completed
- `cancelled` — Reserved for future (expiration, admin override)

### `trial_point_config`

Singleton table (same pattern as `matching_time_config`).

| Column               | Type        | Constraints                                  |
|----------------------|-------------|----------------------------------------------|
| id                   | BOOLEAN PK  | DEFAULT true, CHECK (id = true)             |
| initial_grant_amount | INT         | NOT NULL DEFAULT 3                           |
| created_at           | TIMESTAMPTZ |                                              |
| updated_at           | TIMESTAMPTZ |                                              |

### `task_referee_requests` (existing table modifications)

| Column        | Type                    | Constraints              |
|---------------|-------------------------|--------------------------|
| point_source  | point_source_type       | NOT NULL DEFAULT 'regular' (ENUM type) |
| is_obligation | BOOL                    | NOT NULL DEFAULT false   |

`point_source_type` ENUM values:
- `regular` — Created using regular `point_wallets`
- `trial` — Created using `trial_point_wallets`

`point_source` is set at lock time (task open) and used at settlement time to route to the correct consume/unlock function. `is_obligation` is set at matching time when the referee is matched via obligation fulfillment.

When a referee cancels and a new request is created for re-matching, the new request inherits the `point_source` from the original request.

### RLS Policies

All new tables use RLS with the following policies (consistent with existing patterns):

- **`trial_point_wallets`**: Users can SELECT their own row (`user_id = auth.uid()`). No direct INSERT/UPDATE/DELETE (managed by functions with `SECURITY DEFINER`).
- **`trial_point_ledger`**: Users can SELECT their own rows. No direct INSERT/UPDATE/DELETE.
- **`referee_obligations`**: Users can SELECT their own rows. No direct INSERT/UPDATE/DELETE.
- **`trial_point_config`**: All authenticated users can SELECT (read config). No direct INSERT/UPDATE/DELETE.

## Trial Point Lifecycle

### 1. Grant (Registration)

- Trigger: `on_profiles_insert` (alongside existing `point_wallets` creation)
- Creates `trial_point_wallets` with `balance = trial_point_config.initial_grant_amount`
- Ledger entry: `reason = 'initial_grant'`

### 2. Lock (Task Open)

- Function: `lock_trial_points(user_id, request_id, cost)`
- Precondition: `is_active = true` AND `balance - locked >= cost`
- Effect: `locked += cost`
- Ledger entry: `reason = 'matching_lock'`

### 3. Consume (Judgement Confirm / Evidence Timeout)

- Function: `consume_trial_points(user_id, request_id, cost)`
- Effect: `balance -= cost`, `locked -= cost`
- Ledger entry: `reason = 'matching_settled'`
- Side effect: INSERT into `referee_obligations` with `status = 'pending'`, `source_request_id = request_id`

### 4. Unlock (Matching Failure / Cancel)

- Function: `unlock_trial_points(user_id, request_id, cost)`
- Effect: `locked -= cost`
- Ledger entry: `reason = 'matching_unlock'` or `'matching_refund'`
- No obligation created

### 5. Deactivate (Subscription Start)

- Function: `deactivate_trial_points(user_id)`
- Effect: `is_active = false` (balance unchanged for audit trail)
- Ledger entry: `reason = 'subscription_deactivation'`, `amount = 0`
- Triggered from `handle-stripe-webhook` on `checkout.session.completed` (mode=subscription)
- Called via `supabaseAdmin.rpc('deactivate_trial_points', ...)` in the webhook handler
- If the RPC fails, the webhook should still succeed (subscription activation is primary; deactivation can be retried)

### Task Creation Point Selection Logic

- If `trial_point_wallets.is_active = true` AND available balance > 0 → use trial points
- Otherwise → use regular `point_wallets`
- Both wallets having usable balance simultaneously is not expected (subscription deactivates trial)

### Existing Function Modifications

The following existing functions require updates to support trial points:

- **`validate_task_open_requirements`**: Currently checks only `point_wallets`. Must also check `trial_point_wallets` when `is_active = true` and available balance > 0.
- **`create_task_referee_requests_from_json`**: Currently calls `lock_points()`. Must call `lock_trial_points()` when using trial points, and set `point_source = 'trial'` on the created request.
- **`confirm_judgement_and_rate_referee`**: Currently calls `consume_points()` and `grant_reward()`. Must check `task_referee_requests.point_source` to call `consume_trial_points()` when `'trial'`, and check `is_obligation` to skip reward granting.
- **`settle_evidence_timeout`**: Same routing logic — check `point_source` to determine which consume function to call, check `is_obligation` to skip reward.
- **`cancel_referee_assignment`**: When creating a new request for re-matching, must copy `point_source` from the original request.

### Multi-Request Tasks with Insufficient Trial Points

If a task has multiple referee requests (e.g., 2) but only 1 trial point remains, the task cannot be opened. All requests within a single task must use the same point source. Partial trial point usage within a single task creation is not allowed.

## Referee Obligation Lifecycle

### Creation

- Occurs inside `consume_trial_points()` as a side effect
- 1 consumption = 1 obligation record

### Fulfillment

At the timing where `grant_reward()` is normally called:

1. Check if the referee has any `referee_obligations` with `status = 'pending'`
2. If yes:
   - Update the oldest pending obligation to `status = 'fulfilled'` (FIFO)
   - Set `fulfill_request_id` and `fulfilled_at`
   - Skip `reward_wallet` grant
3. If no:
   - Grant reward points as normal

### Matching Priority

Changes to `process_matching()`:

1. Filter candidates by existing conditions (availability slots, blocked dates, not own task, etc.)
2. Among candidates, check for users with `referee_obligations.status = 'pending'`
3. If found → prioritize (oldest obligation first)
4. If not found → existing matching logic

Obligation users are subject to the same matching conditions as regular referees. No conditions are relaxed.

### Referee UX

- When `is_obligation = true` on the request, display: "This is a trial obligation referee assignment. Reward points will not be granted."

## Subscription Integration

### On Subscription Start

Triggered by `handle-stripe-webhook` (`checkout.session.completed` / `customer.subscription.created`):

1. Existing: upsert `user_subscriptions`
2. New: call `deactivate_trial_points(user_id, subscription_id)`

### Edge Cases

**Locked trial points at subscription start:**
- `is_active = false` is set, but in-flight locked points remain
- `consume_trial_points` and `unlock_trial_points` work regardless of `is_active`
- Only `lock_trial_points` checks `is_active = true`

**Existing users (registered before feature launch):**
- No `trial_point_wallets` created (trigger only fires on new registration)
- No trial points granted retroactively

**Subscription cancel → re-subscribe:**
- Trial points do not restore (`is_active` stays `false`)

**Obligation user declines/cancels as referee:**
- Obligation not consumed (only consumed at reward-grant timing)
- User remains in priority matching pool for future matches

**Account deletion:**
- CASCADE delete removes `trial_point_wallets`, `trial_point_ledger`, `referee_obligations`

## Flutter Client Changes

### Data Models (Freezed)

- `TrialPointWallet` — `balance`, `locked`, `is_active`
- `RefereeObligation` — `id`, `status`, `source_request_id`, `fulfill_request_id`

### Repository

- `BillingRepository` (to be renamed to `PointRepository` or similar in a future refactor PR):
  - `fetchTrialPointWallet()`
  - `fetchRefereeObligations()`

### UI Indicators

**Point display area:**
- Trial point balance shown when `is_active = true`: "Trial points: 2 remaining"
- Pending obligation count: "Free referee duty: 1 remaining"

**Task creation:**
- When using trial points: "Trial points will be used. A free referee obligation will be created upon task completion."

**Referee view (obligation assignment):**
- When `is_obligation = true`: "This is a trial obligation assignment. Reward points will not be granted."

**Subscription screen:**
- When trial points remain: "Starting a subscription will deactivate your remaining trial points."

### Notifications

Following existing `notification_{event}_{recipient}` pattern:
- `notification_trial_points_granted_tasker` — Trial points granted on registration
- `notification_obligation_created_tasker` — Referee obligation created on point consumption
- `notification_obligation_matched_referee` — Matched as obligation referee
