import 'package:peppercheck_flutter/features/authentication/data/auth_state_provider.dart';
import 'package:peppercheck_flutter/features/matching/data/matching_repository.dart';
import 'package:peppercheck_flutter/features/matching/domain/referee_available_time_slot.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'referee_availability_controller.g.dart';

@riverpod
class RefereeAvailabilityController extends _$RefereeAvailabilityController {
  @override
  FutureOr<List<RefereeAvailableTimeSlot>> build() async {
    final userId = ref.watch(authStateChangesProvider).value?.session?.user.id;
    if (userId == null) {
      return [];
    }
    return ref
        .read(matchingRepositoryProvider)
        .getRefereeAvailableTimeSlots(userId);
  }

  Future<void> addTimeSlot(int dow, int startMin, int endMin) async {
    final repository = ref.read(matchingRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repository.createRefereeAvailableTimeSlot(
        dow: dow,
        startMin: startMin,
        endMin: endMin,
      );
      final userId = ref.read(authStateChangesProvider).value?.session?.user.id;
      if (userId == null) return [];
      return repository.getRefereeAvailableTimeSlots(userId);
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
      await repository.updateRefereeAvailableTimeSlot(
        id: id,
        dow: dow,
        startMin: startMin,
        endMin: endMin,
      );
      final userId = ref.read(authStateChangesProvider).value?.session?.user.id;
      if (userId == null) return [];
      return repository.getRefereeAvailableTimeSlots(userId);
    });
  }

  Future<void> deleteTimeSlot(String id) async {
    final repository = ref.read(matchingRepositoryProvider);
    // Optimistic update could be done, but for simplicity we reload
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repository.deleteRefereeAvailableTimeSlot(id);
      final userId = ref.read(authStateChangesProvider).value?.session?.user.id;
      if (userId == null) return [];
      return repository.getRefereeAvailableTimeSlots(userId);
    });
  }
}
