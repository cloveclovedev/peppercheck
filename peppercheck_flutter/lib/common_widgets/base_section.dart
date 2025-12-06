import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';

class BaseSection extends StatelessWidget {
  final String title;
  final Widget child;

  const BaseSection({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppSizes.baseSectionBorderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppSizes.baseSectionHorizontalPadding,
          right: AppSizes.baseSectionHorizontalPadding,
          top: AppSizes.baseSectionTopPadding,
          bottom: AppSizes.baseSectionBottomPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSizes.baseSectionTitleBodyGap),
            DefaultTextStyle.merge(
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
