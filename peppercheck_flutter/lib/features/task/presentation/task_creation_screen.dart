import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/app_background.dart';
import 'package:peppercheck_flutter/common_widgets/app_scaffold.dart';
import 'package:peppercheck_flutter/common_widgets/primary_action_button.dart';
import 'package:peppercheck_flutter/features/task/presentation/task_creation_controller.dart';
import 'package:peppercheck_flutter/features/task/presentation/widgets/task_creation/task_form_section.dart';
import 'package:peppercheck_flutter/features/task/presentation/widgets/task_creation/matching_strategy_selection_section.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class TaskCreationScreen extends ConsumerStatefulWidget {
  const TaskCreationScreen({super.key});

  static const route = '/create_task';

  @override
  ConsumerState<TaskCreationScreen> createState() => _TaskCreationScreenState();
}

class _TaskCreationScreenState extends ConsumerState<TaskCreationScreen> {
  @override
  Widget build(BuildContext context) {
    // Check for extra data (Task for editing)
    final extra = GoRouterState.of(context).extra;
    final task = extra is Task ? extra : null;
    final isEditing = task != null;

    final state = ref.watch(taskCreationControllerProvider(task));
    final controller = ref.read(taskCreationControllerProvider(task).notifier);

    // Determine texts
    final appBarTitle = isEditing
        ? t.task.creation.titleEdit
        : t.task.creation.title;
    final buttonText = isEditing
        ? t.task.creation.buttonUpdate
        : t.task.creation.buttonCreate;

    return AppBackground(
      child: AppScaffold.scrollable(
        currentIndex: -1,
        title: appBarTitle,
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TaskFormSection(initialData: state, task: task),
                if (state.taskStatus == 'open') ...[
                  const SizedBox(height: AppSizes.sectionGap),
                  MatchingStrategySelectionSection(
                    selectedStrategies: state.matchingStrategies,
                    onStrategiesChange: controller.updateMatchingStrategies,
                  ),
                ],
                const SizedBox(height: AppSizes.buttonGap),
                PrimaryActionButton(
                  text: buttonText,
                  onPressed: controller.isFormValid
                      ? () async {
                          await controller.createTask();
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        }
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
