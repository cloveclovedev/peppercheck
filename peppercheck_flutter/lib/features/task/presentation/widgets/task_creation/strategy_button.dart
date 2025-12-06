import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';

class StrategyButton extends StatelessWidget {
  final String strategy;
  final VoidCallback onRemove;

  const StrategyButton({
    super.key,
    required this.strategy,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    // Capitalize first letter
    final displayStrategy = strategy.isNotEmpty
        ? strategy[0].toUpperCase() + strategy.substring(1)
        : strategy;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.accentYellow,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            displayStrategy,
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
