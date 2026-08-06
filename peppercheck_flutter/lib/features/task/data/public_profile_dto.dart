import 'package:freezed_annotation/freezed_annotation.dart';

import '../../matching/domain/public_profile.dart';

part 'public_profile_dto.freezed.dart';
part 'public_profile_dto.g.dart';

/// Mirrors the minimal public profile embedded in task and assignment
/// responses (wire contract §7.1). The repository maps this to
/// [PublicProfile]; domain never imports this DTO.
@freezed
abstract class PublicProfileDto with _$PublicProfileDto {
  const PublicProfileDto._();

  const factory PublicProfileDto({
    required String userId,
    required String username,
    String? avatarUrl,
  }) = _PublicProfileDto;

  factory PublicProfileDto.fromJson(Map<String, dynamic> json) =>
      _$PublicProfileDtoFromJson(json);

  PublicProfile toDomain() =>
      PublicProfile(userId: userId, username: username, avatarUrl: avatarUrl);
}
