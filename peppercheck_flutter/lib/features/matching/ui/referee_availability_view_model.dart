import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/matching_repository.dart';
import '../domain/referee_available_time_slot.dart';

part 'referee_availability_view_model.g.dart';

/// The signed-in referee's weekly availability. Every call is scoped to the
/// bearer, so the list reloads from the server after each edit rather than
/// being patched locally.
@riverpod
class RefereeAvailabilityViewModel extends _$RefereeAvailabilityViewModel {
  @override
  FutureOr<List<RefereeAvailableTimeSlot>> build() =>
      ref.read(matchingRepositoryProvider).fetchTimeSlots();

  Future<void> addTimeSlot(int dow, int startMin, int endMin) async {
    final repository = ref.read(matchingRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repository.createTimeSlot(
        dow: dow,
        startMin: startMin,
        endMin: endMin,
      );
      return repository.fetchTimeSlots();
    });
  }

  Future<void> updateTimeSlot(
    String id,
    int dow,
    int startMin,
    int endMin,
  ) async {
    final repository = ref.read(matchingRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repository.updateTimeSlot(
        id: id,
        dow: dow,
        startMin: startMin,
        endMin: endMin,
      );
      return repository.fetchTimeSlots();
    });
  }

  Future<void> deleteTimeSlot(String id) async {
    final repository = ref.read(matchingRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repository.deleteTimeSlot(id);
      return repository.fetchTimeSlots();
    });
  }
}
