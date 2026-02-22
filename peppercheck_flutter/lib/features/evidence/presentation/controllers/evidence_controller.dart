import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:peppercheck_flutter/features/evidence/data/evidence_repository.dart';
import 'package:peppercheck_flutter/features/task/presentation/providers/task_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'evidence_controller.g.dart';

@riverpod
class EvidenceController extends _$EvidenceController {
  @override
  FutureOr<void> build() {
    // nothing to initialize
  }

  Future<void> submit({
    required String taskId,
    required String description,
    required List<XFile> images,
    required VoidCallback onSuccess,
  }) async {
    if (description.isEmpty) {
      throw Exception('Description is required');
    }
    if (images.isEmpty) {
      throw Exception('At least one image is required');
    }

    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await ref
          .read(evidenceRepositoryProvider)
          .uploadEvidence(
            taskId: taskId,
            description: description,
            images: images,
          );
      // Invalidate task provider to refresh UI
      ref.invalidate(taskProvider(taskId));
      onSuccess();
    });
  }

  Future<void> update({
    required String taskId,
    required String evidenceId,
    required String description,
    required List<XFile> newImages,
    required List<String> assetIdsToRemove,
    required VoidCallback onSuccess,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(evidenceRepositoryProvider).updateEvidence(
            evidenceId: evidenceId,
            taskId: taskId,
            description: description,
            newImages: newImages,
            assetIdsToRemove: assetIdsToRemove,
          );
      ref.invalidate(taskProvider(taskId));
      onSuccess();
    });
  }

  Future<void> resubmit({
    required String taskId,
    required String evidenceId,
    required String description,
    required List<XFile> newImages,
    required List<String> assetIdsToRemove,
    required VoidCallback onSuccess,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(evidenceRepositoryProvider).resubmitEvidence(
            evidenceId: evidenceId,
            taskId: taskId,
            description: description,
            newImages: newImages,
            assetIdsToRemove: assetIdsToRemove,
          );
      ref.invalidate(taskProvider(taskId));
      onSuccess();
    });
  }

  Future<void> confirmEvidenceTimeout({
    required String taskId,
    required String judgementId,
    required VoidCallback onSuccess,
  }) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await ref
          .read(evidenceRepositoryProvider)
          .confirmEvidenceTimeout(judgementId: judgementId);
      ref.invalidate(taskProvider(taskId));
      onSuccess();
    });
  }
}
