# Draft Task Deletion

**Date**: 2026-04-27

## Problem

Once a task is created as a draft, there is no way for the tasker to delete it. Drafts accumulate as the user experiments with creating tasks, and there is no recovery path for unwanted ones. Users currently can only abandon drafts, which leaves them visible in the home screen.

Deletion must be restricted to drafts only. Tasks that have transitioned to `open` (matching started) or `closed` have related records (referee requests, judgements, evidence, rewards) whose removal has complex implications, so they remain non-deletable.

## Decision Log

- **UI placement**: Below the existing "タスク編集" button inside `TaskDetailInfoSection`, only when `task.status == 'draft'`. Reuses the visual style of the account deletion button (`OutlinedButton`, red-tinted, `Icons.delete_outline`) so destructive actions look consistent across the app.
- **Common widget extraction**: A new `DestructiveActionButton` is added in `common_widgets/` (red-tinted variant of `ActionButton`). Both the new task delete button and the existing account deletion button (`account_actions_section.dart`) migrate to it in this PR. The dialog uses the existing `BaseDialog`. The cancel `TextButton` inside the dialog is written inline — generalizing it (only ~5 lines per usage) is not worth the extra widget file.
- **Confirmation dialog**: Single-step, minimal — title only ("このタスクを削除しますか?"), no body warning text. Drafts are low-stakes; the two-step confirmation used for account deletion would be excessive. Cancel + Delete buttons.
- **Backend**: New RPC `public.delete_task(p_task_id uuid)` rather than a direct `supabase.from('tasks').delete()`. Rationale: matches the existing `create_task` / `update_task` RPC pattern so all task CRUD lives in one discoverable place. A bare RLS-only approach would scatter the status check into policy logic that is harder to find.
- **Defense in depth**: Existing RLS DELETE policy (`tasker_id = auth.uid()`) is kept as-is. With `SECURITY INVOKER`, the RPC respects RLS, so ownership is enforced twice (RPC explicit check + RLS).
- **Post-delete navigation**: `context.go('/')` to home + Snackbar "削除しました". Mirrors account deletion completion UX (`account_actions_section.dart:118-121`).
- **Race condition**: If matching starts between page render and delete tap, the RPC's `status <> 'draft'` check rejects the call. The UI surfaces a generic "削除できませんでした" Snackbar.

## Database Layer

### New RPC: `delete_task`

File: `supabase/schemas/task/functions/delete_task.sql`

```sql
CREATE OR REPLACE FUNCTION public.delete_task(p_task_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
    v_current_status public.task_status;
    v_tasker_id uuid;
BEGIN
    SELECT status, tasker_id INTO v_current_status, v_tasker_id
    FROM public.tasks
    WHERE id = p_task_id;

    IF v_current_status IS NULL THEN
        RAISE EXCEPTION 'Task not found';
    END IF;

    IF v_tasker_id != auth.uid() THEN
        RAISE EXCEPTION 'Not authorized to delete this task';
    END IF;

    IF v_current_status != 'draft' THEN
        RAISE EXCEPTION 'Only draft tasks can be deleted';
    END IF;

    DELETE FROM public.tasks WHERE id = p_task_id;
END;
$$;
```

Style mirrors `update_task.sql` (same auth/status check ordering, same exception messages format, `SECURITY INVOKER`).

### config.toml registration

Add the new function to `supabase/config.toml` under `[db.migrations].schema_paths`, alongside the existing task functions:

```toml
"./schemas/task/functions/create_task.sql",
"./schemas/task/functions/update_task.sql",
"./schemas/task/functions/delete_task.sql",   # NEW
```

### Migration generation

Run `supabase db diff -f add_delete_task_function` after editing `config.toml`. Verify with `./scripts/db-reset-and-clear-android-emulators-cache.sh`.

### RLS

No change. The existing `Tasks: delete if tasker` policy remains.

### FK CASCADE

No change. `task_referee_requests`, `task_evidences`, `reports` already cascade on `tasks` deletion. Drafts should not have any of these rows in practice; the cascades remain a safety net.

### pgTAP tests

File: `supabase/tests/database/delete_task.test.sql` (matches existing `<feature>.test.sql` naming).

Cases:

1. ✅ Tasker deletes their own draft task → row removed.
2. ✅ Non-owner attempts deletion → exception "Not authorized to delete this task".
3. ✅ Tasker attempts to delete an `open` task → exception "Only draft tasks can be deleted".
4. ✅ Tasker attempts to delete a `closed` task → exception "Only draft tasks can be deleted".
5. ✅ Non-existent task ID → exception "Task not found".

After adding tests, run the full test suite to verify no regressions (per `.claude/rules/db-testing.md`).

## Flutter Layer

### New common widget

#### `lib/common_widgets/destructive_action_button.dart`

Red-tinted variant of the existing `ActionButton` (`common_widgets/action_button.dart`). Same API (`text`, `icon`, `onPressed`, `isLoading`), but uses `AppColors.textError` for foreground / border / icon, and a red-tinted background:

```dart
final containerColor = active
    ? AppColors.textError.withValues(alpha: 0.1)
    : AppColors.textPrimary.withValues(alpha: 0.05);
final contentColor = active
    ? AppColors.textError
    : AppColors.textPrimary.withValues(alpha: 0.4);
final borderColor = active
    ? AppColors.textError.withValues(alpha: 0.5)
    : AppColors.textPrimary.withValues(alpha: 0.2);
```

Width, padding, border radius, icon-text layout, and loading-spinner behavior all mirror `ActionButton` for visual consistency.

### New feature files

#### 1. `task_repository.dart` — add `deleteTask` method

Add to `peppercheck_flutter/lib/features/task/data/task_repository.dart`:

```dart
Future<void> deleteTask(String taskId) async {
  await _supabase.rpc('delete_task', params: {'p_task_id': taskId});
}
```

#### 2. `lib/features/task/presentation/task_deletion_controller.dart`

Riverpod `AsyncNotifier` (codegen). Exposes `deleteTask(String taskId, {required VoidCallback onSuccess})`. State: `AsyncValue<void>` (initial = `AsyncData(null)`, transitions to `AsyncLoading` during RPC, then `AsyncData` on success or `AsyncError` on failure).

Naming note: per `.claude/rules/flutter.md`, do NOT name the method `update`. Use `deleteTask`.

#### 3. `lib/features/task/presentation/widgets/task_detail/delete_task_button.dart`

`ConsumerWidget` taking a `Task`. Wraps the new `DestructiveActionButton`:

- Label: `t.task.deletion.button` ("タスク削除")
- Icon: `Icons.delete_outline`
- `isLoading` from `taskDeletionControllerProvider` AsyncValue
- On tap → show `DeleteTaskConfirmationDialog`. On confirm → call controller's `deleteTask(task.id, onSuccess: ...)`.

#### 4. `lib/features/task/presentation/widgets/task_detail/delete_task_confirmation_dialog.dart`

Wraps the existing `BaseDialog` (`common_widgets/base_dialog.dart`):

- `title`: `t.task.deletion.confirmTitle` ("このタスクを削除しますか?")
- `content`: `SizedBox.shrink()` — `BaseDialog.content` is required, so this is the workaround for a title-only dialog. The internal `EdgeInsets.fromLTRB(24, 16, 24, 8)` padding still applies, leaving small whitespace below the title; this is acceptable for the minimalist design.
- `actions`:
  - Cancel: inline `TextButton` with `foregroundColor: AppColors.textSecondary`, label `t.common.cancel`, pops dialog
  - Delete: inline `TextButton` with `foregroundColor: AppColors.textError`, label `t.task.deletion.deleteButton`, pops dialog and triggers the `onConfirm` callback

### Changed files

#### `task_detail_info_section.dart`

Inside the existing `if (task.status == 'draft')` block (line 39), add the delete button below the edit button with `SizedBox(height: AppSizes.spacingSmall)` between them:

```dart
if (task.status == 'draft') ...[
  const SizedBox(height: AppSizes.sectionGap),
  ActionButton(
    text: t.task.creation.titleEdit,
    icon: Icons.edit,
    onPressed: () { context.push('/create_task', extra: task); },
  ),
  const SizedBox(height: AppSizes.spacingSmall),
  DeleteTaskButton(task: task),
],
```

No conversion of `TaskDetailInfoSection` itself is needed; `DeleteTaskButton` handles its own Riverpod wiring as a `ConsumerWidget`.

#### `account_actions_section.dart` — migrate to `DestructiveActionButton`

Replace the inline red-tinted `OutlinedButton` (`account_actions_section.dart:60-92`) with `DestructiveActionButton`:

```dart
DestructiveActionButton(
  text: t.account.actions.deleteAccount,
  icon: Icons.delete_outline,
  onPressed: active ? () => _showConfirmation(context, ref) : null,
)
```

The "delete blocked" reason text above the button (`account_actions_section.dart:52-59`) stays as-is.

After the replacement, the now-unused local color variables (`containerColor`, `contentColor`, `borderColor` at lines 39-47) become dead code and should be removed. `_buildDeleteButton` simplifies to: the `Column` with the conditional reason text + the new `DestructiveActionButton`.

### Success flow

The button widget's `onSuccess` callback runs inside the controller after the RPC succeeds:

1. Show Snackbar `t.task.deletion.deletedSnackbar` ("削除しました")
2. `context.go('/')` to navigate to home

### Error flow

On `AsyncError` from the controller, show Snackbar `t.task.deletion.failedSnackbar` ("削除できませんでした"). The user stays on the detail screen. They can refresh to see the up-to-date status (e.g., the delete button will disappear if the task moved to `open`).

### i18n

Add to `peppercheck_flutter/assets/i18n/ja.i18n.json` under `task`:

```json
"deletion": {
  "button": "タスク削除",
  "confirmTitle": "このタスクを削除しますか?",
  "deleteButton": "削除",
  "deletedSnackbar": "削除しました",
  "failedSnackbar": "削除できませんでした"
}
```

The cancel button reuses the existing `t.common.cancel` ("キャンセル").

Run codegen (`flutter pub run build_runner build --delete-conflicting-outputs` or the project-specific slang command) so `t.task.deletion.*` is available.

## Edge Cases

| Case | Behavior |
|---|---|
| Race: status changes from `draft` to `open` between render and tap | RPC raises "Only draft tasks can be deleted" → failure Snackbar |
| Double-tap | Button disabled during `AsyncLoading` |
| Network failure | `AsyncError` → failure Snackbar; user can retry |
| Task already deleted on another device | RPC raises "Task not found" → failure Snackbar |

## Out of Scope

- Bulk deletion of drafts.
- Soft delete / undo. The single-step dialog is the only safety net.
- Deletion of `open` or `closed` tasks. Their lifecycle requires separate design.
- Renaming or reorganizing the existing `billing/` Flutter feature directory.

## Testing

- **DB**: pgTAP cases listed above + full suite regression run.
- **Flutter**: Manual end-to-end on a real device — create draft → open detail → delete → confirm Snackbar + return to home → confirm draft no longer in home list.
- **Race-condition**: Manually verify by transitioning a task to `open` server-side, then tapping delete from a stale detail page; expect failure Snackbar.
- **Build**: `cd peppercheck_flutter && flutter build apk --debug -t lib/main_debug.dart 2>&1 | tail -10` before completion.
