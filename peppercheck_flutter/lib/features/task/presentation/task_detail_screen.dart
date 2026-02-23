import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/app_background.dart';
import 'package:peppercheck_flutter/common_widgets/app_scaffold.dart';

import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/features/task/presentation/widgets/task_detail/task_detail_info_section.dart';
import 'package:peppercheck_flutter/features/task/presentation/widgets/task_detail/task_referees_section.dart';
import 'package:peppercheck_flutter/features/evidence/presentation/widgets/evidence_submission_section.dart';
import 'package:peppercheck_flutter/features/evidence/presentation/widgets/evidence_timeout_referee_section.dart';
import 'package:peppercheck_flutter/features/judgement/presentation/widgets/judgement_section.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:peppercheck_flutter/features/task/presentation/providers/task_provider.dart';

class TaskDetailScreen extends ConsumerWidget {
  final String taskId;
  final Task? initialTask;

  const TaskDetailScreen({super.key, required this.taskId, this.initialTask});

  static const route = '/task_detail';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTask = ref.watch(taskProvider(taskId));

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
        onRefresh: () async {
          return ref.refresh(taskProvider(taskId).future);
        },
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TaskDetailInfoSection(task: displayTask),
                const SizedBox(height: AppSizes.sectionGap),
                TaskRefereesSection(task: displayTask),
                const SizedBox(height: AppSizes.sectionGap),
                if (_shouldShowEvidenceSection(displayTask)) ...[
                  EvidenceSubmissionSection(task: displayTask),
                  const SizedBox(height: AppSizes.sectionGap),
                ],
                if (_shouldShowEvidenceTimeoutRefereeSection(displayTask)) ...[
                  const EvidenceTimeoutRefereeSection(),
                  const SizedBox(height: AppSizes.sectionGap),
                ],
                JudgementSection(task: displayTask),
                const SizedBox(height: AppSizes.sectionGap),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowEvidenceSection(Task task) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || task.taskerId != userId) {
      if (task.evidence != null) return true;
      return false;
    }

    if (task.evidence != null) return true;

    final hasEvidenceTimeout = task.refereeRequests.any(
      (req) => req.judgement?.status == 'evidence_timeout',
    );
    if (hasEvidenceTimeout) return true;

    final hasAcceptedRequest = task.refereeRequests.any(
      (req) => req.status == 'accepted',
    );
    return hasAcceptedRequest;
  }

  bool _shouldShowEvidenceTimeoutRefereeSection(Task task) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return false;
    // Only for non-tasker (referee)
    if (task.taskerId == userId) return false;
    return task.refereeRequests.any(
      (req) => req.judgement?.status == 'evidence_timeout',
    );
  }
}
