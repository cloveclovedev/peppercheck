import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:peppercheck_flutter/features/judgement/domain/judgement.dart';
import 'package:peppercheck_flutter/features/matching/domain/public_profile.dart';

part 'referee_request.freezed.dart';

@freezed
abstract class RefereeRequest with _$RefereeRequest {
  const factory RefereeRequest({
    required String id,
    required String taskId,
    required String status,
    String? matchedRefereeId,
    String? respondedAt,
    required String createdAt,
    String? updatedAt,
    String? pointSource,
    @Default(false) bool isObligation,

    // Aggregated fields
    Judgement? judgement,
    PublicProfile? referee,
  }) = _RefereeRequest;
}
