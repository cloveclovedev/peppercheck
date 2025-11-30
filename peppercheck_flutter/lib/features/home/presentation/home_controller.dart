import 'package:peppercheck_flutter/features/task/data/task_repository.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'home_controller.g.dart';

@riverpod
Future<List<Task>> activeUserTasks(Ref ref) {
  return ref.watch(taskRepositoryProvider).fetchActiveUserTasks();
}

@riverpod
Future<List<Task>> activeRefereeTasks(Ref ref) {
  return ref.watch(taskRepositoryProvider).fetchActiveRefereeTasks();
}
