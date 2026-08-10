// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'referee_blocked_date_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RefereeBlockedDateDto _$RefereeBlockedDateDtoFromJson(
  Map<String, dynamic> json,
) => _RefereeBlockedDateDto(
  id: json['id'] as String,
  startDate: json['startDate'] as String,
  endDate: json['endDate'] as String,
  reason: json['reason'] as String?,
);

Map<String, dynamic> _$RefereeBlockedDateDtoToJson(
  _RefereeBlockedDateDto instance,
) => <String, dynamic>{
  'id': instance.id,
  'startDate': instance.startDate,
  'endDate': instance.endDate,
  'reason': instance.reason,
};
