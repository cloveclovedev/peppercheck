// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'referee_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RefereeRequest _$RefereeRequestFromJson(Map<String, dynamic> json) =>
    _RefereeRequest(
      id: json['id'] as String,
      taskId: json['task_id'] as String,
      matchingStrategy: json['matching_strategy'] as String,
      preferredRefereeId: json['preferred_referee_id'] as String?,
      status: json['status'] as String,
      matchedRefereeId: json['matched_referee_id'] as String?,
      respondedAt: json['responded_at'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String?,
      judgement: json['judgement'] == null
          ? null
          : Judgement.fromJson(json['judgement'] as Map<String, dynamic>),
      referee: json['referee'] == null
          ? null
          : Profile.fromJson(json['referee'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$RefereeRequestToJson(_RefereeRequest instance) =>
    <String, dynamic>{
      'id': instance.id,
      'task_id': instance.taskId,
      'matching_strategy': instance.matchingStrategy,
      'preferred_referee_id': instance.preferredRefereeId,
      'status': instance.status,
      'matched_referee_id': instance.matchedRefereeId,
      'responded_at': instance.respondedAt,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'judgement': instance.judgement,
      'referee': instance.referee,
    };
