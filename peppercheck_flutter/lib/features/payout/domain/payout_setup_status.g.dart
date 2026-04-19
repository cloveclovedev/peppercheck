// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payout_setup_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PayoutSetupStatus _$PayoutSetupStatusFromJson(Map<String, dynamic> json) =>
    _PayoutSetupStatus(
      chargesEnabled: json['charges_enabled'] as bool? ?? false,
      payoutsEnabled: json['payouts_enabled'] as bool? ?? false,
      currentlyDue:
          (json['currentlyDue'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      pendingVerification:
          (json['pendingVerification'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$PayoutSetupStatusToJson(_PayoutSetupStatus instance) =>
    <String, dynamic>{
      'charges_enabled': instance.chargesEnabled,
      'payouts_enabled': instance.payoutsEnabled,
      'currentlyDue': instance.currentlyDue,
      'pendingVerification': instance.pendingVerification,
    };
