import 'package:freezed_annotation/freezed_annotation.dart';

import '../../matching/domain/referee_request.dart';
import 'public_profile_dto.dart';

part 'referee_request_dto.freezed.dart';
part 'referee_request_dto.g.dart';

/// Mirrors a referee request as embedded in a task response (wire contract
/// §7.1). `referee` is populated only once the request is matched. Phase 4a
/// carries no judgement, so the domain's `judgement` stays null until 4c.
@freezed
abstract class RefereeRequestDto with _$RefereeRequestDto {
  const RefereeRequestDto._();

  const factory RefereeRequestDto({
    required String id,
    required String taskId,
    required String status,
    String? matchedRefereeId,
    String? respondedAt,
    String? pointSource,
    @Default(false) bool isObligation,
    required String createdAt,
    required String updatedAt,
    PublicProfileDto? referee,
  }) = _RefereeRequestDto;

  factory RefereeRequestDto.fromJson(Map<String, dynamic> json) =>
      _$RefereeRequestDtoFromJson(json);

  RefereeRequest toDomain() => RefereeRequest(
    id: id,
    taskId: taskId,
    status: status,
    matchedRefereeId: matchedRefereeId,
    respondedAt: respondedAt,
    pointSource: pointSource,
    isObligation: isObligation,
    createdAt: createdAt,
    updatedAt: updatedAt,
    referee: referee?.toDomain(),
  );
}
