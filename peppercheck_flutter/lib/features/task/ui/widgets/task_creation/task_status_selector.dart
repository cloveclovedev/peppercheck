import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class TaskStatusSelector extends StatelessWidget {
  final String selectedStatus;
  final ValueChanged<String> onStatusChange;

  const TaskStatusSelector({
    super.key,
    required this.selectedStatus,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatusButton(
            text: t.task.status.draft,
            icon: Icons.edit_note,
            isSelected: selectedStatus == 'draft',
            onTap: () => onStatusChange('draft'),
          ),
        ),
        const SizedBox(width: AppSizes.gapTaskStatusSelectorButton),
        Expanded(
          child: _StatusButton(
            text: t.task.status.open,
            icon: Icons.public,
            isSelected: selectedStatus == 'open',
            onTap: () => onStatusChange('open'),
          ),
        ),
      ],
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusButton({
    required this.text,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: isSelected
            ? AppColors.accentYellow
            : AppColors.backgroundLight,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            AppSizes.taskStatusSelectorButtonBorderRadius,
          ),
        ),
        padding: const EdgeInsets.symmetric(
          vertical: AppSizes.taskStatusSelectorButtonVerticalPadding,
        ),
      ),
      icon: Icon(icon, size: AppSizes.taskStatusSelectorIconSize),
      label: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
