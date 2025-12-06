import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final bool isMyTask;
  final VoidCallback? onTap;

  const TaskCard({
    super.key,
    required this.task,
    this.isMyTask = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dueDateFormatted = task.dueDate != null
        ? DateFormat(
            'MM/dd H:mm',
          ).format(DateTime.parse(task.dueDate!).toLocal())
        : '';

    final statusStyle = _getStatusStyle(task);

    return Material(
      color: AppColors.backgroundWhite,
      borderRadius: BorderRadius.circular(AppSizes.taskCardBorderRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.taskCardHorizontalPadding,
            vertical: AppSizes.taskCardVerticalPadding,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.person,
                color: AppColors.textSecondary,
                size: AppSizes.taskCardIconSize,
              ),
              const SizedBox(width: AppSizes.taskCardIconGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSizes.taskCardTitleInfoGap),
                    Text(
                      '$dueDateFormatted   ¥${task.feeAmount?.toInt() ?? 0}', // TODO: Multi currency
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.taskCardStatusGap),
              Text(
                statusStyle.text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: statusStyle.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ({String text, Color color}) _getStatusStyle(Task task) {
    switch (task.detailedStatus) {
      case 'draft':
        return (
          text: t.task.status.draft,
          color: AppColors.textPrimary.withValues(alpha: 0.6),
        );
      case 'open':
        return (text: t.task.status.open, color: AppColors.accentYellow);
      case 'judging':
        return (text: t.task.status.judging, color: AppColors.accentBlueLight);
      case 'rejected':
        return (text: t.task.status.rejected, color: AppColors.accentRed);
      case 'completed':
        return (
          text: t.task.status.completed,
          color: AppColors.accentGreenLight,
        );
      case 'closed':
        return (
          text: t.task.status.closed,
          color: AppColors.accentGreen.withValues(alpha: 0.7),
        );
      case 'self_completed':
        return (
          text: t.task.status.self_completed,
          color: AppColors.accentGreen.withValues(alpha: 0.5),
        );
      case 'expired':
        return (
          text: t.task.status.expired,
          color: AppColors.textPrimary.withValues(alpha: 0.4),
        );
      case 'done':
        return (text: t.task.status.done, color: AppColors.accentGreenLight);
      default:
        return (text: task.status, color: AppColors.textPrimary);
    }
  }
}
