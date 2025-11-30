import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:peppercheck_flutter/app/theme/colors.dart';
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

    return Card(
      color: AppColors.backgroundWhite,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              const Icon(Icons.person, color: AppColors.textBlack, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textBlack,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$dueDateFormatted • ¥${task.feeAmount?.toInt() ?? 0}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textBlack.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _getStatusText(task.status),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _getStatusColor(task.status),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'draft':
        return t.task.status.draft;
      case 'open':
        return t.task.status.open;
      case 'judging':
        return t.task.status.judging;
      case 'rejected':
        return t.task.status.rejected;
      case 'completed':
        return t.task.status.completed;
      case 'closed':
        return t.task.status.closed;
      case 'self_completed':
        return t.task.status.self_completed;
      case 'expired':
        return t.task.status.expired;
      case 'done':
        return t.task.status.done;
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'draft':
        return AppColors.textBlack.withValues(alpha: 0.6);
      case 'open':
        return AppColors.accentYellow;
      case 'judging':
        return AppColors.accentBlueLight;
      case 'rejected':
        return AppColors.accentRed;
      case 'completed':
        return AppColors.accentGreenLight;
      case 'closed':
        return AppColors.accentGreen.withValues(alpha: 0.7);
      case 'self_completed':
        return AppColors.accentGreen.withValues(alpha: 0.5);
      case 'expired':
        return AppColors.textBlack.withValues(alpha: 0.4);
      case 'done':
        return AppColors.accentGreenLight;
      default:
        return AppColors.textBlack;
    }
  }
}
