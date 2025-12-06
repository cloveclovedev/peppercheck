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

  void updateSelectedDateTime(DateTime dateTime) {
    state = AsyncData(state.value!.copyWith(selectedDateTime: dateTime));
  }

  void updateTaskStatus(String status) {
    state = AsyncData(state.value!.copyWith(taskStatus: status));
  }

  void updateSelectedStrategies(List<String> strategies) {
    state = AsyncData(state.value!.copyWith(selectedStrategies: strategies));
  }

  Future<void> createTask() async {
    state = const AsyncLoading();
    try {
      // Mock RPC call
      await Future.delayed(const Duration(seconds: 1));

      // Success - in a real app we might return the created task ID or similar
      // For now, we just reset the state or handle navigation in the UI

      // Reset state to initial after success if needed, or keep it for the UI to react
      // state = AsyncData(const TaskCreationRequest());
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
        current.selectedDateTime != null;
  }
}
