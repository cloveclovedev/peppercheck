// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'payment_summary.freezed.dart';
part 'payment_summary.g.dart';

@freezed
abstract class PaymentSummary with _$PaymentSummary {
  const factory PaymentSummary({
    required PointSummary points,
    @JsonKey(name: 'trial_points') TrialPointSummary? trialPoints,
    @JsonKey(name: 'obligations_remaining') required int obligationsRemaining,
    RewardSummary? rewards,
    @JsonKey(name: 'recent_payout') RecentPayout? recentPayout,
    @JsonKey(name: 'total_earned_minor') required int totalEarnedMinor,
    @JsonKey(name: 'total_earned_currency') String? totalEarnedCurrency,
    @JsonKey(name: 'next_payout_date') required String nextPayoutDate,
  }) = _PaymentSummary;

  factory PaymentSummary.fromJson(Map<String, dynamic> json) =>
      _$PaymentSummaryFromJson(json);
}

@freezed
abstract class PointSummary with _$PointSummary {
  const factory PointSummary({
    required int balance,
    required int locked,
    required int available,
  }) = _PointSummary;

  factory PointSummary.fromJson(Map<String, dynamic> json) =>
      _$PointSummaryFromJson(json);
}

@freezed
abstract class TrialPointSummary with _$TrialPointSummary {
  const factory TrialPointSummary({
    required int balance,
    required int locked,
    required int available,
  }) = _TrialPointSummary;

  factory TrialPointSummary.fromJson(Map<String, dynamic> json) =>
      _$TrialPointSummaryFromJson(json);
}

@freezed
abstract class RewardSummary with _$RewardSummary {
  const factory RewardSummary({
    required int balance,
    @JsonKey(name: 'currency_code') required String currencyCode,
    @JsonKey(name: 'currency_exponent') required int currencyExponent,
    @JsonKey(name: 'amount_minor') required int amountMinor,
    @JsonKey(name: 'rate_per_point') required int ratePerPoint,
  }) = _RewardSummary;

  factory RewardSummary.fromJson(Map<String, dynamic> json) =>
      _$RewardSummaryFromJson(json);
}

@freezed
abstract class RecentPayout with _$RecentPayout {
  const factory RecentPayout({
    @JsonKey(name: 'amount_minor') required int amountMinor,
    @JsonKey(name: 'currency_code') required String currencyCode,
    @JsonKey(name: 'currency_exponent') required int currencyExponent,
    required String status,
    @JsonKey(name: 'batch_date') required String batchDate,
  }) = _RecentPayout;

  factory RecentPayout.fromJson(Map<String, dynamic> json) =>
      _$RecentPayoutFromJson(json);
}
