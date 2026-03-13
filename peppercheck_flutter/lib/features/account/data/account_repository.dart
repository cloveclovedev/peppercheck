import 'package:logger/logger.dart';
import 'package:peppercheck_flutter/app/app_logger.dart';
import 'package:peppercheck_flutter/features/account/domain/account_deletable_status.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'account_repository.g.dart';

class AccountRepository {
  final SupabaseClient _client;
  final Logger _logger;

  AccountRepository(this._client, this._logger);

  Future<AccountDeletableStatus> checkDeletable() async {
    try {
      final result = await _client.rpc('check_account_deletable');
      return AccountDeletableStatus.fromJson(result as Map<String, dynamic>);
    } catch (e, st) {
      _logger.e('checkDeletable failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> deleteAccount({bool force = false}) async {
    try {
      final response = await _client.functions.invoke(
        'delete-account',
        body: {'force': force},
      );

      final data = response.data;
      if (data is Map && data['error'] != null) {
        final error = data['error'] as String;
        if (error == 'not_deletable') {
          throw AccountNotDeletableException(
            List<String>.from(data['reasons'] as List),
          );
        }
        if (error == 'payout_failed') {
          throw PayoutFailedException(
            data['reward_balance'] as int,
            data['message'] as String,
          );
        }
        throw Exception(error);
      }
    } catch (e, st) {
      if (e is AccountNotDeletableException || e is PayoutFailedException) {
        rethrow;
      }
      _logger.e('deleteAccount failed', error: e, stackTrace: st);
      rethrow;
    }
  }
}

class AccountNotDeletableException implements Exception {
  final List<String> reasons;
  AccountNotDeletableException(this.reasons);
}

class PayoutFailedException implements Exception {
  final int rewardBalance;
  final String message;
  PayoutFailedException(this.rewardBalance, this.message);
}

@Riverpod(keepAlive: true)
AccountRepository accountRepository(Ref ref) {
  return AccountRepository(
    Supabase.instance.client,
    ref.watch(loggerProvider),
  );
}
