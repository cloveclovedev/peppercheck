# Judgement Timeout Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Automatically time out referee judgements that remain in `in_review` status past `due_date + 3h`, return points to tasker, rate referee negatively, and let tasker confirm before task closes.

**Architecture:** 3-layer backend (cron detection → settlement trigger → tasker confirmation RPC) mirroring the existing Evidence Timeout pattern. Flutter UI adds review timeout state handling to the existing `JudgementSection` widget.

**Tech Stack:** PostgreSQL (pg_cron, triggers, RPC), Supabase Edge Functions (notifications via FCM), Flutter/Riverpod

**Design doc:** `docs/plans/2026-02-15-judgement-timeout-design.md`

---

### Task 1: Detection Function (Schema)

**Files:**
- Create: `supabase/schemas/judgement/functions/detect_review_timeouts.sql`
- Create: `supabase/schemas/judgement/cron/cron_detect_review_timeout.sql`

**Step 1: Create the detection function**

Create `supabase/schemas/judgement/functions/detect_review_timeouts.sql`:

```sql
CREATE OR REPLACE FUNCTION public.detect_and_handle_review_timeouts() RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_timeout_count INTEGER := 0;
    v_now TIMESTAMP WITH TIME ZONE;
BEGIN
    v_now := NOW();

    UPDATE public.judgements j
    SET
        status = 'review_timeout',
        updated_at = v_now
    FROM public.task_referee_requests trr
    JOIN public.tasks t ON trr.task_id = t.id
    WHERE j.id = trr.id
    AND j.status = 'in_review'
    AND v_now > (t.due_date + INTERVAL '3 hours');

    GET DIAGNOSTICS v_timeout_count = ROW_COUNT;

    RETURN json_build_object(
        'success', true,
        'timeout_count', v_timeout_count,
        'processed_at', v_now
    );
END;
$$;

ALTER FUNCTION public.detect_and_handle_review_timeouts() OWNER TO postgres;

COMMENT ON FUNCTION public.detect_and_handle_review_timeouts() IS 'Detects review timeouts (in_review past due_date + 3h) and updates status to review_timeout. Called by pg_cron every 5 minutes.';
```

**Step 2: Create the cron schedule**

Create `supabase/schemas/judgement/cron/cron_detect_review_timeout.sql`:

```sql
SELECT cron.schedule(
    'detect-review-timeouts',
    '*/5 * * * *',
    $$SELECT public.detect_and_handle_review_timeouts()$$
);
```

**Step 3: Commit schema files**

```bash
git add supabase/schemas/judgement/functions/detect_review_timeouts.sql \
  supabase/schemas/judgement/cron/cron_detect_review_timeout.sql
git commit -m "feat: add review timeout detection function and cron schema"
```

---

### Task 2: Settlement Trigger (Schema)

**Files:**
- Create: `supabase/schemas/judgement/triggers/on_review_timeout_settle.sql`

**Step 1: Create the settlement trigger function and trigger**

Create `supabase/schemas/judgement/triggers/on_review_timeout_settle.sql`:

```sql
CREATE OR REPLACE FUNCTION public.settle_review_timeout() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_tasker_id uuid;
    v_referee_id uuid;
    v_task_id uuid;
    v_task_title text;
    v_matching_strategy public.matching_strategy;
    v_cost integer;
BEGIN
    SELECT t.tasker_id, trr.matched_referee_id, trr.task_id, t.title, trr.matching_strategy
    INTO v_tasker_id, v_referee_id, v_task_id, v_task_title, v_matching_strategy
    FROM public.task_referee_requests trr
    JOIN public.tasks t ON t.id = trr.task_id
    WHERE trr.id = NEW.id;

    IF NOT FOUND THEN
        RAISE WARNING 'settle_review_timeout: request not found for judgement %', NEW.id;
        RETURN NEW;
    END IF;

    v_cost := public.get_point_for_matching_strategy(v_matching_strategy);

    -- Return locked points to tasker (no consumption)
    PERFORM public.unlock_points(
        v_tasker_id,
        v_cost,
        'matching_unlock'::public.point_reason,
        'Review timeout (judgement ' || NEW.id || ')',
        NEW.id
    );

    -- Auto Bad rating for referee
    INSERT INTO public.rating_histories (
        rater_id,
        ratee_id,
        judgement_id,
        rating_type,
        is_positive,
        comment
    ) VALUES (
        v_tasker_id,
        v_referee_id,
        NEW.id,
        'referee',
        false,
        NULL
    ) ON CONFLICT (judgement_id, rating_type) DO NOTHING;

    -- Close referee_request directly
    UPDATE public.task_referee_requests
    SET status = 'closed'::public.referee_request_status
    WHERE id = NEW.id;

    -- Notify tasker
    PERFORM public.notify_event(
        v_tasker_id,
        'notification_review_timeout_tasker',
        ARRAY[v_task_title],
        jsonb_build_object('task_id', v_task_id, 'judgement_id', NEW.id)
    );

    -- Notify referee
    PERFORM public.notify_event(
        v_referee_id,
        'notification_review_timeout_referee',
        ARRAY[v_task_title],
        jsonb_build_object('task_id', v_task_id, 'judgement_id', NEW.id)
    );

    RETURN NEW;
END;
$$;

ALTER FUNCTION public.settle_review_timeout() OWNER TO postgres;

CREATE OR REPLACE TRIGGER on_review_timeout_settle
    AFTER UPDATE ON public.judgements
    FOR EACH ROW
    WHEN (NEW.status = 'review_timeout' AND OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION public.settle_review_timeout();

COMMENT ON TRIGGER on_review_timeout_settle ON public.judgements IS 'Unlocks tasker points, rates referee negatively, closes request, and sends notifications when review timeout is detected.';
```

**Note:** The existing `auto_score_timeout_referee` trigger also fires on `is_confirmed = true` for `review_timeout` and attempts to insert a Bad rating. The `ON CONFLICT DO NOTHING` clause prevents duplication — no changes needed to the existing trigger.

**Step 2: Commit schema file**

```bash
git add supabase/schemas/judgement/triggers/on_review_timeout_settle.sql
git commit -m "feat: add review timeout settlement trigger schema"
```

---

### Task 3: Tasker Confirmation RPC (Schema)

**Files:**
- Create: `supabase/schemas/judgement/functions/confirm_review_timeout.sql`

**Step 1: Create the confirmation function**

Create `supabase/schemas/judgement/functions/confirm_review_timeout.sql`:

```sql
CREATE OR REPLACE FUNCTION public.confirm_review_timeout(p_judgement_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_judgement RECORD;
BEGIN
    SELECT j.id, j.status, j.is_confirmed, t.tasker_id
    INTO v_judgement
    FROM public.judgements j
    JOIN public.task_referee_requests trr ON trr.id = j.id
    JOIN public.tasks t ON t.id = trr.task_id
    WHERE j.id = p_judgement_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Judgement not found';
    END IF;

    IF v_judgement.tasker_id != (SELECT auth.uid()) THEN
        RAISE EXCEPTION 'Only the tasker can confirm a review timeout';
    END IF;

    IF v_judgement.status != 'review_timeout' THEN
        RAISE EXCEPTION 'Judgement must be in review_timeout status to confirm';
    END IF;

    -- Idempotency
    IF v_judgement.is_confirmed = TRUE THEN
        RETURN;
    END IF;

    -- Confirm (triggers on_all_judgements_confirmed_close_task)
    UPDATE public.judgements SET is_confirmed = TRUE WHERE id = p_judgement_id;
END;
$$;

ALTER FUNCTION public.confirm_review_timeout(uuid) OWNER TO postgres;

COMMENT ON FUNCTION public.confirm_review_timeout(uuid) IS 'Allows tasker to confirm/acknowledge a review timeout. Points were already returned by settle_review_timeout. Sets is_confirmed = true which triggers task closure check.';
```

**Step 2: Commit schema file**

```bash
git add supabase/schemas/judgement/functions/confirm_review_timeout.sql
git commit -m "feat: add confirm_review_timeout RPC schema"
```

---

### Task 4: Generate Migration and Verify

All backend schema files are now in place. Generate a single migration and verify.

**Step 1: Generate migration**

Run:
```bash
supabase db diff -f add_review_timeout
```

**Step 2: Review the generated migration**

Check the generated file in `supabase/migrations/`. It should contain:
- `detect_and_handle_review_timeouts()` function
- `settle_review_timeout()` function + `on_review_timeout_settle` trigger
- `confirm_review_timeout()` function

**Step 3: Append DML (cron schedule)**

The cron schedule is DML and not captured by `db diff`. Manually append to the end of the generated migration file:

```sql
-- DML, not detected by schema diff
SELECT cron.schedule(
    'detect-review-timeouts',
    '*/5 * * * *',
    $$SELECT public.detect_and_handle_review_timeouts()$$
);
```

**Step 4: Verify migration works from scratch**

Run:
```bash
./scripts/db-reset-and-clear-android-emulators-cache.sh
```

Expected: no errors, DB resets cleanly.

**Step 5: Commit migration**

```bash
git add supabase/migrations/*_add_review_timeout.sql
git commit -m "feat: add review timeout migration"
```

---

### Task 5: Test Snippet

**Files:**
- Create: `supabase/snippets/create_review_timeout_task.sql`

**Step 1: Create the test snippet**

Create `supabase/snippets/create_review_timeout_task.sql`:

```sql
-- Test snippet: Creates a task with review timeout scenario
-- (Evidence submitted, referee hasn't reviewed, past due_date + 3h)
--
-- Usage: Set v_tasker_id and v_referee_id, then run in SQL editor.
-- After running, open the tasker's task detail screen to see the review timeout confirm UI.

DO $$
DECLARE
    v_tasker_id uuid := '00000000-0000-0000-0000-000000000000'; -- Replace with actual tasker ID
    v_referee_id uuid := '00000000-0000-0000-0000-000000000000'; -- Replace with actual referee ID
    v_task_id uuid;
    v_request_id uuid;
BEGIN
    -- 1. Create task with due_date 1 day ago
    INSERT INTO public.tasks (
        tasker_id, title, description, due_date, status
    ) VALUES (
        v_tasker_id,
        'Review Timeout Test Task',
        'This task is for testing review timeout.',
        now() - interval '1 day',
        'open'
    ) RETURNING id INTO v_task_id;

    -- 2. Create accepted referee request
    INSERT INTO public.task_referee_requests (
        task_id, matched_referee_id, status, matching_strategy, responded_at
    ) VALUES (
        v_task_id, v_referee_id, 'accepted', 'standard', now() - interval '2 days'
    ) RETURNING id INTO v_request_id;

    -- 3. Create judgement in in_review status (evidence was submitted)
    INSERT INTO public.judgements (
        id, status
    ) VALUES (
        v_request_id, 'in_review'
    );

    -- 4. Create evidence (so the task looks like evidence was submitted)
    INSERT INTO public.task_evidences (
        task_id, description
    ) VALUES (
        v_task_id, 'Test evidence for review timeout'
    );

    -- 5. Lock points for tasker
    PERFORM public.lock_points(
        v_tasker_id,
        public.get_point_for_matching_strategy('standard'::public.matching_strategy),
        'matching_lock'::public.point_reason,
        'Test lock for review timeout task',
        v_request_id
    );

    -- 6. Trigger review timeout detection
    PERFORM public.detect_and_handle_review_timeouts();

    RAISE NOTICE 'Created review timeout test: task_id=%, request_id=%', v_task_id, v_request_id;
END;
$$;

-- Verification query
SELECT
    t.id AS task_id,
    t.title,
    t.status AS task_status,
    j.status AS judgement_status,
    j.is_confirmed,
    trr.status AS request_status,
    pw.balance,
    pw.locked
FROM public.tasks t
JOIN public.task_referee_requests trr ON trr.task_id = t.id
JOIN public.judgements j ON j.id = trr.id
LEFT JOIN public.point_wallets pw ON pw.user_id = t.tasker_id
WHERE t.title = 'Review Timeout Test Task'
ORDER BY t.created_at DESC
LIMIT 1;
```

**Step 2: Commit**

```bash
git add supabase/snippets/create_review_timeout_task.sql
git commit -m "feat: add review timeout test snippet"
```

---

### Task 6: Notification i18n Strings

**Files:**
- Modify: `peppercheck_flutter/assets/i18n/ja.i18n.json`
- Modify: `peppercheck_flutter/android/app/src/main/res/values/strings.xml`
- Modify: `peppercheck_flutter/android/app/src/main/res/values-ja/strings.xml`
- Modify: `peppercheck_flutter/ios/Runner/en.lproj/Localizable.strings`
- Modify: `peppercheck_flutter/ios/Runner/ja.lproj/Localizable.strings`
- Modify: `peppercheck_flutter/lib/features/notification/application/notification_text_resolver.dart`

**Step 1: Add Flutter i18n strings**

In `peppercheck_flutter/assets/i18n/ja.i18n.json`:

Add to the `"notification"` object:

```json
"review_timeout_tasker_title": "レビュー期限切れ",
"review_timeout_tasker_body": "タスク「${taskTitle}」は期間内に評価されませんでした。ポイントが返却されました。",
"review_timeout_referee_title": "レビュー期限切れ",
"review_timeout_referee_body": "タスク「${taskTitle}」のレビュー期限が過ぎました。"
```

Add to `"task" > "judgement"` object:

```json
"reviewTimeout": {
  "description": "期間内に評価されませんでした。ポイントが返却されました。",
  "confirm": "確認",
  "confirmed": "確認済み",
  "success": "確認しました"
}
```

**Step 2: Add Android strings (English)**

In `peppercheck_flutter/android/app/src/main/res/values/strings.xml`, add before closing `</resources>`:

```xml
<string name="notification_review_timeout_tasker_title">Review Timeout</string>
<string name="notification_review_timeout_tasker_body">Your task "%1$s" was not reviewed in time. Points have been returned.</string>
<string name="notification_review_timeout_referee_title">Review Timeout</string>
<string name="notification_review_timeout_referee_body">The review deadline for task "%1$s" has passed.</string>
```

**Step 3: Add Android strings (Japanese)**

In `peppercheck_flutter/android/app/src/main/res/values-ja/strings.xml`, add before closing `</resources>`:

```xml
<string name="notification_review_timeout_tasker_title">レビュー期限切れ</string>
<string name="notification_review_timeout_tasker_body">タスク「%1$s」は期間内に評価されませんでした。ポイントが返却されました。</string>
<string name="notification_review_timeout_referee_title">レビュー期限切れ</string>
<string name="notification_review_timeout_referee_body">タスク「%1$s」のレビュー期限が過ぎました。</string>
```

**Step 4: Add iOS strings (English)**

In `peppercheck_flutter/ios/Runner/en.lproj/Localizable.strings`, append:

```
"notification_review_timeout_tasker_title" = "Review Timeout";
"notification_review_timeout_tasker_body" = "Your task \"%@\" was not reviewed in time. Points have been returned.";
"notification_review_timeout_referee_title" = "Review Timeout";
"notification_review_timeout_referee_body" = "The review deadline for task \"%@\" has passed.";
```

**Step 5: Add iOS strings (Japanese)**

In `peppercheck_flutter/ios/Runner/ja.lproj/Localizable.strings`, append:

```
"notification_review_timeout_tasker_title" = "レビュー期限切れ";
"notification_review_timeout_tasker_body" = "タスク「%@」は期間内に評価されませんでした。ポイントが返却されました。";
"notification_review_timeout_referee_title" = "レビュー期限切れ";
"notification_review_timeout_referee_body" = "タスク「%@」のレビュー期限が過ぎました。";
```

**Step 6: Update notification text resolver**

In `peppercheck_flutter/lib/features/notification/application/notification_text_resolver.dart`, add cases to the `_resolveKey` switch before `default`:

```dart
case 'notification_review_timeout_tasker_title':
  return t.notification.review_timeout_tasker_title;
case 'notification_review_timeout_tasker_body':
  return t.notification.review_timeout_tasker_body(taskTitle: taskTitle);
case 'notification_review_timeout_referee_title':
  return t.notification.review_timeout_referee_title;
case 'notification_review_timeout_referee_body':
  return t.notification.review_timeout_referee_body(taskTitle: taskTitle);
```

**Step 7: Run slang code generation**

Run:
```bash
cd peppercheck_flutter && dart run slang
```

Expected: generates updated `strings.g.dart`.

**Step 8: Commit**

```bash
git add peppercheck_flutter/assets/i18n/ja.i18n.json \
  peppercheck_flutter/android/app/src/main/res/values/strings.xml \
  peppercheck_flutter/android/app/src/main/res/values-ja/strings.xml \
  peppercheck_flutter/ios/Runner/en.lproj/Localizable.strings \
  peppercheck_flutter/ios/Runner/ja.lproj/Localizable.strings \
  peppercheck_flutter/lib/features/notification/application/notification_text_resolver.dart \
  peppercheck_flutter/lib/gen/slang/
git commit -m "feat: add review timeout notification i18n strings"
```

---

### Task 7: Flutter UI - Review Timeout Confirmation

**Files:**
- Modify: `peppercheck_flutter/lib/features/judgement/data/judgement_repository.dart`
- Modify: `peppercheck_flutter/lib/features/judgement/presentation/controllers/judgement_controller.dart`
- Modify: `peppercheck_flutter/lib/features/judgement/presentation/widgets/judgement_section.dart`

**Step 1: Add `confirmReviewTimeout` to JudgementRepository**

In `peppercheck_flutter/lib/features/judgement/data/judgement_repository.dart`, add method after `confirmJudgement`:

```dart
Future<void> confirmReviewTimeout({
  required String judgementId,
}) async {
  try {
    await _client.rpc(
      'confirm_review_timeout',
      params: {
        'p_judgement_id': judgementId,
      },
    );
  } catch (e, st) {
    _logger.e('confirmReviewTimeout failed', error: e, stackTrace: st);
    rethrow;
  }
}
```

**Step 2: Add `confirmReviewTimeout` to JudgementController**

In `peppercheck_flutter/lib/features/judgement/presentation/controllers/judgement_controller.dart`, add method after `confirmJudgement`:

```dart
Future<void> confirmReviewTimeout({
  required String taskId,
  required String judgementId,
  required VoidCallback onSuccess,
}) async {
  state = const AsyncLoading();

  state = await AsyncValue.guard(() async {
    await ref
        .read(judgementRepositoryProvider)
        .confirmReviewTimeout(judgementId: judgementId);
    ref.invalidate(taskProvider(taskId));
    onSuccess();
  });
}
```

**Step 3: Update JudgementSection to handle review_timeout**

In `peppercheck_flutter/lib/features/judgement/presentation/widgets/judgement_section.dart`:

3a. Update `completedRequests` filter in `build` method to include `review_timeout`:

```dart
final completedRequests = widget.task.refereeRequests
    .where((req) =>
        req.judgement != null &&
        (req.judgement!.status == 'approved' ||
            req.judgement!.status == 'rejected' ||
            req.judgement!.status == 'review_timeout'))
    .toList();
```

3b. Update `_buildResultCard` to handle `review_timeout` status. Replace the status text/color logic:

```dart
final isApproved = judgement.status == 'approved';
final isReviewTimeout = judgement.status == 'review_timeout';

final String statusText;
final Color statusColor;

if (isReviewTimeout) {
  statusText = t.task.judgement.reviewTimeout.description;
  statusColor = AppColors.textError;
} else if (isApproved) {
  statusText = t.task.judgement.approved;
  statusColor = AppColors.accentGreen;
} else {
  statusText = t.task.judgement.rejected;
  statusColor = AppColors.textError;
}
```

3c. Replace the icon in `_buildResultCard` for review_timeout — use a warning icon instead of referee avatar:

In the `Row` children, wrap the avatar/icon section to check for review_timeout:

```dart
if (isReviewTimeout)
  Icon(Icons.warning_amber_rounded, color: AppColors.textError, size: AppSizes.taskCardIconSize)
else if (request.referee?.avatarUrl != null)
  // ... existing avatar code
```

3d. Update the confirm area condition at the bottom of `_buildResultCard`. Replace:

```dart
if (_isCurrentUserTasker() &&
    !judgement.isConfirmed &&
    (judgement.status == 'approved' || judgement.status == 'rejected'))
  _buildConfirmArea(judgement),
```

With:

```dart
if (_isCurrentUserTasker() && !judgement.isConfirmed) ...[
  if (judgement.status == 'approved' || judgement.status == 'rejected')
    _buildConfirmArea(judgement)
  else if (judgement.status == 'review_timeout')
    _buildReviewTimeoutConfirmArea(judgement),
],
```

3e. Add `_confirmReviewTimeout` method:

```dart
void _confirmReviewTimeout(Judgement judgement) {
  ref
      .read(judgementControllerProvider.notifier)
      .confirmReviewTimeout(
        taskId: widget.task.id,
        judgementId: judgement.id,
        onSuccess: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.task.judgement.reviewTimeout.success)),
          );
        },
      );
}
```

3f. Add `_buildReviewTimeoutConfirmArea` method:

```dart
Widget _buildReviewTimeoutConfirmArea(Judgement judgement) {
  final state = ref.watch(judgementControllerProvider);
  final isLoading = state.isLoading;

  return Padding(
    padding: const EdgeInsets.only(top: AppSizes.spacingTiny),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: AppColors.border, height: 1),
        const SizedBox(height: AppSizes.spacingTiny),
        if (state.hasError) ...[
          Text(
            state.error.toString(),
            style: TextStyle(color: AppColors.textError),
          ),
          const SizedBox(height: AppSizes.spacingSmall),
        ],
        PrimaryActionButton(
          text: t.task.judgement.reviewTimeout.confirm,
          icon: Icons.check,
          onPressed: isLoading ? null : () => _confirmReviewTimeout(judgement),
          isLoading: isLoading,
        ),
      ],
    ),
  );
}
```

**Step 4: Run code generation**

Run:
```bash
cd peppercheck_flutter && dart run build_runner build --delete-conflicting-outputs
```

Expected: generates updated `.g.dart` files for repository and controller.

**Step 5: Verify build**

Run:
```bash
cd peppercheck_flutter && flutter analyze
```

Expected: no errors.

**Step 6: Commit**

```bash
git add peppercheck_flutter/lib/features/judgement/
git commit -m "feat: add review timeout confirmation UI"
```

---

### Task 8: Create Follow-up Issues

**Step 1: Create issue for `is_evidence_timeout_confirmed` simplification**

Run:
```bash
gh issue create \
  --title "Simplify evidence timeout: remove is_evidence_timeout_confirmed flag" \
  --body "$(cat <<'EOF'
## Background

The `is_evidence_timeout_confirmed` flag on `judgements` was introduced to trigger `referee_request` closure for evidence timeouts. However, with the review timeout implementation, we established that the status change itself (`review_timeout`) is sufficient to close the `referee_request` directly in the settlement trigger.

## Proposal

- Modify `settle_evidence_timeout()` to close `referee_request` directly (like `settle_review_timeout()` does)
- Remove the `is_evidence_timeout_confirmed` column from `judgements`
- Update `on_judgement_confirmed_close_request` trigger to remove the `is_evidence_timeout_confirmed` condition
- Update `confirm_evidence_timeout()` to remove the `is_evidence_timeout_confirmed` check

## Related

- Review timeout implementation uses direct close pattern (no intermediate flag)
- Design doc: `docs/plans/2026-02-15-judgement-timeout-design.md` (Future Considerations section)
EOF
)" \
  --label "refactor"
```

**Step 2: Create issue for notification template key renaming**

Run:
```bash
gh issue create \
  --title "Standardize notification template keys to _tasker/_referee suffix" \
  --body "$(cat <<'EOF'
## Background

Notification template keys currently use inconsistent naming:
- `notification_evidence_timeout` (tasker) / `notification_evidence_timeout_reward` (referee)
- `notification_review_timeout_tasker` / `notification_review_timeout_referee` (new standard)

## Proposal

Rename existing keys to follow `_tasker` / `_referee` suffix pattern:
- `notification_evidence_timeout` → `notification_evidence_timeout_tasker`
- `notification_evidence_timeout_reward` → `notification_evidence_timeout_referee`

Affects:
- SQL `notify_event()` call in `settle_evidence_timeout()`
- Android `strings.xml` (en + ja)
- iOS `Localizable.strings` (en + ja)
- Flutter `ja.i18n.json`
- Flutter `notification_text_resolver.dart`

## Related

- Design doc: `docs/plans/2026-02-15-judgement-timeout-design.md` (Future Considerations section)
EOF
)" \
  --label "refactor"
```

---

### Task 9: Manual Integration Test

**Step 1: Reset DB and clear emulator caches**

Run:
```bash
./scripts/db-reset-and-clear-android-emulators-cache.sh
```

**Step 2: Run the test snippet**

Open Supabase SQL editor (Studio UI at http://127.0.0.1:54323) and run the snippet from `supabase/snippets/create_review_timeout_task.sql` with actual user IDs.

**Step 3: Verify on emulator**

1. Open tasker's app → Task detail screen
2. Verify review timeout state is shown in judgement section with warning icon + description + confirm button
3. Tap "確認" button
4. Verify state changes to confirmed (checkmark + "確認済み")
5. Verify task status changes to "closed" if all judgements are confirmed

**Step 4: Verify backend state**

Run verification query from the test snippet to confirm:
- `judgement_status = 'review_timeout'`
- `request_status = 'closed'`
- `locked = 0` (points returned to tasker)
- Check `rating_histories` for the auto Bad rating entry
