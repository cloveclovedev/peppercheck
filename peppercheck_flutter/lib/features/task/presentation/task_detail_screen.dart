import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/app_background.dart';
import 'package:peppercheck_flutter/common_widgets/app_scaffold.dart';

import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/features/task/presentation/widgets/task_detail/task_detail_info_section.dart';
import 'package:peppercheck_flutter/features/task/presentation/widgets/task_detail/task_referees_section.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
