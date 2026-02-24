import 'package:peppercheck_flutter/features/matching/domain/referee_available_time_slot.dart';
import 'package:peppercheck_flutter/features/matching/domain/referee_blocked_date.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'matching_repository.g.dart';

@Riverpod(keepAlive: true)
MatchingRepository matchingRepository(Ref ref) {
  return MatchingRepository(Supabase.instance.client);
}

class MatchingRepository {
  final SupabaseClient _supabase;

  MatchingRepository(this._supabase);

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
    await _supabase.rpc(
      'delete_referee_blocked_date',
      params: {'p_id': id},
    );
  }

  Future<Map<String, dynamic>> cancelRefereeAssignment(
    String requestId,
  ) async {
    final response = await _supabase.rpc(
      'cancel_referee_assignment',
      params: {'p_request_id': requestId},
    );
    return response as Map<String, dynamic>;
  }
}
