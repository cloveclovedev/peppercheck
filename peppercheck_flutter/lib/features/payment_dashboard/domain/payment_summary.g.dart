// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PaymentSummary _$PaymentSummaryFromJson(Map<String, dynamic> json) =>
    _PaymentSummary(
      points: PointSummary.fromJson(json['points'] as Map<String, dynamic>),
      trialPoints: json['trial_points'] == null
          ? null
          : TrialPointSummary.fromJson(
              json['trial_points'] as Map<String, dynamic>,
            ),
      obligationsRemaining: (json['obligations_remaining'] as num).toInt(),
      rewards: json['rewards'] == null
          ? null
          : RewardSummary.fromJson(json['rewards'] as Map<String, dynamic>),
      recentPayout: json['recent_payout'] == null
          ? null
          : RecentPayout.fromJson(
              json['recent_payout'] as Map<String, dynamic>,
            ),
      totalEarnedMinor: (json['total_earned_minor'] as num).toInt(),
      totalEarnedCurrency: json['total_earned_currency'] as String?,
      nextPayoutDate: json['next_payout_date'] as String,
    );

Map<String, dynamic> _$PaymentSummaryToJson(_PaymentSummary instance) =>
    <String, dynamic>{
      'points': instance.points,
      'trial_points': instance.trialPoints,
      'obligations_remaining': instance.obligationsRemaining,
      'rewards': instance.rewards,
      'recent_payout': instance.recentPayout,
      'total_earned_minor': instance.totalEarnedMinor,
      'total_earned_currency': instance.totalEarnedCurrency,
      'next_payout_date': instance.nextPayoutDate,
    };

_PointSummary _$PointSummaryFromJson(Map<String, dynamic> json) =>
    _PointSummary(
      balance: (json['balance'] as num).toInt(),
      locked: (json['locked'] as num).toInt(),
      available: (json['available'] as num).toInt(),
    );

Map<String, dynamic> _$PointSummaryToJson(_PointSummary instance) =>
    <String, dynamic>{
      'balance': instance.balance,
      'locked': instance.locked,
      'available': instance.available,
    };

_TrialPointSummary _$TrialPointSummaryFromJson(Map<String, dynamic> json) =>
    _TrialPointSummary(
      balance: (json['balance'] as num).toInt(),
      locked: (json['locked'] as num).toInt(),
      available: (json['available'] as num).toInt(),
    );

Map<String, dynamic> _$TrialPointSummaryToJson(_TrialPointSummary instance) =>
    <String, dynamic>{
      'balance': instance.balance,
      'locked': instance.locked,
      'available': instance.available,
    };

_RewardSummary _$RewardSummaryFromJson(Map<String, dynamic> json) =>
    _RewardSummary(
      balance: (json['balance'] as num).toInt(),
      currencyCode: json['currency_code'] as String,
      currencyExponent: (json['currency_exponent'] as num).toInt(),
      amountMinor: (json['amount_minor'] as num).toInt(),
      ratePerPoint: (json['rate_per_point'] as num).toInt(),
    );

Map<String, dynamic> _$RewardSummaryToJson(_RewardSummary instance) =>
    <String, dynamic>{
      'balance': instance.balance,
      'currency_code': instance.currencyCode,
      'currency_exponent': instance.currencyExponent,
      'amount_minor': instance.amountMinor,
      'rate_per_point': instance.ratePerPoint,
    };

_RecentPayout _$RecentPayoutFromJson(Map<String, dynamic> json) =>
    _RecentPayout(
      amountMinor: (json['amount_minor'] as num).toInt(),
      currencyCode: json['currency_code'] as String,
      currencyExponent: (json['currency_exponent'] as num).toInt(),
      status: json['status'] as String,
      batchDate: json['batch_date'] as String,
    );

Map<String, dynamic> _$RecentPayoutToJson(_RecentPayout instance) =>
    <String, dynamic>{
      'amount_minor': instance.amountMinor,
      'currency_code': instance.currencyCode,
      'currency_exponent': instance.currencyExponent,
      'status': instance.status,
      'batch_date': instance.batchDate,
    };
