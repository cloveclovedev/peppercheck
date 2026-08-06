import 'package:peppercheck_flutter/features/task/data/task_repository.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_provider.g.dart';

@riverpod
Future<Task> task(Ref ref, String taskId) {
  return ref.watch(taskRepositoryProvider).getTask(taskId);
}
