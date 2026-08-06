import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/matching_repository.dart';
import '../domain/referee_blocked_date.dart';

part 'referee_blocked_dates_view_model.g.dart';

/// The signed-in referee's blocked calendar days.
@riverpod
class RefereeBlockedDatesViewModel extends _$RefereeBlockedDatesViewModel {
  @override
  FutureOr<List<RefereeBlockedDate>> build() =>
      ref.read(matchingRepositoryProvider).fetchBlockedDates();

  Future<void> addBlockedDate(
    DateTime startDate,
    DateTime endDate,
    String? reason,
  ) async {
    final repository = ref.read(matchingRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repository.createBlockedDate(
        startDate: startDate,
        endDate: endDate,
        reason: reason,
      );
      return repository.fetchBlockedDates();
    });
  }

  Future<void> editBlockedDate(
    String id,
    DateTime startDate,
    DateTime endDate,
    String? reason,
  ) async {
    final repository = ref.read(matchingRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repository.updateBlockedDate(
        id: id,
        startDate: startDate,
        endDate: endDate,
        reason: reason,
      );
      return repository.fetchBlockedDates();
    });
  }

  Future<void> removeBlockedDate(String id) async {
    final repository = ref.read(matchingRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repository.deleteBlockedDate(id);
      return repository.fetchBlockedDates();
    });
  }
}
