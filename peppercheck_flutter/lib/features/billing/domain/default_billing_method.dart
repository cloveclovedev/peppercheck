// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'default_billing_method.freezed.dart';
part 'default_billing_method.g.dart';

@freezed
abstract class DefaultBillingMethod with _$DefaultBillingMethod {
  const factory DefaultBillingMethod({
    @JsonKey(name: 'pm_brand') String? brand,
    @JsonKey(name: 'pm_last4') String? last4,
    @JsonKey(name: 'pm_exp_month') int? expMonth,
    @JsonKey(name: 'pm_exp_year') int? expYear,
  }) = _DefaultBillingMethod;

  const DefaultBillingMethod._();

  factory DefaultBillingMethod.fromJson(Map<String, dynamic> json) =>
      _$DefaultBillingMethodFromJson(json);

  bool get hasPaymentMethod => last4 != null;
}
