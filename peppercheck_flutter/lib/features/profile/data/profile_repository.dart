import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_client_provider.dart';
import '../../../core/network/api_exception.dart';
import '../domain/profile.dart';
import 'avatar_upload_dto.dart';
import 'profile_dto.dart';
import 'profile_errors.dart';

part 'profile_repository.g.dart';

/// Profile access over the Go API, scoped to the authenticated caller (no
/// `userId` parameter — the bearer identifies the profile).
class ProfileRepository {
  ProfileRepository(this._api);

  final ApiClient _api;

  Future<Profile> fetchOwn() async {
    final json = await _api.getJson('/api/v1/me/profile');
    return ProfileDto.fromJson(json).toDomain();
  }

  Future<void> updateUsername(String username) async {
    try {
      await _api.patchJson('/api/v1/me/profile', body: {'username': username});
    } on ApiException catch (e) {
      if (e.code == 'username_taken') {
        throw const UsernameAlreadyTakenException();
      }
      rethrow;
    }
  }

  Future<void> updateTimezone(String timezone) async {
    await _api.patchJson('/api/v1/me/profile', body: {'timezone': timezone});
  }

  Future<AvatarUploadDto> requestAvatarUpload({
    required String contentType,
    required int fileSizeBytes,
  }) async {
    final json = await _api.postJson(
      '/api/v1/me/avatar/request-upload-url',
      body: {'contentType': contentType, 'fileSizeBytes': fileSizeBytes},
    );
    return AvatarUploadDto.fromJson(json);
  }

  Future<void> commitAvatar(String publicUrl) async {
    await _api.patchJson('/api/v1/me/profile', body: {'avatarUrl': publicUrl});
  }
}

@Riverpod(keepAlive: true)
ProfileRepository profileRepository(Ref ref) =>
    ProfileRepository(ref.watch(apiClientProvider));
