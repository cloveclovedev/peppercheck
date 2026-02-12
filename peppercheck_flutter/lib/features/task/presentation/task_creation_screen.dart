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
import 'package:peppercheck_flutter/features/task/presentation/widgets/task_creation/task_creation_error_dialog.dart';

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

    final asyncState = ref.watch(taskCreationControllerProvider(task));
    final controller = ref.read(taskCreationControllerProvider(task).notifier);

    // Listen for creation errors and show dialog
    ref.listen(
      taskCreationControllerProvider(task).select((state) => state.value?.creationError),
      (previous, next) {
        if (next != null) {
          showDialog(
            context: context,
            builder: (context) => TaskCreationErrorDialog(error: next),
          ).then((_) {
            // Clear error after dialog is dismissed
            controller.clearCreationError();
          });
        }
      },
    );

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
            child: asyncState.when(
              data: (state) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TaskFormSection(initialData: state.request, task: task),
                  if (state.request.taskStatus == 'open') ...[
                    const SizedBox(height: AppSizes.sectionGap),
                    MatchingStrategySelectionSection(
                      selectedStrategies: state.request.matchingStrategies,
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
                              final currentState = ref.read(taskCreationControllerProvider(task));
                              // Success check: if no creation error, close screen
                              if (currentState.value?.creationError == null) {
                                Navigator.of(context).pop();
                              }
                              // Error dialog is handled by ref.listen
                            }
                          }
                        : null,
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                // This error case is for initialization errors only
                // Creation errors are handled via ref.listen and stored in state.creationError
                child: Text('初期化エラーが発生しました'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
