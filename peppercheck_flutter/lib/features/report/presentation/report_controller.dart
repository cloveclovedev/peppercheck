import 'dart:async';

import 'package:peppercheck_flutter/features/report/data/report_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'report_controller.g.dart';

@riverpod
class ReportController extends _$ReportController {
  @override
  FutureOr<void> build() {}

  Future<bool> submitReport({
    required String taskId,
    required String reporterRole,
    required String contentType,
    String? contentId,
    required String reason,
    String? detail,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(reportRepositoryProvider)
          .submitReport(
            taskId: taskId,
            reporterRole: reporterRole,
            contentType: contentType,
            contentId: contentId,
            reason: reason,
            detail: detail,
          );
    });
    return !state.hasError;
  }
}

@riverpod
Future<bool> hasReported(Ref ref, String taskId) {
  return ref.watch(reportRepositoryProvider).hasReported(taskId);
}
