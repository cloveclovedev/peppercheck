# Error State Separation Refactoring Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Separate initialization errors from creation errors in task creation flow to prevent form disappearance during error dialogs.

**Architecture:** Add `creationError` field to `TaskCreationState` for creation/submission errors, keeping `AsyncValue.error` exclusively for initialization errors. This ensures creation errors don't affect form rendering.

**Tech Stack:** Flutter, Riverpod (AsyncNotifier), Freezed, Slang i18n

---

### Task 1: Add creationError field to TaskCreationState

**Files:**
- Modify: `peppercheck_flutter/lib/features/task/presentation/task_creation_state.dart`

**Step 1: Add creationError field to TaskCreationState**

Update the freezed class to include optional creationError field:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:peppercheck_flutter/features/task/domain/task_creation_request.dart';
import 'package:peppercheck_flutter/features/task/domain/task_creation_error.dart';

part 'task_creation_state.freezed.dart';

@freezed
class TaskCreationState with _$TaskCreationState {
  const factory TaskCreationState({
    required TaskCreationRequest request,
    TaskCreationError? creationError,
  }) = _TaskCreationState;
}
```

**Step 2: Regenerate freezed code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Success, new creationError field available in copyWith

**Step 3: Commit**

```bash
git add peppercheck_flutter/lib/features/task/presentation/task_creation_state.dart peppercheck_flutter/lib/features/task/presentation/task_creation_state.freezed.dart
git commit -m "feat: add creationError field to TaskCreationState"
```

---

### Task 2: Update controller to separate creation errors

**Files:**
- Modify: `peppercheck_flutter/lib/features/task/presentation/task_creation_controller.dart`

**Step 1: Update build method to initialize creationError as null**

Modify the build method to explicitly set creationError to null:

```dart
@override
FutureOr<TaskCreationState> build(Task? initialTask) {
  if (initialTask != null) {
    _taskId = initialTask.id;
    return TaskCreationState(
      request: TaskCreationRequest(
        title: initialTask.title,
        description: initialTask.description ?? '',
        criteria: initialTask.criteria ?? '',
        dueDate: initialTask.dueDate != null
            ? DateTime.tryParse(initialTask.dueDate!)
            : null,
        taskStatus: initialTask.status,
        matchingStrategies: initialTask.refereeRequests
            .map((r) => r.matchingStrategy)
            .toList(),
      ),
      creationError: null,
    );
  }
  _taskId = null;
  return const TaskCreationState(
    request: TaskCreationRequest(),
    creationError: null,
  );
}
```

**Step 2: Refactor createTask to use creationError field**

Replace AsyncValue.guard with explicit try-catch that stores errors in creationError field:

```dart
Future<void> createTask() async {
  final currentState = state.value;
  if (currentState == null) return;

  // Clear any previous creation error
  state = AsyncData(currentState.copyWith(creationError: null));
  state = const AsyncLoading();

  try {
    final taskRepository = ref.read(taskRepositoryProvider);
    final request = currentState.request;

    if (_taskId != null) {
      await taskRepository.updateTask(_taskId!, request);
      ref.invalidate(taskProvider(_taskId!));
    } else {
      await taskRepository.createTask(request);
    }

    // Refresh the home screen lists
    ref.invalidate(activeUserTasksProvider);

    // Success - return to data state with no error
    state = AsyncData(currentState.copyWith(creationError: null));
  } catch (error, stackTrace) {
    ref.read(loggerProvider).e(
      'Task creation failed',
      error: error,
      stackTrace: stackTrace,
    );

    // Parse and store creation error, but keep state as AsyncData
    final creationError = TaskCreationError.parse(error.toString());
    state = AsyncData(currentState.copyWith(creationError: creationError));
  }
}
```

**Step 3: Add clearCreationError method**

Add a method to clear the creation error:

```dart
void clearCreationError() {
  final currentState = state.value;
  if (currentState?.creationError != null) {
    state = AsyncData(currentState!.copyWith(creationError: null));
  }
}
```

**Step 4: Remove old clearError method**

Delete the `clearError()` method as it's no longer needed (replaced by `clearCreationError()`):

```dart
// DELETE THIS METHOD:
void clearError() {
  // If state has error but also has cached data, restore the data state
  if (state.hasError && state.hasValue) {
    state = AsyncData(state.value!);
  }
}
```

**Step 5: Commit**

```bash
git add peppercheck_flutter/lib/features/task/presentation/task_creation_controller.dart
git commit -m "refactor: store creation errors in state field instead of AsyncValue"
```

---

### Task 3: Update screen to listen to creationError

**Files:**
- Modify: `peppercheck_flutter/lib/features/task/presentation/task_creation_screen.dart`

**Step 1: Replace ref.listen to watch creationError field**

Replace the existing ref.listen implementation with one that watches the creationError field:

```dart
// Listen for creation errors and show dialog
ref.listen(
  taskCreationControllerProvider(task).select((state) => state.value?.creationError),
  (previous, next) {
    if (next != null) {
      showDialog(
        context: context,
        builder: (context) => TaskCreationErrorDialog(error: next),
      ).then((_) {
        // Clear error after dialog is dismissed
        controller.clearCreationError();
      });
    }
  },
);
```

**Step 2: Simplify button onPressed logic**

Remove the error checking logic from button since errors no longer affect AsyncValue state:

```dart
PrimaryActionButton(
  text: buttonText,
  onPressed: controller.isFormValid
      ? () async {
          await controller.createTask();
          if (context.mounted) {
            final currentState = ref.read(taskCreationControllerProvider(task));
            // Success check: if no creation error, close screen
            if (currentState.value?.creationError == null) {
              Navigator.of(context).pop();
            }
            // Error dialog is handled by ref.listen
          }
        }
      : null,
),
```

**Step 3: Update asyncState.when error case comment**

Update the comment in the error case to clarify it's for initialization errors only:

```dart
asyncState.when(
  data: (state) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TaskFormSection(initialData: state.request, task: task),
      if (state.request.taskStatus == 'open') ...[
        const SizedBox(height: AppSizes.sectionGap),
        MatchingStrategySelectionSection(
          selectedStrategies: state.request.matchingStrategies,
          onStrategiesChange: controller.updateMatchingStrategies,
        ),
      ],
      const SizedBox(height: AppSizes.buttonGap),
      PrimaryActionButton(
        text: buttonText,
        onPressed: controller.isFormValid
            ? () async {
                await controller.createTask();
                if (context.mounted) {
                  final currentState = ref.read(taskCreationControllerProvider(task));
                  if (currentState.value?.creationError == null) {
                    Navigator.of(context).pop();
                  }
                }
              }
            : null,
      ),
    ],
  ),
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (error, stack) => Center(
    // This error case is for initialization errors only
    // Creation errors are handled via ref.listen and stored in state.creationError
    child: Text('初期化エラーが発生しました'),
  ),
),
```

**Step 4: Commit**

```bash
git add peppercheck_flutter/lib/features/task/presentation/task_creation_screen.dart
git commit -m "refactor: listen to creationError field instead of AsyncValue error"
```

---

### Task 4: Verify implementation on Android emulator

**Files:**
- None (manual testing)

**Step 1: Start Android emulator**

Run: `open -a /Applications/Android\ Studio.app` or use existing running emulator
Expected: Emulator running and accessible

**Step 2: Run Flutter app**

Run: `cd peppercheck_flutter && flutter run`
Expected: App builds and launches on emulator

**Step 3: Test insufficient points error scenario**

Manual steps:
1. Navigate to task creation screen
2. Fill in all required fields:
   - Title: "Test Task"
   - Criteria: "Test criteria"
   - Due date: tomorrow
   - Matching strategies: select at least one
3. Tap "作成" button
4. Expected: Error dialog appears with "ポイントが不足しています" and point details
5. Verify: Behind the dialog, the form is still visible (NOT "初期化エラーが発生しました")
6. Tap "OK" on dialog
7. Expected: Dialog closes, form is still visible and editable
8. Verify: Can edit the title field
9. Expected: Changes are reflected in the UI

**Step 4: Test form editing after error**

Manual steps:
1. After dismissing error dialog, change title to "Modified Test Task"
2. Tap "作成" button again
3. Expected: Same error dialog appears (still insufficient points)
4. Verify: Form still shows "Modified Test Task" behind dialog
5. Tap "OK" and verify form is editable again

**Step 5: Document test results**

Create a comment or note with test results:
- ✅ Error dialog shows correct error message
- ✅ Form remains visible behind dialog (not "初期化エラー")
- ✅ Form is editable after dismissing dialog
- ✅ Form state persists through multiple error attempts

---

### Task 5: Update implementation plan with completion notes

**Files:**
- Modify: `docs/plans/2026-02-11-task-creation-error-handling.md`

**Step 1: Add refactoring completion note**

Add a note at the top of the original plan documenting the refactoring:

```markdown
## Update (2026-02-11)

**Refactoring completed:** Error state separation implemented to fix UX issue where form disappeared during error dialogs.

- Created separate plan: `docs/plans/2026-02-11-refactor-error-state-separation.md`
- **Key change:** Separated initialization errors (AsyncValue.error) from creation errors (TaskCreationState.creationError field)
- **Result:** Error dialogs now show without affecting form rendering

See refactoring plan for implementation details.

---
```

**Step 2: Commit**

```bash
git add docs/plans/2026-02-11-task-creation-error-handling.md
git commit -m "docs: add refactoring completion note to original plan"
```

---

## Execution Handoff

Plan complete and saved to `docs/plans/2026-02-11-refactor-error-state-separation.md`. Two execution options:

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

Which approach?
