import 'package:freezed_annotation/freezed_annotation.dart';

import '../domain/app_user.dart';

part 'me_dto.freezed.dart';
part 'me_dto.g.dart';

/// Mirrors the `GET /api/v1/me` response envelope (HTTP contract, not a DB row).
/// The repository maps this to [AppUser]; domain never imports this DTO.
@freezed
abstract class MeResponse with _$MeResponse {
  const MeResponse._();

  const factory MeResponse({
    required MeUser user,
    required MeIdentity identity,
  }) = _MeResponse;

  factory MeResponse.fromJson(Map<String, dynamic> json) =>
      _$MeResponseFromJson(json);

  AppUser toDomain() => AppUser(
    internalUserId: user.id,
    issuer: identity.issuer,
    status: user.status,
    createdAt: DateTime.parse(user.createdAt),
  );
}

@freezed
abstract class MeUser with _$MeUser {
  const factory MeUser({
    required String id,
    required String status,
    required String createdAt,
  }) = _MeUser;

  factory MeUser.fromJson(Map<String, dynamic> json) => _$MeUserFromJson(json);
}

@freezed
abstract class MeIdentity with _$MeIdentity {
  const factory MeIdentity({required String issuer}) = _MeIdentity;

  factory MeIdentity.fromJson(Map<String, dynamic> json) =>
      _$MeIdentityFromJson(json);
}
