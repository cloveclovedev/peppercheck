import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/action_button.dart';
import 'package:peppercheck_flutter/common_widgets/primary_action_button.dart';
import 'package:peppercheck_flutter/common_widgets/base_text_field.dart';

import 'package:peppercheck_flutter/features/evidence/data/image_normalizer.dart';
import 'package:peppercheck_flutter/features/evidence/presentation/controllers/evidence_controller.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/features/matching/domain/referee_request.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EvidenceSubmissionSection extends ConsumerStatefulWidget {
  final Task task;

  const EvidenceSubmissionSection({super.key, required this.task});

  @override
  ConsumerState<EvidenceSubmissionSection> createState() =>
      _EvidenceSubmissionSectionState();
}

class _EvidenceSubmissionSectionState
    extends ConsumerState<EvidenceSubmissionSection> {
  final _descriptionController = TextEditingController();
  List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  bool _isEditing = false;
  bool _isResubmit = false;
  List<String> _assetIdsToRemove = [];

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(_onDescriptionChanged);
  }

  @override
  void dispose() {
    _descriptionController.removeListener(_onDescriptionChanged);
    _descriptionController.dispose();
    super.dispose();
  }

  void _onDescriptionChanged() {
    if (mounted) setState(() {});
  }

  bool _canReopen() {
    final judgement = widget.task.refereeRequests
        .cast<RefereeRequest?>()
        .firstWhere((req) => req?.judgement != null, orElse: () => null)
        ?.judgement;
    if (judgement == null) return false;

    final dueDate = widget.task.dueDate != null
        ? DateTime.parse(widget.task.dueDate!)
        : null;
    return judgement.status == 'rejected' &&
        judgement.reopenCount < 1 &&
        !judgement.isConfirmed &&
        dueDate != null &&
        dueDate.isAfter(DateTime.now());
  }

  bool _isInReview() {
    return widget.task.refereeRequests.any(
      (req) => req.judgement?.status == 'in_review',
    );
  }

  bool _isCurrentUserTasker() {
    return Supabase.instance.client.auth.currentUser?.id ==
        widget.task.taskerId;
  }

  String _mapErrorMessage(Object error) {
    if (error is ImageTooLargeException) {
      return t.task.evidence.image_too_large;
    }
    if (error is ImageProcessingException) {
      return t.task.evidence.image_processing_failed;
    }
    return error.toString();
  }

  Widget? _buildProgressText() {
    final state = ref.watch(evidenceControllerProvider);
    final value = state.value;
    if (value == null) return null;

    String? text;
    if (value.isPreparing) {
      final p = value.progress!;
      text = p.total > 1
          ? t.task.evidence.preparing_multi(current: p.current, total: p.total)
          : t.task.evidence.preparing;
    } else if (value.isUploading) {
      final p = value.progress!;
      text = p.total > 1
          ? t.task.evidence.uploading_multi(current: p.current, total: p.total)
          : t.task.evidence.uploading;
    }

    if (text == null) return null;
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.spacingTiny),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
    );
  }

  Widget? _buildErrorText() {
    final state = ref.watch(evidenceControllerProvider);
    if (!state.hasError) return null;
    return Text(
      _mapErrorMessage(state.error!),
      style: const TextStyle(color: AppColors.textError),
    );
  }

  void _enterEditMode({required bool isResubmit}) {
    final evidence = widget.task.evidence!;
    setState(() {
      _isEditing = true;
      _isResubmit = isResubmit;
      _descriptionController.text = evidence.description;
      _assetIdsToRemove = [];
      _selectedImages = [];
    });
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _isResubmit = false;
      _assetIdsToRemove = [];
      _selectedImages = [];
      _descriptionController.clear();
    });
  }

  void _updateEvidence() {
    final evidence = widget.task.evidence!;
    ref
        .read(evidenceControllerProvider.notifier)
        .updateEvidence(
          taskId: widget.task.id,
          evidenceId: evidence.id,
          description: _descriptionController.text,
          newImages: _selectedImages,
          assetIdsToRemove: _assetIdsToRemove,
          onSuccess: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t.task.evidence.update_success)),
            );
            setState(() {
              _isEditing = false;
            });
          },
        );
  }

  void _resubmitEvidence() {
    final evidence = widget.task.evidence!;
    ref
        .read(evidenceControllerProvider.notifier)
        .resubmit(
          taskId: widget.task.id,
          evidenceId: evidence.id,
          description: _descriptionController.text,
          newImages: _selectedImages,
          assetIdsToRemove: _assetIdsToRemove,
          onSuccess: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t.task.evidence.resubmit_success)),
            );
            setState(() {
              _isEditing = false;
            });
          },
        );
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
          // Limit to 5 images total (remaining existing + new)
          final evidence = widget.task.evidence;
          final remainingCount = _isEditing && evidence != null
              ? evidence.assets
                    .where((a) => !_assetIdsToRemove.contains(a.id))
                    .length
              : 0;
          final maxNew = 5 - remainingCount;
          if (_selectedImages.length > maxNew) {
            _selectedImages.removeRange(maxNew, _selectedImages.length);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(t.task.evidence.maxImages)));
          }
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _submit() {
    ref
        .read(evidenceControllerProvider.notifier)
        .submit(
          taskId: widget.task.id,
          description: _descriptionController.text,
          images: _selectedImages,
          onSuccess: () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(t.task.evidence.success)));
            // Clear form? Or maybe the parent will hide this section as status changes
            // logic: if status changes to in_review, this widget might be replaced by read-only view
          },
        );
  }

  void _confirmTimeout() {
    final request = widget.task.refereeRequests
        .cast<RefereeRequest?>()
        .firstWhere(
          (req) =>
              req?.judgement?.status == 'evidence_timeout' &&
              req!.judgement!.isConfirmed == false,
          orElse: () => null,
        );
    if (request == null) return;

    ref
        .read(evidenceControllerProvider.notifier)
        .confirmEvidenceTimeout(
          taskId: widget.task.id,
          judgementId: request.judgement!.id,
          onSuccess: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t.task.evidence.timeout.success)),
            );
          },
        );
  }

  Widget _buildEditForm(bool isLoading) {
    final evidence = widget.task.evidence!;
    final remainingAssets = evidence.assets
        .where((asset) => !_assetIdsToRemove.contains(asset.id))
        .toList();
    final totalImageCount = remainingAssets.length + _selectedImages.length;

    return BaseSection(
      title: _isResubmit ? t.task.evidence.resubmit : t.task.evidence.edit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BaseTextField(
            value: _descriptionController.text,
            onValueChange: (_) {},
            label: t.task.evidence.description,
            maxLines: 1,
            controller: _descriptionController,
          ),
          const SizedBox(height: AppSizes.spacingSmall),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Existing assets with remove buttons
                for (final asset in remainingAssets) ...[
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: asset.publicUrl != null
                              ? Image.network(
                                  asset.publicUrl!,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.broken_image),
                                )
                              : const Icon(Icons.image),
                        ),
                      ),
                      Positioned(
                        top: -4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _assetIdsToRemove.add(asset.id);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                // Newly selected images
                for (int i = 0; i < _selectedImages.length; i++) ...[
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: FileImage(File(_selectedImages[i].path)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: -4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(i),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (totalImageCount < 5)
                  InkWell(
                    onTap: _pickImages,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.backgroundWhite,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.add_a_photo,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.spacingSmall),
          if (_buildErrorText() != null) ...[
            _buildErrorText()!,
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: _isResubmit
                    ? PrimaryActionButton(
                        text: t.task.evidence.resubmit,
                        onPressed: _descriptionController.text.isNotEmpty
                            ? _resubmitEvidence
                            : null,
                        isLoading: isLoading,
                      )
                    : ActionButton(
                        text: t.task.evidence.update,
                        onPressed: _descriptionController.text.isNotEmpty
                            ? _updateEvidence
                            : null,
                        isLoading: isLoading,
                      ),
              ),
              const SizedBox(width: AppSizes.spacingSmall),
              TextButton(onPressed: _cancelEdit, child: Text(t.common.cancel)),
            ],
          ),
          if (_buildProgressText() != null) _buildProgressText()!,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(evidenceControllerProvider);
    final isLoading = state.isLoading || (state.value?.isLoading ?? false);

    // Check if evidence is already submitted
    // If Evidence exists, show submitted view (Read Only) or edit form
    final evidence = widget.task.evidence;
    if (evidence != null) {
      if (_isEditing) {
        return _buildEditForm(isLoading);
      }

      return BaseSection(
        title: t.task.evidence.submitted,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              evidence.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSizes.spacingSmall),

            Builder(
              builder: (context) {
                final imageUrls = evidence.assets
                    .where((a) => a.publicUrl != null)
                    .map((a) => a.publicUrl!)
                    .toList(growable: false);
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: evidence.assets.map((asset) {
                    if (asset.publicUrl != null) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              fullscreenDialog: true,
                              builder: (_) => _FullscreenImageViewer(
                                imageUrls: imageUrls,
                                initialIndex: imageUrls.indexOf(
                                  asset.publicUrl!,
                                ),
                              ),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusSmall,
                          ),
                          child: Image.network(
                            asset.publicUrl!,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  width: 100,
                                  height: 100,
                                  color: Colors.grey,
                                  child: const Icon(Icons.broken_image),
                                ),
                          ),
                        ),
                      );
                    } else {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusSmall,
                        ),
                        child: Container(
                          width: 100,
                          height: 100,
                          color: Colors.grey,
                          child: const Icon(Icons.image),
                        ),
                      );
                    }
                  }).toList(),
                );
              },
            ),
            if (_isInReview() && _isCurrentUserTasker()) ...[
              const SizedBox(height: AppSizes.spacingSmall),
              ActionButton(
                text: t.task.evidence.edit,
                onPressed: () => _enterEditMode(isResubmit: false),
                isLoading: false,
              ),
            ],
            if (_canReopen() && _isCurrentUserTasker()) ...[
              const SizedBox(height: AppSizes.spacingSmall),
              PrimaryActionButton(
                text: t.task.evidence.resubmit,
                onPressed: () => _enterEditMode(isResubmit: true),
                isLoading: false,
              ),
            ],
          ],
        ),
      );
    }

    // Check for evidence timeout state
    final hasEvidenceTimeout = widget.task.refereeRequests.any(
      (req) => req.judgement?.status == 'evidence_timeout',
    );

    if (hasEvidenceTimeout) {
      final allConfirmed = widget.task.refereeRequests.every(
        (req) =>
            req.judgement?.status != 'evidence_timeout' ||
            req.judgement!.isConfirmed,
      );

      return BaseSection(
        title: t.task.evidence.submit,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.textError,
                  size: 20,
                ),
                const SizedBox(width: AppSizes.spacingTiny),
                Expanded(
                  child: Text(
                    t.task.evidence.timeout.description,
                    style: TextStyle(color: AppColors.textError),
                  ),
                ),
              ],
            ),
            if (!allConfirmed) ...[
              const SizedBox(height: AppSizes.spacingSmall),
              if (_buildErrorText() != null) ...[
                _buildErrorText()!,
                const SizedBox(height: AppSizes.spacingSmall),
              ],
              PrimaryActionButton(
                text: t.task.evidence.timeout.confirm,
                icon: Icons.check,
                onPressed: () => _confirmTimeout(),
                isLoading: isLoading,
              ),
            ] else ...[
              const SizedBox(height: AppSizes.spacingSmall),
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppColors.accentGreen,
                    size: 16,
                  ),
                  const SizedBox(width: AppSizes.spacingTiny),
                  Text(
                    t.task.evidence.timeout.confirmed,
                    style: TextStyle(color: AppColors.accentGreen),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    // Submission Form
    // Only show if Request Accepted? (Logic handled by parent or here)
    // Requirement: "Request Accepted" -> Show section.
    // Parent TaskDetailScreen checks this condition before showing this widget?
    // Let's assume this widget is only shown when valid.

    return BaseSection(
      title: t.task.evidence.submit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BaseTextField(
            value: _descriptionController.text,
            onValueChange: (_) {},
            label: t.task.evidence.description,
            maxLines: 1,
            controller: _descriptionController,
          ),
          const SizedBox(height: AppSizes.spacingSmall),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < _selectedImages.length; i++) ...[
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: FileImage(File(_selectedImages[i].path)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: -4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(i),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (_selectedImages.length < 5)
                  InkWell(
                    onTap: _pickImages,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.backgroundWhite,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.add_a_photo,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.spacingSmall),
          if (_buildErrorText() != null) ...[
            _buildErrorText()!,
            const SizedBox(height: 8),
          ],
          PrimaryActionButton(
            text: t.task.evidence.submit,
            onPressed:
                _selectedImages.isNotEmpty &&
                    _descriptionController.text.isNotEmpty
                ? _submit
                : null,
            isLoading: isLoading,
          ),
          if (_buildProgressText() != null) _buildProgressText()!,
        ],
      ),
    );
  }
}

class _FullscreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _FullscreenImageViewer({
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _pageController.addListener(_handlePageChanged);
  }

  void _handlePageChanged() {
    final page = _pageController.page;
    if (page == null) return;
    final newIndex = page.round();
    if (newIndex != _currentIndex) {
      setState(() => _currentIndex = newIndex);
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_handlePageChanged);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.imageUrls.length,
              itemBuilder: (context, index) {
                return Image.network(
                  widget.imageUrls[index],
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          if (widget.imageUrls.length > 1)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(
                    bottom: AppSizes.spacingStandard,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.spacingMedium,
                      vertical: AppSizes.spacingTiny,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.imageUrls.length}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
