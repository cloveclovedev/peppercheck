import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/features/authentication/data/auth_state_provider.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class TaskCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final dueDateFormatted = task.dueDate != null
        ? DateFormat(
            'MM/dd H:mm',
          ).format(DateTime.parse(task.dueDate!).toLocal())
        : '';

    final currentUserId = ref.watch(currentUserProvider)?.id ?? '';
    final statuses = task.getDetailedStatuses(currentUserId);

    return Material(
      color: AppColors.backgroundWhite,
      borderRadius: BorderRadius.circular(AppSizes.cardBorderRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap:
            onTap ?? () => context.push('/task_detail/${task.id}', extra: task),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.cardPaddingHorizontal,
            vertical: AppSizes.cardPaddingVertical,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.person,
                color: AppColors.textSecondary,
                size: AppSizes.taskCardIconSize,
              ),
              const SizedBox(width: AppSizes.cardIconGap),
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
              _buildStatusLabels(context, statuses),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusLabels(BuildContext context, List<String> statuses) {
    if (statuses.length == 1) {
      final style = _getStatusStyle(statuses[0]);
      return Text(
        style.text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: style.color,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < statuses.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.spacingTiny,
              ),
              child: Text(
                '|',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ),
          () {
            final style = _getStatusStyle(statuses[i]);
            return Text(
              style.text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: style.color,
                fontWeight: FontWeight.bold,
              ),
            );
          }(),
        ],
      ],
    );
  }

  ({String text, Color color}) _getStatusStyle(String statusKey) {
    switch (statusKey) {
      case 'draft':
        return (text: t.task.status.draft, color: AppColors.textMuted);
      case 'matching':
        return (text: t.task.status.matching, color: AppColors.accentYellow);
      case 'matching_complete':
        return (
          text: t.task.status.matchingComplete,
          color: AppColors.accentGreenLight,
        );
      case 'matching_failed':
        return (text: t.task.status.matchingFailed, color: AppColors.accentRed);
      case 'awaiting_evidence':
        return (
          text: t.task.status.awaitingEvidence,
          color: AppColors.accentYellow,
        );
      case 'evidence_timeout':
        return (
          text: t.task.status.evidenceTimeout,
          color: AppColors.textSecondary,
        );
      case 'in_review':
        return (text: t.task.status.inReview, color: AppColors.accentBlueLight);
      case 'approved':
        return (
          text: t.task.status.approved,
          color: AppColors.accentGreenLight,
        );
      case 'rejected':
        return (text: t.task.status.rejected, color: AppColors.accentBlue);
      case 'review_timeout':
        return (
          text: t.task.status.reviewTimeout,
          color: AppColors.textSecondary,
        );
      case 'payment_processing':
        return (
          text: t.task.status.paymentProcessing,
          color: AppColors.accentYellow,
        );
      case 'closed':
        return (text: t.task.status.closed, color: AppColors.accentGreen);
      default:
        return (text: statusKey, color: AppColors.textPrimary);
    }
  }
}
