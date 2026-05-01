import 'dart:async';

import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:peppercheck_flutter/features/authentication/data/auth_state_provider.dart';
import 'package:peppercheck_flutter/features/profile/data/profile_repository.dart';
import 'package:peppercheck_flutter/features/profile/presentation/providers/current_profile_provider.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'avatar_edit_controller.g.dart';

@riverpod
class AvatarEditController extends _$AvatarEditController {
  @override
  FutureOr<void> build() {}

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
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: t.profile.edit.cropTitle,
          hideBottomControls: true,
          cropStyle: CropStyle.circle,
        ),
        IOSUiSettings(
          title: t.profile.edit.cropTitle,
          aspectRatioPickerButtonHidden: true,
          resetAspectRatioEnabled: false,
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
