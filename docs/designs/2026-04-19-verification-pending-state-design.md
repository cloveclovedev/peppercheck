# Show Verification Pending State During Connect Onboarding

**Issue**: #355
**Date**: 2026-04-19

## Problem

After completing Stripe Connect onboarding, if identity verification is still pending, the app shows the "出金設定を再開する" (resume payout setup) button. This is misleading because the user has already completed all required steps and is simply waiting for Stripe's verification.

## Decision Log

- **Logic location**: Flutter-side parsing of `connect_requirements` JSONB (not a DB-side computed column). Rationale: raw Stripe data is already stored; Flutter gains full flexibility without schema changes.
- **Real-time updates**: Not included in v1.0. The existing `AppLifecycleListener.onResume` → re-fetch pattern is sufficient. Supabase Realtime can be added later.
- **Pending verification message**: Generic "審査中です。完了までしばらくお待ちください" (not identity-specific), because `pending_verification` can include non-identity items (e.g., bank account verification).
- **Edge case (`currently_due` empty, `pending_verification` empty, `payouts_enabled=false`)**: Treated as `isInProgress` (show resume button). This is a rare transitional state.

## State Model

`PayoutSetupStatus` gains two new fields parsed from `connect_requirements`:

```dart
List<String> currentlyDue        // from requirements.currently_due
List<String> pendingVerification // from requirements.pending_verification
```

State priority (evaluated top-to-bottom, first match wins):

| Condition | State | UI |
|---|---|---|
| `payouts_enabled = true` | `isComplete` | No change |
| `payouts_enabled = false`, `currentlyDue` empty, `pendingVerification` non-empty | `isPendingVerification` | Message + no action button |
| `payouts_enabled = false`, otherwise | `isInProgress` / `isNotStarted` | No change (existing behavior) |

`isInProgress` and `isNotStarted` retain their existing `charges_enabled`-based distinction.

## Changes

### 1. `payout_setup_status.dart`

Add `currentlyDue` and `pendingVerification` fields. These are not directly deserialized from the Supabase row JSON (which has a nested `connect_requirements` JSONB column), so they are populated by the repository layer, not `fromJson`.

Add `isPendingVerification` getter:

```dart
bool get isPendingVerification =>
    !payoutsEnabled && currentlyDue.isEmpty && pendingVerification.isNotEmpty;
```

Update `isInProgress` to exclude the pending verification case:

```dart
bool get isInProgress =>
    chargesEnabled && !payoutsEnabled && !isPendingVerification;
```

### 2. `stripe_payout_repository.dart`

Add `connect_requirements` to the select query. Parse `currently_due` and `pending_verification` from the JSONB before constructing `PayoutSetupStatus`:

```dart
final data = await _supabase
    .from('stripe_accounts')
    .select('charges_enabled, payouts_enabled, connect_requirements')
    .maybeSingle();

// Parse connect_requirements
final requirements = data?['connect_requirements'] as Map<String, dynamic>?;
final currentlyDue = (requirements?['currently_due'] as List?)
    ?.cast<String>() ?? [];
final pendingVerification = (requirements?['pending_verification'] as List?)
    ?.cast<String>() ?? [];
```

### 3. `payout_setup_section.dart`

Add a branch for `isPendingVerification` before the existing `isInProgress` / `isNotStarted` branches. Display:

- Message: `t.payout.verificationPendingDescription` ("審査中です。完了までしばらくお待ちください")
- No action button (neither resume nor setup)
- No hints section

### 4. i18n (`ja.i18n.json`)

Add one key:

```json
"verificationPendingDescription": "審査中です。完了までしばらくお待ちください"
```

## Not Changed

- **DB schema**: No migration needed. `connect_requirements` JSONB is already stored and updated by the webhook.
- **Webhook handler**: Already saves full `account.requirements` object (#345).
- **Realtime subscription**: Deferred; out of v1.0 scope.
- **`payout_controller.dart`**: No changes needed; it already fetches status and invalidates on resume.
