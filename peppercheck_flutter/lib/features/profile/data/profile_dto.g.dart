// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProfileDto _$ProfileDtoFromJson(Map<String, dynamic> json) => _ProfileDto(
  username: json['username'] as String,
  avatarUrl: json['avatarUrl'] as String?,
  timezone: json['timezone'] as String,
  createdAt: json['createdAt'] as String,
  updatedAt: json['updatedAt'] as String,
);

Map<String, dynamic> _$ProfileDtoToJson(_ProfileDto instance) =>
    <String, dynamic>{
      'username': instance.username,
      'avatarUrl': instance.avatarUrl,
      'timezone': instance.timezone,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
    };
