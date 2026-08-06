import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_client_provider.dart';
import '../../../core/network/paginated_fetch.dart';
import '../../task/data/task_dto.dart';
import '../../task/domain/task.dart';
import '../domain/matching_config.dart';
import '../domain/referee_available_time_slot.dart';
import '../domain/referee_blocked_date.dart';
import 'matching_config_dto.dart';
import 'referee_blocked_date_dto.dart';
import 'referee_time_slot_dto.dart';

part 'matching_repository.g.dart';

@Riverpod(keepAlive: true)
MatchingRepository matchingRepository(Ref ref) {
  return MatchingRepository(ref.watch(apiClientProvider));
}

/// Matching over the Go API: the public config, the caller's referee
/// assignments, cancelling an assignment, and the caller's own availability.
/// Every endpoint is scoped to the bearer, so nothing here takes a user id.
class MatchingRepository {
  MatchingRepository(this._api);

  final ApiClient _api;

  /// The server-owned deadlines and limits. Cached by [matchingConfigProvider].
  Future<MatchingConfig> fetchConfig() async {
    final json = await _api.getJson('/api/v1/matching/config');
    return MatchingConfigDto.fromJson(json).toDomain();
  }

  /// Tasks the caller referees. Each task embeds the caller's referee request
  /// and the tasker's public profile. Bounded active list, so every cursor page
  /// is followed.
  Future<List<Task>> fetchMyAssignments() async {
    final pages = await fetchAllPages(
      _api,
      '/api/v1/me/assignments',
      itemsKey: 'assignments',
    );
    return pages.map((json) => TaskDto.fromJson(json).toDomain()).toList();
  }

  /// Cancels the caller's accepted assignment; the server re-opens a pending
  /// request for the task and returns the updated task.
  Future<Task> cancelAssignment(String requestId) async {
    final json = await _api.postJson(
      '/api/v1/referee-requests/$requestId/cancel',
    );
    return TaskDto.fromJson(json).toDomain();
  }

  static const _timeSlotsPath = '/api/v1/me/availability/time-slots';
  static const _blockedDatesPath = '/api/v1/me/availability/blocked-dates';

  Future<List<RefereeAvailableTimeSlot>> fetchTimeSlots() async {
    final json = await _api.getJson(_timeSlotsPath);
    return _slots(json);
  }

  Future<RefereeAvailableTimeSlot> createTimeSlot({
    required int dow,
    required int startMin,
    required int endMin,
    bool isActive = true,
  }) async {
    final json = await _api.postJson(
      _timeSlotsPath,
      body: _slotBody(
        dow: dow,
        startMin: startMin,
        endMin: endMin,
        isActive: isActive,
      ),
    );
    return RefereeTimeSlotDto.fromJson(json).toDomain();
  }

  Future<RefereeAvailableTimeSlot> updateTimeSlot({
    required String id,
    required int dow,
    required int startMin,
    required int endMin,
    bool isActive = true,
  }) async {
    final json = await _api.putJsonObject(
      '$_timeSlotsPath/$id',
      body: _slotBody(
        dow: dow,
        startMin: startMin,
        endMin: endMin,
        isActive: isActive,
      ),
    );
    return RefereeTimeSlotDto.fromJson(json).toDomain();
  }

  Future<void> deleteTimeSlot(String id) =>
      _api.deleteJson('$_timeSlotsPath/$id');

  Future<List<RefereeBlockedDate>> fetchBlockedDates() async {
    final json = await _api.getJson(_blockedDatesPath);
    return _blockedDates(json);
  }

  Future<RefereeBlockedDate> createBlockedDate({
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
  }) async {
    final json = await _api.postJson(
      _blockedDatesPath,
      body: _blockedDateBody(
        startDate: startDate,
        endDate: endDate,
        reason: reason,
      ),
    );
    return RefereeBlockedDateDto.fromJson(json).toDomain();
  }

  Future<RefereeBlockedDate> updateBlockedDate({
    required String id,
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
  }) async {
    final json = await _api.putJsonObject(
      '$_blockedDatesPath/$id',
      body: _blockedDateBody(
        startDate: startDate,
        endDate: endDate,
        reason: reason,
      ),
    );
    return RefereeBlockedDateDto.fromJson(json).toDomain();
  }

  Future<void> deleteBlockedDate(String id) =>
      _api.deleteJson('$_blockedDatesPath/$id');

  List<RefereeAvailableTimeSlot> _slots(Map<String, dynamic> json) {
    final items = json['timeSlots'];
    if (items is! List) return const [];
    return items
        .map(
          (item) => RefereeTimeSlotDto.fromJson(
            Map<String, dynamic>.from(item as Map),
          ).toDomain(),
        )
        .toList();
  }

  List<RefereeBlockedDate> _blockedDates(Map<String, dynamic> json) {
    final items = json['blockedDates'];
    if (items is! List) return const [];
    return items
        .map(
          (item) => RefereeBlockedDateDto.fromJson(
            Map<String, dynamic>.from(item as Map),
          ).toDomain(),
        )
        .toList();
  }

  Map<String, dynamic> _slotBody({
    required int dow,
    required int startMin,
    required int endMin,
    required bool isActive,
  }) => {
    'dow': dow,
    'startMin': startMin,
    'endMin': endMin,
    'isActive': isActive,
  };

  /// Blocked dates are calendar days, so only the date part goes on the wire.
  Map<String, dynamic> _blockedDateBody({
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
  }) => {
    'startDate': _day(startDate),
    'endDate': _day(endDate),
    'reason': reason,
  };

  static String _day(DateTime date) => date.toIso8601String().substring(0, 10);
}
