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

    // Listen for success to pop
    ref.listen(taskCreationControllerProvider, (previous, next) {
      if (previous is AsyncLoading && next is AsyncData) {
        // Success handling
      }
    });

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
                    // Header to Form spacing - matching Home/Payment (usually small or none if AppBar provides enough)
                    // User said "Header and task form section spacing is large".
                    // AppBar has default height.
                    // We removed the explicit SizedBox(height: 16).
                    TaskFormSection(
                      title: request.title,
                      onTitleChange: controller.updateTitle,
                      description: request.description,
                      onDescriptionChange: controller.updateDescription,
                      criteria: request.criteria,
                      onCriteriaChange: controller.updateCriteria,
                      selectedDateTime: request.selectedDateTime,
                      onDateTimeClick: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (date != null && context.mounted) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (time != null) {
                            final dateTime = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                            controller.updateSelectedDateTime(dateTime);
                          }
                        }
                      },
                      taskStatus: request.taskStatus,
                      onStatusChange: controller.updateTaskStatus,
                    ),
                    if (request.taskStatus == 'open') ...[
                      const SizedBox(height: AppSizes.sectionGap),
                      MatchingStrategySelectionSection(
                        selectedStrategies: request.selectedStrategies,
                        onStrategiesChange: controller.updateSelectedStrategies,
                      ),
                      const SizedBox(height: AppSizes.spacingMedium),
                    ] else ...[
                      const SizedBox(height: AppSizes.spacingLarge),
                    ],
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
                    const SizedBox(height: 32),
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
