# Confirm Judgement Flutter UI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add UI for Taskers to confirm referee judgement results with a binary rating (fair/unfair) inside the existing JudgementSection widget.

**Architecture:** Extend the existing `JudgementSection` with a confirm area below each result card (when the user is Tasker and judgement is unconfirmed). Add `confirmJudgement()` to the repository and controller layers. The confirm area has thumbs up/down toggle, optional comment, and a confirm button.

**Tech Stack:** Flutter, Riverpod (riverpod_annotation code gen), Supabase RPC, freezed models, slang i18n

---

### Task 1: Add i18n strings for confirm UI

**Files:**
- Modify: `peppercheck_flutter/assets/i18n/ja.i18n.json`

**Step 1: Add confirm strings to ja.i18n.json**

In `peppercheck_flutter/assets/i18n/ja.i18n.json`, add a `confirm` object inside `task.judgement`:

```json
"judgement": {
  "title": "判定",
  "comment": "コメント",
  "commentPlaceholder": "判定理由を記述してください",
  "approve": "承認",
  "reject": "却下",
  "approved": "承認済み",
  "rejected": "却下済み",
  "success": "判定を送信しました",
  "error": "エラーが発生しました: $message",
  "commentRequired": "コメントを入力してください",
  "confirm": {
    "question": "この判定は適切でしたか？",
    "fair": "適切",
    "unfair": "不適切",
    "comment": "コメント（任意）",
    "submit": "確認する",
    "success": "判定を確認しました"
  }
}
```

**Step 2: Run slang code generation**

Run: `cd peppercheck_flutter && dart run build_runner build --delete-conflicting-outputs`

Expected: The generated file `lib/gen/slang/strings_ja.g.dart` will contain a new `TranslationsTaskJudgementConfirmJa` class with the confirm strings accessible via `t.task.judgement.confirm.question`, etc.

**Step 3: Commit**

```bash
git add peppercheck_flutter/assets/i18n/ja.i18n.json peppercheck_flutter/lib/gen/slang/
git commit -m "feat(flutter): add i18n strings for judgement confirm UI"
```

---

### Task 2: Add `confirmJudgement()` to JudgementRepository

**Files:**
- Modify: `peppercheck_flutter/lib/features/judgement/data/judgement_repository.dart`

**Step 1: Add the confirmJudgement method**

Add this method to the `JudgementRepository` class in `peppercheck_flutter/lib/features/judgement/data/judgement_repository.dart`, after the existing `judgeEvidence` method:

```dart
Future<void> confirmJudgement({
  required String judgementId,
  required bool isPositive,
  String? comment,
}) async {
  try {
    await _client.rpc(
      'confirm_judgement_and_rate_referee',
      params: {
        'p_judgement_id': judgementId,
        'p_is_positive': isPositive,
        if (comment != null && comment.isNotEmpty) 'p_comment': comment,
      },
    );
  } catch (e, st) {
    _logger.e('confirmJudgement failed', error: e, stackTrace: st);
    rethrow;
  }
}
```

**Step 2: Commit**

```bash
git add peppercheck_flutter/lib/features/judgement/data/judgement_repository.dart
git commit -m "feat(flutter): add confirmJudgement to JudgementRepository"
```

---

### Task 3: Add `confirmJudgement()` to JudgementController

**Files:**
- Modify: `peppercheck_flutter/lib/features/judgement/presentation/controllers/judgement_controller.dart`

**Step 1: Add the confirmJudgement action**

Add this method to the `JudgementController` class in `peppercheck_flutter/lib/features/judgement/presentation/controllers/judgement_controller.dart`, after the existing `submit` method:

```dart
Future<void> confirmJudgement({
  required String taskId,
  required String judgementId,
  required bool isPositive,
  String? comment,
  required VoidCallback onSuccess,
}) async {
  state = const AsyncLoading();

  state = await AsyncValue.guard(() async {
    await ref
        .read(judgementRepositoryProvider)
        .confirmJudgement(
          judgementId: judgementId,
          isPositive: isPositive,
          comment: comment,
        );
    ref.invalidate(taskProvider(taskId));
    onSuccess();
  });
}
```

**Step 2: Commit**

```bash
git add peppercheck_flutter/lib/features/judgement/presentation/controllers/judgement_controller.dart
git commit -m "feat(flutter): add confirmJudgement to JudgementController"
```

---

### Task 4: Add confirm UI to JudgementSection

**Files:**
- Modify: `peppercheck_flutter/lib/features/judgement/presentation/widgets/judgement_section.dart`

This is the main UI task. The changes are:

1. Add local state for the confirm form (`_selectedIsPositive` and `_confirmCommentController`)
2. Add Tasker detection via `_isCurrentUserTasker()`
3. Modify `_buildResultCard` to show a confirmed checkmark when `isConfirmed == true`
4. Add `_buildConfirmArea` widget below result card content when applicable

**Step 1: Add state variables and Tasker detection**

In `_JudgementSectionState`, add a new `TextEditingController` and state variable. Also add a helper method to detect if the current user is the Tasker.

Add after the existing `_commentController` field (line 24):

```dart
final _confirmCommentController = TextEditingController();
bool? _selectedIsPositive;
```

Update `initState` to also listen to `_confirmCommentController`:

```dart
@override
void initState() {
  super.initState();
  _commentController.addListener(() => setState(() {}));
  _confirmCommentController.addListener(() => setState(() {}));
}
```

Update `dispose` to also dispose `_confirmCommentController`:

```dart
@override
void dispose() {
  _commentController.dispose();
  _confirmCommentController.dispose();
  super.dispose();
}
```

Add a helper method after `_getCurrentUserRequest()`:

```dart
bool _isCurrentUserTasker() {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  return userId != null && widget.task.taskerId == userId;
}
```

**Step 2: Add confirmed checkmark to result card**

Modify `_buildResultCard` to show a green checkmark icon at the trailing end of the Row when `judgement.isConfirmed == true`. The checkmark is only meaningful for the Tasker, so show it only when the current user is the Tasker.

In `_buildResultCard`, after the `Expanded(child: Column(...))` widget and before the closing `]` of the `Row.children`, add:

```dart
if (judgement.isConfirmed && _isCurrentUserTasker())
  Padding(
    padding: const EdgeInsets.only(left: AppSizes.spacingSmall),
    child: Icon(
      Icons.check_circle,
      color: AppColors.accentGreen,
      size: AppSizes.taskCardIconSize,
    ),
  ),
```

**Step 3: Add confirm area below result card**

Modify `_buildResultCard` to append the confirm area below the existing Row when the user is Tasker and judgement is not confirmed.

Replace the current `_buildResultCard` method's Container body. The current structure is:

```dart
child: Row(children: [...])
```

Change it to:

```dart
child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Row(
      children: [
        // ... existing avatar, status text, comment, checkmark (unchanged)
      ],
    ),
    if (_isCurrentUserTasker() &&
        !judgement.isConfirmed &&
        (judgement.status == 'approved' || judgement.status == 'rejected'))
      _buildConfirmArea(judgement),
  ],
),
```

**Step 4: Implement _buildConfirmArea**

Add this method to `_JudgementSectionState`:

```dart
void _submitConfirm(Judgement judgement) {
  if (_selectedIsPositive == null) return;

  ref
      .read(judgementControllerProvider.notifier)
      .confirmJudgement(
        taskId: widget.task.id,
        judgementId: judgement.id,
        isPositive: _selectedIsPositive!,
        comment: _confirmCommentController.text.trim().isEmpty
            ? null
            : _confirmCommentController.text.trim(),
        onSuccess: () {
          setState(() {
            _selectedIsPositive = null;
            _confirmCommentController.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.task.judgement.confirm.success)),
          );
        },
      );
}

Widget _buildConfirmArea(Judgement judgement) {
  final state = ref.watch(judgementControllerProvider);
  final isLoading = state.isLoading;

  return Padding(
    padding: const EdgeInsets.only(top: AppSizes.spacingSmall),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: AppColors.border),
        const SizedBox(height: AppSizes.spacingSmall),
        Text(
          t.task.judgement.confirm.question,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSizes.spacingSmall),
        Row(
          children: [
            Expanded(
              child: _RatingButton(
                icon: Icons.thumb_up,
                selectedIcon: Icons.thumb_up,
                label: t.task.judgement.confirm.fair,
                isSelected: _selectedIsPositive == true,
                color: AppColors.accentGreen,
                onTap: isLoading
                    ? null
                    : () => setState(() => _selectedIsPositive = true),
              ),
            ),
            const SizedBox(width: AppSizes.spacingSmall),
            Expanded(
              child: _RatingButton(
                icon: Icons.thumb_down,
                selectedIcon: Icons.thumb_down,
                label: t.task.judgement.confirm.unfair,
                isSelected: _selectedIsPositive == false,
                color: AppColors.textError,
                onTap: isLoading
                    ? null
                    : () => setState(() => _selectedIsPositive = false),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.spacingSmall),
        BaseTextField(
          value: _confirmCommentController.text,
          onValueChange: (_) {},
          label: t.task.judgement.confirm.comment,
          maxLines: 3,
          minLines: 1,
          controller: _confirmCommentController,
        ),
        const SizedBox(height: AppSizes.spacingSmall),
        if (state.hasError) ...[
          Text(
            state.error.toString(),
            style: TextStyle(color: AppColors.textError),
          ),
          const SizedBox(height: AppSizes.spacingSmall),
        ],
        PrimaryActionButton(
          text: t.task.judgement.confirm.submit,
          icon: Icons.check,
          onPressed: _selectedIsPositive != null && !isLoading
              ? () => _submitConfirm(judgement)
              : null,
          isLoading: isLoading,
        ),
      ],
    ),
  );
}
```

**Step 5: Add the _RatingButton widget**

Add this private widget class at the bottom of the file (before the closing of the file, after `_RejectButton`):

```dart
class _RatingButton extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback? onTap;

  const _RatingButton({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? color.withValues(alpha: 0.1)
        : AppColors.textPrimary.withValues(alpha: 0.05);
    final fgColor = isSelected
        ? color
        : AppColors.textPrimary.withValues(alpha: 0.4);
    final borderColor = isSelected
        ? color.withValues(alpha: 0.5)
        : AppColors.textPrimary.withValues(alpha: 0.2);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spacingStandard,
          vertical: AppSizes.spacingSmall,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppSizes.cardBorderRadius),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              size: 20,
              color: fgColor,
            ),
            const SizedBox(width: AppSizes.spacingSmall),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: fgColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Step 6: Add missing import**

Add at the top of `judgement_section.dart`:

```dart
import 'package:peppercheck_flutter/features/judgement/domain/judgement.dart';
```

**Step 7: Commit**

```bash
git add peppercheck_flutter/lib/features/judgement/presentation/widgets/judgement_section.dart
git commit -m "feat(flutter): add confirm judgement UI with binary rating"
```

---

### Task 5: Build and verify

**Step 1: Run build_runner to regenerate Riverpod providers**

Run: `cd peppercheck_flutter && dart run build_runner build --delete-conflicting-outputs`

Expected: Clean build with no errors. The controller's `.g.dart` file should regenerate.

**Step 2: Run Flutter analyze**

Run: `cd peppercheck_flutter && flutter analyze`

Expected: No errors. Fix any warnings if present.

**Step 3: Commit generated files if changed**

```bash
git add peppercheck_flutter/lib/
git commit -m "chore(flutter): regenerate build_runner output"
```
