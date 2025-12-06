import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/common_widgets/base_text_field.dart';
import 'package:peppercheck_flutter/features/task/presentation/task_creation_controller.dart';
import 'package:peppercheck_flutter/features/task/presentation/widgets/task_creation/task_status_selector.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class TaskFormSection extends ConsumerWidget {
  const TaskFormSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only watch the specific part if possible, or the whole state.
    // For simplicity, watch the whole state as it's a form.
    final state = ref.watch(taskCreationControllerProvider);
    final controller = ref.read(taskCreationControllerProvider.notifier);
    final dateFormatter = DateFormat('yyyy/MM/dd H:mm');

    return state.when(
      data: (request) {
        return BaseSection(
          title: t.task.creation.sectionInfo,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BaseTextField(
                value: request.title,
                onValueChange: controller.updateTitle,
                label: t.task.creation.labelTitle,
              ),
              BaseTextField(
                value: request.description,
                onValueChange: controller.updateDescription,
                label: t.task.creation.labelDescription,
              ),
              BaseTextField(
                value: request.criteria,
                onValueChange: controller.updateCriteria,
                label: t.task.creation.labelCriteria,
              ),
              BaseTextField(
                key: ValueKey(request.selectedDateTime),
                value: request.selectedDateTime != null
                    ? dateFormatter.format(request.selectedDateTime!)
                    : '',
                onValueChange: (_) {},
                label: t.task.creation.labelDeadline,
                readOnly: true,
                onClick: () => _pickDateTime(context, controller),
                trailingIcon: const Icon(
                  Icons.access_time,
                  color: AppColors.accentBlueLight,
                ),
              ),
              const SizedBox(height: AppSizes.gapTaskStatusSelector),
              TaskStatusSelector(
                selectedStatus: request.taskStatus,
                onStatusChange: controller.updateTaskStatus,
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
    );
  }

  Future<void> _pickDateTime(
    BuildContext context,
    TaskCreationController controller,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && context.mounted) {
      final now = TimeOfDay.now();
      final initialTime = TimeOfDay(hour: (now.hour + 1) % 24, minute: 0);

      final time = await showTimePicker(
        context: context,
        initialTime: initialTime,
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
  }
}
