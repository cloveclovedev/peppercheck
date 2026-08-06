import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/features/matching/domain/referee_request.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/features/task/domain/task_viewer_role.dart';

void main() {
  Task taskWith({
    required String taskerId,
    List<RefereeRequest> reqs = const [],
  }) => Task(
    id: 't1',
    taskerId: taskerId,
    title: 'x',
    status: 'open',
    createdAt: '2026-07-01T00:00:00Z',
    refereeRequests: reqs,
  );

  RefereeRequest req({required String id, String? matchedRefereeId}) =>
      RefereeRequest(
        id: id,
        taskId: 't1',
        status: 'accepted',
        createdAt: '2026-07-01T00:00:00Z',
        matchedRefereeId: matchedRefereeId,
      );

  test('null user -> neither', () {
    final r = taskWith(taskerId: 'u_owner').viewerRole(null);
    expect(r.isTasker, false);
    expect(r.isAssignedReferee, false);
  });

  test('tasker match', () {
    expect(taskWith(taskerId: 'u_me').viewerRole('u_me').isTasker, true);
  });

  test('assigned referee resolves myRequest', () {
    final t = taskWith(
      taskerId: 'u_owner',
      reqs: [
        req(id: 'r1', matchedRefereeId: 'u_other'),
        req(id: 'r2', matchedRefereeId: 'u_me'),
      ],
    );
    final r = t.viewerRole('u_me');
    expect(r.isTasker, false);
    expect(r.isAssignedReferee, true);
    expect(r.myRequest!.id, 'r2');
  });

  test('stranger -> neither', () {
    final r = taskWith(
      taskerId: 'u_owner',
      reqs: [req(id: 'r1', matchedRefereeId: 'u_other')],
    ).viewerRole('u_stranger');
    expect(r.isTasker, false);
    expect(r.isAssignedReferee, false);
  });

  test('pending requests carry no matched referee, so they are not mine', () {
    final t = taskWith(
      taskerId: 'u_owner',
      reqs: [
        RefereeRequest(
          id: 'r1',
          taskId: 't1',
          status: 'pending',
          createdAt: '2026-07-01T00:00:00Z',
        ),
      ],
    );
    expect(t.viewerRole('u_me').isAssignedReferee, false);
  });
}
