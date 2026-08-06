import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_client_provider.dart';
import '../../../core/network/paginated_fetch.dart';
import '../domain/task.dart';
import '../domain/task_creation_request.dart';
import 'task_dto.dart';

part 'task_repository.g.dart';

/// Task authoring over the Go API, scoped to the authenticated caller (the
/// bearer identifies the tasker; no `taskerId` parameter). Bodies and response
/// envelopes follow the wire contract §7.1.
class TaskRepository {
  TaskRepository(this._api);

  final ApiClient _api;

  Future<Task> createDraft(TaskCreationRequest request) async {
    final json = await _api.postJson(
      '/api/v1/tasks',
      body: _draftBody(request),
    );
    return TaskDto.fromJson(json).toDomain();
  }

  Future<Task> updateDraft(String id, TaskCreationRequest request) async {
    final json = await _api.patchJson(
      '/api/v1/tasks/$id',
      body: _draftBody(request),
    );
    return TaskDto.fromJson(json).toDomain();
  }

  Future<void> deleteDraft(String id) => _api.deleteJson('/api/v1/tasks/$id');

  /// Opens a draft and creates [refereeCount] referee requests (1..the config's
  /// `maxRefereesPerTask`). A failed open requirement surfaces as an
  /// [ApiException] with code `validation_error`.
  Future<Task> publish(String id, {required int refereeCount}) async {
    final json = await _api.postJson(
      '/api/v1/tasks/$id/publish',
      body: {'refereeCount': refereeCount},
    );
    return TaskDto.fromJson(json).toDomain();
  }

  Future<Task> getTask(String id) async {
    final json = await _api.getJson('/api/v1/tasks/$id');
    return TaskDto.fromJson(json).toDomain();
  }

  /// The caller's own tasks that are still in play. `GET /me/tasks` filters by
  /// one exact status, so the two active statuses are fetched separately and
  /// merged — which also keeps closed history off the wire entirely, so this
  /// stays a bounded list as the user accumulates finished tasks. Every cursor
  /// page is followed; there is no "load more".
  Future<List<Task>> fetchMyActiveTasks() async {
    final pages = await Future.wait(
      _activeStatuses.map(
        (status) => fetchAllPages(
          _api,
          '/api/v1/me/tasks?status=$status',
          itemsKey: 'tasks',
        ),
      ),
    );
    return pages
        .expand((page) => page)
        .map((json) => TaskDto.fromJson(json).toDomain())
        .toList();
  }

  /// Task statuses a tasker still acts on; `closed` is history.
  static const _activeStatuses = ['draft', 'open'];

  Map<String, dynamic> _draftBody(TaskCreationRequest request) => {
    'title': request.title,
    'description': request.description,
    'criteria': request.criteria,
    'dueDate': request.dueDate?.toUtc().toIso8601String(),
  };
}

@Riverpod(keepAlive: true)
TaskRepository taskRepository(Ref ref) =>
    TaskRepository(ref.watch(apiClientProvider));
