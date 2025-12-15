import 'package:peppercheck_flutter/features/task/data/task_repository.dart';
import 'package:peppercheck_flutter/features/task/domain/task_creation_request.dart';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_creation_controller.g.dart';

@riverpod
class TaskCreationController extends _$TaskCreationController {
  @override
  FutureOr<TaskCreationRequest> build() {
    return const TaskCreationRequest();
  }

  void updateTitle(String title) {
    state = AsyncData(state.value!.copyWith(title: title));
  }

  void updateDescription(String description) {
    state = AsyncData(state.value!.copyWith(description: description));
  }

  void updateCriteria(String criteria) {
    state = AsyncData(state.value!.copyWith(criteria: criteria));
  }

  void updateDueDate(DateTime date) {
    state = AsyncData(state.value!.copyWith(dueDate: date));
  }

  void updateTaskStatus(String status) {
    state = AsyncData(state.value!.copyWith(taskStatus: status));
  }

  void updateMatchingStrategies(List<String> strategies) {
    state = AsyncData(state.value!.copyWith(matchingStrategies: strategies));
  }

  Future<void> createTask() async {
    state = const AsyncLoading();
    try {
      final taskRepository = ref.read(taskRepositoryProvider);
      final request = state
          .value!; // state.value is definitely not null here as per logic flow usually, but good to be safe.
      // Actually state.when in UI ensures data is loaded, but here in async method we check.

      await taskRepository.createTask(request);

      // state = AsyncData(const TaskCreationRequest()); // Optional: reset state
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  bool get isFormValid {
    final current = state.value;
    if (current == null) return false;
    return current.title.isNotEmpty &&
        current.description.isNotEmpty &&
        current.criteria.isNotEmpty &&
        current.dueDate != null;
  }
}
