import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';

class DestructiveActionButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double borderRadius;

  /// When true (default), the button stretches to fill its parent's width.
  /// Set to false for a content-sized button that the caller positions.
  final bool fullWidth;

  const DestructiveActionButton({
    super.key,
    required this.text,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.borderRadius = 20,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool active = onPressed != null && !isLoading;

    final containerColor = active
        ? AppColors.textError.withValues(alpha: 0.1)
        : AppColors.textPrimary.withValues(alpha: 0.05);
    final contentColor = active
        ? AppColors.textError
        : AppColors.textPrimary.withValues(alpha: 0.4);
    final borderColor = active
        ? AppColors.textError.withValues(alpha: 0.5)
        : AppColors.textPrimary.withValues(alpha: 0.2);

    Widget button = OutlinedButton(
      onPressed: active ? onPressed : null,
      style: OutlinedButton.styleFrom(
        backgroundColor: containerColor,
        foregroundColor: contentColor,
        side: BorderSide(color: borderColor, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        elevation: 0,
      ),
      child: isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(contentColor),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: contentColor),
                  const SizedBox(width: 6),
                ],
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: contentColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
    );

    if (!fullWidth) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}
