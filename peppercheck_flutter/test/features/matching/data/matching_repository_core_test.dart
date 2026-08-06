import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peppercheck_flutter/core/network/api_client.dart';
import 'package:peppercheck_flutter/features/matching/data/matching_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'matching_repository_core_test.mocks.dart';

Map<String, dynamic> _assignmentJson({
  String id = 't1',
  String requestId = 'r1',
}) => {
  'id': id,
  'taskerId': 'u_tasker',
  'title': 'Run 5km',
  'description': null,
  'criteria': 'a photo of the watch',
  'dueDate': '2026-08-01T00:00:00Z',
  'status': 'open',
  'createdAt': '2026-07-25T00:00:00Z',
  'updatedAt': '2026-07-25T00:00:00Z',
  'tasker': {'userId': 'u_tasker', 'username': 'tanaka', 'avatarUrl': null},
  'refereeRequests': [
    {
      'id': requestId,
      'taskId': id,
      'status': 'accepted',
      'matchedRefereeId': 'u_me',
      'respondedAt': '2026-07-26T00:00:00Z',
      'pointSource': 'regular',
      'isObligation': false,
      'createdAt': '2026-07-25T00:00:00Z',
      'updatedAt': '2026-07-26T00:00:00Z',
      'referee': {'userId': 'u_me', 'username': 'suzuki', 'avatarUrl': null},
    },
  ],
};

@GenerateNiceMocks([MockSpec<ApiClient>(), MockSpec<SupabaseClient>()])
void main() {
  late MockApiClient api;
  late MatchingRepository repo;

  setUp(() {
    api = MockApiClient();
    repo = MatchingRepository(api, MockSupabaseClient());
  });

  test('fetchConfig maps GET /matching/config', () async {
    when(api.getJson('/api/v1/matching/config')).thenAnswer(
      (_) async => {
        'openDeadlineHours': 24,
        'cancelDeadlineHours': 12,
        'rematchCutoffHours': 14,
        'maxRefereesPerTask': 2,
        'matchingPointCost': 1,
      },
    );

    final config = await repo.fetchConfig();

    expect(config.openDeadlineHours, 24);
    expect(config.cancelDeadlineHours, 12);
    expect(config.rematchCutoffHours, 14);
    expect(config.maxRefereesPerTask, 2);
    expect(config.matchingPointCost, 1);
  });

  group('fetchMyAssignments', () {
    test('maps assignments with the caller real referee request', () async {
      when(api.getJson('/api/v1/me/assignments')).thenAnswer(
        (_) async => {
          'assignments': [_assignmentJson()],
          'nextCursor': null,
        },
      );

      final tasks = await repo.fetchMyAssignments();

      final request = tasks.single.refereeRequests.single;
      expect(request.id, 'r1');
      expect(request.id, isNot('synthetic-id'));
      expect(request.matchedRefereeId, 'u_me');
      expect(tasks.single.tasker?.username, 'tanaka');
    });

    test('follows the cursor across pages', () async {
      when(api.getJson('/api/v1/me/assignments')).thenAnswer(
        (_) async => {
          'assignments': [_assignmentJson(id: 't1', requestId: 'r1')],
          'nextCursor': 'c1',
        },
      );
      when(api.getJson('/api/v1/me/assignments?cursor=c1')).thenAnswer(
        (_) async => {
          'assignments': [_assignmentJson(id: 't2', requestId: 'r2')],
          'nextCursor': null,
        },
      );

      final tasks = await repo.fetchMyAssignments();

      expect(tasks.map((t) => t.id), ['t1', 't2']);
      verify(api.getJson(any)).called(2);
    });
  });

  test(
    'cancelAssignment POSTs the cancel endpoint and maps the task',
    () async {
      when(
        api.postJson('/api/v1/referee-requests/r1/cancel'),
      ).thenAnswer((_) async => _assignmentJson());

      final task = await repo.cancelAssignment('r1');

      expect(task.id, 't1');
      verify(api.postJson('/api/v1/referee-requests/r1/cancel')).called(1);
    },
  );
}
