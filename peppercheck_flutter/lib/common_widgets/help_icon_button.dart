import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/base_dialog.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

/// Compact `?` icon that opens a [BaseDialog] with the provided title and body.
///
/// Sized to fit within an existing title/label row without inflating its
/// height. Uses [GestureDetector] (not [IconButton]) to avoid Material's
/// default 48×48 padding which would push the host row taller.
///
/// Pass [iconSize] to scale the glyph for smaller adjacent text (e.g. 12px
/// to sit next to a font-11 muted sub-label).
class HelpIconButton extends StatelessWidget {
  final String title;
  final String body;
  final double iconSize;

  const HelpIconButton({
    super.key,
    required this.title,
    required this.body,
    this.iconSize = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showHelp(context),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacingMicro),
        child: Icon(
          Icons.help_outline,
          size: iconSize,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => BaseDialog(
        title: title,
        content: Text(
          body,
          style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
            color: AppColors.textPrimary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: Text(t.common.close),
          ),
        ],
      ),
    );
  }
}
