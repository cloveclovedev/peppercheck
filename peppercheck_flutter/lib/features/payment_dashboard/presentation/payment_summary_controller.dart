import 'package:peppercheck_flutter/features/payment_dashboard/data/payment_summary_repository.dart';
import 'package:peppercheck_flutter/features/payment_dashboard/domain/payment_summary.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'payment_summary_controller.g.dart';

@riverpod
class PaymentSummaryController extends _$PaymentSummaryController {
  @override
  Future<PaymentSummary> build() async {
    final repository = ref.watch(paymentSummaryRepositoryProvider);
    return repository.fetchSummary();
  }
}
