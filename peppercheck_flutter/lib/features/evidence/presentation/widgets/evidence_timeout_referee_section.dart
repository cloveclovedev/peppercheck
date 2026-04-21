import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class EvidenceTimeoutRefereeSection extends StatelessWidget {
  const EvidenceTimeoutRefereeSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseSection(
      title: t.task.evidence.timeout.title,
      child: Container(
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
            Icon(Icons.info_outline, color: AppColors.accentGreen, size: 20),
            const SizedBox(width: AppSizes.spacingTiny),
            Expanded(
              child: Text(
                t.task.evidence.timeout.referee_description,
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
