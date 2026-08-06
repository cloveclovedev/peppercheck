import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../matching/data/matching_repository.dart';
import '../../task/data/task_repository.dart';
import '../../task/domain/task.dart';
import '../../task/domain/task_ordering.dart';

part 'home_view_model.g.dart';

/// Tasks the signed-in user owns and still acts on. Refreshed by pull-to-refresh
/// and on resume; the matching result is polled on the task detail screen, not
/// here.
@riverpod
Future<List<Task>> activeUserTasks(Ref ref) async {
  final tasks = await ref.watch(taskRepositoryProvider).fetchMyActiveTasks();
  return sortedByDueDate(tasks);
}

/// Tasks the signed-in user referees. Each row carries the caller's real
/// referee request as served by `GET /me/assignments`. That endpoint takes no
/// status filter and also reports finished assignments, so closed tasks are
/// dropped here to keep the home list to what the referee still acts on.
@riverpod
Future<List<Task>> activeRefereeTasks(Ref ref) async {
  final tasks = await ref
      .watch(matchingRepositoryProvider)
      .fetchMyAssignments();
  return sortedByDueDate(tasks.where((t) => t.status != 'closed').toList());
}
