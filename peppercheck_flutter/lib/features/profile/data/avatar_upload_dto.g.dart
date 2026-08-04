// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'avatar_upload_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AvatarUploadDto _$AvatarUploadDtoFromJson(Map<String, dynamic> json) =>
    _AvatarUploadDto(
      uploadUrl: json['uploadUrl'] as String,
      publicUrl: json['publicUrl'] as String,
      expiresAt: json['expiresAt'] as String,
    );

Map<String, dynamic> _$AvatarUploadDtoToJson(_AvatarUploadDto instance) =>
    <String, dynamic>{
      'uploadUrl': instance.uploadUrl,
      'publicUrl': instance.publicUrl,
      'expiresAt': instance.expiresAt,
    };
