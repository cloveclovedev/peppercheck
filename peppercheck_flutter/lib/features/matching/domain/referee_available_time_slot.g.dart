// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'referee_available_time_slot.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RefereeAvailableTimeSlot _$RefereeAvailableTimeSlotFromJson(
  Map<String, dynamic> json,
) => _RefereeAvailableTimeSlot(
  id: json['id'] as String,
  userId: json['user_id'] as String,
  dow: (json['dow'] as num).toInt(),
  startMin: (json['start_min'] as num).toInt(),
  endMin: (json['end_min'] as num).toInt(),
  isActive: json['is_active'] as bool,
  createdAt: json['created_at'] as String?,
  updatedAt: json['updated_at'] as String?,
);

Map<String, dynamic> _$RefereeAvailableTimeSlotToJson(
  _RefereeAvailableTimeSlot instance,
) => <String, dynamic>{
  'id': instance.id,
  'user_id': instance.userId,
  'dow': instance.dow,
  'start_min': instance.startMin,
  'end_min': instance.endMin,
  'is_active': instance.isActive,
  'created_at': instance.createdAt,
  'updated_at': instance.updatedAt,
};
