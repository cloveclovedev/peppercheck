import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/action_button.dart';
import 'package:peppercheck_flutter/common_widgets/base_text_field.dart';

import 'package:peppercheck_flutter/features/evidence/presentation/controllers/evidence_controller.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

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
  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
          // Limit to 5 images
          if (_selectedImages.length > 5) {
            _selectedImages.removeRange(5, _selectedImages.length);
            _selectedImages.removeRange(5, _selectedImages.length);
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
    final request = widget.task.refereeRequests.firstWhere(
      (req) =>
          req.judgement?.status == 'evidence_timeout' &&
          req.judgement!.isConfirmed == false,
    );

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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(evidenceControllerProvider);
    final isLoading = state.isLoading;

    // Check if evidence is already submitted
    // If Evidence exists, show submitted view (Read Only)
    // Assuming Task.evidence is nullable.
    final evidence = widget.task.evidence;
    if (evidence != null) {
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

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: evidence.assets.map((asset) {
                if (asset.publicUrl != null) {
                  return Image.network(
                    asset.publicUrl!,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.broken_image),
                  );
                } else {
                  return Container(
                    width: 100,
                    height: 100,
                    color: Colors.grey,
                    child: const Icon(Icons.image),
                  );
                }
              }).toList(),
            ),
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
        title: t.task.evidence.timeout.title,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: AppColors.textError, size: 20),
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
              if (state.hasError) ...[
                Text(
                  state.error.toString(),
                  style: TextStyle(color: AppColors.textError),
                ),
                const SizedBox(height: AppSizes.spacingSmall),
              ],
              ActionButton(
                text: t.task.evidence.timeout.confirm,
                onPressed: () => _confirmTimeout(),
                isLoading: isLoading,
              ),
            ] else ...[
              const SizedBox(height: AppSizes.spacingSmall),
              Row(
                children: [
                  Icon(Icons.check_circle,
                      color: AppColors.accentGreen, size: 16),
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
            onValueChange: (val) => _descriptionController.text = val,
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
          if (state.hasError) ...[
            Text(
              state.error.toString(),
              style: TextStyle(color: AppColors.textError),
            ),
            const SizedBox(height: 8),
          ],
          ActionButton(
            text: t.task.evidence.submit,
            onPressed:
                _selectedImages.isNotEmpty &&
                    _descriptionController.text.isNotEmpty
                ? _submit
                : null,
            isLoading: isLoading,
          ),
        ],
      ),
    );
  }
}
