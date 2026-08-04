import 'package:freezed_annotation/freezed_annotation.dart';

import '../domain/profile.dart';

part 'profile_dto.freezed.dart';
part 'profile_dto.g.dart';

/// Mirrors the `GET /PATCH /api/v1/me/profile` response envelope (idless, no
/// Stripe fields; HTTP contract, not a DB row). The repository maps this to
/// [Profile]; domain never imports this DTO.
@freezed
abstract class ProfileDto with _$ProfileDto {
  const ProfileDto._();

  const factory ProfileDto({
    required String username,
    String? avatarUrl,
    required String timezone,
    required String createdAt,
    required String updatedAt,
  }) = _ProfileDto;

  factory ProfileDto.fromJson(Map<String, dynamic> json) =>
      _$ProfileDtoFromJson(json);

  Profile toDomain() => Profile(
    username: username,
    avatarUrl: avatarUrl,
    timezone: timezone,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
