import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
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
            isSelected: selectedStatus == 'draft',
            onTap: () => onStatusChange('draft'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatusButton(
            text: t.task.status.open,
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
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusButton({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? AppColors.accentYellow
            : AppColors.backgroundLight,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
