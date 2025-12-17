import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/action_button.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/features/matching/presentation/controllers/referee_availability_controller.dart';
import 'package:peppercheck_flutter/features/matching/presentation/widgets/time_slot_card.dart';
import 'package:peppercheck_flutter/features/matching/presentation/widgets/time_slot_dialog.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class RefereeAvailabilitySection extends ConsumerWidget {
  const RefereeAvailabilitySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availabilityState = ref.watch(refereeAvailabilityControllerProvider);

    return BaseSection(
      title: t.matching.referee_availability.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          availabilityState.when(
            data: (slots) {
              if (slots.isEmpty) {
                return Text(
                  t.matching.referee_availability.no_slots,
                  style: const TextStyle(color: AppColors.textMuted),
                );
              }
              return Column(
                children: [
                  for (int i = 0; i < slots.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSizes.timeSlotCardGap),
                    TimeSlotCard(timeSlot: slots[i]),
                  ],
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, st) => Text(
              t.common.error(message: err.toString()),
              style: const TextStyle(color: AppColors.accentRed),
            ),
          ),

          const SizedBox(height: AppSizes.timeSlotCardAddButtonGap),

          ActionButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => TimeSlotDialog(
                  onSave: (dow, start, end) {
                    ref
                        .read(refereeAvailabilityControllerProvider.notifier)
                        .addTimeSlot(dow, start, end);
                  },
                ),
              );
            },
            icon: Icons.add,
            text: t.matching.referee_availability.add_slot,
          ),
        ],
      ),
    );
  }
}
