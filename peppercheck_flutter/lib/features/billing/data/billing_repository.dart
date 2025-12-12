import 'package:peppercheck_flutter/features/billing/domain/point_wallet.dart';
import 'package:peppercheck_flutter/features/billing/domain/subscription.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'billing_repository.g.dart';

@Riverpod(keepAlive: true)
BillingRepository billingRepository(Ref ref) {
  return BillingRepository(Supabase.instance.client);
}

class BillingRepository {
  final SupabaseClient _supabase;

  BillingRepository(this._supabase);

  Future<Subscription?> fetchSubscription() async {
    try {
      // Direct select from user_subscriptions table
      // RLS ensures we only get our own row
      final data = await _supabase
          .from('user_subscriptions')
          .select(
            'status, plan_id, provider, current_period_end, cancel_at_period_end',
          )
          .maybeSingle();

      if (data == null) {
        return null;
      }

      return Subscription.fromJson(data);
    } catch (_) {
      // In case of error or no data, rethrow or return null depending on policy
      // For now, rethrow to let controller handle it
      rethrow;
    }
  }

  Future<PointWallet> fetchPointWallet() async {
    try {
      final data = await _supabase
          .from('point_wallets')
          .select('balance')
          .maybeSingle();

      if (data == null) {
        // Default to asking DB or fallback?
        // If row doesn't exist, it might mean user setup is incomplete, or just 0.
        // For wallets, usually 0 is safe default if row missing (though row *should* exist).
        return const PointWallet(balance: 0);
      }
      return PointWallet.fromJson(data);
    } catch (_) {
      rethrow;
    }
  }
}
