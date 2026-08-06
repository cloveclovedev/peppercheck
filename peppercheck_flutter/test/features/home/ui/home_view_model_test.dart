import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peppercheck_flutter/features/home/ui/home_view_model.dart';
import 'package:peppercheck_flutter/features/matching/data/matching_repository.dart';
import 'package:peppercheck_flutter/features/matching/domain/referee_request.dart';
import 'package:peppercheck_flutter/features/task/data/task_repository.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';

import 'home_view_model_test.mocks.dart';

Task _task({
  String id = 't1',
  List<RefereeRequest> refereeRequests = const [],
}) => Task(
  id: id,
  taskerId: 'u_tasker',
  title: 'Run 5km',
  status: 'open',
  createdAt: '2026-07-25T00:00:00Z',
  refereeRequests: refereeRequests,
);

@GenerateNiceMocks([MockSpec<TaskRepository>(), MockSpec<MatchingRepository>()])
void main() {
  late MockTaskRepository taskRepository;
  late MockMatchingRepository matchingRepository;

  setUp(() {
    taskRepository = MockTaskRepository();
    matchingRepository = MockMatchingRepository();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(taskRepository),
        matchingRepositoryProvider.overrideWithValue(matchingRepository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('activeUserTasks resolves the caller own tasks', () async {
    when(
      taskRepository.fetchMyTasks(),
    ).thenAnswer((_) async => [_task(id: 'mine')]);

    final tasks = await makeContainer().read(activeUserTasksProvider.future);

    expect(tasks.map((t) => t.id), ['mine']);
    verify(taskRepository.fetchMyTasks()).called(1);
  });

  test(
    'activeRefereeTasks resolves assignments with real request ids',
    () async {
      when(matchingRepository.fetchMyAssignments()).thenAnswer(
        (_) async => [
          _task(
            id: 'assigned',
            refereeRequests: [
              const RefereeRequest(
                id: 'r1',
                taskId: 'assigned',
                status: 'accepted',
                matchedRefereeId: 'u_me',
                createdAt: '2026-07-25T00:00:00Z',
              ),
            ],
          ),
        ],
      );

      final tasks = await makeContainer().read(
        activeRefereeTasksProvider.future,
      );

      expect(tasks.single.refereeRequests.single.id, 'r1');
      expect(
        tasks.single.refereeRequests.map((r) => r.id),
        isNot(contains('synthetic-id')),
      );
      verify(matchingRepository.fetchMyAssignments()).called(1);
    },
  );
}
