// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'referee_blocked_date.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RefereeBlockedDate _$RefereeBlockedDateFromJson(Map<String, dynamic> json) =>
    _RefereeBlockedDate(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      reason: json['reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$RefereeBlockedDateToJson(_RefereeBlockedDate instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'start_date': instance.startDate.toIso8601String(),
      'end_date': instance.endDate.toIso8601String(),
      'reason': instance.reason,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };
