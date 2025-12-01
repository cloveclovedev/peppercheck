// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payout_setup_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PayoutSetupStatus _$PayoutSetupStatusFromJson(Map<String, dynamic> json) =>
    _PayoutSetupStatus(
      chargesEnabled: json['charges_enabled'] as bool? ?? false,
      payoutsEnabled: json['payouts_enabled'] as bool? ?? false,
    );

Map<String, dynamic> _$PayoutSetupStatusToJson(_PayoutSetupStatus instance) =>
    <String, dynamic>{
      'charges_enabled': instance.chargesEnabled,
      'payouts_enabled': instance.payoutsEnabled,
    };
