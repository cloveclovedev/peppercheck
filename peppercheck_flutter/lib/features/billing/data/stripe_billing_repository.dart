import 'package:logger/logger.dart';
import 'package:peppercheck_flutter/features/billing/domain/default_billing_method.dart';
import 'package:peppercheck_flutter/features/billing/domain/stripe_billing_setup_session.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'stripe_billing_repository.g.dart';

@Riverpod(keepAlive: true)
StripeBillingRepository stripeBillingRepository(Ref ref) {
  return StripeBillingRepository(Supabase.instance.client);
}

class StripeBillingRepository {
  final SupabaseClient _supabase;
  final _logger = Logger();

  StripeBillingRepository(this._supabase);

  Future<StripeBillingSetupSession> createBillingSetupSession() async {
    try {
      final response = await _supabase.functions.invoke('billing-setup');

      // The response.data is already a Map<String, dynamic> if the function returns JSON
      final data = response.data as Map<String, dynamic>;

      return StripeBillingSetupSession.fromJson(data);
    } catch (e, stack) {
      _logger.e(
        'Failed to create billing setup session',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<DefaultBillingMethod?> fetchDefaultBillingMethod() async {
    try {
      final data = await _supabase
          .from('stripe_accounts')
          .select('pm_brand, pm_last4, pm_exp_month, pm_exp_year')
          .single();
      return DefaultBillingMethod.fromJson(data);
    } on PostgrestException catch (e) {
      // If no row found or other error, return null or rethrow
      // Assuming 1:1 relation, if no row, user has no account?
      // User said "stripe account itself exists", so maybe just fields are null.
      // But if single() fails, it throws.
      // Let's assume it might throw if row missing, return null.
      if (e.code == 'PGRST116') {
        // JSON object requested, multiple (or no) rows returned
        return null;
      }
      _logger.e(
        'Failed to fetch default billing method (PostgrestException)',
        error: e,
      );
      rethrow;
    } catch (e, stack) {
      _logger.e(
        'Failed to fetch default billing method',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }
}
