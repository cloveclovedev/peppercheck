import 'package:peppercheck_flutter/app/app_logger.dart';
import 'package:peppercheck_flutter/features/task/data/task_repository.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/features/task/presentation/task_creation_state.dart';
import 'package:peppercheck_flutter/features/task/domain/task_creation_request.dart';
import 'package:peppercheck_flutter/features/task/domain/task_creation_error.dart';
import 'package:peppercheck_flutter/features/home/ui/home_view_model.dart';
import 'package:peppercheck_flutter/features/task/presentation/providers/task_provider.dart';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_creation_controller.g.dart';

@riverpod
class TaskCreationController extends _$TaskCreationController {
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
          // Strategies left the domain in Phase 4a; only the number of referee
          // requests still matters here, and the publish UI replaces this with
          // an explicit referee count.
          matchingStrategies: List<String>.filled(
            initialTask.refereeRequests.length,
            'standard',
          ),
        ),
        creationError: null,
      );
    }
    _taskId = null;
    return const TaskCreationState(
      request: TaskCreationRequest(),
      creationError: null,
    );
  }

  void updateTitle(String title) {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(
      currentState.copyWith(
        request: currentState.request.copyWith(title: title),
      ),
    );
  }

  void updateDescription(String description) {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(
      currentState.copyWith(
        request: currentState.request.copyWith(description: description),
      ),
    );
  }

  void updateCriteria(String criteria) {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(
      currentState.copyWith(
        request: currentState.request.copyWith(criteria: criteria),
      ),
    );
  }

  void updateDueDate(DateTime date) {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(
      currentState.copyWith(
        request: currentState.request.copyWith(dueDate: date),
      ),
    );
  }

  void updateTaskStatus(String status) {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(
      currentState.copyWith(
        request: currentState.request.copyWith(taskStatus: status),
      ),
    );
  }

  void updateMatchingStrategies(List<String> strategies) {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(
      currentState.copyWith(
        request: currentState.request.copyWith(matchingStrategies: strategies),
      ),
    );
  }

  Future<void> createTask() async {
    final currentState = state.value;
    if (currentState == null) return;

    state = const AsyncLoading();

    try {
      final taskRepository = ref.read(taskRepositoryProvider);
      final request = currentState.request;

      // The Go API separates authoring a draft from publishing it; the publish
      // UI (with its explicit referee-count selector) replaces the strategy
      // list in the next step of this migration.
      final Task saved;
      if (_taskId != null) {
        saved = await taskRepository.updateDraft(_taskId!, request);
        ref.invalidate(taskProvider(_taskId!));
      } else {
        saved = await taskRepository.createDraft(request);
      }
      if (request.taskStatus == 'open') {
        await taskRepository.publish(
          saved.id,
          refereeCount: request.matchingStrategies.length,
        );
        ref.invalidate(taskProvider(saved.id));
      }

      // Refresh the home screen lists
      ref.invalidate(activeUserTasksProvider);

      // Success - clear any error and return to data state
      state = AsyncData(currentState.copyWith(creationError: null));
    } catch (error, stackTrace) {
      ref
          .read(loggerProvider)
          .e('Task creation failed', error: error, stackTrace: stackTrace);

      // Parse and store creation error, but keep state as AsyncData
      final creationError = TaskCreationError.parse(error.toString());
      state = AsyncData(currentState.copyWith(creationError: creationError));
    }
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
            request.matchingStrategies.isNotEmpty;
      },
      loading: () => false,
      error: (_, __) => false, // ignore: unnecessary_underscores
    );
  }
}
