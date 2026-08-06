import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  TaskRepository(this._api, this._supabase);

  final ApiClient _api;

  /// TRANSITIONAL: the referee assignment list is still served by the Supabase
  /// RPC until it moves to `MatchingRepository.fetchMyAssignments`, which the
  /// home lists switch to in the same pull request.
  final SupabaseClient _supabase;

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

  /// The caller's own tasks. This is a bounded active list, so every cursor
  /// page is followed and the whole list is returned; there is no "load more".
  Future<List<Task>> fetchMyTasks() async {
    final pages = await fetchAllPages(
      _api,
      '/api/v1/me/tasks',
      itemsKey: 'tasks',
    );
    return pages.map((json) => TaskDto.fromJson(json).toDomain()).toList();
  }

  /// TRANSITIONAL: superseded by `MatchingRepository.fetchMyAssignments`.
  Future<List<Task>> fetchActiveRefereeTasks() async {
    final data = await _supabase.rpc('get_active_referee_tasks');
    if (data == null) return [];

    return (data as List).map((json) {
      final taskJson = json['task'] as Map<String, dynamic>;
      return Task.fromJson({
        ...taskJson,
        'task_referee_requests': <Map<String, dynamic>>[],
      });
    }).toList();
  }

  Map<String, dynamic> _draftBody(TaskCreationRequest request) => {
    'title': request.title,
    'description': request.description,
    'criteria': request.criteria,
    'dueDate': request.dueDate?.toUtc().toIso8601String(),
  };
}

@Riverpod(keepAlive: true)
TaskRepository taskRepository(Ref ref) =>
    TaskRepository(ref.watch(apiClientProvider), Supabase.instance.client);
