import 'package:freezed_annotation/freezed_annotation.dart';

part 'public_profile.freezed.dart';

/// Minimal public display profile of another user, embedded in task and
/// assignment responses (wire contract §7.1). It carries display fields only —
/// it is not the owner's editable [Profile]. JSON lives in the DTO layer, so
/// this domain model has no `fromJson`.
@freezed
abstract class PublicProfile with _$PublicProfile {
  const factory PublicProfile({
    required String userId,
    required String username,
    String? avatarUrl,
  }) = _PublicProfile;
}
