# Issue #72 Follow-up Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Clean up 4 small issues (#248, #247, #246, #258) from the Flutter Android epic, each as a separate PR.

**Architecture:** Mechanical renames (#248, #258), DB schema simplification (#247), and a new Flutter widget (#246). All changes are independent across PRs but share a design doc.

**Tech Stack:** PostgreSQL (Supabase), Flutter/Dart (Freezed, slang i18n), Android XML, iOS strings

**Design doc:** `docs/plans/2026-02-23-issue72-followup-design.md`

---

## PR 1: Issue #248 — Standardize notification template keys

Branch: `refactor/standardize-notification-keys`

### Task 1: Create naming convention documentation

**Files:**
- Create: `docs/overview/naming-conventions.md`
- Create: `.claude/rules/notification-keys.md`

**Step 1: Create the developer-facing naming conventions page**

Create `docs/overview/naming-conventions.md`:

```markdown
# Naming Conventions

Project-wide naming conventions. New conventions should be added here as sections.

## Notification Template Keys

### Pattern

`notification_{event}_{recipient}`

- `{recipient}` is always `_tasker` or `_referee`
- Every key must have a recipient suffix, even when the recipient seems obvious from the event name
- The `notification_` prefix is retained as a namespace (required for flat key systems like Android `strings.xml` / iOS `Localizable.strings`)

### How keys flow through the system

1. **SQL**: `notify_event(user_id, 'notification_{event}_{recipient}', ...)` — base key only, no `_title`/`_body` suffix
2. **`notify_event()` function**: Auto-appends `_title` and `_body` to construct `title_loc_key` / `body_loc_key`
3. **Edge Function** (`send-notification`): Forwards loc_keys to FCM as-is
4. **Background/terminated notifications**: Android `strings.xml` / iOS `Localizable.strings` resolve the loc_key natively
5. **Foreground notifications**: Flutter `notification_text_resolver.dart` resolves the loc_key to slang `t.notification.*` accessors
6. **Flutter i18n**: `ja.i18n.json` `notification` section stores the localized text (keys without `notification_` prefix, e.g. `evidence_timeout_tasker_title`)

### Adding a new notification

1. Choose base key following the pattern: `notification_{event}_{recipient}`
2. Add to ALL 5 layers:
   - SQL `notify_event()` call
   - Android `strings.xml` (en + ja) with `_title` and `_body` suffixed keys
   - iOS `Localizable.strings` (en + ja) with `_title` and `_body` suffixed keys
   - Flutter `ja.i18n.json` `notification` section (without `notification_` prefix)
   - Flutter `notification_text_resolver.dart` switch cases
3. Regenerate slang: `cd peppercheck_flutter && dart run build_runner build`
```

**Step 2: Create the LLM-facing rule**

Create `.claude/rules/notification-keys.md`:

```markdown
# Notification Template Keys

## Naming Convention

Pattern: `notification_{event}_{recipient}` where `{recipient}` is `_tasker` or `_referee`.

Every key must have a recipient suffix. The `notification_` prefix is retained as a namespace.

## Full details

See `docs/overview/naming-conventions.md` for the complete specification including the system flow and how to add new notifications.
```

**Step 3: Commit**

```bash
git add docs/overview/naming-conventions.md .claude/rules/notification-keys.md
git commit -m "docs: add notification key naming convention"
```

---

### Task 2: Rename notification keys in SQL schemas

**Files:**
- Modify: `supabase/schemas/matching/functions/process_matching.sql`
- Modify: `supabase/schemas/evidence/triggers/on_task_evidences_upserted_notify_referee.sql`
- Modify: `supabase/schemas/judgement/triggers/on_judgements_status_changed.sql`
- Modify: `supabase/schemas/judgement/triggers/on_judgement_confirmed.sql`
- Modify: `supabase/schemas/judgement/triggers/on_evidence_timeout_settle.sql`
- Modify: `supabase/schemas/reward/functions/prepare_monthly_payouts.sql`

**Step 1: Apply renames**

| File | Line | Old | New |
|------|------|-----|-----|
| `process_matching.sql` | 173 | `'notification_referee_assigned'` | `'notification_task_assigned_referee'` |
| `process_matching.sql` | 181 | `'notification_request_matched'` | `'notification_request_matched_tasker'` |
| `on_task_evidences_upserted_notify_referee.sql` | 27 | `'notification_evidence_submitted'` | `'notification_evidence_submitted_referee'` |
| `on_task_evidences_upserted_notify_referee.sql` | 34 | `'notification_evidence_updated'` | `'notification_evidence_updated_referee'` |
| `on_judgements_status_changed.sql` | 34 | `'notification_judgement_approved'` | `'notification_judgement_approved_tasker'` |
| `on_judgements_status_changed.sql` | 37 | `'notification_judgement_rejected'` | `'notification_judgement_rejected_tasker'` |
| `on_judgements_status_changed.sql` | 42 | `'notification_evidence_resubmitted'` | `'notification_evidence_resubmitted_referee'` |
| `on_judgement_confirmed.sql` | 30 | `'notification_judgement_confirmed'` | `'notification_judgement_confirmed_referee'` |
| `on_evidence_timeout_settle.sql` | 56 | `'notification_evidence_timeout'` | `'notification_evidence_timeout_tasker'` |
| `on_evidence_timeout_settle.sql` | 64 | `'notification_evidence_timeout_reward'` | `'notification_evidence_timeout_referee'` |
| `prepare_monthly_payouts.sql` | 72 | `'notification_payout_connect_required'` | `'notification_payout_connect_required_referee'` |

Files already correct (no changes): `on_judgement_confirmed_notify.sql`, `on_review_timeout_settle.sql`.

---

### Task 3: Rename notification keys in Android strings

**Files:**
- Modify: `peppercheck_flutter/android/app/src/main/res/values/strings.xml`
- Modify: `peppercheck_flutter/android/app/src/main/res/values-ja/strings.xml`

**Step 1: Rename `name` attributes in BOTH en and ja files** (string content stays the same)

| Old name attribute | New name attribute |
|----|-----|
| `notification_referee_assigned_title` | `notification_task_assigned_referee_title` |
| `notification_referee_assigned_body` | `notification_task_assigned_referee_body` |
| `notification_request_matched_title` | `notification_request_matched_tasker_title` |
| `notification_request_matched_body` | `notification_request_matched_tasker_body` |
| `notification_evidence_submitted_title` | `notification_evidence_submitted_referee_title` |
| `notification_evidence_submitted_body` | `notification_evidence_submitted_referee_body` |
| `notification_evidence_updated_title` | `notification_evidence_updated_referee_title` |
| `notification_evidence_updated_body` | `notification_evidence_updated_referee_body` |
| `notification_evidence_resubmitted_title` | `notification_evidence_resubmitted_referee_title` |
| `notification_evidence_resubmitted_body` | `notification_evidence_resubmitted_referee_body` |
| `notification_evidence_timeout_title` | `notification_evidence_timeout_tasker_title` |
| `notification_evidence_timeout_body` | `notification_evidence_timeout_tasker_body` |
| `notification_evidence_timeout_reward_title` | `notification_evidence_timeout_referee_title` |
| `notification_evidence_timeout_reward_body` | `notification_evidence_timeout_referee_body` |
| `notification_payout_connect_required_title` | `notification_payout_connect_required_referee_title` |
| `notification_payout_connect_required_body` | `notification_payout_connect_required_referee_body` |

Keys already correct (no change): `notification_review_timeout_*`, `notification_auto_confirm_*`, `notification_payout_failed_*`.

---

### Task 4: Rename notification keys in iOS strings

**Files:**
- Modify: `peppercheck_flutter/ios/Runner/en.lproj/Localizable.strings`
- Modify: `peppercheck_flutter/ios/Runner/ja.lproj/Localizable.strings`

**Step 1: Rename key names in both files**

Same rename table as Task 3. Note: iOS files may not have all keys (e.g. `notification_payout_*` may be absent) — only rename keys that exist.

---

### Task 5: Rename Flutter i18n keys and regenerate

**Files:**
- Modify: `peppercheck_flutter/assets/i18n/ja.i18n.json`

**Step 1: Rename keys in the `notification` section**

Keys are inside the `"notification"` JSON namespace (no `notification_` prefix):

| Old key | New key |
|---------|---------|
| `evidence_timeout_title` | `evidence_timeout_tasker_title` |
| `evidence_timeout_body` | `evidence_timeout_tasker_body` |
| `evidence_timeout_reward_title` | `evidence_timeout_referee_title` |
| `evidence_timeout_reward_body` | `evidence_timeout_referee_body` |
| `request_matched_title` | `request_matched_tasker_title` |
| `request_matched_body` | `request_matched_tasker_body` |
| `referee_assigned_title` | `task_assigned_referee_title` |
| `referee_assigned_body` | `task_assigned_referee_body` |
| `evidence_submitted_title` | `evidence_submitted_referee_title` |
| `evidence_submitted_body` | `evidence_submitted_referee_body` |
| `evidence_updated_title` | `evidence_updated_referee_title` |
| `evidence_updated_body` | `evidence_updated_referee_body` |
| `evidence_resubmitted_title` | `evidence_resubmitted_referee_title` |
| `evidence_resubmitted_body` | `evidence_resubmitted_referee_body` |

Keys already correct (no change): `review_timeout_*`, `auto_confirm_*`, `request_accepted_*`, `fallback_*`.

**Step 2: Regenerate slang**

```bash
cd peppercheck_flutter && dart run build_runner build --delete-conflicting-outputs
```

---

### Task 6: Update notification_text_resolver.dart

**Files:**
- Modify: `peppercheck_flutter/lib/features/notification/application/notification_text_resolver.dart`

**Step 1: Update both switch case keys AND `t.notification.*` accessor calls**

The case label is the key string from FCM. The accessor is the generated slang code.

| Old case key | New case key | Old accessor | New accessor |
|---|---|---|---|
| `notification_evidence_timeout_title` | `notification_evidence_timeout_tasker_title` | `t.notification.evidence_timeout_title` | `t.notification.evidence_timeout_tasker_title` |
| `notification_evidence_timeout_body` | `notification_evidence_timeout_tasker_body` | `t.notification.evidence_timeout_body(...)` | `t.notification.evidence_timeout_tasker_body(...)` |
| `notification_evidence_timeout_reward_title` | `notification_evidence_timeout_referee_title` | `t.notification.evidence_timeout_reward_title` | `t.notification.evidence_timeout_referee_title` |
| `notification_evidence_timeout_reward_body` | `notification_evidence_timeout_referee_body` | `t.notification.evidence_timeout_reward_body(...)` | `t.notification.evidence_timeout_referee_body(...)` |
| `notification_request_matched_title` | `notification_request_matched_tasker_title` | `t.notification.request_matched_title` | `t.notification.request_matched_tasker_title` |
| `notification_request_matched_body` | `notification_request_matched_tasker_body` | `t.notification.request_matched_body(...)` | `t.notification.request_matched_tasker_body(...)` |
| `notification_referee_assigned_title` | `notification_task_assigned_referee_title` | `t.notification.referee_assigned_title` | `t.notification.task_assigned_referee_title` |
| `notification_referee_assigned_body` | `notification_task_assigned_referee_body` | `t.notification.referee_assigned_body(...)` | `t.notification.task_assigned_referee_body(...)` |
| `notification_evidence_submitted_title` | `notification_evidence_submitted_referee_title` | `t.notification.evidence_submitted_title` | `t.notification.evidence_submitted_referee_title` |
| `notification_evidence_submitted_body` | `notification_evidence_submitted_referee_body` | `t.notification.evidence_submitted_body(...)` | `t.notification.evidence_submitted_referee_body(...)` |
| `notification_evidence_updated_title` | `notification_evidence_updated_referee_title` | `t.notification.evidence_updated_title` | `t.notification.evidence_updated_referee_title` |
| `notification_evidence_updated_body` | `notification_evidence_updated_referee_body` | `t.notification.evidence_updated_body(...)` | `t.notification.evidence_updated_referee_body(...)` |
| `notification_evidence_resubmitted_title` | `notification_evidence_resubmitted_referee_title` | `t.notification.evidence_resubmitted_title` | `t.notification.evidence_resubmitted_referee_title` |
| `notification_evidence_resubmitted_body` | `notification_evidence_resubmitted_referee_body` | `t.notification.evidence_resubmitted_body(...)` | `t.notification.evidence_resubmitted_referee_body(...)` |

Cases already correct: `notification_review_timeout_*`, `notification_auto_confirm_*`.

---

### Task 7: Generate migration and verify

**Step 1: Generate migration**

```bash
supabase db diff -f standardize_notification_template_keys
```

**Step 2: Review** — migration should only contain function body changes (the `notify_event()` key string arguments). No table/column changes.

**Step 3: DB reset and verify**

```bash
./scripts/db-reset-and-clear-android-emulators-cache.sh
```

**Step 4: Run all DB tests**

```bash
for f in supabase/tests/test_*.sql; do
  echo "=== Running $f ==="
  docker cp "$f" supabase_db_supabase:/tmp/ && \
  docker exec supabase_db_supabase psql -U postgres -f "/tmp/$(basename "$f")"
  echo ""
done
```

**Step 5: Build Flutter**

```bash
cd peppercheck_flutter && flutter build apk --debug -t lib/main_debug.dart 2>&1 | tail -10
```

**Step 6: Commit**

```bash
git add -A
git commit -m "refactor: standardize notification template keys (#248)"
```

---

## PR 2: Issue #247 — Remove is_evidence_timeout_confirmed flag

Branch: `refactor/remove-evidence-timeout-confirmed-flag`

### Task 8: Update SQL test expectations (TDD — test first)

**Files:**
- Modify: `supabase/tests/test_evidence_timeout_settlement.sql`

**Step 1: Replace Test 3 to verify direct request closure without the flag**

Replace lines 109-122 with:

```sql
-- ===== Test 3: Request auto-closed directly by settlement trigger =====
\echo ''
\echo '=========================================='
\echo ' Test 3: Auto-close referee side'
\echo '=========================================='

DO $$
BEGIN
  -- is_evidence_timeout_confirmed column removed — settlement trigger now closes request directly
  ASSERT (SELECT status FROM public.task_referee_requests WHERE id = 'cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = 'closed',
    'Test 3 FAILED: request should be closed';
  RAISE NOTICE 'Test 3 PASSED: referee side auto-closed';
END $$;
```

**Step 2: Run test** — should still pass (the request status assertion was already present).

```bash
docker cp supabase/tests/test_evidence_timeout_settlement.sql supabase_db_supabase:/tmp/ && \
docker exec supabase_db_supabase psql -U postgres -f /tmp/test_evidence_timeout_settlement.sql
```

---

### Task 9: Update SQL schema files

**Files:**
- Modify: `supabase/schemas/judgement/triggers/on_evidence_timeout_settle.sql`
- Modify: `supabase/schemas/judgement/functions/confirm_evidence_timeout.sql`
- Modify: `supabase/schemas/judgement/triggers/on_judgement_confirmed_close_request.sql`
- Delete: `supabase/schemas/judgement/triggers/on_judgements_evidence_timeout_close_referee_request.sql`
- Modify: `supabase/schemas/judgement/tables/judgements.sql`
- Modify: `supabase/config.toml`

**Step 1: Modify `on_evidence_timeout_settle.sql`**

Replace lines 47-51 (the `is_evidence_timeout_confirmed` UPDATE) with:

```sql
    -- Close referee request directly (same pattern as settle_review_timeout)
    UPDATE public.task_referee_requests
    SET status = 'closed'::public.referee_request_status
    WHERE id = NEW.id;
```

**Step 2: Rewrite `confirm_evidence_timeout.sql`**

Match `confirm_review_timeout()` pattern exactly:

```sql
CREATE OR REPLACE FUNCTION public.confirm_evidence_timeout(p_judgement_id uuid) RETURNS void
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
        RAISE EXCEPTION 'Only the tasker can confirm an evidence timeout';
    END IF;

    IF v_judgement.status != 'evidence_timeout' THEN
        RAISE EXCEPTION 'Judgement must be in evidence_timeout status to confirm';
    END IF;

    -- Idempotency
    IF v_judgement.is_confirmed = TRUE THEN
        RETURN;
    END IF;

    -- Confirm (triggers on_all_judgements_confirmed_close_task)
    UPDATE public.judgements SET is_confirmed = TRUE WHERE id = p_judgement_id;
END;
$$;

ALTER FUNCTION public.confirm_evidence_timeout(uuid) OWNER TO postgres;

COMMENT ON FUNCTION public.confirm_evidence_timeout(uuid) IS 'Allows tasker to confirm/acknowledge an evidence timeout. Points were already settled by the settle_evidence_timeout trigger. Sets is_confirmed = true which triggers task closure check.';
```

**Step 3: Simplify `on_judgement_confirmed_close_request.sql` WHEN clause**

Remove the `is_evidence_timeout_confirmed` condition:

```sql
CREATE OR REPLACE TRIGGER on_judgement_confirmed_close_request
    AFTER UPDATE ON public.judgements
    FOR EACH ROW
    WHEN (NEW.is_confirmed = true AND OLD.is_confirmed = false)
    EXECUTE FUNCTION public.close_referee_request_on_confirmed();
```

**Step 4: Delete the no-op trigger file**

```bash
rm supabase/schemas/judgement/triggers/on_judgements_evidence_timeout_close_referee_request.sql
```

**Step 5: Remove from `supabase/config.toml`**

Delete the line:
```
"./schemas/judgement/triggers/on_judgements_evidence_timeout_close_referee_request.sql",
```

**Step 6: Modify `judgements.sql`**

Remove from table definition (line 25):
```sql
    is_evidence_timeout_confirmed boolean DEFAULT false NOT NULL,
```

Remove index (line 37):
```sql
CREATE INDEX idx_judgements_evidence_timeout_confirmed ON public.judgements USING btree (is_evidence_timeout_confirmed) WHERE (status = 'evidence_timeout'::judgement_status);
```

Remove column comment (line 43):
```sql
COMMENT ON COLUMN public.judgements.is_evidence_timeout_confirmed IS 'Indicates whether the referee has confirmed the evidence timeout.';
```

---

### Task 10: Update Dart model and regenerate

**Files:**
- Modify: `peppercheck_flutter/lib/features/judgement/domain/judgement.dart`

**Step 1: Remove the field (lines 16-18)**

Remove these 3 lines:
```dart
    @JsonKey(name: 'is_evidence_timeout_confirmed')
    @Default(false)
    bool isEvidenceTimeoutConfirmed,
```

**Step 2: Regenerate Freezed + JSON serialization**

```bash
cd peppercheck_flutter && dart run build_runner build --delete-conflicting-outputs
```

---

### Task 11: Generate migration, test, and build

**Step 1: Generate migration**

```bash
supabase db diff -f remove_evidence_timeout_confirmed_flag
```

**Step 2: Review** — should contain: DROP column, DROP index, updated function bodies, DROP of `handle_evidence_timeout_confirmed` function/trigger.

**Step 3: DB reset**

```bash
./scripts/db-reset-and-clear-android-emulators-cache.sh
```

**Step 4: Run all DB tests**

```bash
for f in supabase/tests/test_*.sql; do
  echo "=== Running $f ==="
  docker cp "$f" supabase_db_supabase:/tmp/ && \
  docker exec supabase_db_supabase psql -U postgres -f "/tmp/$(basename "$f")"
  echo ""
done
```

**Step 5: Build Flutter**

```bash
cd peppercheck_flutter && flutter build apk --debug -t lib/main_debug.dart 2>&1 | tail -10
```

**Step 6: Commit**

```bash
git add -A
git commit -m "refactor: remove is_evidence_timeout_confirmed flag (#247)"
```

---

## PR 3: Issue #246 — Show evidence timeout state on referee task detail screen

Branch: `feat/referee-evidence-timeout-ui`

### Task 12: Add i18n strings for referee evidence timeout

**Files:**
- Modify: `peppercheck_flutter/assets/i18n/ja.i18n.json`

**Step 1: Add `referee_description` to the `task.evidence.timeout` object**

```json
"timeout": {
  "description": "期限を過ぎました。ポイントが支払われました。",
  "referee_description": "エビデンスの提出期限が過ぎたため、報酬が付与されました。",
  "confirm": "確認",
  "confirmed": "確認済み",
  "success": "確認しました"
}
```

**Step 2: Regenerate slang**

```bash
cd peppercheck_flutter && dart run build_runner build --delete-conflicting-outputs
```

---

### Task 13: Create EvidenceTimeoutRefereeSection widget

**Files:**
- Create: `peppercheck_flutter/lib/features/evidence/presentation/widgets/evidence_timeout_referee_section.dart`

**Step 1: Create the widget**

Information-only section (no buttons). Uses `accentGreen` + `info_outline` since this is a positive outcome for the referee (reward earned):

```dart
import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class EvidenceTimeoutRefereeSection extends StatelessWidget {
  const EvidenceTimeoutRefereeSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseSection(
      title: t.task.evidence.title,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.cardPaddingHorizontal,
          vertical: AppSizes.cardPaddingVertical,
        ),
        decoration: BoxDecoration(
          color: AppColors.backgroundWhite,
          borderRadius: BorderRadius.circular(AppSizes.cardBorderRadius),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.accentGreen, size: 20),
            const SizedBox(width: AppSizes.spacingTiny),
            Expanded(
              child: Text(
                t.task.evidence.timeout.referee_description,
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

### Task 14: Integrate in TaskDetailScreen

**Files:**
- Modify: `peppercheck_flutter/lib/features/task/presentation/task_detail_screen.dart`

**Step 1: Add import**

```dart
import 'package:peppercheck_flutter/features/evidence/presentation/widgets/evidence_timeout_referee_section.dart';
```

**Step 2: Add section after EvidenceSubmissionSection block (after line 66)**

```dart
if (_shouldShowEvidenceTimeoutRefereeSection(displayTask)) ...[
  const EvidenceTimeoutRefereeSection(),
  const SizedBox(height: AppSizes.sectionGap),
],
```

**Step 3: Add helper method after `_shouldShowEvidenceSection` (after line 95)**

```dart
bool _shouldShowEvidenceTimeoutRefereeSection(Task task) {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return false;
  // Only for non-tasker (referee)
  if (task.taskerId == userId) return false;
  return task.refereeRequests.any(
    (req) => req.judgement?.status == 'evidence_timeout',
  );
}
```

Note: `_shouldShowEvidenceSection` already returns `false` for referee when evidence is null and there's no evidence, so the two sections won't overlap.

**Step 4: Build Flutter**

```bash
cd peppercheck_flutter && flutter build apk --debug -t lib/main_debug.dart 2>&1 | tail -10
```

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: show evidence timeout state on referee task detail screen (#246)"
```

---

## PR 4: Issue #258 — Improve evidence submission button styles

Branch: `ui/evidence-button-styling`

### Task 15: Change evidence buttons to PrimaryActionButton

**Files:**
- Modify: `peppercheck_flutter/lib/features/evidence/presentation/widgets/evidence_submission_section.dart`

**Step 1: Ensure PrimaryActionButton import exists**

Add if not already present:
```dart
import 'package:peppercheck_flutter/common_widgets/primary_action_button.dart';
```

**Step 2: Change initial Submit button (line 601)**

Replace `ActionButton` with `PrimaryActionButton`:

```dart
PrimaryActionButton(
  text: t.task.evidence.submit,
  onPressed:
      _selectedImages.isNotEmpty &&
          _descriptionController.text.isNotEmpty
      ? _submit
      : null,
  isLoading: isLoading,
),
```

**Step 3: Change Resubmit button in submitted view (line 433)**

Replace `ActionButton` with `PrimaryActionButton`:

```dart
PrimaryActionButton(
  text: t.task.evidence.resubmit,
  onPressed: () => _enterEditMode(isResubmit: true),
  isLoading: false,
),
```

**Step 4: Split the edit form button (lines 353-362) into conditional**

Currently one `ActionButton` handles both Update and Resubmit. Replace `Expanded(child: ActionButton(...))` with:

```dart
Expanded(
  child: _isResubmit
      ? PrimaryActionButton(
          text: t.task.evidence.resubmit,
          onPressed: _descriptionController.text.isNotEmpty
              ? _resubmitEvidence
              : null,
          isLoading: isLoading,
        )
      : ActionButton(
          text: t.task.evidence.update,
          onPressed: _descriptionController.text.isNotEmpty
              ? _updateEvidence
              : null,
          isLoading: isLoading,
        ),
),
```

**Step 5: Build Flutter**

```bash
cd peppercheck_flutter && flutter build apk --debug -t lib/main_debug.dart 2>&1 | tail -10
```

**Step 6: Commit**

```bash
git add -A
git commit -m "ui: improve evidence submission button styles (#258)"
```
