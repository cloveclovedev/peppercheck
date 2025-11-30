// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'stripe_billing_setup_session.freezed.dart';
part 'stripe_billing_setup_session.g.dart';

@freezed
abstract class StripeBillingSetupSession with _$StripeBillingSetupSession {
  const factory StripeBillingSetupSession({
    @JsonKey(name: 'customerId') required String customerId,
    @JsonKey(name: 'setupIntentClientSecret')
    required String setupIntentClientSecret,
    @JsonKey(name: 'ephemeralKeySecret') required String ephemeralKeySecret,
  }) = _StripeBillingSetupSession;

  factory StripeBillingSetupSession.fromJson(Map<String, dynamic> json) =>
      _$StripeBillingSetupSessionFromJson(json);
}
