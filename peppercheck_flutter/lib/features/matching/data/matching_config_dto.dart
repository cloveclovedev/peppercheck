import 'package:freezed_annotation/freezed_annotation.dart';

import '../domain/matching_config.dart';

part 'matching_config_dto.freezed.dart';
part 'matching_config_dto.g.dart';

/// Mirrors the `GET /api/v1/matching/config` response (wire contract §7.1).
@freezed
abstract class MatchingConfigDto with _$MatchingConfigDto {
  const MatchingConfigDto._();

  const factory MatchingConfigDto({
    required int openDeadlineHours,
    required int cancelDeadlineHours,
    required int rematchCutoffHours,
    required int maxRefereesPerTask,
    required int matchingPointCost,
  }) = _MatchingConfigDto;

  factory MatchingConfigDto.fromJson(Map<String, dynamic> json) =>
      _$MatchingConfigDtoFromJson(json);

  MatchingConfig toDomain() => MatchingConfig(
    openDeadlineHours: openDeadlineHours,
    cancelDeadlineHours: cancelDeadlineHours,
    rematchCutoffHours: rematchCutoffHours,
    maxRefereesPerTask: maxRefereesPerTask,
    matchingPointCost: matchingPointCost,
  );
}
