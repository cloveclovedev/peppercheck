import 'dart:async';

import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:peppercheck_flutter/features/authentication/data/auth_state_provider.dart';
import 'package:peppercheck_flutter/features/profile/data/profile_repository.dart';
import 'package:peppercheck_flutter/features/profile/presentation/providers/current_profile_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_edit_controller.g.dart';

/// Validates a username synchronously. Returns an error key on failure,
/// or null if the value is valid. Shared between the dialog (real-time
/// `onChanged` validation) and the controller (defense-in-depth).
String? validateUsername(String value) {
  final trimmed = value.trim();
  if (trimmed.length < 2) return 'tooShort';
  if (trimmed.length > 20) return 'tooLong';
  // Allow-list: any letter (any script — Latin, Japanese, etc.), digit,
  // underscore, hyphen. Rejects emoji, punctuation, whitespace, and
  // zero-width / variation-selector codepoints automatically.
  final allowed = RegExp(r'^[\p{L}\p{N}_\-]+$', unicode: true);
  if (!allowed.hasMatch(trimmed)) return 'invalidChars';
  return null;
}

@riverpod
class ProfileEditController extends _$ProfileEditController {
  @override
  FutureOr<void> build() {}

  Future<void> updateUsername({
    required String username,
    required void Function() onSuccess,
  }) async {
    final trimmed = username.trim();

    final validationError = validateUsername(trimmed);
    if (validationError != null) {
      state = AsyncError(validationError, StackTrace.current);
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = AsyncError('not_logged_in', StackTrace.current);
      return;
    }

    // Skip API call if value is unchanged
    final currentProfile = ref.read(currentProfileProvider).value;
    if (currentProfile?.username == trimmed) {
      onSuccess();
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(profileRepositoryProvider)
          .updateUsername(user.id, trimmed);
      ref.invalidate(currentProfileProvider);
      onSuccess();
    });
  }

  Future<void> pickCropAndUpdateAvatar({
    required void Function() onSuccess,
    required void Function(String errorKey) onError,
  }) async {
    final picker = ImagePicker();
    final XFile? picked;
    try {
      picked = await picker.pickImage(source: ImageSource.gallery);
    } catch (_) {
      onError('galleryPermission');
      return;
    }
    if (picked == null) return; // user cancelled

    final cropper = ImageCropper();
    final cropped = await cropper.cropImage(
      sourcePath: picked.path,
      maxWidth: 512,
      maxHeight: 512,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'crop',
          aspectRatioPresets: const [CropAspectRatioPreset.square],
          lockAspectRatio: true,
          cropStyle: CropStyle.circle,
        ),
        IOSUiSettings(
          title: 'crop',
          aspectRatioPresets: const [CropAspectRatioPreset.square],
          aspectRatioLockEnabled: true,
          cropStyle: CropStyle.circle,
        ),
      ],
    );
    if (cropped == null) return; // user cancelled cropper

    final user = ref.read(currentUserProvider);
    if (user == null) {
      onError('generic');
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(profileRepositoryProvider).updateAvatar(user.id, cropped);
      ref.invalidate(currentProfileProvider);
      onSuccess();
    });

    if (state.hasError) {
      onError('uploadFailed');
    }
  }
}
