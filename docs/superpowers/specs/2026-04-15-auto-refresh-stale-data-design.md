# Auto-Refresh Stale Data Across Screens After Mutations

**Issue**: #344
**Date**: 2026-04-15
**Status**: Draft

## Problem

Multiple screens show stale data after mutations because Riverpod provider invalidation is incomplete. Users must manually pull-to-refresh or navigate away and back to see updated information.

## Scope

### In scope

- **Scenarios 1-4 (quick wins)**: Add missing `ref.invalidate()` calls after mutations
- **Scenario 4 (push notification tap)**: Invalidate task data before navigation
- **App resume refresh**: Automatically invalidate stale providers when the app returns to foreground
- **Investigation**: Verify invalidate timing and screen transition order across all mutation flows

### Out of scope

- Supabase Realtime subscriptions (deferred post-MVP due to past reliability issues with race conditions — see #321, #328, #330, #333)

## Design Principles

Based on Riverpod best practices:

1. **Colocate invalidation with mutations** — each controller invalidates the providers it makes stale, directly in the mutation method. No centralized invalidation helper.
2. **`ref.invalidate()` for cache busting** — marks cached data as stale; the next read triggers a fresh fetch from Supabase.
3. **`ref.invalidate(familyProvider)` without parameters** — invalidates all instances of a family provider at once. Only currently-watched instances actually refetch.

## Detailed Design

### 1. Controller Invalidation Changes (Scenarios 1-4)

Add missing `ref.invalidate()` calls to each controller's mutation methods:

| Controller | Methods | Add invalidation for |
|---|---|---|
| `EvidenceController` | `submit`, `updateEvidence`, `resubmit`, `confirmEvidenceTimeout` | `activeUserTasksProvider`, `activeRefereeTasksProvider` |
| `JudgementController` | `submit`, `confirmJudgement`, `confirmReviewTimeout` | `activeUserTasksProvider`, `activeRefereeTasksProvider` |
| `TaskRefereesSection` | cancel assignment action | `activeRefereeTasksProvider` |
| `TaskCreationController` | `createTask` | `pointWalletProvider`, `trialPointWalletProvider` |
| `FCMService` | `_navigateFromData` | `taskProvider(taskId)` before navigation |

### 2. Push Notification Tap Refresh (Scenario 4)

In `FCMService._navigateFromData()`:

- Extract `taskId` from notification payload
- Call `ref.invalidate(taskProvider(taskId))` before `router.push('/task_detail/$taskId')`
- This ensures the task detail screen fetches fresh data on open

### 3. AppLifecycleObserver (App Resume Refresh)

A new `ConsumerStatefulWidget` with `WidgetsBindingObserver` mixin, placed near the top of the widget tree (inside `ProviderScope`, wrapping or adjacent to `MaterialApp`).

**Trigger**: `AppLifecycleState.resumed`

**Invalidation targets**:

| Provider | Reason |
|---|---|
| `activeUserTasksProvider` | Home screen tasker task list |
| `activeRefereeTasksProvider` | Home screen referee task list |
| `taskProvider` | All task detail instances (parameter-less invalidation) |
| `pointWalletProvider` | Point balance |
| `trialPointWalletProvider` | Trial point balance |

**Guard conditions**:

1. **Authentication check**: Skip invalidation if the user is not authenticated (avoid unnecessary API calls on the login screen)
2. **Throttle (30 seconds)**: Skip invalidation if less than 30 seconds have elapsed since the last resume-triggered invalidation (prevents excessive refetches from brief app switches, e.g., pulling down the notification shade)

### 4. Investigation Items

Before implementation, verify the following across all mutation flows. If issues are found, include fixes in the implementation scope:

1. **Invalidate timing vs. screen transition order** — Confirm that `ref.invalidate()` executes before navigation (e.g., `router.push`, `router.pop`). If invalidation happens after navigation, the destination screen may read stale cache before the invalidation takes effect.
2. **autoDispose behavior of home screen providers** — Check whether `activeUserTasksProvider` and `activeRefereeTasksProvider` use `autoDispose`. If they do, navigating away from the home screen disposes them, and returning automatically triggers a fresh fetch — making explicit invalidation unnecessary for some flows.
3. **Pull-to-refresh coexistence** — Ensure that automatic invalidation (from mutations or app resume) and manual pull-to-refresh do not cause redundant simultaneous fetches.

## Acceptance Criteria

- [ ] After evidence submission/update/resubmit/timeout confirmation, returning to home screen shows updated task status without manual refresh
- [ ] After judgement submission/confirmation/timeout confirmation, returning to home screen shows updated task status without manual refresh
- [ ] After referee cancellation, the task disappears from the referee's home screen without manual refresh
- [ ] After task creation, point balance reflects the deduction immediately
- [ ] Tapping a push notification shows the latest task data on the detail screen
- [ ] Returning the app to foreground refreshes data on the current screen (after 30s throttle, when authenticated)
- [ ] No unnecessary API calls when unauthenticated or within the throttle window
