# Evidence Timeout UI & Test Tooling Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add Flutter UI for taskers to confirm evidence timeouts, create a SQL test snippet for generating expired tasks, and document remaining notification work.

**Architecture:** The Task domain model already includes `Task → RefereeRequest → Judgement` with `status` and `isConfirmed` fields. We add a third state to `EvidenceSubmissionSection` for evidence timeout, a new `confirmEvidenceTimeout` method through the existing evidence controller/repository pattern, and a SQL snippet in `supabase/snippets/`.

**Tech Stack:** Flutter/Dart (Riverpod, Freezed), Supabase RPC, PostgreSQL

---

### Task 1: Add i18n strings for evidence timeout

**Files:**
- Modify: `peppercheck_flutter/assets/i18n/ja.i18n.json`

**Step 1: Add evidence timeout strings to ja.i18n.json**

In the `"evidence"` section (around line 123-132), add timeout-related keys after the existing `"error"` key:

```json
"evidence": {
  "title": "エビデンス",
  "submit": "エビデンスを提出",
  "submitted": "提出済みエビデンス",
  "description": "説明",
  "descriptionPlaceholder": "タスクの完了を証明する内容を記述してください",
  "maxImages": "画像は最大5枚までです",
  "success": "エビデンスを提出しました",
  "error": "エラーが発生しました: $message",
  "timeout": {
    "title": "エビデンス未提出",
    "description": "期限を過ぎました。ポイントが支払われました。",
    "confirm": "確認する",
    "confirmed": "確認済み",
    "success": "確認しました"
  }
}
```

**Step 2: Run slang code generation**

Run: `cd peppercheck_flutter && dart run slang`
Expected: Code generation completes, `t.task.evidence.timeout.*` accessors become available.

**Step 3: Commit**

```bash
git add peppercheck_flutter/assets/i18n/ja.i18n.json peppercheck_flutter/lib/gen/slang/
git commit -m "feat(i18n): add evidence timeout strings (#72)"
```

---

### Task 2: Add `confirmEvidenceTimeout` to EvidenceRepository

**Files:**
- Modify: `peppercheck_flutter/lib/features/evidence/data/evidence_repository.dart`

**Step 1: Add confirmEvidenceTimeout method**

Add this method to `EvidenceRepository` class after the existing `uploadEvidence` method (after line 83):

```dart
Future<void> confirmEvidenceTimeout({
  required String judgementId,
}) async {
  try {
    await _client.rpc(
      'confirm_evidence_timeout',
      params: {
        'p_judgement_id': judgementId,
      },
    );
  } catch (e, st) {
    _logger.e('confirmEvidenceTimeout failed', error: e, stackTrace: st);
    rethrow;
  }
}
```

**Step 2: Commit**

```bash
git add peppercheck_flutter/lib/features/evidence/data/evidence_repository.dart
git commit -m "feat(evidence): add confirmEvidenceTimeout repository method (#72)"
```

---

### Task 3: Add `confirmEvidenceTimeout` to EvidenceController

**Files:**
- Modify: `peppercheck_flutter/lib/features/evidence/presentation/controllers/evidence_controller.dart`

**Step 1: Add confirmEvidenceTimeout method**

Add this method to `EvidenceController` class after the existing `submit` method (after line 43):

```dart
Future<void> confirmEvidenceTimeout({
  required String taskId,
  required String judgementId,
  required VoidCallback onSuccess,
}) async {
  state = const AsyncLoading();

  state = await AsyncValue.guard(() async {
    await ref
        .read(evidenceRepositoryProvider)
        .confirmEvidenceTimeout(judgementId: judgementId);
    ref.invalidate(taskProvider(taskId));
    onSuccess();
  });
}
```

**Step 2: Commit**

```bash
git add peppercheck_flutter/lib/features/evidence/presentation/controllers/evidence_controller.dart
git commit -m "feat(evidence): add confirmEvidenceTimeout controller method (#72)"
```

---

### Task 4: Update `_shouldShowEvidenceSection` in TaskDetailScreen

**Files:**
- Modify: `peppercheck_flutter/lib/features/task/presentation/task_detail_screen.dart`

**Step 1: Add evidence timeout visibility check**

Replace the `_shouldShowEvidenceSection` method (lines 65-93) with:

```dart
bool _shouldShowEvidenceSection(Task task) {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null || task.taskerId != userId) {
    if (task.evidence != null) return true;
    return false;
  }

  // Tasker: show if evidence exists
  if (task.evidence != null) return true;

  // Tasker: show if any judgement has evidence_timeout status
  final hasEvidenceTimeout = task.refereeRequests.any(
    (req) => req.judgement?.status == 'evidence_timeout',
  );
  if (hasEvidenceTimeout) return true;

  // Tasker: show if any request is accepted (for submission form)
  final hasAcceptedRequest = task.refereeRequests.any(
    (req) => req.status == 'accepted',
  );
  return hasAcceptedRequest;
}
```

**Step 2: Commit**

```bash
git add peppercheck_flutter/lib/features/task/presentation/task_detail_screen.dart
git commit -m "feat(task): show evidence section for evidence timeout state (#72)"
```

---

### Task 5: Add evidence timeout UI to EvidenceSubmissionSection

**Files:**
- Modify: `peppercheck_flutter/lib/features/evidence/presentation/widgets/evidence_submission_section.dart`

**Step 1: Add timeout detection and UI**

In the `build` method of `_EvidenceSubmissionSectionState`, after the existing evidence-submitted check (after line 129, before the submission form), add the evidence timeout state:

```dart
// Check for evidence timeout state
final hasEvidenceTimeout = widget.task.refereeRequests.any(
  (req) => req.judgement?.status == 'evidence_timeout',
);

if (hasEvidenceTimeout) {
  final allConfirmed = widget.task.refereeRequests.every(
    (req) =>
        req.judgement?.status != 'evidence_timeout' ||
        req.judgement!.isConfirmed,
  );

  return BaseSection(
    title: t.task.evidence.timeout.title,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppColors.textError, size: 20),
            const SizedBox(width: AppSizes.spacingTiny),
            Expanded(
              child: Text(
                t.task.evidence.timeout.description,
                style: TextStyle(color: AppColors.textError),
              ),
            ),
          ],
        ),
        if (!allConfirmed) ...[
          const SizedBox(height: AppSizes.spacingSmall),
          if (state.hasError) ...[
            Text(
              state.error.toString(),
              style: TextStyle(color: AppColors.textError),
            ),
            const SizedBox(height: AppSizes.spacingSmall),
          ],
          ActionButton(
            text: t.task.evidence.timeout.confirm,
            onPressed: () => _confirmTimeout(),
            isLoading: isLoading,
          ),
        ] else ...[
          const SizedBox(height: AppSizes.spacingSmall),
          Row(
            children: [
              Icon(Icons.check_circle,
                  color: AppColors.accentGreen, size: 16),
              const SizedBox(width: AppSizes.spacingTiny),
              Text(
                t.task.evidence.timeout.confirmed,
                style: TextStyle(color: AppColors.accentGreen),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}
```

**Step 2: Add `_confirmTimeout` method**

Add this method to `_EvidenceSubmissionSectionState` (after `_submit` method, around line 80):

```dart
void _confirmTimeout() {
  // Find the first unconfirmed evidence_timeout judgement
  final request = widget.task.refereeRequests.firstWhere(
    (req) =>
        req.judgement?.status == 'evidence_timeout' &&
        req.judgement!.isConfirmed == false,
  );

  ref
      .read(evidenceControllerProvider.notifier)
      .confirmEvidenceTimeout(
        taskId: widget.task.id,
        judgementId: request.judgement!.id,
        onSuccess: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.task.evidence.timeout.success)),
          );
        },
      );
}
```

**Step 3: Run the app to verify**

Run: `cd peppercheck_flutter && flutter run`
Expected: App builds and runs without errors.

**Step 4: Commit**

```bash
git add peppercheck_flutter/lib/features/evidence/presentation/widgets/evidence_submission_section.dart
git commit -m "feat(evidence): add evidence timeout confirmation UI (#72)"
```

---

### Task 6: Create SQL test snippet for expired tasks

**Files:**
- Create: `supabase/snippets/create_expired_task.sql`

**Step 1: Create the snippet**

Reference existing snippet pattern from `supabase/snippets/force_process_matching.sql`.

```sql
-- Snippet to create a task with expired due_date for testing evidence timeout flow.
--
-- Usage:
--   1. Set v_tasker_id and v_referee_id below to actual user IDs from your local DB
--   2. Run this snippet via Supabase SQL editor or psql
--   3. The script creates the task, triggers timeout detection, and shows results
--
-- Prerequisites:
--   - Both users must exist in profiles table
--   - Tasker must have sufficient points (at least 1 point available)

DO $$
DECLARE
    -- ========================================
    -- CONFIGURE THESE VALUES
    -- ========================================
    v_tasker_id uuid := '00000000-0000-0000-0000-000000000000';  -- Replace with actual tasker user ID
    v_referee_id uuid := '00000000-0000-0000-0000-000000000000'; -- Replace with actual referee user ID
    -- ========================================

    v_task_id uuid;
    v_request_id uuid;
    v_result json;
BEGIN
    -- 1. Create task with due_date in the past
    INSERT INTO public.tasks (tasker_id, title, description, criteria, due_date, status)
    VALUES (
        v_tasker_id,
        '[TEST] Expired task ' || to_char(now(), 'HH24:MI:SS'),
        'Test task for evidence timeout verification',
        'Test criteria',
        now() - interval '1 day',  -- Due date = yesterday
        'open'
    )
    RETURNING id INTO v_task_id;
    RAISE NOTICE 'Created task: %', v_task_id;

    -- 2. Create accepted referee request
    INSERT INTO public.task_referee_requests (task_id, matching_strategy, status, matched_referee_id, responded_at)
    VALUES (
        v_task_id,
        'standard',
        'accepted',
        v_referee_id,
        now() - interval '2 days'
    )
    RETURNING id INTO v_request_id;
    RAISE NOTICE 'Created referee request: %', v_request_id;

    -- 3. Create judgement in awaiting_evidence status
    INSERT INTO public.judgements (id, status)
    VALUES (v_request_id, 'awaiting_evidence');
    RAISE NOTICE 'Created judgement: %', v_request_id;

    -- 4. Lock points for the tasker (simulating what happens when task opens)
    PERFORM public.lock_points(
        v_tasker_id,
        public.get_point_for_matching_strategy('standard'::public.matching_strategy),
        'matching_locked'::public.point_reason,
        'Test lock for expired task',
        v_request_id
    );
    RAISE NOTICE 'Locked points for tasker';

    -- 5. Run evidence timeout detection (this triggers settlement via on_evidence_timeout_settle)
    v_result := public.detect_and_handle_evidence_timeouts();
    RAISE NOTICE 'Timeout detection result: %', v_result;

    -- 6. Show final state
    RAISE NOTICE '--- RESULTS ---';
    RAISE NOTICE 'Task ID: %', v_task_id;
    RAISE NOTICE 'Check task_detail screen for tasker to see timeout confirmation UI';
END $$;

-- Verify: Check the created task and judgement state
-- (Run after the DO block above)
SELECT
    t.id AS task_id,
    t.title,
    t.status AS task_status,
    t.due_date,
    j.status AS judgement_status,
    j.is_evidence_timeout_confirmed,
    j.is_confirmed,
    trr.status AS request_status
FROM public.tasks t
JOIN public.task_referee_requests trr ON trr.task_id = t.id
JOIN public.judgements j ON j.id = trr.id
WHERE t.title LIKE '[TEST] Expired task%'
ORDER BY t.created_at DESC
LIMIT 5;
```

**Step 2: Commit**

```bash
git add supabase/snippets/create_expired_task.sql
git commit -m "feat(dev): add SQL snippet to create expired tasks for timeout testing (#72)"
```

---

### Task 7: Run build_runner and verify app compiles

**Step 1: Run code generation**

Run: `cd peppercheck_flutter && dart run build_runner build --delete-conflicting-outputs`
Expected: Code generation completes with no errors. Generated files for evidence_controller and evidence_repository updated.

**Step 2: Verify Flutter build**

Run: `cd peppercheck_flutter && flutter build apk --debug 2>&1 | tail -5`
Expected: Build succeeds with no compilation errors.

**Step 3: Commit generated files if changed**

```bash
git add peppercheck_flutter/lib/features/evidence/presentation/controllers/evidence_controller.g.dart
git add peppercheck_flutter/lib/features/evidence/data/evidence_repository.g.dart
git commit -m "chore: regenerate riverpod code (#72)"
```

---

### Task 8: Document remaining notification work

**Step 1: Create a summary of remaining notification tasks**

Create or update a comment on issue #72 (or a markdown file) listing:

1. **Edge Function notification templates** - Add localized title/body strings for:
   - `notification_evidence_timeout` (to tasker): "エビデンス未提出のタスクがあります" / "{task_title} の期限が過ぎました。ポイントが支払われました。"
   - `notification_evidence_timeout_reward` (to referee): "報酬が付与されました" / "{task_title} のエビデンスが未提出のため、報酬が付与されました。"

2. **Flutter FCM handler** - Route `notification_evidence_timeout` tap to task detail screen using `task_id` from notification data payload.

3. **i18n for notifications** - Add notification title/body keys to `ja.i18n.json` (separate from in-app UI strings).

**Step 2: Commit**

No code changes needed. This is documentation only - can be added as a GitHub issue comment.
