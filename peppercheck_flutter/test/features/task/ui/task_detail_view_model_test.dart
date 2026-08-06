import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peppercheck_flutter/core/async/poll_sleep_provider.dart';
import 'package:peppercheck_flutter/features/matching/domain/referee_request.dart';
import 'package:peppercheck_flutter/features/task/data/task_repository.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/features/task/ui/task_detail_view_model.dart';

import 'task_detail_view_model_test.mocks.dart';

Task _task({required List<String> requestStatuses}) => Task(
  id: 't1',
  taskerId: 'u_tasker',
  title: 'Run 5km',
  status: 'open',
  createdAt: '2026-07-25T00:00:00Z',
  refereeRequests: [
    for (var i = 0; i < requestStatuses.length; i++)
      RefereeRequest(
        id: 'r$i',
        taskId: 't1',
        status: requestStatuses[i],
        matchedRefereeId: requestStatuses[i] == 'accepted' ? 'u_ref' : null,
        createdAt: '2026-07-25T00:00:00Z',
      ),
  ],
);

@GenerateNiceMocks([MockSpec<TaskRepository>()])
void main() {
  late MockTaskRepository repository;

  setUp(() => repository = MockTaskRepository());

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repository),
        // No real time passes in these tests.
        pollSleepProvider.overrideWithValue((_) async {}),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('build exposes the fetched task', () async {
    when(
      repository.getTask('t1'),
    ).thenAnswer((_) async => _task(requestStatuses: ['pending']));

    final task = await makeContainer().read(taskDetailProvider('t1').future);

    expect(task.id, 't1');
    verify(repository.getTask('t1')).called(1);
  });

  test('isMatching is true only while a request is pending', () {
    expect(TaskDetail.isMatching(_task(requestStatuses: ['pending'])), true);
    expect(
      TaskDetail.isMatching(_task(requestStatuses: ['accepted', 'pending'])),
      true,
    );
    expect(TaskDetail.isMatching(_task(requestStatuses: ['accepted'])), false);
    expect(TaskDetail.isMatching(_task(requestStatuses: [])), false);
  });

  test('polls until nothing is pending, then stops', () async {
    var calls = 0;
    when(repository.getTask('t1')).thenAnswer((_) async {
      calls++;
      return calls < 3
          ? _task(requestStatuses: ['pending'])
          : _task(requestStatuses: ['accepted']);
    });

    final container = makeContainer();
    await container.read(taskDetailProvider('t1').future);
    expect(calls, 1);

    await container.read(taskDetailProvider('t1').notifier).pollUntilMatched();

    // The build fetch plus the polled fetches, and no fetch after the match.
    expect(calls, 3);
    final state = container.read(taskDetailProvider('t1'));
    expect(state.value!.refereeRequests.single.status, 'accepted');
  });

  test('publishes every intermediate result to the screen', () async {
    final seen = <String>[];
    var calls = 0;
    when(repository.getTask('t1')).thenAnswer((_) async {
      calls++;
      return calls < 2
          ? _task(requestStatuses: ['pending'])
          : _task(requestStatuses: ['accepted']);
    });

    final container = makeContainer();
    await container.read(taskDetailProvider('t1').future);
    container.listen(taskDetailProvider('t1'), (previous, next) {
      final task = next.value;
      if (task != null) seen.add(task.refereeRequests.single.status);
    });

    await container.read(taskDetailProvider('t1').notifier).pollUntilMatched();

    expect(seen, contains('accepted'));
  });

  test(
    'gives up after the schedule without matching, keeping the last task',
    () async {
      when(
        repository.getTask('t1'),
      ).thenAnswer((_) async => _task(requestStatuses: ['pending']));

      final container = makeContainer();
      await container.read(taskDetailProvider('t1').future);
      await container
          .read(taskDetailProvider('t1').notifier)
          .pollUntilMatched();

      // One build fetch plus one per entry of the default schedule.
      verify(repository.getTask('t1')).called(7);
      expect(
        container
            .read(taskDetailProvider('t1'))
            .value!
            .refereeRequests
            .single
            .status,
        'pending',
      );
    },
  );

  test('disposal cancels the poll without writing state afterwards', () async {
    var calls = 0;
    when(repository.getTask('t1')).thenAnswer((_) async {
      calls++;
      return _task(requestStatuses: ['pending']);
    });

    final container = ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repository),
        pollSleepProvider.overrideWithValue((_) async {}),
      ],
    );
    await container.read(taskDetailProvider('t1').future);
    final notifier = container.read(taskDetailProvider('t1').notifier);

    final polling = notifier.pollUntilMatched();
    container.dispose();
    await polling;

    // The cancellation token stops the loop rather than throwing on a
    // disposed notifier.
    expect(calls, lessThan(7));
  });
}
