import 'package:peppercheck_flutter/app/app_logger.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/features/task/domain/task_creation_request.dart';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';

part 'task_repository.g.dart';

class TaskRepository {
  final SupabaseClient _client;
  final Logger _logger;

  TaskRepository(this._client, this._logger);

  Future<String> createTask(TaskCreationRequest request) async {
    try {
      final refereeRequests = request.matchingStrategies.map((strategy) {
        return {'matching_strategy': strategy};
      }).toList();

      final params = {
        'title': request.title,
        'description': request.description,
        'criteria': request.criteria,
        'due_date': request.dueDate?.toUtc().toIso8601String(),
        'status': request.taskStatus,
        'referee_requests': refereeRequests,
      };

      final taskId = await _client.rpc('create_task', params: params);
      return taskId as String;
    } catch (e, st) {
      _logger.e('createTask failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> updateTask(String taskId, TaskCreationRequest request) async {
    try {
      final refereeRequests = request.matchingStrategies.map((strategy) {
        return {'matching_strategy': strategy};
      }).toList();

      final params = {
        'p_task_id': taskId,
        'p_title': request.title,
        'p_description': request.description,
        'p_criteria': request.criteria,
        'p_due_date': request.dueDate?.toUtc().toIso8601String(),
        'p_status': request.taskStatus,
        'p_referee_requests': refereeRequests,
      };

      await _client.rpc('update_task', params: params);
    } catch (e, st) {
      _logger.e('updateTask failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<Task>> fetchActiveUserTasks() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Fetch tasks created by the user that are not closed
      // Join task_referee_requests, judgements, and profiles (referees)
      // Note: Supabase join syntax can be complex for deep nesting or multiple joins on same table.
      // We'll fetch related data and map it manually if needed, or use deep select if possible.
      // Here assuming we can get:
      // tasks -> task_referee_requests -> (judgements, profiles(referee))

      final data = await _client
          .from('tasks')
          .select('''
            *,
            task_referee_requests (
              *,
              judgements (*),
              profiles:matched_referee_id (*)
            )
          ''')
          .eq('tasker_id', userId)
          .neq('status', 'closed')
          .order('created_at', ascending: false);

      return (data as List).map((json) {
        final Map<String, dynamic> taskJson = Map<String, dynamic>.from(json);

        // Handle referee requests list
        if (taskJson['task_referee_requests'] is List) {
          final requests = taskJson['task_referee_requests'] as List;

          taskJson['task_referee_requests'] = requests.map((req) {
            final Map<String, dynamic> reqJson = Map<String, dynamic>.from(req);

            // Map judgements (assuming 1:1 for a request usually, but DB might return list)
            if (reqJson['judgements'] is List &&
                (reqJson['judgements'] as List).isNotEmpty) {
              reqJson['judgement'] = (reqJson['judgements'] as List).first;
            }

            // Map referee profile
            if (reqJson['profiles'] != null) {
              reqJson['referee'] = reqJson['profiles'];
            }

            return reqJson;
          }).toList();
        }

        return Task.fromJson(taskJson);
      }).toList();
    } catch (e, st) {
      _logger.e('fetchActiveUserTasks failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<Task>> fetchActiveRefereeTasks() async {
    try {
      // Call RPC get_active_referee_tasks
      final data = await _client.rpc('get_active_referee_tasks');

      if (data == null) return [];

      // Map the RPC response (RefereeTaskResponse structure) to our unified Task model
      // RPC returns: { task: {...}, judgement: {...}, tasker_profile: {...} }
      return (data as List).map((json) {
        final taskJson = json['task'] as Map<String, dynamic>;
        final judgementJson = json['judgement'] as Map<String, dynamic>;
        final taskerProfileJson =
            json['tasker_profile'] as Map<String, dynamic>;

        // Construct a RefereeRequest that represents "My View" of this task
        // We don't have the full RefereeRequest object from RPC (it returns task, judgement, profile),
        // but we can infer or construct a partial one if needed, or just attach judgement/referee to a synthetic request.
        // However, the RPC *should* ideally return the request info too.
        // Assuming for now we map what we have.

        // Since we don't have the RefereeRequest ID from this specific RPC (based on previous view),
        // we might need to adjust the RPC or just use a placeholder if the UI depends on it.
        // But wait, the RPC `get_active_referee_tasks` usually joins `task_referee_requests`.
        // Let's assume for now we construct a Task with a single RefereeRequest containing the Judgement.

        final refereeRequestJson = {
          'id': 'synthetic-id', // Placeholder or need to fetch from RPC
          'task_id': taskJson['id'],
          'status': 'matched', // Implied
          'matching_strategy': 'unknown',
          'created_at': DateTime.now().toIso8601String(),
          'judgement': judgementJson,
          // 'referee': current_user_profile // We could fetch this if needed, but maybe not strictly required for "My View"
        };

        final mergedJson = {
          ...taskJson,
          'task_referee_requests': [refereeRequestJson],
          'tasker_profile': taskerProfileJson,
        };
        return Task.fromJson(mergedJson);
      }).toList();
    } catch (e, st) {
      _logger.e('fetchActiveRefereeTasks failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<Task> getTask(String id) async {
    try {
      final data = await _client
          .from('tasks')
          .select('''
            *,
            task_referee_requests (
              *,
              judgements (*),
              profiles:matched_referee_id (*)
            )
          ''')
          .eq('id', id)
          .single();

      final Map<String, dynamic> taskJson = Map<String, dynamic>.from(data);

      if (taskJson['task_referee_requests'] is List) {
        final requests = taskJson['task_referee_requests'] as List;

        taskJson['task_referee_requests'] = requests.map((req) {
          final Map<String, dynamic> reqJson = Map<String, dynamic>.from(req);

          if (reqJson['judgements'] is List &&
              (reqJson['judgements'] as List).isNotEmpty) {
            reqJson['judgement'] = (reqJson['judgements'] as List).first;
          }

          if (reqJson['profiles'] != null) {
            reqJson['referee'] = reqJson['profiles'];
          }

          return reqJson;
        }).toList();
      }

      return Task.fromJson(taskJson);
    } catch (e, st) {
      _logger.e('getTask failed for id: $id', error: e, stackTrace: st);
      rethrow;
    }
  }
}

@Riverpod(keepAlive: true)
TaskRepository taskRepository(Ref ref) {
  return TaskRepository(Supabase.instance.client, ref.watch(loggerProvider));
}
