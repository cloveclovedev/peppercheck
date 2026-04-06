import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'report_repository.g.dart';

@riverpod
ReportRepository reportRepository(Ref ref) {
  return ReportRepository(Supabase.instance.client);
}

class ReportRepository {
  final SupabaseClient _client;

  ReportRepository(this._client);

  Future<void> submitReport({
    required String taskId,
    required String reporterRole,
    required String contentType,
    String? contentId,
    required String reason,
    String? detail,
  }) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('reports').insert({
      'reporter_id': userId,
      'task_id': taskId,
      'reporter_role': reporterRole,
      'content_type': contentType,
      if (contentId != null) 'content_id': contentId,
      'reason': reason,
      if (detail != null) 'detail': detail,
    });
  }

  Future<bool> hasReported(String taskId) async {
    final userId = _client.auth.currentUser!.id;
    final result = await _client
        .from('reports')
        .select('id')
        .eq('reporter_id', userId)
        .eq('task_id', taskId)
        .maybeSingle();
    return result != null;
  }
}
