// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'referee_request_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RefereeRequestDto _$RefereeRequestDtoFromJson(Map<String, dynamic> json) =>
    _RefereeRequestDto(
      id: json['id'] as String,
      taskId: json['taskId'] as String,
      status: json['status'] as String,
      matchedRefereeId: json['matchedRefereeId'] as String?,
      respondedAt: json['respondedAt'] as String?,
      pointSource: json['pointSource'] as String?,
      isObligation: json['isObligation'] as bool? ?? false,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
      referee: json['referee'] == null
          ? null
          : PublicProfileDto.fromJson(json['referee'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$RefereeRequestDtoToJson(_RefereeRequestDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'taskId': instance.taskId,
      'status': instance.status,
      'matchedRefereeId': instance.matchedRefereeId,
      'respondedAt': instance.respondedAt,
      'pointSource': instance.pointSource,
      'isObligation': instance.isObligation,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
      'referee': instance.referee,
    };
