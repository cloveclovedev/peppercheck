import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../matching/data/matching_repository.dart';
import '../../task/data/task_repository.dart';
import '../../task/domain/task.dart';

part 'home_view_model.g.dart';

/// Tasks the signed-in user owns. Refreshed by pull-to-refresh and on resume;
/// the matching result is polled on the task detail screen, not here.
@riverpod
Future<List<Task>> activeUserTasks(Ref ref) {
  return ref.watch(taskRepositoryProvider).fetchMyTasks();
}

/// Tasks the signed-in user referees. Each row carries the caller's real
/// referee request as served by `GET /me/assignments`.
@riverpod
Future<List<Task>> activeRefereeTasks(Ref ref) {
  return ref.watch(matchingRepositoryProvider).fetchMyAssignments();
}
