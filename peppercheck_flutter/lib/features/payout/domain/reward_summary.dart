// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'reward_summary.freezed.dart';
part 'reward_summary.g.dart';

@freezed
abstract class RewardSummary with _$RewardSummary {
  const factory RewardSummary({
    @JsonKey(name: 'available_minor') required int availableMinor,
    @JsonKey(name: 'pending_minor') required int pendingMinor,
    @JsonKey(name: 'incoming_pending_minor') required int incomingPendingMinor,
    @JsonKey(name: 'currency_code') required String currencyCode,
  }) = _RewardSummary;

  factory RewardSummary.fromJson(Map<String, dynamic> json) =>
      _$RewardSummaryFromJson(json);
}
