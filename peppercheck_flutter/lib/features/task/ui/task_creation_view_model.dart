import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/app_logger.dart';
import '../../../core/network/api_exception.dart';
import '../../home/ui/home_view_model.dart';
import '../data/task_repository.dart';
import '../domain/task.dart';
import '../domain/task_creation_error.dart';
import '../domain/task_creation_request.dart';
import 'task_detail_view_model.dart';
import 'task_creation_state.dart';

part 'task_creation_view_model.g.dart';

@riverpod
class TaskCreationViewModel extends _$TaskCreationViewModel {
  String? _taskId;

  @override
  FutureOr<TaskCreationState> build(Task? initialTask) {
    if (initialTask != null) {
      _taskId = initialTask.id;
      return TaskCreationState(
        request: TaskCreationRequest(
          title: initialTask.title,
          description: initialTask.description ?? '',
          criteria: initialTask.criteria ?? '',
          dueDate: initialTask.dueDate != null
              ? DateTime.tryParse(initialTask.dueDate!)
              : null,
          taskStatus: initialTask.status,
        ),
        refereeCount: initialTask.refereeRequests.isEmpty
            ? 1
            : initialTask.refereeRequests.length,
        creationError: null,
      );
    }
    _taskId = null;
    return const TaskCreationState(
      request: TaskCreationRequest(),
      creationError: null,
    );
  }

  void updateTitle(String title) =>
      _patchRequest((r) => r.copyWith(title: title));

  void updateDescription(String description) =>
      _patchRequest((r) => r.copyWith(description: description));

  void updateCriteria(String criteria) =>
      _patchRequest((r) => r.copyWith(criteria: criteria));

  void updateDueDate(DateTime date) =>
      _patchRequest((r) => r.copyWith(dueDate: date));

  void updateTaskStatus(String status) =>
      _patchRequest((r) => r.copyWith(taskStatus: status));

  void updateRefereeCount(int count) {
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncData(currentState.copyWith(refereeCount: count));
  }

  /// Saves the form as a draft — `POST /tasks` the first time, `PATCH` after —
  /// and returns the saved task, or null when the call failed (the error is in
  /// `state.creationError`).
  Future<Task?> saveDraft() async {
    final currentState = state.value;
    if (currentState == null) return null;

    state = const AsyncLoading();
    try {
      final repository = ref.read(taskRepositoryProvider);
      final Task saved;
      if (_taskId != null) {
        saved = await repository.updateDraft(_taskId!, currentState.request);
        ref.invalidate(taskDetailProvider(_taskId!));
      } else {
        saved = await repository.createDraft(currentState.request);
        _taskId = saved.id;
      }
      ref.invalidate(activeUserTasksProvider);
      state = AsyncData(currentState.copyWith(creationError: null));
      return saved;
    } catch (error, stackTrace) {
      _recordError(currentState, error, stackTrace);
      return null;
    }
  }

  /// Opens a saved draft with [refereeCount] referee requests. The server
  /// enforces the open requirements and the count bound; a `validation_error`
  /// surfaces through `state.creationError`.
  Future<bool> publish({required int refereeCount}) async {
    final currentState = state.value;
    if (currentState == null) return false;
    final taskId = _taskId;
    if (taskId == null) return false;

    state = const AsyncLoading();
    try {
      await ref
          .read(taskRepositoryProvider)
          .publish(taskId, refereeCount: refereeCount);
      ref.invalidate(taskDetailProvider(taskId));
      ref.invalidate(activeUserTasksProvider);
      state = AsyncData(currentState.copyWith(creationError: null));
      return true;
    } catch (error, stackTrace) {
      _recordError(currentState, error, stackTrace);
      return false;
    }
  }

  /// The screen's single action: save the draft, then publish it when the
  /// author picked "start matching".
  Future<void> submit() async {
    final currentState = state.value;
    if (currentState == null) return;

    final saved = await saveDraft();
    if (saved == null) return;
    if (currentState.request.taskStatus != 'open') return;

    await publish(refereeCount: currentState.refereeCount);
  }

  void clearCreationError() {
    final currentState = state.value;
    if (currentState?.creationError != null) {
      state = AsyncData(currentState!.copyWith(creationError: null));
    }
  }

  bool get isFormValid {
    return state.when(
      data: (currentState) {
        final request = currentState.request;
        if (request.taskStatus == 'draft') {
          return request.title.isNotEmpty;
        }
        return request.title.isNotEmpty &&
            request.criteria.isNotEmpty &&
            request.dueDate != null &&
            currentState.refereeCount >= 1;
      },
      loading: () => false,
      error: (_, __) => false, // ignore: unnecessary_underscores
    );
  }

  void _patchRequest(TaskCreationRequest Function(TaskCreationRequest) patch) {
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncData(
      currentState.copyWith(request: patch(currentState.request)),
    );
  }

  void _recordError(
    TaskCreationState currentState,
    Object error,
    StackTrace stackTrace,
  ) {
    ref
        .read(loggerProvider)
        .e('Task save failed', error: error, stackTrace: stackTrace);
    // The Go API returns a stable error envelope; show its message rather than
    // the exception's own toString.
    final message = error is ApiException ? error.message : error.toString();
    state = AsyncData(
      currentState.copyWith(creationError: TaskCreationError.parse(message)),
    );
  }
}
