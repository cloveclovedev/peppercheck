import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/async/poll_sleep_provider.dart';
import '../../../core/async/progressive_poller.dart';
import '../data/task_repository.dart';
import '../domain/task.dart';

part 'task_detail_view_model.g.dart';

/// Owns the task detail screen's copy of a task, including the short poll that
/// turns a freshly published task from "matching" into its matched referees.
///
/// Matching runs asynchronously on the server, so the client polls rather than
/// subscribing: push notifications only tell the user something happened, and
/// every screen update is API-sourced.
@riverpod
class TaskDetail extends _$TaskDetail {
  final _token = CancellationToken();

  /// build()'s argument is not in scope in the notifier's other methods, so it
  /// is stashed here.
  late final String _taskId;

  @override
  Future<Task> build(String taskId) async {
    _taskId = taskId;
    ref.onDispose(_token.cancel);
    return ref.read(taskRepositoryProvider).getTask(taskId);
  }

  /// True while the server still owes this task a referee, which is also the
  /// poll's stop condition.
  static bool isMatching(Task task) =>
      task.refereeRequests.any((r) => r.status == 'pending');

  /// Re-reads the task on the progressive schedule until nothing is pending,
  /// publishing every intermediate result so the screen updates itself without
  /// a manual refresh. Safe to call again; the poll simply runs once more.
  Future<void> pollUntilMatched() async {
    final repository = ref.read(taskRepositoryProvider);
    final sleep = ref.read(pollSleepProvider);

    await pollUntil<Task>(
      fetch: () async {
        final task = await repository.getTask(_taskId);
        // Riverpod v3: the notifier may have been disposed during the await.
        if (ref.mounted) state = AsyncData(task);
        return task;
      },
      isDone: (task) => !isMatching(task),
      cancel: _token,
      sleep: sleep,
    );
  }
}
