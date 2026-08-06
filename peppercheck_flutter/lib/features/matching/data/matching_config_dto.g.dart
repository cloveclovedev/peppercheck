// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'matching_config_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MatchingConfigDto _$MatchingConfigDtoFromJson(Map<String, dynamic> json) =>
    _MatchingConfigDto(
      openDeadlineHours: (json['openDeadlineHours'] as num).toInt(),
      cancelDeadlineHours: (json['cancelDeadlineHours'] as num).toInt(),
      rematchCutoffHours: (json['rematchCutoffHours'] as num).toInt(),
      maxRefereesPerTask: (json['maxRefereesPerTask'] as num).toInt(),
      matchingPointCost: (json['matchingPointCost'] as num).toInt(),
    );

Map<String, dynamic> _$MatchingConfigDtoToJson(_MatchingConfigDto instance) =>
    <String, dynamic>{
      'openDeadlineHours': instance.openDeadlineHours,
      'cancelDeadlineHours': instance.cancelDeadlineHours,
      'rematchCutoffHours': instance.rematchCutoffHours,
      'maxRefereesPerTask': instance.maxRefereesPerTask,
      'matchingPointCost': instance.matchingPointCost,
    };
