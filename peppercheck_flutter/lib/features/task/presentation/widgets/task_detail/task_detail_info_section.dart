import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/action_button.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class TaskDetailInfoSection extends StatelessWidget {
  final Task task;

  const TaskDetailInfoSection({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('yyyy/MM/dd H:mm');
    final formattedDate = task.dueDate != null
        ? dateFormatter.format(DateTime.parse(task.dueDate!).toLocal())
        : '-';

    return BaseSection(
      title: t.task.creation.sectionInfo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(t.task.creation.labelTitle, task.title, isTitle: true),
          const SizedBox(height: AppSizes.spacingStandard),
          _buildInfoRow(
            t.task.creation.labelDescription,
            task.description ?? '-',
          ),
          const SizedBox(height: AppSizes.spacingStandard),
          _buildInfoRow(t.task.creation.labelCriteria, task.criteria ?? '-'),
          const SizedBox(height: AppSizes.spacingStandard),

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
        const SizedBox(height: 4),
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
}
