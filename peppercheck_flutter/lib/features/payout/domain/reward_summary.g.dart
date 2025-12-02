// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reward_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RewardSummary _$RewardSummaryFromJson(Map<String, dynamic> json) =>
    _RewardSummary(
      availableMinor: (json['available_minor'] as num).toInt(),
      pendingMinor: (json['pending_minor'] as num).toInt(),
      incomingPendingMinor: (json['incoming_pending_minor'] as num).toInt(),
      currencyCode: json['currency_code'] as String,
    );

Map<String, dynamic> _$RewardSummaryToJson(_RewardSummary instance) =>
    <String, dynamic>{
      'available_minor': instance.availableMinor,
      'pending_minor': instance.pendingMinor,
      'incoming_pending_minor': instance.incomingPendingMinor,
      'currency_code': instance.currencyCode,
    };
