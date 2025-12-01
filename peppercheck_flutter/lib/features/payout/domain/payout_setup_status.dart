// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'payout_setup_status.freezed.dart';
part 'payout_setup_status.g.dart';

@freezed
abstract class PayoutSetupStatus with _$PayoutSetupStatus {
  const factory PayoutSetupStatus({
    @JsonKey(name: 'charges_enabled') @Default(false) bool chargesEnabled,
    @JsonKey(name: 'payouts_enabled') @Default(false) bool payoutsEnabled,
  }) = _PayoutSetupStatus;

  const PayoutSetupStatus._();

  factory PayoutSetupStatus.fromJson(Map<String, dynamic> json) =>
      _$PayoutSetupStatusFromJson(json);

  bool get isComplete => chargesEnabled && payoutsEnabled;
  bool get isInProgress => chargesEnabled && !payoutsEnabled;
  bool get isNotStarted => !chargesEnabled && !payoutsEnabled;
}
