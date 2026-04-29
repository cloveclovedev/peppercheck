import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:peppercheck_flutter/features/evidence/data/evidence_repository.dart';
import 'package:peppercheck_flutter/features/evidence/presentation/controllers/evidence_submission_state.dart';
import 'package:peppercheck_flutter/features/home/presentation/home_controller.dart';
import 'package:peppercheck_flutter/features/task/presentation/providers/task_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'evidence_controller.g.dart';

@riverpod
class EvidenceController extends _$EvidenceController {
  @override
  FutureOr<EvidenceSubmissionState> build() {
    return const EvidenceSubmissionState.idle();
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
    await _runUpload(
      taskId: taskId,
      onSuccess: onSuccess,
      action: (repo, onPreparing, onUploading) => repo.uploadEvidence(
        taskId: taskId,
        description: description,
        images: images,
        onPreparing: onPreparing,
        onUploading: onUploading,
      ),
    );
  }

  Future<void> updateEvidence({
    required String taskId,
    required String evidenceId,
    required String description,
    required List<XFile> newImages,
    required List<String> assetIdsToRemove,
    required VoidCallback onSuccess,
  }) async {
    await _runUpload(
      taskId: taskId,
      onSuccess: onSuccess,
      action: (repo, onPreparing, onUploading) => repo.updateEvidence(
        evidenceId: evidenceId,
        taskId: taskId,
        description: description,
        newImages: newImages,
        assetIdsToRemove: assetIdsToRemove,
        onPreparing: onPreparing,
        onUploading: onUploading,
      ),
    );
  }

  Future<void> resubmit({
    required String taskId,
    required String evidenceId,
    required String description,
    required List<XFile> newImages,
    required List<String> assetIdsToRemove,
    required VoidCallback onSuccess,
  }) async {
    await _runUpload(
      taskId: taskId,
      onSuccess: onSuccess,
      action: (repo, onPreparing, onUploading) => repo.resubmitEvidence(
        evidenceId: evidenceId,
        taskId: taskId,
        description: description,
        newImages: newImages,
        assetIdsToRemove: assetIdsToRemove,
        onPreparing: onPreparing,
        onUploading: onUploading,
      ),
    );
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
      ref.invalidate(activeUserTasksProvider);
      ref.invalidate(activeRefereeTasksProvider);
      onSuccess();
      return const EvidenceSubmissionState.idle();
    });
  }

  Future<void> _runUpload({
    required String taskId,
    required VoidCallback onSuccess,
    required Future<void> Function(
      EvidenceRepository repo,
      ProgressCallback onPreparing,
      ProgressCallback onUploading,
    )
    action,
  }) async {
    state = const AsyncData(EvidenceSubmissionState.idle());
    state = await AsyncValue.guard(() async {
      final repo = ref.read(evidenceRepositoryProvider);
      void onPreparing(int current, int total) {
        state = AsyncData(
          EvidenceSubmissionState.preparing(current: current, total: total),
        );
      }

      void onUploading(int current, int total) {
        state = AsyncData(
          EvidenceSubmissionState.uploading(current: current, total: total),
        );
      }

      await action(repo, onPreparing, onUploading);
      ref.invalidate(taskProvider(taskId));
      ref.invalidate(activeUserTasksProvider);
      ref.invalidate(activeRefereeTasksProvider);
      onSuccess();
      return const EvidenceSubmissionState.idle();
    });
  }
}
