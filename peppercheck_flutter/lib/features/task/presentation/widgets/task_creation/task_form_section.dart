import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/common_widgets/base_text_field.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/features/task/domain/task_creation_request.dart';
import 'package:peppercheck_flutter/features/task/presentation/task_creation_controller.dart';
import 'package:peppercheck_flutter/features/task/presentation/widgets/task_creation/task_status_selector.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class TaskFormSection extends ConsumerStatefulWidget {
  const TaskFormSection({
    super.key,
    required this.initialData,
    required this.task,
  });

  final TaskCreationRequest initialData;
  final Task? task;

  @override
  ConsumerState<TaskFormSection> createState() => _TaskFormSectionState();
}

class _TaskFormSectionState extends ConsumerState<TaskFormSection> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _criteriaController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialData.title);
    _descController = TextEditingController(
      text: widget.initialData.description,
    );
    _criteriaController = TextEditingController(
      text: widget.initialData.criteria,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _criteriaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Access the specific provider family using the passed task (key)
    final controller = ref.read(
      taskCreationControllerProvider(widget.task).notifier,
    );
    final dateFormatter = DateFormat('yyyy/MM/dd H:mm');
    // Watch current state for updates not managed by local controllers (like date/status)
    // Note: Text fields are managed by local controllers, but we might want to watch for external changes?
    // For now, simple initialization is enough as per requirements.
    // However, status and date ARE managed by provider state.
    final state = ref.watch(taskCreationControllerProvider(widget.task));

    return BaseSection(
      title: t.task.creation.sectionInfo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BaseTextField(
            controller: _titleController,
            value: state
                .title, // Keep value for initial sync if needed, but controller handles it
            onValueChange: controller.updateTitle,
            label: t.task.creation.labelTitle,
          ),
          BaseTextField(
            controller: _descController,
            value: state.description,
            onValueChange: controller.updateDescription,
            label: t.task.creation.labelDescription,
          ),
          BaseTextField(
            controller: _criteriaController,
            value: state.criteria,
            onValueChange: controller.updateCriteria,
            label: t.task.creation.labelCriteria,
          ),
          BaseTextField(
            key: ValueKey(state.dueDate),
            value: state.dueDate != null
                ? dateFormatter.format(state.dueDate!)
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
            selectedStatus: state.taskStatus,
            onStatusChange: controller.updateTaskStatus,
          ),
        ],
      ),
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
        controller.updateDueDate(dateTime);
      }
    }
  }
}
