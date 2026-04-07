# Matching Plan Point Display

## Summary

Replace the hardcoded yen-based pricing display (¥50/¥100) in the task creation screen's matching plan selection with point-based display (1pt/2pt) fetched dynamically from the backend RPC.

## Background

The app has fully transitioned from yen-based billing to a point consumption system (regular points + trial points). However, the matching plan selection UI in the task creation screen still displays hardcoded yen amounts (`selectedStrategies.length * 50` → `¥$totalFee`). This needs to be updated to reflect the actual point costs.

### Current state

- **UI:** `matching_strategy_selection_section.dart` hardcodes `¥50` per strategy
- **Backend:** `get_point_for_matching_strategy('standard')` returns `1` (point)
- **Actual flow:** When a task is opened, `create_task_referee_requests_from_json()` locks 1 point per standard strategy from the user's wallet

## Design

### Display format

`{totalPoints}pt` — consistent with the payment dashboard screen (e.g., `1pt`, `2pt`).

### Point cost retrieval

Fetch the cost via Supabase RPC (`get_point_for_matching_strategy`) once when the screen renders. Cache the result in a Riverpod provider so subsequent rebuilds don't trigger additional DB calls.

### Changes

#### 1. BillingRepository — add `fetchMatchingStrategyCost()`

Add a method to `billing_repository.dart`:

```dart
Future<int> fetchMatchingStrategyCost(String strategy) async {
  final result = await _supabase.rpc(
    'get_point_for_matching_strategy',
    params: {'p_strategy': strategy},
  );
  return result as int;
}
```

#### 2. billing_providers.dart — add `matchingStrategyCostProvider`

```dart
@riverpod
FutureOr<int> matchingStrategyCost(Ref ref, String strategy) {
  return ref.read(billingRepositoryProvider).fetchMatchingStrategyCost(strategy);
}
```

- Parameterized by strategy name (`.family` equivalent)
- Cached per unique strategy — `matchingStrategyCost('standard')` fetches once, returns cache on subsequent reads

#### 3. MatchingStrategySelectionSection — convert to ConsumerWidget

- Change from `StatelessWidget` to `ConsumerWidget`
- Watch `matchingStrategyCostProvider('standard')` to get cost per plan
- Replace `selectedStrategies.length * 50` with `selectedStrategies.length * costPerPlan`
- Replace `'¥$totalFee'` with `'${totalPoints}pt'`
- Handle `AsyncValue` states: loading (show `--pt` or small indicator), error (show `--pt`), data (show calculated total)

#### 4. No changes required

- `TaskCreationScreen` — structure unchanged
- `TaskCreationController` — no pricing logic added here
- `_TrialPointNotice` — independent, unchanged
- DB schema / `get_point_for_matching_strategy()` — used as-is

### Data flow

```
Screen opens
  → MatchingStrategySelectionSection.build()
  → ref.watch(matchingStrategyCostProvider('standard'))
  → [first time] BillingRepository.fetchMatchingStrategyCost('standard')
  → Supabase RPC: get_point_for_matching_strategy('standard')
  → returns 1
  → cached in provider

User adds/removes plan
  → selectedStrategies changes → widget rebuild
  → ref.watch(...) returns cached value (no DB call)
  → totalPoints = selectedStrategies.length * 1
  → displays "1pt" or "2pt"
```

### Future evolution

When more matching plans are introduced (e.g., light, premium), the single-strategy provider can be replaced with a bulk-fetch provider:

```dart
// New RPC: get_all_matching_strategy_costs() → {'standard': 1, 'premium': 3}
@riverpod
FutureOr<Map<String, int>> allMatchingStrategyCosts(Ref ref) { ... }
```

This is out of scope for this change — current implementation handles only `standard`.
