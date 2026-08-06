// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'public_profile_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PublicProfileDto _$PublicProfileDtoFromJson(Map<String, dynamic> json) =>
    _PublicProfileDto(
      userId: json['userId'] as String,
      username: json['username'] as String,
      avatarUrl: json['avatarUrl'] as String?,
    );

Map<String, dynamic> _$PublicProfileDtoToJson(_PublicProfileDto instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'username': instance.username,
      'avatarUrl': instance.avatarUrl,
    };
