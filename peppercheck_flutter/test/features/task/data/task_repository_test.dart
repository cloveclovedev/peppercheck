import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peppercheck_flutter/core/network/api_client.dart';
import 'package:peppercheck_flutter/core/network/api_exception.dart';
import 'package:peppercheck_flutter/features/task/data/task_repository.dart';
import 'package:peppercheck_flutter/features/task/domain/task_creation_request.dart';

import 'task_repository_test.mocks.dart';

/// A task as served by the Go API (wire contract §7.1, camelCase).
Map<String, dynamic> _taskJson({
  String id = 't1',
  String status = 'draft',
  List<Map<String, dynamic>> refereeRequests = const [],
}) => {
  'id': id,
  'taskerId': 'u_tasker',
  'title': 'Run 5km',
  'description': 'every morning',
  'criteria': 'a photo of the watch',
  'dueDate': '2026-08-01T00:00:00Z',
  'status': status,
  'createdAt': '2026-07-25T00:00:00Z',
  'updatedAt': '2026-07-25T00:00:00Z',
  'tasker': {
    'userId': 'u_tasker',
    'username': 'tanaka',
    'avatarUrl': 'https://cdn.example.com/tasker.jpg',
  },
  'refereeRequests': refereeRequests,
};

Map<String, dynamic> _requestJson({
  String id = 'r1',
  String status = 'pending',
  Map<String, dynamic>? referee,
}) => {
  'id': id,
  'taskId': 't1',
  'status': status,
  'matchedRefereeId': referee?['userId'],
  'respondedAt': null,
  'pointSource': 'regular',
  'isObligation': false,
  'createdAt': '2026-07-25T00:00:00Z',
  'updatedAt': '2026-07-25T00:00:00Z',
  'referee': referee,
};

@GenerateNiceMocks([MockSpec<ApiClient>()])
void main() {
  late MockApiClient api;
  late TaskRepository repo;

  setUp(() {
    api = MockApiClient();
    repo = TaskRepository(api);
  });

  const request = TaskCreationRequest(
    title: 'Run 5km',
    description: 'every morning',
    criteria: 'a photo of the watch',
  );

  final draftBody = {
    'title': 'Run 5km',
    'description': 'every morning',
    'criteria': 'a photo of the watch',
    'dueDate': null,
  };

  group('createDraft', () {
    test('POSTs the draft body and maps the response', () async {
      when(
        api.postJson('/api/v1/tasks', body: draftBody),
      ).thenAnswer((_) async => _taskJson());

      final task = await repo.createDraft(request);

      expect(task.id, 't1');
      expect(task.status, 'draft');
      expect(task.refereeRequests, isEmpty);
      verify(api.postJson('/api/v1/tasks', body: draftBody)).called(1);
    });

    test('sends the due date as RFC3339 UTC', () async {
      when(
        api.postJson('/api/v1/tasks', body: anyNamed('body')),
      ).thenAnswer((_) async => _taskJson());

      await repo.createDraft(
        request.copyWith(dueDate: DateTime.utc(2026, 8, 1, 9)),
      );

      final body =
          verify(
                api.postJson('/api/v1/tasks', body: captureAnyNamed('body')),
              ).captured.single
              as Map<String, dynamic>;
      expect(body['dueDate'], '2026-08-01T09:00:00.000Z');
    });
  });

  test('updateDraft PATCHes the task', () async {
    when(
      api.patchJson('/api/v1/tasks/t1', body: draftBody),
    ).thenAnswer((_) async => _taskJson());

    final task = await repo.updateDraft('t1', request);

    expect(task.id, 't1');
    verify(api.patchJson('/api/v1/tasks/t1', body: draftBody)).called(1);
  });

  test('deleteDraft DELETEs the task', () async {
    await repo.deleteDraft('t1');
    verify(api.deleteJson('/api/v1/tasks/t1')).called(1);
  });

  group('publish', () {
    test('sends refereeCount and maps the opened task', () async {
      when(
        api.postJson('/api/v1/tasks/t1/publish', body: {'refereeCount': 2}),
      ).thenAnswer(
        (_) async => _taskJson(
          status: 'open',
          refereeRequests: [
            _requestJson(id: 'r1'),
            _requestJson(id: 'r2'),
          ],
        ),
      );

      final task = await repo.publish('t1', refereeCount: 2);

      expect(task.status, 'open');
      expect(task.refereeRequests.map((r) => r.status), ['pending', 'pending']);
      expect(task.refereeRequests.first.referee, isNull);
    });

    test('propagates a validation_error', () async {
      when(
        api.postJson('/api/v1/tasks/t1/publish', body: {'refereeCount': 1}),
      ).thenThrow(
        const ApiException(
          code: 'validation_error',
          message: 'due date required',
        ),
      );

      expect(
        () => repo.publish('t1', refereeCount: 1),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'validation_error'),
        ),
      );
    });
  });

  test('getTask maps the embedded public profiles', () async {
    when(api.getJson('/api/v1/tasks/t1')).thenAnswer(
      (_) async => _taskJson(
        status: 'open',
        refereeRequests: [
          _requestJson(
            id: 'r1',
            status: 'accepted',
            referee: {
              'userId': 'u_ref',
              'username': 'suzuki',
              'avatarUrl': 'https://cdn.example.com/ref.jpg',
            },
          ),
        ],
      ),
    );

    final task = await repo.getTask('t1');

    expect(task.tasker?.username, 'tanaka');
    expect(task.tasker?.userId, 'u_tasker');
    final matched = task.refereeRequests.single;
    expect(matched.matchedRefereeId, 'u_ref');
    expect(matched.referee?.avatarUrl, 'https://cdn.example.com/ref.jpg');
    expect(matched.judgement, isNull);
  });

  group('fetchMyActiveTasks', () {
    test('asks for the active statuses only, never closed history', () async {
      when(api.getJson('/api/v1/me/tasks?status=draft')).thenAnswer(
        (_) async => {
          'tasks': [_taskJson(id: 'd')],
          'nextCursor': null,
        },
      );
      when(api.getJson('/api/v1/me/tasks?status=open')).thenAnswer(
        (_) async => {
          'tasks': [_taskJson(id: 'o', status: 'open')],
          'nextCursor': null,
        },
      );

      final tasks = await repo.fetchMyActiveTasks();

      expect(tasks.map((t) => t.id), ['d', 'o']);
      verify(api.getJson('/api/v1/me/tasks?status=draft')).called(1);
      verify(api.getJson('/api/v1/me/tasks?status=open')).called(1);
      verifyNever(api.getJson('/api/v1/me/tasks'));
      verifyNever(api.getJson('/api/v1/me/tasks?status=closed'));
    });

    test('aggregates every cursor page of each status', () async {
      when(api.getJson('/api/v1/me/tasks?status=draft')).thenAnswer(
        (_) async => {
          'tasks': [_taskJson(id: 'a')],
          'nextCursor': 'a+b/c==',
        },
      );
      when(
        api.getJson('/api/v1/me/tasks?status=draft&cursor=a%2Bb%2Fc%3D%3D'),
      ).thenAnswer(
        (_) async => {
          'tasks': [_taskJson(id: 'b')],
          'nextCursor': null,
        },
      );
      when(api.getJson('/api/v1/me/tasks?status=open')).thenAnswer(
        (_) async => {'tasks': <Map<String, dynamic>>[], 'nextCursor': null},
      );

      final tasks = await repo.fetchMyActiveTasks();

      expect(tasks.map((t) => t.id), ['a', 'b']);
    });
  });
}
