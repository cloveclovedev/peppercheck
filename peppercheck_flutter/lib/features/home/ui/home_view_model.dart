import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_state.dart';
import '../../matching/data/matching_repository.dart';
import '../../task/data/task_repository.dart';
import '../../task/domain/task.dart';
import '../../task/domain/task_ordering.dart';
import '../../task/domain/task_viewer_role.dart';

part 'home_view_model.g.dart';

/// Tasks the signed-in user owns and still acts on. Refreshed by pull-to-refresh
/// and on resume; the matching result is polled on the task detail screen, not
/// here.
@riverpod
Future<List<Task>> activeUserTasks(Ref ref) async {
  final tasks = await ref.watch(taskRepositoryProvider).fetchMyActiveTasks();
  return sortedByDueDate(tasks);
}

/// Tasks the signed-in user referees. `GET /me/assignments` reports every task
/// the caller has an accepted *or* closed request on, and a task stays open
/// while a sibling referee is still working, so the caller's own request — not
/// the task's status — decides whether the assignment is still live.
@riverpod
Future<List<Task>> activeRefereeTasks(Ref ref) async {
  final tasks = await ref
      .watch(matchingRepositoryProvider)
      .fetchMyAssignments();
  final me = await ref.watch(currentAppUserProvider.future);
  final live = tasks
      .where(
        (t) => t.viewerRole(me?.internalUserId).myRequest?.status == 'accepted',
      )
      .toList();
  return sortedByDueDate(live);
}
