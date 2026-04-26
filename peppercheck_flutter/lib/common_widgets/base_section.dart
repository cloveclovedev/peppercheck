import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';

class BaseSection extends StatelessWidget {
  final String title;
  final Widget child;

  /// Optional widget rendered immediately to the right of the title with a
  /// small gap. The trailing widget must not increase the title row's height.
  final Widget? trailing;

  const BaseSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final titleWidget = Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.bold,
      ),
    );

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
            if (trailing != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  titleWidget,
                  const SizedBox(width: AppSizes.spacingTiny),
                  trailing!,
                ],
              )
            else
              titleWidget,
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
