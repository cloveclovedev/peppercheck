import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/action_button.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/features/matching/presentation/controllers/referee_blocked_dates_controller.dart';
import 'package:peppercheck_flutter/features/matching/presentation/widgets/blocked_date_card.dart';
import 'package:peppercheck_flutter/features/matching/presentation/widgets/blocked_date_dialog.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class RefereeBlockedDatesSection extends ConsumerWidget {
  const RefereeBlockedDatesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedDatesState = ref.watch(refereeBlockedDatesControllerProvider);

    return BaseSection(
      title: t.matching.referee_blocked_dates.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          blockedDatesState.when(
            data: (dates) {
              if (dates.isEmpty) {
                return Text(
                  t.matching.referee_blocked_dates.no_dates,
                  style: const TextStyle(color: AppColors.textMuted),
                );
              }
              return Column(
                children: [
                  for (int i = 0; i < dates.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSizes.timeSlotCardGap),
                    BlockedDateCard(blockedDate: dates[i]),
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
                builder: (context) => BlockedDateDialog(
                  onSave: (startDate, endDate, reason) {
                    ref
                        .read(refereeBlockedDatesControllerProvider.notifier)
                        .addBlockedDate(startDate, endDate, reason);
                  },
                ),
              );
            },
            icon: Icons.add,
            text: t.matching.referee_blocked_dates.add_date,
          ),
        ],
      ),
    );
  }
}
