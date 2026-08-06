import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/features/auth/application/auth_state.dart';
import 'package:peppercheck_flutter/features/auth/domain/app_user.dart';
import 'package:peppercheck_flutter/features/matching/domain/referee_request.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/features/task/ui/task_detail_view_model.dart';
import 'package:peppercheck_flutter/features/task/ui/task_role_provider.dart';

Task _task({List<RefereeRequest> requests = const []}) => Task(
  id: 't1',
  taskerId: 'u_owner',
  title: 'Run 5km',
  status: 'open',
  createdAt: '2026-07-25T00:00:00Z',
  refereeRequests: requests,
);

RefereeRequest _request({required String id, String? refereeId}) =>
    RefereeRequest(
      id: id,
      taskId: 't1',
      status: 'accepted',
      matchedRefereeId: refereeId,
      createdAt: '2026-07-25T00:00:00Z',
    );

ProviderContainer _container({required Task task, required String? userId}) {
  final container = ProviderContainer(
    overrides: [
      taskDetailProvider('t1').overrideWith(() => _StubTaskDetail(task)),
      currentAppUserProvider.overrideWith(
        (ref) async => userId == null
            ? null
            : AppUser(
                internalUserId: userId,
                issuer: 'iss',
                status: 'active',
                createdAt: DateTime.utc(2026),
              ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

class _StubTaskDetail extends TaskDetail {
  _StubTaskDetail(this._task);

  final Task _task;

  @override
  Future<Task> build(String taskId) async => _task;
}

void main() {
  test('the tasker is resolved from the internal user id', () async {
    final role = await _container(
      task: _task(),
      userId: 'u_owner',
    ).read(taskRoleProvider('t1').future);

    expect(role.isTasker, true);
    expect(role.isAssignedReferee, false);
  });

  test('an assigned referee resolves their own request', () async {
    final role = await _container(
      task: _task(
        requests: [
          _request(id: 'r1', refereeId: 'u_other'),
          _request(id: 'r2', refereeId: 'u_me'),
        ],
      ),
      userId: 'u_me',
    ).read(taskRoleProvider('t1').future);

    expect(role.isTasker, false);
    expect(role.myRequest?.id, 'r2');
  });

  test('a signed-out viewer is neither', () async {
    final role = await _container(
      task: _task(
        requests: [_request(id: 'r1', refereeId: 'u_other')],
      ),
      userId: null,
    ).read(taskRoleProvider('t1').future);

    expect(role.isTasker, false);
    expect(role.isAssignedReferee, false);
  });
}
