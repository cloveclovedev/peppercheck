import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:peppercheck_flutter/features/task/domain/task_creation_request.dart';

part 'task_creation_state.freezed.dart';

@freezed
abstract class TaskCreationState with _$TaskCreationState {
  const factory TaskCreationState({
    required TaskCreationRequest request,
    @Default(false) bool isSubmitting,
  }) = _TaskCreationState;
}
