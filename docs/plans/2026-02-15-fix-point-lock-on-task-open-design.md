# Fix Point Lock on Task Open

**Date**: 2026-02-15
**Issue**: #72 (follow-up)

## Problem

When a task is opened, `validate_task_open_requirements()` checks that the user has enough available points, but `lock_points()` is never called. This means `point_wallets.locked` remains 0. Later, when `confirm_judgement_and_rate_referee()` calls `consume_points()`, it fails because `consume_points()` requires `locked >= amount`.

Error observed:
```
PostgrestException(message: Insufficient locked points: required 1, locked 0, code: P0001)
```

## Root Cause

Two separate systems track "locked" points:
1. `point_wallets.locked` column — updated by `lock_points()` / `unlock_points()` / `consume_points()`
2. `calculate_locked_points_by_active_tasks()` — computes locked points from active `task_referee_requests`

The validation at task open uses system 2 (calculate from requests), but `consume_points()` uses system 1 (`point_wallets.locked`). Since `lock_points()` is never called, the two systems are out of sync.

## Solution

Consolidate to a single source of truth: `point_wallets.locked`.

### Change 1: Add `lock_points()` call in `create_task_referee_requests_from_json()`

After each request is inserted, call `lock_points()` to increment `point_wallets.locked` by the matching strategy cost.

### Change 2: Simplify `validate_task_open_requirements()`

Replace the `calculate_locked_points_by_active_tasks()` call with a direct read of `point_wallets.locked`. The check becomes:
```
(balance - locked) >= new_cost
```

### Change 3: Delete `calculate_locked_points_by_active_tasks()`

No longer needed. Only referenced from `validate_task_open_requirements()`.

### Change 4: Migration file

New migration that applies all changes above.

## Non-changes

- `reward_wallets` creation at signup: not needed. `grant_reward()` uses upsert to create on first reward.
- `lock_points()`, `unlock_points()`, `consume_points()`, `grant_reward()` functions: no changes needed.
- `confirm_judgement_and_rate_referee()`: no changes needed.
