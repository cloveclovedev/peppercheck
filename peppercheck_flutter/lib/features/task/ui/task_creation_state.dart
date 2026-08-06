import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:peppercheck_flutter/features/task/domain/task_creation_request.dart';
import 'package:peppercheck_flutter/features/task/domain/task_creation_error.dart';

part 'task_creation_state.freezed.dart';

@freezed
abstract class TaskCreationState with _$TaskCreationState {
  const factory TaskCreationState({
    required TaskCreationRequest request,

    /// How many referees to request when publishing. Bounded by the server's
    /// `maxRefereesPerTask`; the selector clamps it once the config loads.
    @Default(1) int refereeCount,
    TaskCreationError? creationError,
  }) = _TaskCreationState;
}
