import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/common_widgets/base_text_field.dart';
import 'package:peppercheck_flutter/features/task/presentation/widgets/task_creation/task_status_selector.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';
import 'package:intl/intl.dart';

class TaskFormSection extends StatefulWidget {
  final String title;
  final ValueChanged<String> onTitleChange;
  final String description;
  final ValueChanged<String> onDescriptionChange;
  final String criteria;
  final ValueChanged<String> onCriteriaChange;
  final DateTime? selectedDateTime;
  final VoidCallback onDateTimeClick;
  final String taskStatus;
  final ValueChanged<String> onStatusChange;

  const TaskFormSection({
    super.key,
    required this.title,
    required this.onTitleChange,
    required this.description,
    required this.onDescriptionChange,
    required this.criteria,
    required this.onCriteriaChange,
    required this.selectedDateTime,
    required this.onDateTimeClick,
    required this.taskStatus,
    required this.onStatusChange,
  });

  @override
  State<TaskFormSection> createState() => _TaskFormSectionState();
}

class _TaskFormSectionState extends State<TaskFormSection> {
  late TextEditingController _dateController;
  final DateFormat _dateFormatter = DateFormat('yyyy/MM/dd HH:mm');

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(
      text: widget.selectedDateTime != null
          ? _dateFormatter.format(widget.selectedDateTime!)
          : '',
    );
  }

  @override
  void didUpdateWidget(covariant TaskFormSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDateTime != oldWidget.selectedDateTime) {
      _dateController.text = widget.selectedDateTime != null
          ? _dateFormatter.format(widget.selectedDateTime!)
          : '';
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseSection(
      title: t.task.creation.sectionInfo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BaseTextField(
            value: widget.title,
            onValueChange: widget.onTitleChange,
            label: t.task.creation.labelTitle,
          ),
          const SizedBox(height: AppSizes.spacingTiny),
          BaseTextField(
            value: widget.description,
            onValueChange: widget.onDescriptionChange,
            label: t.task.creation.labelDescription,
          ),
          const SizedBox(height: AppSizes.spacingTiny),
          BaseTextField(
            value: widget.criteria,
            onValueChange: widget.onCriteriaChange,
            label: t.task.creation.labelCriteria,
          ),
          const SizedBox(height: AppSizes.spacingTiny),
          // For date field, we use a controller to ensure updates are reflected
          // since BaseTextField might not update purely on 'value' change if it has internal state
          // However, BaseTextField takes 'value' and 'onValueChange'.
          // If BaseTextField uses a controller internally and initializes it only once, that's the issue.
          // By passing a key, we can force rebuild, but that loses focus (not an issue for read-only date).
          // OR we can rely on BaseTextField correctly handling updates.
          // Let's assume BaseTextField needs a key or we use a raw TextField here if BaseTextField is problematic.
          // But better to fix BaseTextField or use Key.
          // Using Key is simplest for now for the date field.
          BaseTextField(
            key: ValueKey(widget.selectedDateTime),
            value: widget.selectedDateTime != null
                ? _dateFormatter.format(widget.selectedDateTime!)
                : '',
            onValueChange: (_) {},
            label: t.task.creation.labelDeadline,
            readOnly: true,
            onClick: widget.onDateTimeClick,
            trailingIcon: const Icon(
              Icons.access_time,
              color: AppColors.accentBlueLight,
            ),
          ),
          const SizedBox(height: AppSizes.spacingSmall),
          TaskStatusSelector(
            selectedStatus: widget.taskStatus,
            onStatusChange: widget.onStatusChange,
          ),
        ],
      ),
    );
  }
}
