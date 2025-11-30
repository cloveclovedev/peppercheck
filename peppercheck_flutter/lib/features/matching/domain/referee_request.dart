import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:peppercheck_flutter/features/judgement/domain/judgement.dart';
import 'package:peppercheck_flutter/features/profile/domain/profile.dart';

part 'referee_request.freezed.dart';
part 'referee_request.g.dart';

// ignore_for_file: invalid_annotation_target

@freezed
abstract class RefereeRequest with _$RefereeRequest {
  const factory RefereeRequest({
    required String id,
    @JsonKey(name: 'task_id') required String taskId,
    @JsonKey(name: 'matching_strategy') required String matchingStrategy,
    @JsonKey(name: 'preferred_referee_id') String? preferredRefereeId,
    required String status,
    @JsonKey(name: 'matched_referee_id') String? matchedRefereeId,
    @JsonKey(name: 'responded_at') String? respondedAt,
    @JsonKey(name: 'created_at') required String createdAt,
    @JsonKey(name: 'updated_at') String? updatedAt,

    // Aggregated fields
    Judgement? judgement,
    Profile? referee,
  }) = _RefereeRequest;

  factory RefereeRequest.fromJson(Map<String, dynamic> json) =>
      _$RefereeRequestFromJson(json);
}
