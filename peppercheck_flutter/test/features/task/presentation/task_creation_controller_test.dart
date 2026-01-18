import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peppercheck_flutter/features/task/presentation/task_creation_controller.dart';

void main() {
  test('TaskCreationController validation logic', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Initial state is draft, empty
    // We access the notifier to call methods and check getters
    final controller = container.read(
      taskCreationControllerProvider(null).notifier,
    );

    // 1. Initial Draft State (Empty) -> Invalid
    expect(controller.state.taskStatus, 'draft');
    expect(controller.isFormValid, false);

    // 2. Draft with Title -> Valid
    controller.updateTitle('My Task');
    expect(controller.isFormValid, true);

    // 3. Switch to Open (Title only) -> Invalid
    controller.updateTaskStatus('open');
    expect(controller.isFormValid, false);

    // 4. Open with Title + Criteria -> Invalid
    controller.updateCriteria('Some criteria');
    expect(controller.isFormValid, false);

    // 5. Open with Title + Criteria + DueDate -> Invalid (Missing strategies)
    controller.updateDueDate(DateTime.now());
    expect(controller.isFormValid, false);

    // 5b. Open with Title + Criteria + DueDate + Strategies -> Valid
    controller.updateMatchingStrategies(['some_strategy']);
    expect(controller.isFormValid, true);

    // 6. Open Description is Optional (Check with empty description)
    controller.updateDescription('');
    expect(controller.isFormValid, true);

    // 7. Verify removing title makes it invalid again
    controller.updateTitle('');
    expect(controller.isFormValid, false);
  });
}
