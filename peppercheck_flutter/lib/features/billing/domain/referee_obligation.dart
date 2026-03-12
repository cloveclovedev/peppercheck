import 'package:freezed_annotation/freezed_annotation.dart';

part 'referee_obligation.freezed.dart';
part 'referee_obligation.g.dart';

@freezed
abstract class RefereeObligation with _$RefereeObligation {
  const factory RefereeObligation({
    required String id,
    required String status,
    @JsonKey(name: 'source_request_id') required String sourceRequestId,
    @JsonKey(name: 'fulfill_request_id') String? fulfillRequestId,
    @JsonKey(name: 'created_at') required String createdAt,
    @JsonKey(name: 'fulfilled_at') String? fulfilledAt,
  }) = _RefereeObligation;

  factory RefereeObligation.fromJson(Map<String, dynamic> json) =>
      _$RefereeObligationFromJson(json);
}
