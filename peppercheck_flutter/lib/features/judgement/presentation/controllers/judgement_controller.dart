import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/features/judgement/data/judgement_repository.dart';
import 'package:peppercheck_flutter/features/task/presentation/providers/task_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'judgement_controller.g.dart';

@riverpod
class JudgementController extends _$JudgementController {
  @override
  FutureOr<void> build() {
    // nothing to initialize
  }

  Future<void> submit({
    required String taskId,
    required String judgementId,
    required String status,
    required String comment,
    required VoidCallback onSuccess,
  }) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await ref
          .read(judgementRepositoryProvider)
          .judgeEvidence(
            judgementId: judgementId,
            status: status,
            comment: comment,
          );
      ref.invalidate(taskProvider(taskId));
      onSuccess();
    });
  }

  Future<void> confirmJudgement({
    required String taskId,
    required String judgementId,
    required bool isPositive,
    String? comment,
    required VoidCallback onSuccess,
  }) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await ref
          .read(judgementRepositoryProvider)
          .confirmJudgement(
            judgementId: judgementId,
            isPositive: isPositive,
            comment: comment,
          );
      ref.invalidate(taskProvider(taskId));
      onSuccess();
    });
  }
}
