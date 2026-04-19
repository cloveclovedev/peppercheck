import 'package:logger/logger.dart';
import 'package:peppercheck_flutter/features/payout/domain/payout_request_response.dart';
import 'package:peppercheck_flutter/features/payout/domain/payout_setup_status.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'stripe_payout_repository.g.dart';

@Riverpod(keepAlive: true)
StripePayoutRepository stripePayoutRepository(Ref ref) {
  return StripePayoutRepository(Supabase.instance.client);
}

class StripePayoutRepository {
  final SupabaseClient _supabase;
  final _logger = Logger();

  StripePayoutRepository(this._supabase);

  Future<PayoutSetupStatus> fetchPayoutSetupStatus() async {
    try {
      final data = await _supabase
          .from('stripe_accounts')
          .select('charges_enabled, payouts_enabled, connect_requirements')
          .maybeSingle();

      if (data == null) {
        return const PayoutSetupStatus();
      }

      final requirements =
          data['connect_requirements'] as Map<String, dynamic>?;
      final currentlyDue =
          (requirements?['currently_due'] as List?)?.cast<String>() ?? [];
      final pendingVerification =
          (requirements?['pending_verification'] as List?)?.cast<String>() ??
          [];

      return PayoutSetupStatus(
        chargesEnabled: data['charges_enabled'] as bool? ?? false,
        payoutsEnabled: data['payouts_enabled'] as bool? ?? false,
        currentlyDue: currentlyDue,
        pendingVerification: pendingVerification,
      );
    } catch (e, stack) {
      _logger.e(
        'Failed to fetch payout setup status',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<String> createPayoutSetupSession() async {
    try {
      final response = await _supabase.functions.invoke('payout-setup');
      final data = response.data as Map<String, dynamic>;
      return data['url'] as String;
    } catch (e, stack) {
      _logger.e(
        'Failed to create payout setup session',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<PayoutRequestResponse> requestPayout({
    required int amountMinor,
    required String currencyCode,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'payout-request',
        body: {'amount_minor': amountMinor, 'currency_code': currencyCode},
      );
      final data = response.data as Map<String, dynamic>;
      return PayoutRequestResponse.fromJson(data);
    } catch (e, stack) {
      _logger.e('Failed to request payout', error: e, stackTrace: stack);
      rethrow;
    }
  }
}
