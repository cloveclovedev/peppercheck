import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';

/// Shared card container for use inside [BaseSection] and elsewhere.
///
/// Provides the visual shell (background, border, radius, padding, tap handling)
/// while leaving content entirely to [child].
///
/// Default style matches the app's standard card appearance (radius 12, border,
/// backgroundLight). Override properties to match other card styles:
///
/// ```dart
/// // TaskCard-style (no border, white background):
/// BaseCard(
///   borderColor: null,
///   backgroundColor: AppColors.backgroundWhite,
///   child: ...,
/// )
/// ```
class BaseCard extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// If true, the card stretches to fill available width.
  final bool expandWidth;

  const BaseCard({
    super.key,
    required this.child,
    this.backgroundColor,
    this.borderColor = AppColors.border,
    this.borderRadius = AppSizes.baseCardBorderRadius,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSizes.baseCardPaddingHorizontal,
      vertical: AppSizes.baseCardPaddingVertical,
    ),
    this.onTap,
    this.expandWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: backgroundColor ?? AppColors.backgroundLight,
      borderRadius: BorderRadius.circular(borderRadius),
      border: borderColor != null ? Border.all(color: borderColor!) : null,
    );

    if (onTap != null) {
      return Material(
        color: backgroundColor ?? AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          child: Container(
            width: expandWidth ? double.infinity : null,
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: borderColor != null
                  ? Border.all(color: borderColor!)
                  : null,
            ),
            child: child,
          ),
        ),
      );
    }

    return Container(
      width: expandWidth ? double.infinity : null,
      padding: padding,
      decoration: decoration,
      child: child,
    );
  }
}
