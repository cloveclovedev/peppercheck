import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile.freezed.dart';
part 'profile.g.dart';

// ignore_for_file: invalid_annotation_target

@freezed
abstract class Profile with _$Profile {
  const factory Profile({
    required String id,
    String? username,
    @JsonKey(name: 'avatar_url') String? avatarUrl,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'stripe_connect_account_id') String? stripeConnectAccountId,
    @JsonKey(name: 'updated_at') String? updatedAt,
    String? timezone,
  }) = _Profile;

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);
}
