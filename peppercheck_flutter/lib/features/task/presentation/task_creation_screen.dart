import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/app_background.dart';
import 'package:peppercheck_flutter/common_widgets/app_scaffold.dart';
import 'package:peppercheck_flutter/common_widgets/primary_action_button.dart';
import 'package:peppercheck_flutter/features/task/presentation/task_creation_controller.dart';
import 'package:peppercheck_flutter/features/task/presentation/widgets/task_creation/task_form_section.dart';
import 'package:peppercheck_flutter/features/task/presentation/widgets/task_creation/matching_strategy_selection_section.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class TaskCreationScreen extends ConsumerWidget {
  const TaskCreationScreen({super.key});

  static const route = '/create_task';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(taskCreationControllerProvider);
    final controller = ref.read(taskCreationControllerProvider.notifier);

    return AppBackground(
      child: AppScaffold.scrollable(
        title: t.task.creation.title,
        slivers: [
          SliverToBoxAdapter(
            child: state.when(
              data: (request) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TaskFormSection(),
                    if (request.taskStatus == 'open') ...[
                      const SizedBox(height: AppSizes.sectionGap),
                      MatchingStrategySelectionSection(
                        selectedStrategies: request.selectedStrategies,
                        onStrategiesChange: controller.updateSelectedStrategies,
                      ),
                    ],
                    const SizedBox(height: AppSizes.buttonGap),
                    PrimaryActionButton(
                      text: t.task.creation.buttonCreate,
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
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
