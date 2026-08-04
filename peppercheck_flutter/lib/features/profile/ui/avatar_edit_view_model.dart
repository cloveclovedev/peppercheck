import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:peppercheck_flutter/core/network/api_exception.dart';
import 'package:peppercheck_flutter/core/network/presigned_upload_client_provider.dart';
import 'package:peppercheck_flutter/features/profile/data/profile_repository.dart';
import 'package:peppercheck_flutter/features/profile/ui/current_profile_provider.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'avatar_edit_view_model.g.dart';

const _maxAvatarBytes = 5 * 1024 * 1024;

@riverpod
class AvatarEditViewModel extends _$AvatarEditViewModel {
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

    final bytes = await cropped.readAsBytes();
    await uploadAvatarBytes(bytes, onSuccess: onSuccess, onError: onError);
  }

  /// The request → PUT → commit flow, split out from [pickCropAndUpdateAvatar]
  /// so it is testable without a real image picker/cropper platform channel.
  @visibleForTesting
  Future<void> uploadAvatarBytes(
    List<int> bytes, {
    required void Function() onSuccess,
    required void Function(String errorKey) onError,
  }) async {
    if (bytes.length > _maxAvatarBytes) {
      onError('tooLarge');
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(profileRepositoryProvider);
      final upload = await repo.requestAvatarUpload(
        contentType: 'image/jpeg',
        fileSizeBytes: bytes.length,
      );
      await ref
          .read(presignedUploadClientProvider)
          .put(
            uploadUrl: upload.uploadUrl,
            bytes: bytes,
            contentType: 'image/jpeg',
          );
      await repo.commitAvatar(upload.publicUrl);
      ref.invalidate(currentProfileProvider);
      onSuccess();
    });

    if (state.hasError) {
      final error = state.error;
      onError(
        error is ApiException && error.code == 'rate_limited'
            ? 'rateLimited'
            : 'uploadFailed',
      );
    }
  }
}
