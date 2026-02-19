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

  Future<void> confirmJudgement({
    required String judgementId,
    required bool isPositive,
    String? comment,
  }) async {
    try {
      await _client.rpc(
        'confirm_judgement_and_rate_referee',
        params: {
          'p_judgement_id': judgementId,
          'p_is_positive': isPositive,
          if (comment != null && comment.isNotEmpty) 'p_comment': comment,
        },
      );
    } catch (e, st) {
      _logger.e('confirmJudgement failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> confirmReviewTimeout({
    required String judgementId,
  }) async {
    try {
      await _client.rpc(
        'confirm_review_timeout',
        params: {
          'p_judgement_id': judgementId,
        },
      );
    } catch (e, st) {
      _logger.e('confirmReviewTimeout failed', error: e, stackTrace: st);
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
