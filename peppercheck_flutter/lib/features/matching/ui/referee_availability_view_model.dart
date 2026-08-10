import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/matching_repository.dart';
import '../domain/referee_available_time_slot.dart';

part 'referee_availability_view_model.g.dart';

/// The signed-in referee's weekly availability. Every call is scoped to the
/// bearer, so the list reloads from the server after each edit rather than
/// being patched locally.
///
/// Only active slots are exposed: the API returns disabled slots too, but the
/// cards render no enabled/disabled state, so showing one would read as normal
/// availability that matching silently skips. They come back with the toggle
/// UI.
@riverpod
class RefereeAvailabilityViewModel extends _$RefereeAvailabilityViewModel {
  @override
  FutureOr<List<RefereeAvailableTimeSlot>> build() => _loadActive();

  Future<List<RefereeAvailableTimeSlot>> _loadActive() async {
    final slots = await ref.read(matchingRepositoryProvider).fetchTimeSlots();
    return slots.where((slot) => slot.isActive).toList();
  }

  Future<void> addTimeSlot(int dow, int startMin, int endMin) async {
    final repository = ref.read(matchingRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repository.createTimeSlot(
        dow: dow,
        startMin: startMin,
        endMin: endMin,
      );
      return _loadActive();
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
        // Carry the slot's own flag through the edit; a hard-coded true would
        // reactivate a disabled slot behind the referee's back.
        isActive: _isActive(id),
      );
      return _loadActive();
    });
  }

  Future<void> deleteTimeSlot(String id) async {
    final repository = ref.read(matchingRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repository.deleteTimeSlot(id);
      return _loadActive();
    });
  }

  bool _isActive(String id) =>
      state.value
          ?.firstWhere((slot) => slot.id == id, orElse: _unknownSlot)
          .isActive ??
      true;

  static RefereeAvailableTimeSlot _unknownSlot() =>
      const RefereeAvailableTimeSlot(
        id: '',
        dow: 0,
        startMin: 0,
        endMin: 0,
        isActive: true,
      );
}
