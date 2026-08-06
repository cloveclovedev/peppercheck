import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peppercheck_flutter/core/network/api_exception.dart';
import 'package:peppercheck_flutter/features/task/data/task_repository.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/features/task/domain/task_creation_error.dart';
import 'package:peppercheck_flutter/features/task/ui/task_creation_view_model.dart';

import 'task_creation_view_model_test.mocks.dart';

Task _task({String id = 't1', String status = 'draft'}) => Task(
  id: id,
  taskerId: 'u_tasker',
  title: 'My Task',
  status: status,
  createdAt: '2026-07-25T00:00:00Z',
);

@GenerateNiceMocks([MockSpec<TaskRepository>()])
void main() {
  late MockTaskRepository repository;

  setUp(() => repository = MockTaskRepository());

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [taskRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('TaskCreationViewModel validation logic', () async {
    final container = makeContainer();
    final viewModel = container.read(
      taskCreationViewModelProvider(null).notifier,
    );
    await container.read(taskCreationViewModelProvider(null).future);

    // 1. Initial Draft State (Empty) -> Invalid
    expect(viewModel.state.value!.request.taskStatus, 'draft');
    expect(viewModel.isFormValid, false);

    // 2. Draft with Title -> Valid
    viewModel.updateTitle('My Task');
    expect(viewModel.isFormValid, true);

    // 3. Switch to Open (Title only) -> Invalid
    viewModel.updateTaskStatus('open');
    expect(viewModel.isFormValid, false);

    // 4. Open with Title + Criteria -> Invalid
    viewModel.updateCriteria('Some criteria');
    expect(viewModel.isFormValid, false);

    // 5. Open with Title + Criteria + DueDate -> Valid; the referee count
    //    defaults to 1, so there is nothing else to pick.
    viewModel.updateDueDate(DateTime.now());
    expect(viewModel.state.value!.refereeCount, 1);
    expect(viewModel.isFormValid, true);

    // 6. Open Description is Optional (Check with empty description)
    viewModel.updateDescription('');
    expect(viewModel.isFormValid, true);

    // 7. Verify removing title makes it invalid again
    viewModel.updateTitle('');
    expect(viewModel.isFormValid, false);
  });

  test('submit saves a draft without publishing it', () async {
    when(repository.createDraft(any)).thenAnswer((_) async => _task());

    final container = makeContainer();
    final viewModel = container.read(
      taskCreationViewModelProvider(null).notifier,
    );
    await container.read(taskCreationViewModelProvider(null).future);

    viewModel.updateTitle('My Task');
    await viewModel.submit();

    verify(repository.createDraft(any)).called(1);
    verifyNever(
      repository.publish(any, refereeCount: anyNamed('refereeCount')),
    );
  });

  test('submit publishes with the selected referee count', () async {
    when(repository.createDraft(any)).thenAnswer((_) async => _task());
    when(
      repository.publish('t1', refereeCount: 2),
    ).thenAnswer((_) async => _task(status: 'open'));

    final container = makeContainer();
    final viewModel = container.read(
      taskCreationViewModelProvider(null).notifier,
    );
    await container.read(taskCreationViewModelProvider(null).future);

    viewModel.updateTitle('My Task');
    viewModel.updateCriteria('Some criteria');
    viewModel.updateDueDate(DateTime.now());
    viewModel.updateTaskStatus('open');
    viewModel.updateRefereeCount(2);
    await viewModel.submit();

    verify(repository.publish('t1', refereeCount: 2)).called(1);
  });

  test('an existing draft edit updates instead of creating', () async {
    when(
      repository.updateDraft('t9', any),
    ).thenAnswer((_) async => _task(id: 't9'));

    final container = makeContainer();
    final initial = _task(id: 't9');
    final viewModel = container.read(
      taskCreationViewModelProvider(initial).notifier,
    );
    await container.read(taskCreationViewModelProvider(initial).future);

    await viewModel.submit();

    verify(repository.updateDraft('t9', any)).called(1);
    verifyNever(repository.createDraft(any));
  });

  test('a publish validation_error surfaces as a creation error', () async {
    when(repository.createDraft(any)).thenAnswer((_) async => _task());
    when(repository.publish('t1', refereeCount: 1)).thenThrow(
      const ApiException(
        code: 'validation_error',
        message: 'due date must be at least 24 hours from now',
      ),
    );

    final container = makeContainer();
    final viewModel = container.read(
      taskCreationViewModelProvider(null).notifier,
    );
    await container.read(taskCreationViewModelProvider(null).future);

    viewModel.updateTitle('My Task');
    viewModel.updateTaskStatus('open');
    await viewModel.submit();

    final error = viewModel.state.value!.creationError;
    expect(error, isNotNull);
    expect(error!.type, TaskCreationErrorType.unknown);
    expect(error.message, contains('due date'));
  });
}
