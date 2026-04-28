import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/features/matching/domain/referee_request.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class TaskerRefereesSection extends StatelessWidget {
  final Task task;

  const TaskerRefereesSection({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final requests = task.refereeRequests;
    if (requests.isEmpty) {
      return const SizedBox.shrink();
    }

    return BaseSection(
      title: t.task.detail.sectionRefereesTasker,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _RefereeCard(request: requests[0])),
          const SizedBox(width: AppSizes.baseCardGap),
          Expanded(
            child: requests.length > 1
                ? _RefereeCard(request: requests[1])
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _RefereeCard extends StatelessWidget {
  final RefereeRequest request;

  const _RefereeCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final referee = request.referee;
    final username = referee?.username ?? t.task.detail.refereePending;
    final avatarUrl = referee?.avatarUrl;
    final strategyLabel = _strategyLabel(request.matchingStrategy);
    final statusLabel = _statusLabel(request.status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.baseCardPaddingHorizontal,
        vertical: AppSizes.baseCardPaddingVertical,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(AppSizes.baseCardBorderRadius),
      ),
      child: Row(
        children: [
          if (avatarUrl != null)
            CircleAvatar(
              radius: AppSizes.baseCardIconSize / 2,
              backgroundImage: NetworkImage(avatarUrl),
              backgroundColor: Colors.transparent,
            )
          else
            const Icon(
              Icons.person,
              color: AppColors.textSecondary,
              size: AppSizes.baseCardIconSize,
            ),
          const SizedBox(width: AppSizes.baseCardIconGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$strategyLabel ($statusLabel)',
                  style: const TextStyle(color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _strategyLabel(String value) {
  switch (value) {
    case 'standard':
      return t.task.detail.matchingStrategy.standard;
    case 'premium':
      return t.task.detail.matchingStrategy.premium;
    case 'direct':
      return t.task.detail.matchingStrategy.direct;
    default:
      return value;
  }
}

String _statusLabel(String value) {
  switch (value) {
    case 'pending':
      return t.task.detail.refereeStatus.pending;
    case 'matched':
      return t.task.detail.refereeStatus.matched;
    case 'accepted':
      return t.task.detail.refereeStatus.accepted;
    case 'declined':
      return t.task.detail.refereeStatus.declined;
    case 'expired':
      return t.task.detail.refereeStatus.expired;
    case 'payment_processing':
      return t.task.detail.refereeStatus.paymentProcessing;
    case 'closed':
      return t.task.detail.refereeStatus.closed;
    case 'cancelled':
      return t.task.detail.refereeStatus.cancelled;
    default:
      return value;
  }
}
