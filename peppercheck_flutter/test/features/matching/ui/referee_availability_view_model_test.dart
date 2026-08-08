import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peppercheck_flutter/features/matching/data/matching_repository.dart';
import 'package:peppercheck_flutter/features/matching/domain/referee_available_time_slot.dart';
import 'package:peppercheck_flutter/features/matching/ui/referee_availability_view_model.dart';

import 'referee_availability_view_model_test.mocks.dart';

RefereeAvailableTimeSlot _slot({
  String id = 's1',
  int dow = 1,
  bool isActive = true,
}) => RefereeAvailableTimeSlot(
  id: id,
  dow: dow,
  startMin: 540,
  endMin: 720,
  isActive: isActive,
);

@GenerateNiceMocks([MockSpec<MatchingRepository>()])
void main() {
  late MockMatchingRepository repository;

  setUp(() => repository = MockMatchingRepository());

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [matchingRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('hides disabled slots, which the cards cannot represent', () async {
    when(repository.fetchTimeSlots()).thenAnswer(
      (_) async => [
        _slot(id: 'active'),
        _slot(id: 'disabled', dow: 2, isActive: false),
      ],
    );

    final slots = await makeContainer().read(
      refereeAvailabilityViewModelProvider.future,
    );

    expect(slots.map((s) => s.id), ['active']);
  });

  test('editing a slot preserves its enabled state', () async {
    when(
      repository.fetchTimeSlots(),
    ).thenAnswer((_) async => [_slot(id: 's1')]);

    final container = makeContainer();
    await container.read(refereeAvailabilityViewModelProvider.future);
    await container
        .read(refereeAvailabilityViewModelProvider.notifier)
        .updateTimeSlot('s1', 2, 600, 660);

    verify(
      repository.updateTimeSlot(
        id: 's1',
        dow: 2,
        startMin: 600,
        endMin: 660,
        isActive: true,
      ),
    ).called(1);
  });

  test('adding a slot reloads the list', () async {
    when(
      repository.fetchTimeSlots(),
    ).thenAnswer((_) async => [_slot(id: 's1')]);

    final container = makeContainer();
    await container.read(refereeAvailabilityViewModelProvider.future);
    await container
        .read(refereeAvailabilityViewModelProvider.notifier)
        .addTimeSlot(3, 540, 720);

    verify(
      repository.createTimeSlot(dow: 3, startMin: 540, endMin: 720),
    ).called(1);
    verify(repository.fetchTimeSlots()).called(2);
  });
}
