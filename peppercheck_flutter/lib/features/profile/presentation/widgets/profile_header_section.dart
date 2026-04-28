import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/features/profile/presentation/avatar_edit_controller.dart';
import 'package:peppercheck_flutter/features/profile/presentation/providers/current_profile_provider.dart';
import 'package:peppercheck_flutter/features/profile/presentation/widgets/edit_username_dialog.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class ProfileHeaderSection extends ConsumerWidget {
  const ProfileHeaderSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final avatarState = ref.watch(avatarEditControllerProvider);
    final isUploadingAvatar = avatarState.isLoading;

    return BaseSection(
      title: t.profile.header.sectionTitle,
      child: profileAsync.when(
        loading: () => const SizedBox(
          height: AppSizes.avatarSizeLarge,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, st) => SizedBox(
          height: AppSizes.avatarSizeLarge,
          child: Center(child: Text(t.profile.edit.errors.generic)),
        ),
        data: (profile) {
          if (profile == null) {
            return const SizedBox.shrink();
          }
          return Row(
            children: [
              _AvatarTile(
                avatarUrl: profile.avatarUrl,
                isUploading: isUploadingAvatar,
                onTap: isUploadingAvatar
                    ? null
                    : () => _onAvatarTap(context, ref),
              ),
              const SizedBox(width: AppSizes.spacingMedium),
              Expanded(
                child: Text(
                  profile.username ?? '',
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.edit, size: 16),
                label: Text(t.profile.header.editUsernameButton),
                onPressed: () =>
                    _onEditUsername(context, profile.username ?? ''),
              ),
            ],
          );
        },
      ),
    );
  }

  void _onAvatarTap(BuildContext context, WidgetRef ref) {
    ref
        .read(avatarEditControllerProvider.notifier)
        .pickCropAndUpdateAvatar(
          onSuccess: () {},
          onError: (errorKey) {
            if (!context.mounted) return;
            final messenger = ScaffoldMessenger.of(context);
            final message = switch (errorKey) {
              'galleryPermission' => t.profile.edit.errors.galleryPermission,
              'uploadFailed' => t.profile.edit.errors.uploadFailed,
              _ => t.profile.edit.errors.generic,
            };
            messenger.showSnackBar(SnackBar(content: Text(message)));
          },
        );
  }

  void _onEditUsername(BuildContext context, String currentUsername) {
    showDialog(
      context: context,
      builder: (_) => EditUsernameDialog(currentUsername: currentUsername),
    );
  }
}

class _AvatarTile extends StatelessWidget {
  final String? avatarUrl;
  final bool isUploading;
  final VoidCallback? onTap;

  const _AvatarTile({
    required this.avatarUrl,
    required this.isUploading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const double size = AppSizes.avatarSizeLarge;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: size / 2,
              backgroundColor: AppColors.backgroundWhite,
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl!)
                  : null,
              child: avatarUrl == null
                  ? const Icon(Icons.person, size: size * 0.6)
                  : null,
            ),
            if (isUploading)
              Positioned.fill(
                child: ClipOval(
                  child: Container(
                    color: Colors.black54,
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
