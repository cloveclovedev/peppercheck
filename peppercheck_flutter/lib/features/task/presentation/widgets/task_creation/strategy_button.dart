import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';

class StrategyButton extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const StrategyButton({
    super.key,
    required this.label,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.strategyButtonHorizontalPadding,
            vertical: AppSizes.strategyButtonVerticalPadding,
          ),
          decoration: BoxDecoration(
            color: AppColors.accentYellow,
            borderRadius: BorderRadius.circular(
              AppSizes.strategyButtonBorderRadius,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Positioned(
          top: -4,
          right: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
