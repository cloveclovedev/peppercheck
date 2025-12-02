import 'package:freezed_annotation/freezed_annotation.dart';

part 'payout_request_response.freezed.dart';
part 'payout_request_response.g.dart';

@freezed
abstract class PayoutRequestResponse with _$PayoutRequestResponse {
  const factory PayoutRequestResponse({
    required String id,
    required String status,
  }) = _PayoutRequestResponse;

  factory PayoutRequestResponse.fromJson(Map<String, dynamic> json) =>
      _$PayoutRequestResponseFromJson(json);
}
