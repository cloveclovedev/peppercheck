import 'package:peppercheck_flutter/features/payment_dashboard/domain/payment_summary.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'payment_summary_repository.g.dart';

@Riverpod(keepAlive: true)
PaymentSummaryRepository paymentSummaryRepository(Ref ref) {
  return PaymentSummaryRepository(Supabase.instance.client);
}

class PaymentSummaryRepository {
  final SupabaseClient _supabase;

  PaymentSummaryRepository(this._supabase);

  Future<PaymentSummary> fetchSummary() async {
    final data = await _supabase.rpc('get_payment_summary');
    return PaymentSummary.fromJson(data as Map<String, dynamic>);
  }
}
