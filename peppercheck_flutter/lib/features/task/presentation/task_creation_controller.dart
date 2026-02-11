import 'package:peppercheck_flutter/features/task/data/task_repository.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/features/task/domain/task_creation_request.dart';
import 'package:peppercheck_flutter/features/home/presentation/home_controller.dart';
import 'package:peppercheck_flutter/features/task/presentation/providers/task_provider.dart';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_creation_controller.g.dart';

@riverpod
class TaskCreationController extends _$TaskCreationController {
  String? _taskId;

  @override
  TaskCreationRequest build(Task? initialTask) {
    if (initialTask != null) {
      _taskId = initialTask.id;
      return TaskCreationRequest(
        title: initialTask.title,
        description: initialTask.description ?? '',
        criteria: initialTask.criteria ?? '',
        dueDate: initialTask.dueDate != null
            ? DateTime.tryParse(initialTask.dueDate!)
            : null,
        taskStatus: initialTask.status,
        matchingStrategies: initialTask.refereeRequests
            .map((r) => r.matchingStrategy)
            .toList(),
      );
    }
    _taskId = null;
    return const TaskCreationRequest();
  }

  void updateTitle(String title) {
    state = state.copyWith(title: title);
  }

  void updateDescription(String description) {
    state = state.copyWith(description: description);
  }

  void updateCriteria(String criteria) {
    state = state.copyWith(criteria: criteria);
  }

  void updateDueDate(DateTime date) {
    state = state.copyWith(dueDate: date);
  }

  void updateTaskStatus(String status) {
    state = state.copyWith(taskStatus: status);
  }

  void updateMatchingStrategies(List<String> strategies) {
    state = state.copyWith(matchingStrategies: strategies);
  }

  Future<bool> createTask() async {
    try {
      // Clear any previous error
      state = state.copyWith(errorMessage: null);

      final taskRepository = ref.read(taskRepositoryProvider);
      final request = state;

      if (_taskId != null) {
        await taskRepository.updateTask(_taskId!, request);
        ref.invalidate(taskProvider(_taskId!));
      } else {
        await taskRepository.createTask(request);
      }

      // Refresh the home screen lists
      ref.invalidate(activeUserTasksProvider);

      return true; // Success
    } catch (e) {
      // Store error in state
      state = state.copyWith(errorMessage: e.toString());
      return false; // Failure
    }
  }

  bool get isFormValid {
    final current = state;
    if (current.taskStatus == 'draft') {
      return current.title.isNotEmpty;
    }
    return current.title.isNotEmpty &&
        current.criteria.isNotEmpty &&
        current.dueDate != null &&
        current.matchingStrategies.isNotEmpty;
  }
}
