import 'package:freezed_annotation/freezed_annotation.dart';

part 'subscription.freezed.dart';
part 'subscription.g.dart';

// ignore_for_file: invalid_annotation_target

@freezed
abstract class Subscription with _$Subscription {
  const factory Subscription({
    required String status,
    @JsonKey(name: 'plan_id') String? planId,
    String? provider,
    @JsonKey(name: 'current_period_end') String? currentPeriodEnd,
    @JsonKey(name: 'cancel_at_period_end') bool? cancelAtPeriodEnd,
  }) = _Subscription;

  factory Subscription.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionFromJson(json);
}
