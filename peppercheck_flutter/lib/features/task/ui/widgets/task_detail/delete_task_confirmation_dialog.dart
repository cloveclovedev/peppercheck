import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/common_widgets/base_dialog.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class DeleteTaskConfirmationDialog extends StatelessWidget {
  final VoidCallback onConfirm;

  const DeleteTaskConfirmationDialog({super.key, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return BaseDialog(
      title: t.task.deletion.confirmTitle,
      // BaseDialog.content is required; use SizedBox.shrink for a title-only dialog.
      content: const SizedBox.shrink(),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          child: Text(t.common.cancel),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
          style: TextButton.styleFrom(foregroundColor: AppColors.textError),
          child: Text(t.task.deletion.deleteButton),
        ),
      ],
    );
  }
}
