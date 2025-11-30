import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/theme/colors.dart';

class ActionButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;

  const ActionButton({
    super.key,
    required this.text,
    this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bool active = onPressed != null;

    final containerColor = active
        ? AppColors.accentBlueLight.withValues(alpha: 0.1)
        : AppColors.textBlack.withValues(alpha: 0.05);
    final contentColor = active
        ? AppColors.accentBlueLight
        : AppColors.textBlack.withValues(alpha: 0.4);
    final borderColor = active
        ? AppColors.accentBlueLight.withValues(alpha: 0.5)
        : AppColors.textBlack.withValues(alpha: 0.2);

    Widget button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: containerColor,
        foregroundColor: contentColor,
        side: BorderSide(color: borderColor, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: Size.zero, // Remove default minimum size
        tapTargetSize:
            MaterialTapTargetSize.shrinkWrap, // Remove extra tap target spacing
        elevation: 0,
      ),
      child: Row(
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
              fontWeight: FontWeight.w500, // Medium equivalent
            ),
          ),
        ],
      ),
    );

    return SizedBox(width: double.infinity, child: button);
  }
}
