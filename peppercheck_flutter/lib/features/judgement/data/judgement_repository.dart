import 'package:logger/logger.dart';
import 'package:peppercheck_flutter/app/app_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'judgement_repository.g.dart';

class JudgementRepository {
  final SupabaseClient _client;
  final Logger _logger;

  JudgementRepository(this._client, this._logger);

  Future<void> judgeEvidence({
    required String judgementId,
    required String status,
    required String comment,
  }) async {
    try {
      await _client.rpc(
        'judge_evidence',
        params: {
          'p_judgement_id': judgementId,
          'p_status': status,
          'p_comment': comment,
        },
      );
    } catch (e, st) {
      _logger.e('judgeEvidence failed', error: e, stackTrace: st);
      rethrow;
    }
  }
}

@Riverpod(keepAlive: true)
JudgementRepository judgementRepository(Ref ref) {
  return JudgementRepository(
    Supabase.instance.client,
    ref.watch(loggerProvider),
  );
}
