import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/app_logger.dart';
import 'package:peppercheck_flutter/features/task/data/task_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_deletion_controller.g.dart';

@riverpod
class TaskDeletionController extends _$TaskDeletionController {
  @override
  FutureOr<void> build() async {}

  Future<void> deleteTask(
    String taskId, {
    required VoidCallback onSuccess,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(taskRepositoryProvider).deleteTask(taskId);
      onSuccess();
    });
    if (state.hasError) {
      ref
          .read(loggerProvider)
          .e(
            'Task deletion error',
            error: state.error,
            stackTrace: state.stackTrace,
          );
    }
  }
}
