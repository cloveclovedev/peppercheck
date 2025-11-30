// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'default_billing_method.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DefaultBillingMethod _$DefaultBillingMethodFromJson(
  Map<String, dynamic> json,
) => _DefaultBillingMethod(
  brand: json['pm_brand'] as String?,
  last4: json['pm_last4'] as String?,
  expMonth: (json['pm_exp_month'] as num?)?.toInt(),
  expYear: (json['pm_exp_year'] as num?)?.toInt(),
);

Map<String, dynamic> _$DefaultBillingMethodToJson(
  _DefaultBillingMethod instance,
) => <String, dynamic>{
  'pm_brand': instance.brand,
  'pm_last4': instance.last4,
  'pm_exp_month': instance.expMonth,
  'pm_exp_year': instance.expYear,
};
