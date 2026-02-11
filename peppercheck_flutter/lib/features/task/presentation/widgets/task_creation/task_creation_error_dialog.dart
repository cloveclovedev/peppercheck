import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/features/task/domain/task_creation_error.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class TaskCreationErrorDialog extends StatelessWidget {
  final TaskCreationError error;

  const TaskCreationErrorDialog({
    super.key,
    required this.error,
  });

  String _getTitle() {
    final errorStrings = t.task.creation.error;
    switch (error.type) {
      case TaskCreationErrorType.insufficientPoints:
        return errorStrings.insufficientPoints;
      case TaskCreationErrorType.dueDateTooSoon:
        return errorStrings.dueDateTooSoon;
      case TaskCreationErrorType.walletNotFound:
        return errorStrings.walletNotFound;
      case TaskCreationErrorType.unknown:
        return errorStrings.unknown;
    }
  }

  String _getDetailMessage() {
    final errorStrings = t.task.creation.error;
    switch (error.type) {
      case TaskCreationErrorType.insufficientPoints:
        return errorStrings.insufficientPointsDetail(
          balance: error.balance ?? 0,
          locked: error.locked ?? 0,
          required: error.required ?? 0,
        );
      case TaskCreationErrorType.dueDateTooSoon:
        return errorStrings.dueDateTooSoonDetail(
          minHours: error.minHours ?? 0,
        );
      case TaskCreationErrorType.walletNotFound:
        return errorStrings.walletNotFoundDetail;
      case TaskCreationErrorType.unknown:
        return errorStrings.unknownDetail(message: error.message);
    }
  }

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
        _getTitle(),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
      ),
      content: Text(
        _getDetailMessage(),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
            ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentYellow,
            foregroundColor: AppColors.textPrimary,
          ),
          child: Text(t.task.creation.error.buttonOk),
        ),
      ],
    );
  }
}
