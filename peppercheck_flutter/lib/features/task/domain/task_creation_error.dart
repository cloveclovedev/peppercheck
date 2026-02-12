import 'package:freezed_annotation/freezed_annotation.dart';

part 'task_creation_error.freezed.dart';

enum TaskCreationErrorType {
  insufficientPoints,
  dueDateTooSoon,
  walletNotFound,
  unknown,
}

@freezed
abstract class TaskCreationError with _$TaskCreationError {
  const factory TaskCreationError({
    required TaskCreationErrorType type,
    required String message,
    int? balance,
    int? locked,
    int? required,
    int? minHours,
  }) = _TaskCreationError;

  factory TaskCreationError.parse(String errorMessage) {
    // Parse "Insufficient points. Balance: X, Locked: Y, Required: Z"
    final insufficientPointsRegex = RegExp(
      r'Insufficient points\. Balance: (\d+), Locked: (\d+), Required: (\d+)',
    );
    final match = insufficientPointsRegex.firstMatch(errorMessage);
    if (match != null) {
      return TaskCreationError(
        type: TaskCreationErrorType.insufficientPoints,
        message: errorMessage,
        balance: int.tryParse(match.group(1) ?? ''),
        locked: int.tryParse(match.group(2) ?? ''),
        required: int.tryParse(match.group(3) ?? ''),
      );
    }

    // Parse "Due date must be at least X hours from now"
    final dueDateRegex = RegExp(r'Due date must be at least (\d+) hours from now');
    final dueDateMatch = dueDateRegex.firstMatch(errorMessage);
    if (dueDateMatch != null) {
      return TaskCreationError(
        type: TaskCreationErrorType.dueDateTooSoon,
        message: errorMessage,
        minHours: int.tryParse(dueDateMatch.group(1) ?? ''),
      );
    }

    // Check for wallet not found
    if (errorMessage.contains('Point wallet not found')) {
      return TaskCreationError(
        type: TaskCreationErrorType.walletNotFound,
        message: errorMessage,
      );
    }

    // Unknown error
    return TaskCreationError(
      type: TaskCreationErrorType.unknown,
      message: errorMessage,
    );
  }
}
