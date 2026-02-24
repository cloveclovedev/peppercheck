import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/features/matching/domain/referee_blocked_date.dart';
import 'package:peppercheck_flutter/features/matching/presentation/controllers/referee_blocked_dates_controller.dart';
import 'package:peppercheck_flutter/features/matching/presentation/widgets/blocked_date_dialog.dart';

class BlockedDateCard extends ConsumerWidget {
  final RefereeBlockedDate blockedDate;

  const BlockedDateCard({super.key, required this.blockedDate});

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateRange() {
    final start = _formatDate(blockedDate.startDate);
    final end = _formatDate(blockedDate.endDate);
    if (start == end) {
      return start;
    }
    return '$start - $end';
  }

  void _onEdit(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => BlockedDateDialog(
        blockedDate: blockedDate,
        onSave: (startDate, endDate, reason) {
          ref
              .read(refereeBlockedDatesControllerProvider.notifier)
              .editBlockedDate(blockedDate.id, startDate, endDate, reason);
        },
      ),
    );
  }

  void _onDelete(WidgetRef ref) {
    ref
        .read(refereeBlockedDatesControllerProvider.notifier)
        .removeBlockedDate(blockedDate.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: AppColors.backgroundWhite,
      borderRadius: BorderRadius.circular(AppSizes.timeSlotCardBorderRadius),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.timeSlotCardHorizontalPadding,
          vertical: AppSizes.timeSlotCardVerticalPadding,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDateRange(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (blockedDate.reason != null &&
                      blockedDate.reason!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      blockedDate.reason!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => _onEdit(context, ref),
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(AppSizes.timeSlotCardIconPadding),
                    child: Icon(
                      Icons.edit,
                      color: AppColors.textSecondary,
                      size: AppSizes.timeSlotCardIconSize,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => _onDelete(ref),
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(AppSizes.timeSlotCardIconPadding),
                    child: Icon(
                      Icons.delete,
                      color: AppColors.accentRed,
                      size: AppSizes.timeSlotCardIconSize,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
