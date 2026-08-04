// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Profile _$ProfileFromJson(Map<String, dynamic> json) => _Profile(
  username: json['username'] as String?,
  avatarUrl: json['avatar_url'] as String?,
  createdAt: json['created_at'] as String?,
  updatedAt: json['updated_at'] as String?,
  timezone: json['timezone'] as String?,
);

Map<String, dynamic> _$ProfileToJson(_Profile instance) => <String, dynamic>{
  'username': instance.username,
  'avatar_url': instance.avatarUrl,
  'created_at': instance.createdAt,
  'updated_at': instance.updatedAt,
  'timezone': instance.timezone,
};
