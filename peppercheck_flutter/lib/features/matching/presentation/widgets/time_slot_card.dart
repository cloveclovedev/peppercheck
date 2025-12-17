import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/features/matching/domain/referee_available_time_slot.dart';
import 'package:peppercheck_flutter/features/matching/presentation/controllers/referee_availability_controller.dart';
import 'package:peppercheck_flutter/features/matching/presentation/widgets/time_slot_dialog.dart';

import 'package:peppercheck_flutter/app/utils/date_time_utils.dart';

class TimeSlotCard extends ConsumerWidget {
  final RefereeAvailableTimeSlot timeSlot;

  const TimeSlotCard({super.key, required this.timeSlot});

  void _onEdit(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => TimeSlotDialog(
        timeSlot: timeSlot,
        onSave: (dow, start, end) {
          ref
              .read(refereeAvailabilityControllerProvider.notifier)
              .updateTimeSlot(timeSlot.id, dow, start, end);
        },
      ),
    );
  }

  void _onDelete(WidgetRef ref) {
    ref
        .read(refereeAvailabilityControllerProvider.notifier)
        .deleteTimeSlot(timeSlot.id);
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
              child: Row(
                children: [
                  Text(
                    getDayName(timeSlot.dow),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${formatMinutes(timeSlot.startMin)} - ${formatMinutes(timeSlot.endMin)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
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
