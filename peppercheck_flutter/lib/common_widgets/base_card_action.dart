import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';

/// A compact FilledTonalButton for use inside [BaseCard].
///
/// Provides a consistent in-card action button style: light background tint
/// with colored text, bodySmall size, minimal internal padding.
///
/// ```dart
/// BaseCard(
///   child: Row(
///     children: [
///       Expanded(child: Text('Info')),
///       BaseCardAction(
///         label: 'Change',
///         onPressed: () {},
///       ),
///     ],
///   ),
/// )
/// ```
class BaseCardAction extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;

  const BaseCardAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.accentBlue,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: color,
        textStyle: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label),
    );
  }
}
