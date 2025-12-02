import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:peppercheck_flutter/features/currency/data/currency_repository.dart';
import 'package:peppercheck_flutter/features/currency/domain/currency.dart';
import 'package:peppercheck_flutter/features/payout/data/stripe_payout_repository.dart';
import 'package:peppercheck_flutter/features/payout/domain/reward_summary.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reward_summary_controller.freezed.dart';
part 'reward_summary_controller.g.dart';

@freezed
abstract class RewardSummaryState with _$RewardSummaryState {
  const factory RewardSummaryState({
    required RewardSummary summary,
    required Currency currency,
    @Default(false) bool isRequestingPayout,
  }) = _RewardSummaryState;
}

@riverpod
class RewardSummaryController extends _$RewardSummaryController {
  @override
  Future<RewardSummaryState> build() async {
    final repository = ref.watch(stripePayoutRepositoryProvider);
    final currencyRepository = ref.watch(currencyRepositoryProvider);

    final summary = await repository.fetchPayoutSummary();
    final currency = await currencyRepository.getCurrency(summary.currencyCode);

    return RewardSummaryState(summary: summary, currency: currency);
  }

  Future<void> requestPayout(int amountMinor) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncValue.data(currentState.copyWith(isRequestingPayout: true));

    try {
      final repository = ref.read(stripePayoutRepositoryProvider);
      await repository.requestPayout(
        amountMinor: amountMinor,
        currencyCode: currentState.summary.currencyCode,
      );

      // Refresh the summary after successful payout request
      ref.invalidateSelf();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
