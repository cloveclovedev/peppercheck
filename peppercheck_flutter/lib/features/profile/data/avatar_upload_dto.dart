import 'package:freezed_annotation/freezed_annotation.dart';

part 'avatar_upload_dto.freezed.dart';
part 'avatar_upload_dto.g.dart';

/// Mirrors the `POST /api/v1/me/avatar/request-upload-url` response envelope.
@freezed
abstract class AvatarUploadDto with _$AvatarUploadDto {
  const factory AvatarUploadDto({
    required String uploadUrl,
    required String publicUrl,
    required String expiresAt,
  }) = _AvatarUploadDto;

  factory AvatarUploadDto.fromJson(Map<String, dynamic> json) =>
      _$AvatarUploadDtoFromJson(json);
}
