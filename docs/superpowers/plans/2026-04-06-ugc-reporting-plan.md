# UGC Reporting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a UGC reporting mechanism to satisfy Google Play's content reporting requirement, allowing users to report inappropriate content from the task detail screen.

**Architecture:** Overflow menu (`⋮`) on TaskDetailScreen opens a two-step bottom sheet (content type → reason). Reports are stored in a `reports` table with RLS allowing insert/select own. Reporter role and content context are auto-detected from task data.

**Tech Stack:** Supabase (PostgreSQL, RLS), Flutter (Riverpod, Freezed not needed — write-only), slang (i18n)

**Design Spec:** `docs/superpowers/specs/2026-04-06-ugc-reporting-design.md`

---

### Task 1: DB Schema — ENUMs

**Files:**
- Create: `supabase/schemas/report/tables/enums.sql`

- [ ] **Step 1: Create ENUM file**

```sql
CREATE TYPE public.report_content_type AS ENUM (
    'task_description',
    'evidence',
    'judgement'
);

CREATE TYPE public.report_reason AS ENUM (
    'inappropriate_content',
    'harassment',
    'spam',
    'other'
);

CREATE TYPE public.report_status AS ENUM (
    'pending',
    'reviewing',
    'resolved',
    'dismissed'
);

CREATE TYPE public.reporter_role AS ENUM (
    'tasker',
    'referee'
);
```

- [ ] **Step 2: Commit**

```bash
git add supabase/schemas/report/tables/enums.sql
git commit -m "feat(supabase): add report ENUM types"
```

---

### Task 2: DB Schema — Table

**Files:**
- Create: `supabase/schemas/report/tables/reports.sql`

- [ ] **Step 1: Create table file**

```sql
CREATE TABLE IF NOT EXISTS public.reports (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    reporter_id uuid NOT NULL,
    task_id uuid NOT NULL,
    reporter_role public.reporter_role NOT NULL,
    content_type public.report_content_type NOT NULL,
    content_id uuid,
    reason public.report_reason NOT NULL,
    detail text,
    status public.report_status NOT NULL DEFAULT 'pending'::public.report_status,
    admin_note text,
    resolved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT reports_pkey PRIMARY KEY (id),
    CONSTRAINT reports_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES auth.users(id) ON DELETE CASCADE,
    CONSTRAINT reports_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE,
    CONSTRAINT reports_unique_per_user_task UNIQUE (reporter_id, task_id)
);

ALTER TABLE public.reports OWNER TO postgres;

CREATE INDEX idx_reports_task_id ON public.reports USING btree (task_id);
CREATE INDEX idx_reports_status ON public.reports USING btree (status);
CREATE INDEX idx_reports_created_at ON public.reports USING btree (created_at);

CREATE TRIGGER on_reports_update_set_updated_at
    BEFORE UPDATE ON public.reports
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();
```

- [ ] **Step 2: Commit**

```bash
git add supabase/schemas/report/tables/reports.sql
git commit -m "feat(supabase): add reports table schema"
```

---

### Task 3: DB Schema — RLS Policies

**Files:**
- Create: `supabase/schemas/report/policies/reports_policies.sql`

- [ ] **Step 1: Create policies file**

```sql
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "reports: insert own" ON public.reports
    FOR INSERT
    WITH CHECK (reporter_id = (SELECT auth.uid()));

CREATE POLICY "reports: select own" ON public.reports
    FOR SELECT
    USING (reporter_id = (SELECT auth.uid()));
```

- [ ] **Step 2: Commit**

```bash
git add supabase/schemas/report/policies/reports_policies.sql
git commit -m "feat(supabase): add RLS policies for reports table"
```

---

### Task 4: Register Schema Files and Generate Migration

**Files:**
- Modify: `supabase/config.toml` (the `schema_paths` array in `[db.migrations]`)

- [ ] **Step 1: Register schema files in config.toml**

Add these entries to the `schema_paths` array. Place the ENUMs before the table, and policies in the policies section. Follow the existing ordering pattern in config.toml:

In the **tables section** (after task-related tables, before view/function sections):
```toml
# Report
"./schemas/report/tables/enums.sql",
"./schemas/report/tables/reports.sql",
```

In the **policies section** (after existing policy entries):
```toml
"./schemas/report/policies/reports_policies.sql",
```

- [ ] **Step 2: Generate migration**

```bash
supabase db diff -f add_reports_table
```

- [ ] **Step 3: Review the generated migration file**

Open `supabase/migrations/*_add_reports_table.sql` and verify it contains:
- All 4 ENUM types
- The `reports` table with all columns, constraints, and indexes
- The `handle_updated_at` trigger
- RLS enable + 2 policies

- [ ] **Step 4: Reset DB and verify**

```bash
./scripts/db-reset-and-clear-android-emulators-cache.sh
```

Wait for user to verify the reset completed successfully.

- [ ] **Step 5: Commit**

```bash
git add supabase/config.toml supabase/migrations/*_add_reports_table.sql
git commit -m "feat(supabase): add reports table migration"
```

---

### Task 5: DB Tests

**Files:**
- Create: `supabase/tests/database/reports.test.sql`

Tests use pgTAP format and run via `supabase test db`.

- [ ] **Step 1: Write pgTAP tests**

```sql
begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

-- ============================================================
-- Setup: create two test users
-- ============================================================
INSERT INTO auth.users (id, email) VALUES
    ('a1111111-1111-1111-1111-111111111111', 'reporter@test.com'),
    ('b2222222-2222-2222-2222-222222222222', 'other@test.com');

-- Create a task owned by 'other' user
INSERT INTO public.tasks (id, tasker_id, title, due_date, status) VALUES
    ('c3333333-3333-3333-3333-333333333333',
     'b2222222-2222-2222-2222-222222222222',
     'Test Task',
     NOW() + INTERVAL '1 day',
     'open');

-- ============================================================
-- Test 1: Can insert a report
-- ============================================================
SELECT lives_ok(
    $$
    INSERT INTO public.reports (reporter_id, task_id, reporter_role, content_type, reason, detail)
    VALUES (
        'a1111111-1111-1111-1111-111111111111',
        'c3333333-3333-3333-3333-333333333333',
        'referee',
        'task_description',
        'inappropriate_content',
        'Test report detail'
    )
    $$,
    'Can insert a report'
);

-- ============================================================
-- Test 2: Status defaults to pending
-- ============================================================
SELECT is(
    (SELECT status::text FROM public.reports
     WHERE reporter_id = 'a1111111-1111-1111-1111-111111111111'
       AND task_id = 'c3333333-3333-3333-3333-333333333333'),
    'pending',
    'Report status defaults to pending'
);

-- ============================================================
-- Test 3: Unique constraint prevents duplicate report (same reporter + task)
-- ============================================================
SELECT throws_ok(
    $$
    INSERT INTO public.reports (reporter_id, task_id, reporter_role, content_type, reason)
    VALUES (
        'a1111111-1111-1111-1111-111111111111',
        'c3333333-3333-3333-3333-333333333333',
        'referee',
        'evidence',
        'spam'
    )
    $$,
    '23505',
    NULL,
    'Duplicate report (same reporter + task) raises unique violation'
);

-- ============================================================
-- Test 4: Different user can report the same task
-- ============================================================
SELECT lives_ok(
    $$
    INSERT INTO public.reports (reporter_id, task_id, reporter_role, content_type, reason)
    VALUES (
        'b2222222-2222-2222-2222-222222222222',
        'c3333333-3333-3333-3333-333333333333',
        'tasker',
        'judgement',
        'harassment'
    )
    $$,
    'Different user can report the same task'
);

select * from finish();
rollback;
```

- [ ] **Step 2: Run tests**

```bash
supabase test db
```

Expected: All 4 tests pass.

- [ ] **Step 3: Commit**

```bash
git add supabase/tests/database/reports.test.sql
git commit -m "test(supabase): add pgTAP tests for reports table"
```

---

### Task 6: i18n Strings

**Files:**
- Modify: `peppercheck_flutter/assets/i18n/ja.i18n.json`

- [ ] **Step 1: Add report strings to ja.i18n.json**

Add a `report` section at the top level of the JSON:

```json
"report": {
  "menuItem": "問題を報告",
  "menuItemReported": "問題を報告（報告済み）",
  "sheetTitle": "問題を報告",
  "contentTypeTitle": "何を報告しますか？",
  "contentType": {
    "taskDescription": "タスクの説明文",
    "evidence": "エビデンス",
    "judgement": "評価・コメント"
  },
  "reasonTitle": "報告理由",
  "reason": {
    "inappropriateContent": "不適切なコンテンツ",
    "harassment": "ハラスメント",
    "spam": "スパム",
    "other": "その他"
  },
  "detailHint": "詳細を入力（任意）",
  "submit": "送信",
  "successMessage": "報告を送信しました",
  "errorMessage": "報告の送信に失敗しました: $message"
}
```

- [ ] **Step 2: Run slang code generation**

```bash
cd peppercheck_flutter && dart run slang
```

Verify `lib/gen/slang/strings.g.dart` is regenerated without errors.

- [ ] **Step 3: Commit**

```bash
git add peppercheck_flutter/assets/i18n/ja.i18n.json peppercheck_flutter/lib/gen/slang/
git commit -m "feat(flutter): add i18n strings for report feature"
```

---

### Task 7: Flutter Repository

**Files:**
- Create: `peppercheck_flutter/lib/features/report/data/report_repository.dart`

- [ ] **Step 1: Create report repository**

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'report_repository.g.dart';

@riverpod
ReportRepository reportRepository(Ref ref) {
  return ReportRepository(Supabase.instance.client);
}

class ReportRepository {
  final SupabaseClient _client;

  ReportRepository(this._client);

  Future<void> submitReport({
    required String taskId,
    required String reporterRole,
    required String contentType,
    String? contentId,
    required String reason,
    String? detail,
  }) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('reports').insert({
      'reporter_id': userId,
      'task_id': taskId,
      'reporter_role': reporterRole,
      'content_type': contentType,
      'content_id': contentId,
      'reason': reason,
      'detail': detail,
    });
  }

  Future<bool> hasReported(String taskId) async {
    final userId = _client.auth.currentUser!.id;
    final result = await _client
        .from('reports')
        .select('id')
        .eq('reporter_id', userId)
        .eq('task_id', taskId)
        .maybeSingle();
    return result != null;
  }
}
```

- [ ] **Step 2: Run code generation**

```bash
cd peppercheck_flutter && dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 3: Commit**

```bash
git add peppercheck_flutter/lib/features/report/
git commit -m "feat(flutter): add report repository"
```

---

### Task 8: Flutter Controller

**Files:**
- Create: `peppercheck_flutter/lib/features/report/presentation/report_controller.dart`

- [ ] **Step 1: Create report controller**

```dart
import 'dart:async';

import 'package:peppercheck_flutter/features/report/data/report_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'report_controller.g.dart';

@riverpod
class ReportController extends _$ReportController {
  @override
  FutureOr<void> build() {}

  Future<bool> submitReport({
    required String taskId,
    required String reporterRole,
    required String contentType,
    String? contentId,
    required String reason,
    String? detail,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(reportRepositoryProvider).submitReport(
            taskId: taskId,
            reporterRole: reporterRole,
            contentType: contentType,
            contentId: contentId,
            reason: reason,
            detail: detail,
          );
    });
    return !state.hasError;
  }
}

@riverpod
Future<bool> hasReported(Ref ref, String taskId) {
  return ref.watch(reportRepositoryProvider).hasReported(taskId);
}
```

- [ ] **Step 2: Run code generation**

```bash
cd peppercheck_flutter && dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 3: Commit**

```bash
git add peppercheck_flutter/lib/features/report/
git commit -m "feat(flutter): add report controller and hasReported provider"
```

---

### Task 9: Report Bottom Sheet Widget

**Files:**
- Create: `peppercheck_flutter/lib/features/report/presentation/widgets/report_bottom_sheet.dart`

This is a `StatefulWidget` managing local selection state (content type, reason, detail text). Submission delegates to `ReportController`.

- [ ] **Step 1: Create the bottom sheet widget**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/features/report/presentation/report_controller.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

/// Shows the report bottom sheet and returns `true` if the report was submitted.
Future<bool?> showReportBottomSheet(
  BuildContext context, {
  required String taskId,
  required bool isTasker,
  required String? evidenceId,
  required String? judgementId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReportBottomSheet(
      taskId: taskId,
      isTasker: isTasker,
      evidenceId: evidenceId,
      judgementId: judgementId,
    ),
  );
}

class _ReportBottomSheet extends ConsumerStatefulWidget {
  final String taskId;
  final bool isTasker;
  final String? evidenceId;
  final String? judgementId;

  const _ReportBottomSheet({
    required this.taskId,
    required this.isTasker,
    required this.evidenceId,
    required this.judgementId,
  });

  @override
  ConsumerState<_ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends ConsumerState<_ReportBottomSheet> {
  String? _selectedContentType;
  String? _selectedReason;
  final _detailController = TextEditingController();
  bool _isSubmitting = false;

  List<_RadioOption> get _contentTypeOptions {
    if (widget.isTasker) {
      return [
        _RadioOption('judgement', t.report.contentType.judgement),
      ];
    }
    return [
      _RadioOption('task_description', t.report.contentType.taskDescription),
      _RadioOption('evidence', t.report.contentType.evidence),
    ];
  }

  static const _reasonOptions = [
    ('inappropriate_content', null),
    ('harassment', null),
    ('spam', null),
    ('other', null),
  ];

  String _reasonLabel(String value) {
    switch (value) {
      case 'inappropriate_content':
        return t.report.reason.inappropriateContent;
      case 'harassment':
        return t.report.reason.harassment;
      case 'spam':
        return t.report.reason.spam;
      case 'other':
        return t.report.reason.other;
      default:
        return value;
    }
  }

  String? _resolveContentId() {
    switch (_selectedContentType) {
      case 'evidence':
        return widget.evidenceId;
      case 'judgement':
        return widget.judgementId;
      default:
        return null;
    }
  }

  Future<void> _submit() async {
    if (_selectedContentType == null || _selectedReason == null) return;

    setState(() => _isSubmitting = true);

    final success = await ref.read(reportControllerProvider.notifier).submitReport(
          taskId: widget.taskId,
          reporterRole: widget.isTasker ? 'tasker' : 'referee',
          contentType: _selectedContentType!,
          contentId: _resolveContentId(),
          reason: _selectedReason!,
          detail: _selectedReason == 'other' ? _detailController.text : null,
        );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _isSubmitting = false);
      final errorState = ref.read(reportControllerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t.report.errorMessage(message: errorState.error.toString()),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit =
        _selectedContentType != null && _selectedReason != null && !_isSubmitting;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.screenHorizontalPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSizes.spacingSmall),
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.spacingMedium),
              Text(
                t.report.sheetTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: AppSizes.spacingMedium),
              // Content type selection
              Text(
                t.report.contentTypeTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSizes.spacingSmall),
              ..._contentTypeOptions.map(
                (option) => RadioListTile<String>(
                  title: Text(option.label),
                  value: option.value,
                  groupValue: _selectedContentType,
                  onChanged: (v) => setState(() => _selectedContentType = v),
                ),
              ),
              const SizedBox(height: AppSizes.spacingMedium),
              // Reason selection
              Text(
                t.report.reasonTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSizes.spacingSmall),
              ...['inappropriate_content', 'harassment', 'spam', 'other'].map(
                (reason) => RadioListTile<String>(
                  title: Text(_reasonLabel(reason)),
                  value: reason,
                  groupValue: _selectedReason,
                  onChanged: (v) => setState(() => _selectedReason = v),
                ),
              ),
              // Detail field for "other"
              if (_selectedReason == 'other') ...[
                const SizedBox(height: AppSizes.spacingSmall),
                TextField(
                  controller: _detailController,
                  decoration: InputDecoration(
                    hintText: t.report.detailHint,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
              const SizedBox(height: AppSizes.spacingMedium),
              // Submit button
              FilledButton(
                onPressed: canSubmit ? _submit : null,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(t.report.submit),
              ),
              const SizedBox(height: AppSizes.spacingMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioOption {
  final String value;
  final String label;
  const _RadioOption(this.value, this.label);
}
```

- [ ] **Step 2: Commit**

```bash
git add peppercheck_flutter/lib/features/report/presentation/widgets/report_bottom_sheet.dart
git commit -m "feat(flutter): add report bottom sheet widget"
```

---

### Task 10: Report Menu Button + TaskDetailScreen Integration

**Files:**
- Create: `peppercheck_flutter/lib/features/report/presentation/widgets/report_menu_button.dart`
- Modify: `peppercheck_flutter/lib/features/task/presentation/task_detail_screen.dart`

- [ ] **Step 1: Create the report menu button widget**

This widget encapsulates the `PopupMenuButton`, the "already reported" check, and opening the bottom sheet.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peppercheck_flutter/features/report/presentation/report_controller.dart';
import 'package:peppercheck_flutter/features/report/presentation/widgets/report_bottom_sheet.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportMenuButton extends ConsumerWidget {
  final Task task;

  const ReportMenuButton({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasReportedAsync = ref.watch(hasReportedProvider(task.id));
    final alreadyReported = hasReportedAsync.valueOrNull ?? false;

    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'report' && !alreadyReported) {
          final userId = Supabase.instance.client.auth.currentUser?.id;
          final isTasker = task.taskerId == userId;
          final judgementId = task.refereeRequests
              .where((r) => r.judgement != null)
              .map((r) => r.judgement!.id)
              .firstOrNull;

          final reported = await showReportBottomSheet(
            context,
            taskId: task.id,
            isTasker: isTasker,
            evidenceId: task.evidence?.id,
            judgementId: judgementId,
          );

          if (reported == true) {
            ref.invalidate(hasReportedProvider(task.id));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t.report.successMessage)),
              );
            }
          }
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: 'report',
          enabled: !alreadyReported,
          child: Text(
            alreadyReported
                ? t.report.menuItemReported
                : t.report.menuItem,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Add ReportMenuButton to TaskDetailScreen**

In `peppercheck_flutter/lib/features/task/presentation/task_detail_screen.dart`:

Add import:
```dart
import 'package:peppercheck_flutter/features/report/presentation/widgets/report_menu_button.dart';
```

In the `build` method, add `actions` to both `AppScaffold.scrollable` calls where `displayTask` is available:

Change:
```dart
      return AppBackground(
        child: AppScaffold.scrollable(
          title: t.task.detail.title,
          currentIndex: -1,
          onRefresh: () async {
```

To:
```dart
      return AppBackground(
        child: AppScaffold.scrollable(
          title: t.task.detail.title,
          currentIndex: -1,
          actions: [ReportMenuButton(task: displayTask)],
          onRefresh: () async {
```

- [ ] **Step 3: Commit**

```bash
git add peppercheck_flutter/lib/features/report/presentation/widgets/report_menu_button.dart peppercheck_flutter/lib/features/task/presentation/task_detail_screen.dart
git commit -m "feat(flutter): integrate report menu into task detail screen"
```

---

### Task 11: Build Verification

- [ ] **Step 1: Run code generation**

```bash
cd peppercheck_flutter && dart run build_runner build --delete-conflicting-outputs
```

Expected: completes without errors. Generated files appear for `report_repository.g.dart` and `report_controller.g.dart`.

- [ ] **Step 2: Run Flutter build**

```bash
cd peppercheck_flutter && flutter build apk --debug -t lib/main_debug.dart 2>&1 | tail -20
```

Expected: `BUILD SUCCESSFUL`

- [ ] **Step 3: Run all DB tests to verify no regressions**

```bash
supabase test db
```

Expected: All tests pass including the new `reports.test.sql`.

- [ ] **Step 4: Commit any generated files**

```bash
cd peppercheck_flutter && git add -A lib/features/report/ lib/gen/
git commit -m "chore(flutter): add generated files for report feature"
```
