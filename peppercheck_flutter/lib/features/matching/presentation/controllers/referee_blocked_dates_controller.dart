import 'package:peppercheck_flutter/features/matching/data/matching_repository.dart';
import 'package:peppercheck_flutter/features/matching/domain/referee_blocked_date.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'referee_blocked_dates_controller.g.dart';

@riverpod
class RefereeBlockedDatesController extends _$RefereeBlockedDatesController {
  @override
  FutureOr<List<RefereeBlockedDate>> build() async {
    return ref.read(matchingRepositoryProvider).getRefereeBlockedDates();
  }

  Future<void> addBlockedDate(
    DateTime startDate,
    DateTime endDate,
    String? reason,
  ) async {
    final repository = ref.read(matchingRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repository.createRefereeBlockedDate(
        startDate: startDate,
        endDate: endDate,
        reason: reason,
      );
      return repository.getRefereeBlockedDates();
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
      await repository.updateRefereeBlockedDate(
        id: id,
        startDate: startDate,
        endDate: endDate,
        reason: reason,
      );
      return repository.getRefereeBlockedDates();
    });
  }

  Future<void> removeBlockedDate(String id) async {
    final repository = ref.read(matchingRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repository.deleteRefereeBlockedDate(id);
      return repository.getRefereeBlockedDates();
    });
  }
}
