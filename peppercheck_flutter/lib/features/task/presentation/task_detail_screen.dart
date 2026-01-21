import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/app_background.dart';
import 'package:peppercheck_flutter/common_widgets/app_scaffold.dart';

import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/features/task/presentation/widgets/task_detail/task_detail_info_section.dart';
import 'package:peppercheck_flutter/features/task/presentation/widgets/task_detail/task_referees_section.dart';
import 'package:peppercheck_flutter/features/evidence/presentation/widgets/evidence_submission_section.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:peppercheck_flutter/features/task/presentation/providers/task_provider.dart';

class TaskDetailScreen extends ConsumerWidget {
  final Task task;

  const TaskDetailScreen({super.key, required this.task});

  static const route = '/task_detail';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the latest task data from the server
    final asyncTask = ref.watch(taskProvider(task.id));

    // Use the latest data if available, otherwise fallback to the passed task (optimistic UI)
    // This ensures no flickering on initial load while ensuring we show the latest status after updates.
    final displayTask = asyncTask.asData?.value ?? task;

    return AppBackground(
      child: AppScaffold.scrollable(
        title: t.task.detail.title,
        currentIndex: -1, // No bottom nav item selected
        onRefresh: () async {
          // Invalidate to force a re-fetch
          return ref.refresh(taskProvider(task.id).future);
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
                if (_shouldShowEvidenceSection(displayTask))
                  EvidenceSubmissionSection(task: displayTask),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowEvidenceSection(Task task) {
    // 1. User must be logged in and be the tasker
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || task.taskerId != userId) {
      // If not tasker, we still might want to show submitted evidence?
      // Requirement: Show section if User is Tasker and at least one Request is Accepted.
      // Referees also need to see evidence.
      // "Submitted Evidence" part of EvidenceSubmissionSection handles read-only view.
      // So we should show it if evidence exists OR (isTasker && hasAcceptedRequest).
      // Logic refined based on "EvidenceSubmissionSection" handling "Submitted View".

      if (task.evidence != null) {
        return true; // Always show if evidence exists (for referee/tasker)
      }
      return false;
    }

    // 2. If Tasker: Show if evidence exists OR if request accepted
    if (task.evidence != null) {
      return true;
    }

    // Check if any request is accepted
    // RefereeRequest status: 'accepted'
    final hasAcceptedRequest = task.refereeRequests.any(
      (req) => req.status == 'accepted',
    );
    return hasAcceptedRequest;
  }
}
