// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stripe_billing_setup_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_StripeBillingSetupSession _$StripeBillingSetupSessionFromJson(
  Map<String, dynamic> json,
) => _StripeBillingSetupSession(
  customerId: json['customerId'] as String,
  setupIntentClientSecret: json['setupIntentClientSecret'] as String,
  ephemeralKeySecret: json['ephemeralKeySecret'] as String,
);

Map<String, dynamic> _$StripeBillingSetupSessionToJson(
  _StripeBillingSetupSession instance,
) => <String, dynamic>{
  'customerId': instance.customerId,
  'setupIntentClientSecret': instance.setupIntentClientSecret,
  'ephemeralKeySecret': instance.ephemeralKeySecret,
};
