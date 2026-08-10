import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/app_background.dart';
import 'package:peppercheck_flutter/common_widgets/app_scaffold.dart';

import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/features/task/ui/widgets/task_detail/task_detail_info_section.dart';
import 'package:peppercheck_flutter/features/task/ui/widgets/task_detail/tasker_referees_section.dart';
import 'package:peppercheck_flutter/features/task/ui/widgets/task_detail/withdraw_matching_button.dart';
import 'package:peppercheck_flutter/features/task/ui/task_detail_view_model.dart';
import 'package:peppercheck_flutter/features/task/ui/task_role_provider.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';
// Phase 4b: evidence_submission_section, evidence_timeout_referee_section
// Phase 4c: judgement_section, report_menu_button
// Those features still read Supabase auth even on their empty branch, so they
// stay unmounted until their own phase migrates them.

class TaskDetailScreen extends ConsumerStatefulWidget {
  final String taskId;
  final Task? initialTask;

  const TaskDetailScreen({super.key, required this.taskId, this.initialTask});

  static const route = '/task_detail';

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  /// One poll per visit: a task that is still matching when the screen opens
  /// (typically right after publishing) is watched until the server answers.
  bool _pollStarted = false;

  void _startPollIfMatching(Task task) {
    if (_pollStarted || !TaskDetail.isMatching(task)) return;
    _pollStarted = true;
    // The notifier owns the poll's failures; nothing here can act on them.
    unawaited(
      ref.read(taskDetailProvider(widget.taskId).notifier).pollUntilMatched(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskId = widget.taskId;
    final initialTask = widget.initialTask;
    final asyncTask = ref.watch(taskDetailProvider(taskId));
    final role = ref.watch(taskRoleProvider(taskId));

    final loadedTask = asyncTask.value;
    if (loadedTask != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _startPollIfMatching(loadedTask),
      );
    }

    // Use latest data if available, then initialTask, then show loading
    final displayTask = asyncTask.asData?.value ?? initialTask;

    if (displayTask == null) {
      return AppBackground(
        child: AppScaffold.scrollable(
          title: t.task.detail.title,
          currentIndex: -1,
          slivers: [
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      );
    }

    return AppBackground(
      child: AppScaffold.scrollable(
        title: t.task.detail.title,
        currentIndex: -1,
        // Phase 4c: actions: [ReportMenuButton(task: displayTask)],
        onRefresh: () async {
          // A manual refresh may also restart a poll that stopped early.
          _pollStarted = false;
          return ref.refresh(taskDetailProvider(taskId).future);
        },
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TaskDetailInfoSection(task: displayTask),
                const SizedBox(height: AppSizes.sectionGap),
                if (role.value?.isTasker ?? false) ...[
                  TaskerRefereesSection(task: displayTask),
                  const SizedBox(height: AppSizes.sectionGap),
                ],
                // Phase 4b: EvidenceSubmissionSection,
                // EvidenceTimeoutRefereeSection
                // Phase 4c: JudgementSection
                WithdrawMatchingButton(task: displayTask),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
