import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/action_button.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/features/matching/domain/public_profile.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/features/task/ui/task_role_provider.dart';
import 'package:peppercheck_flutter/features/task/ui/widgets/task_detail/delete_task_button.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class TaskDetailInfoSection extends ConsumerWidget {
  final Task task;

  const TaskDetailInfoSection({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormatter = DateFormat('yyyy/MM/dd H:mm');
    final formattedDate = task.dueDate != null
        ? dateFormatter.format(DateTime.parse(task.dueDate!).toLocal())
        : '-';

    // The tasker's own view has no "my request"; only an assigned referee does.
    final myRequest = ref.watch(taskRoleProvider(task.id)).value?.myRequest;

    return BaseSection(
      title: t.task.creation.sectionInfo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(t.task.creation.labelTitle, task.title, isTitle: true),
          const SizedBox(height: AppSizes.spacingTiny),
          _buildInfoRow(
            t.task.creation.labelDescription,
            task.description ?? '-',
          ),
          const SizedBox(height: AppSizes.spacingTiny),
          _buildInfoRow(t.task.creation.labelCriteria, task.criteria ?? '-'),
          const SizedBox(height: AppSizes.spacingTiny),

          _buildInfoRow(t.task.creation.labelDeadline, formattedDate),
          if (task.status == 'draft') ...[
            const SizedBox(
              height: AppSizes.sectionGap,
            ), // Gap similar to RefereeAvailabilitySection
            ActionButton(
              text: t.task.creation.titleEdit,
              icon: Icons.edit,
              onPressed: () {
                context.push('/create_task', extra: task);
              },
            ),
            const SizedBox(height: AppSizes.spacingSmall),
            DeleteTaskButton(task: task),
          ],
          if (myRequest != null) ...[
            const SizedBox(height: AppSizes.spacingTiny),
            _buildTaskerRow(context, task.tasker),
            if (myRequest.isObligation) ...[
              const SizedBox(height: AppSizes.spacingSmall),
              Text(
                t.billing.obligationRefereeNotice,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isTitle = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSizes.spacingMicro),
        Text(
          value,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: isTitle ? 18 : 14,
            fontWeight: isTitle ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildTaskerRow(BuildContext context, PublicProfile? tasker) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.task.detail.labelTasker,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSizes.spacingMicro),
        Container(
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
              if (tasker?.avatarUrl != null)
                CircleAvatar(
                  radius: AppSizes.avatarSizeMedium / 2,
                  backgroundImage: NetworkImage(tasker!.avatarUrl!),
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
                  tasker?.username ?? '...',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
