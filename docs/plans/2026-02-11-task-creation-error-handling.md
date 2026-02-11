# Task Creation Error Handling Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add proper error handling to task creation flow, displaying user-friendly error dialogs when creation fails.

**Architecture:** Catch exceptions from Supabase RPC (`create_task`), parse error messages to identify error types (insufficient points, invalid due date, wallet not found), and display appropriate error dialogs with detailed information. Use Riverpod state management to communicate errors from repository → controller → screen.

**Tech Stack:** Flutter, Riverpod, Freezed, Supabase, slang (i18n)

---

## Background

### Current Problem
When creating a task with insufficient points, the app crashes because:
1. Supabase RPC `validate_task_open_requirements` raises exceptions (e.g., "Insufficient points. Balance: X, Locked: Y, Required: Z")
2. `TaskRepository.createTask()` catches and rethrows the exception
3. `TaskCreationController.createTask()` has no error handling
4. `TaskCreationScreen` assumes success and pops the screen, causing unhandled exception

### Error Cases to Handle
From `supabase/schemas/task/functions/utils/validate_task_open_requirements.sql`:
1. **Insufficient points** (line 56-58): "Insufficient points. Balance: X, Locked: Y, Required: Z"
2. **Due date too soon** (line 28-30): "Due date must be at least X hours from now"
3. **Wallet not found** (line 50-52): "Point wallet not found for user"
4. **Other errors**: Generic error messages

---

## Task 1: Add Error State to TaskCreationController

**Files:**
- Modify: `peppercheck_flutter/lib/features/task/presentation/task_creation_controller.dart:1-86`

**Step 1: Add error field to state**

Add an optional error message field to `TaskCreationRequest`:

```dart
@freezed
abstract class TaskCreationRequest with _$TaskCreationRequest {
  const factory TaskCreationRequest({
    @Default('') String title,
    @Default('') String description,
    @Default('') String criteria,
    DateTime? dueDate,
    @Default('draft') String taskStatus,
    @Default([]) List<String> matchingStrategies,
    String? errorMessage, // Add this field
  }) = _TaskCreationRequest;

  factory TaskCreationRequest.fromJson(Map<String, dynamic> json) =>
      _$TaskCreationRequestFromJson(json);
}
```

**Step 2: Regenerate Freezed code**

Run: `cd peppercheck_flutter && dart run build_runner build --delete-conflicting-outputs`
Expected: Generate `task_creation_request.freezed.dart` and `task_creation_request.g.dart` with the new field

**Step 3: Add error handling to createTask**

Modify `TaskCreationController.createTask()` to catch exceptions and update state:

```dart
Future<bool> createTask() async {
  try {
    // Clear any previous error
    state = state.copyWith(errorMessage: null);

    final taskRepository = ref.read(taskRepositoryProvider);
    final request = state;

    if (_taskId != null) {
      await taskRepository.updateTask(_taskId!, request);
      ref.invalidate(taskProvider(_taskId!));
    } else {
      await taskRepository.createTask(request);
    }

    // Refresh the home screen lists
    ref.invalidate(activeUserTasksProvider);

    return true; // Success
  } catch (e) {
    // Store error in state
    state = state.copyWith(errorMessage: e.toString());
    return false; // Failure
  }
}
```

**Step 4: Commit**

```bash
git add peppercheck_flutter/lib/features/task/domain/task_creation_request.dart
git add peppercheck_flutter/lib/features/task/domain/task_creation_request.freezed.dart
git add peppercheck_flutter/lib/features/task/domain/task_creation_request.g.dart
git add peppercheck_flutter/lib/features/task/presentation/task_creation_controller.dart
git commit -m "feat: add error state to TaskCreationController"
```

---

## Task 2: Create Error Parsing Utility

**Files:**
- Create: `peppercheck_flutter/lib/features/task/domain/task_creation_error.dart`

**Step 1: Define error types**

Create an enum for error types:

```dart
enum TaskCreationErrorType {
  insufficientPoints,
  dueDateTooSoon,
  walletNotFound,
  unknown,
}
```

**Step 2: Create error data class**

Add a class to hold parsed error information:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'task_creation_error.freezed.dart';

enum TaskCreationErrorType {
  insufficientPoints,
  dueDateTooSoon,
  walletNotFound,
  unknown,
}

@freezed
class TaskCreationError with _$TaskCreationError {
  const factory TaskCreationError({
    required TaskCreationErrorType type,
    required String message,
    int? balance,
    int? locked,
    int? required,
    int? minHours,
  }) = _TaskCreationError;

  factory TaskCreationError.parse(String errorMessage) {
    // Parse "Insufficient points. Balance: X, Locked: Y, Required: Z"
    final insufficientPointsRegex = RegExp(
      r'Insufficient points\. Balance: (\d+), Locked: (\d+), Required: (\d+)',
    );
    final match = insufficientPointsRegex.firstMatch(errorMessage);
    if (match != null) {
      return TaskCreationError(
        type: TaskCreationErrorType.insufficientPoints,
        message: errorMessage,
        balance: int.tryParse(match.group(1) ?? ''),
        locked: int.tryParse(match.group(2) ?? ''),
        required: int.tryParse(match.group(3) ?? ''),
      );
    }

    // Parse "Due date must be at least X hours from now"
    final dueDateRegex = RegExp(r'Due date must be at least (\d+) hours from now');
    final dueDateMatch = dueDateRegex.firstMatch(errorMessage);
    if (dueDateMatch != null) {
      return TaskCreationError(
        type: TaskCreationErrorType.dueDateTooSoon,
        message: errorMessage,
        minHours: int.tryParse(dueDateMatch.group(1) ?? ''),
      );
    }

    // Check for wallet not found
    if (errorMessage.contains('Point wallet not found')) {
      return TaskCreationError(
        type: TaskCreationErrorType.walletNotFound,
        message: errorMessage,
      );
    }

    // Unknown error
    return TaskCreationError(
      type: TaskCreationErrorType.unknown,
      message: errorMessage,
    );
  }
}
```

**Step 3: Generate Freezed code**

Run: `cd peppercheck_flutter && dart run build_runner build --delete-conflicting-outputs`
Expected: Generate `task_creation_error.freezed.dart`

**Step 4: Commit**

```bash
git add peppercheck_flutter/lib/features/task/domain/task_creation_error.dart
git add peppercheck_flutter/lib/features/task/domain/task_creation_error.freezed.dart
git commit -m "feat: add error parsing utility for task creation"
```

---

## Task 3: Add i18n Strings for Error Messages

**Files:**
- Modify: `peppercheck_flutter/assets/i18n/ja.i18n.json:78-121`

**Step 1: Add error messages to i18n**

Add error message strings under the `task.creation` section:

```json
{
  "task": {
    "creation": {
      "title": "タスク作成",
      "titleEdit": "タスク編集",
      "sectionInfo": "タスク情報",
      "labelTitle": "タイトル",
      "labelDescription": "詳細 (任意)",
      "labelCriteria": "完了条件",
      "labelDeadline": "期限",
      "sectionMatching": "マッチングプラン",
      "buttonAdd": "追加",
      "buttonCreate": "作成",
      "buttonUpdate": "更新",
      "strategy": {
        "standard": "スタンダード"
      },
      "error": {
        "title": "エラー",
        "insufficientPoints": "ポイントが不足しています",
        "insufficientPointsDetail": "現在の残高: $balance pt\nロック済み: $locked pt\n必要なポイント: $required pt",
        "dueDateTooSoon": "期限が近すぎます",
        "dueDateTooSoonDetail": "タスクの期限は現在時刻から最低 $minHours 時間後である必要があります",
        "walletNotFound": "ポイントウォレットが見つかりません",
        "walletNotFoundDetail": "ポイントウォレットの初期化に問題が発生しています。サポートにお問い合わせください。",
        "unknown": "エラーが発生しました",
        "unknownDetail": "$message",
        "buttonOk": "OK"
      }
    }
  }
}
```

**Step 2: Regenerate slang translations**

Run: `cd peppercheck_flutter && dart run slang`
Expected: Regenerate `lib/gen/slang/strings.g.dart` and `lib/gen/slang/strings_ja.g.dart` with new keys

**Step 3: Commit**

```bash
git add peppercheck_flutter/assets/i18n/ja.i18n.json
git add peppercheck_flutter/lib/gen/slang/strings.g.dart
git add peppercheck_flutter/lib/gen/slang/strings_ja.g.dart
git commit -m "feat: add i18n strings for task creation errors"
```

---

## Task 4: Create Error Dialog Widget

**Files:**
- Create: `peppercheck_flutter/lib/features/task/presentation/widgets/task_creation/task_creation_error_dialog.dart`

**Step 1: Create error dialog widget**

Create a reusable dialog widget:

```dart
import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/features/task/domain/task_creation_error.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class TaskCreationErrorDialog extends StatelessWidget {
  final TaskCreationError error;

  const TaskCreationErrorDialog({
    super.key,
    required this.error,
  });

  String _getTitle() {
    final errorStrings = t.task.creation.error;
    switch (error.type) {
      case TaskCreationErrorType.insufficientPoints:
        return errorStrings.insufficientPoints;
      case TaskCreationErrorType.dueDateTooSoon:
        return errorStrings.dueDateTooSoon;
      case TaskCreationErrorType.walletNotFound:
        return errorStrings.walletNotFound;
      case TaskCreationErrorType.unknown:
        return errorStrings.unknown;
    }
  }

  String _getDetailMessage() {
    final errorStrings = t.task.creation.error;
    switch (error.type) {
      case TaskCreationErrorType.insufficientPoints:
        return errorStrings.insufficientPointsDetail(
          balance: error.balance ?? 0,
          locked: error.locked ?? 0,
          required: error.required ?? 0,
        );
      case TaskCreationErrorType.dueDateTooSoon:
        return errorStrings.dueDateTooSoonDetail(
          minHours: error.minHours ?? 0,
        );
      case TaskCreationErrorType.walletNotFound:
        return errorStrings.walletNotFoundDetail;
      case TaskCreationErrorType.unknown:
        return errorStrings.unknownDetail(message: error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.backgroundWhite,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      title: Text(
        _getTitle(),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
      ),
      content: Text(
        _getDetailMessage(),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
            ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentYellow,
            foregroundColor: AppColors.textPrimary,
          ),
          child: Text(t.task.creation.error.buttonOk),
        ),
      ],
    );
  }
}
```

**Step 2: Commit**

```bash
git add peppercheck_flutter/lib/features/task/presentation/widgets/task_creation/task_creation_error_dialog.dart
git commit -m "feat: create error dialog widget for task creation"
```

---

## Task 5: Integrate Error Handling in TaskCreationScreen

**Files:**
- Modify: `peppercheck_flutter/lib/features/task/presentation/task_creation_screen.dart:1-80`

**Step 1: Import required dependencies**

Add imports at the top of the file:

```dart
import 'package:peppercheck_flutter/features/task/domain/task_creation_error.dart';
import 'package:peppercheck_flutter/features/task/presentation/widgets/task_creation/task_creation_error_dialog.dart';
```

**Step 2: Add error listener**

Replace the current button's `onPressed` handler (lines 64-69) with error-aware logic:

```dart
PrimaryActionButton(
  text: buttonText,
  onPressed: controller.isFormValid
      ? () async {
          final success = await controller.createTask();
          if (context.mounted) {
            if (success) {
              // Success: close the screen
              Navigator.of(context).pop();
            } else {
              // Error: show dialog
              final errorMessage = state.errorMessage;
              if (errorMessage != null) {
                final error = TaskCreationError.parse(errorMessage);
                await showDialog(
                  context: context,
                  builder: (context) => TaskCreationErrorDialog(error: error),
                );
              }
            }
          }
        }
      : null,
),
```

**Step 3: Test manually with emulator**

Run: `cd peppercheck_flutter && flutter run`

Test scenarios:
1. Create task with insufficient points → Should show error dialog with balance details
2. Create task with due date too soon → Should show error dialog with minimum hours
3. Create task successfully → Should close the screen normally

**Step 4: Commit**

```bash
git add peppercheck_flutter/lib/features/task/presentation/task_creation_screen.dart
git commit -m "feat: integrate error handling in task creation screen"
```

---

## Task 6: Create GitHub Issue for Phase 2

**Files:**
- None (GitHub issue creation)

**Step 1: Create GitHub issue**

Create an issue with the following content:

**Title:** Phase 2: Add "Save as Draft and Charge" button to task creation error dialog

**Body:**
```markdown
## Context
In Phase 1, we implemented error dialogs for task creation failures. When a user encounters an "Insufficient Points" error, they currently see an OK button that closes the dialog and keeps them on the task creation screen.

## Goal
Enhance the user experience by allowing users to:
1. Automatically save their task as a draft (status='draft')
2. Navigate to the charge screen in one click
3. Return to the draft task after charging

## Implementation Details

### Dialog Changes
- Add a "Save as Draft and Charge" button to the insufficient points error dialog
- Keep the OK button as a secondary option

### Flow
1. User clicks "Save as Draft and Charge"
2. Controller automatically changes `taskStatus` to 'draft'
3. Save task via `createTask()` (draft tasks skip point validation)
4. Navigate to charge screen
5. After charging, provide navigation back to draft tasks list or edit screen

### Considerations
- Decide on return destination after charging (home? draft tasks? edit screen?)
- Ensure draft task is properly saved before navigation
- Handle errors during draft save gracefully
- Consider adding a toast/snackbar: "Task saved as draft"

## Acceptance Criteria
- [ ] "Insufficient Points" error dialog has two buttons: "OK" and "Save as Draft and Charge"
- [ ] Clicking "Save as Draft and Charge" saves task with status='draft'
- [ ] User is navigated to charge screen
- [ ] Task input data is preserved
- [ ] After charging, user can easily return to continue their task

## Related
- Phase 1 PR: [Link to PR after merge]
- Design doc: `docs/plans/2026-02-11-task-creation-error-handling.md`
```

Run: `gh issue create --title "Phase 2: Add \"Save as Draft and Charge\" button to task creation error dialog" --body "[paste body above]" --label "enhancement"`

Expected: Issue created successfully with issue number

**Step 2: Commit documentation update**

Add a note to the plan document:

```bash
echo "\n\n## Phase 2 (Future Work)\n\nSee GitHub Issue #[issue-number] for Phase 2 implementation details.\n" >> docs/plans/2026-02-11-task-creation-error-handling.md
git add docs/plans/2026-02-11-task-creation-error-handling.md
git commit -m "docs: add Phase 2 reference to task creation error handling plan"
```

---

## Testing Strategy

### Manual Testing Checklist
- [ ] Insufficient points error shows correct balance, locked, and required values
- [ ] Due date too soon error shows minimum hours requirement
- [ ] Wallet not found error shows user-friendly message
- [ ] Dialog closes on OK button
- [ ] After closing dialog, user remains on task creation screen with form data intact
- [ ] Successful task creation closes screen normally

### Edge Cases
- [ ] Network error during task creation
- [ ] Malformed error messages from backend
- [ ] Multiple rapid clicks on create button
- [ ] Task creation while offline

---

## Rollout Plan

1. Deploy Phase 1 changes
2. Monitor error logs for any unhandled exceptions
3. Gather user feedback on error dialog clarity
4. Implement Phase 2 based on user feedback and prioritization

---

## Dependencies

- Supabase RPC: `create_task` (already exists)
- Validation function: `validate_task_open_requirements` (already exists)
- Flutter packages: freezed, riverpod, slang (already installed)

---

## Risks & Mitigations

**Risk:** Error message format changes in backend
**Mitigation:** Regex parsing is flexible; unknown errors fall back to generic message

**Risk:** Missing translations for new error keys
**Mitigation:** slang will generate compile-time errors if keys are missing

**Risk:** User confusion about what to do after error
**Mitigation:** Clear error messages with specific details; Phase 2 will add direct action button

## Phase 2 (Future Work)

See GitHub Issue #215 for Phase 2 implementation details.
