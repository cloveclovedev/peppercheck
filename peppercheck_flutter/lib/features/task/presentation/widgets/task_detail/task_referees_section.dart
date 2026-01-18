import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class TaskRefereesSection extends StatelessWidget {
  final Task task;

  const TaskRefereesSection({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    if (task.refereeRequests.isEmpty) {
      return const SizedBox.shrink();
    }

    return BaseSection(
      title: t.task.detail.sectionRequests,
      child: Column(
        children: [
          for (int i = 0; i < task.refereeRequests.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSizes.cardGap),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.cardPaddingHorizontal,
                vertical: AppSizes.cardPaddingVertical,
              ),
              decoration: BoxDecoration(
                color: AppColors.backgroundWhite,
                borderRadius: BorderRadius.circular(AppSizes.cardBorderRadius),
              ),
              child: Row(
                children: [
                  if (task.refereeRequests[i].referee?.avatarUrl != null)
                    CircleAvatar(
                      radius: AppSizes.taskCardIconSize / 2,
                      backgroundImage: NetworkImage(
                        task.refereeRequests[i].referee!.avatarUrl!,
                      ),
                      backgroundColor: Colors.transparent,
                    )
                  else
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
                          task.refereeRequests[i].matchingStrategy,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${t.task.detail.labelStatus}: ${task.refereeRequests[i].status}',
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
