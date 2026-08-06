import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_client_provider.dart';
import '../../../core/network/paginated_fetch.dart';
import '../../task/data/task_dto.dart';
import '../../task/domain/task.dart';
import '../domain/matching_config.dart';
import '../domain/referee_available_time_slot.dart';
import '../domain/referee_blocked_date.dart';
import 'matching_config_dto.dart';

part 'matching_repository.g.dart';

@Riverpod(keepAlive: true)
MatchingRepository matchingRepository(Ref ref) {
  return MatchingRepository(
    ref.watch(apiClientProvider),
    Supabase.instance.client,
  );
}

/// Matching over the Go API: the public config, the caller's referee
/// assignments, cancelling an assignment, and (from the availability step on)
/// the caller's availability.
///
/// TRANSITIONAL: availability CRUD still runs through Supabase RPCs until it
/// moves to the Go API later in this pull request; the Supabase client goes
/// away with it.
class MatchingRepository {
  MatchingRepository(this._api, this._supabase);

  final ApiClient _api;
  final SupabaseClient _supabase;

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

  Future<List<RefereeAvailableTimeSlot>> getRefereeAvailableTimeSlots(
    String userId,
  ) async {
    final response = await _supabase
        .from('referee_available_time_slots')
        .select()
        .eq('user_id', userId)
        // TODO: Future enhancement - Fetch both active/inactive slots.
        // Currently only fetching active slots. Ideally, we should fetch all and
        // allow users to toggle is_active status via UI (e.g. switch/radio).
        // Inactive slots should be displayed as grayed out.
        .eq('is_active', true)
        .order('dow', ascending: true)
        .order('start_min', ascending: true);

    return (response as List)
        .map((e) => RefereeAvailableTimeSlot.fromJson(e))
        .toList();
  }

  Future<String> createRefereeAvailableTimeSlot({
    required int dow,
    required int startMin,
    required int endMin,
  }) async {
    final response = await _supabase.rpc<String>(
      'create_referee_available_time_slot',
      params: {'p_dow': dow, 'p_start_min': startMin, 'p_end_min': endMin},
    );
    return response;
  }

  Future<void> updateRefereeAvailableTimeSlot({
    required String id,
    required int dow,
    required int startMin,
    required int endMin,
  }) async {
    await _supabase.rpc(
      'update_referee_available_time_slot',
      params: {
        'p_id': id,
        'p_dow': dow,
        'p_start_min': startMin,
        'p_end_min': endMin,
      },
    );
  }

  Future<void> deleteRefereeAvailableTimeSlot(String id) async {
    await _supabase.rpc(
      'delete_referee_available_time_slot',
      params: {'p_id': id},
    );
  }

  Future<List<RefereeBlockedDate>> getRefereeBlockedDates() async {
    final response = await _supabase
        .from('referee_blocked_dates')
        .select()
        .order('start_date', ascending: true);

    return (response as List)
        .map((e) => RefereeBlockedDate.fromJson(e))
        .toList();
  }

  Future<String> createRefereeBlockedDate({
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
  }) async {
    final response = await _supabase.rpc<String>(
      'create_referee_blocked_date',
      params: {
        'p_start_date': startDate.toIso8601String().substring(0, 10),
        'p_end_date': endDate.toIso8601String().substring(0, 10),
        'p_reason': reason,
      },
    );
    return response;
  }

  Future<void> updateRefereeBlockedDate({
    required String id,
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
  }) async {
    await _supabase.rpc(
      'update_referee_blocked_date',
      params: {
        'p_id': id,
        'p_start_date': startDate.toIso8601String().substring(0, 10),
        'p_end_date': endDate.toIso8601String().substring(0, 10),
        'p_reason': reason,
      },
    );
  }

  Future<void> deleteRefereeBlockedDate(String id) async {
    await _supabase.rpc('delete_referee_blocked_date', params: {'p_id': id});
  }
}
