// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Subscription _$SubscriptionFromJson(Map<String, dynamic> json) =>
    _Subscription(
      status: json['status'] as String,
      planId: json['plan_id'] as String?,
      provider: json['provider'] as String?,
      currentPeriodEnd: json['current_period_end'] as String?,
      cancelAtPeriodEnd: json['cancel_at_period_end'] as bool?,
    );

Map<String, dynamic> _$SubscriptionToJson(_Subscription instance) =>
    <String, dynamic>{
      'status': instance.status,
      'plan_id': instance.planId,
      'provider': instance.provider,
      'current_period_end': instance.currentPeriodEnd,
      'cancel_at_period_end': instance.cancelAtPeriodEnd,
    };
