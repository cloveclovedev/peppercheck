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
              radius: AppSizes.avatarSizeMedium / 2,
              backgroundImage: NetworkImage(avatarUrl),
              backgroundColor: Colors.transparent,
            )
          else
            const Icon(
              Icons.person,
              color: AppColors.textSecondary,
              size: AppSizes.avatarSizeMedium,
            ),
          const SizedBox(width: AppSizes.baseCardIconGap),
          Expanded(
            child: Text(
              username,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
