// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'referee_time_slot_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RefereeTimeSlotDto _$RefereeTimeSlotDtoFromJson(Map<String, dynamic> json) =>
    _RefereeTimeSlotDto(
      id: json['id'] as String,
      dow: (json['dow'] as num).toInt(),
      startMin: (json['startMin'] as num).toInt(),
      endMin: (json['endMin'] as num).toInt(),
      isActive: json['isActive'] as bool,
    );

Map<String, dynamic> _$RefereeTimeSlotDtoToJson(_RefereeTimeSlotDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'dow': instance.dow,
      'startMin': instance.startMin,
      'endMin': instance.endMin,
      'isActive': instance.isActive,
    };
