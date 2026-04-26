import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';

class BaseDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;

  const BaseDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.backgroundWhite,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(child: content),
      actions: actions,
    );
  }
}
