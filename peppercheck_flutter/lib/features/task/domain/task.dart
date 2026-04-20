import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:peppercheck_flutter/features/evidence/domain/task_evidence.dart';
import 'package:peppercheck_flutter/features/matching/domain/referee_request.dart';
import 'package:peppercheck_flutter/features/profile/domain/profile.dart';

part 'task.freezed.dart';
part 'task.g.dart';

// ignore_for_file: invalid_annotation_target

@freezed
abstract class Task with _$Task {
  const factory Task({
    required String id,
    @JsonKey(name: 'tasker_id') required String taskerId,
    required String title,
    String? description,
    String? criteria,
    @JsonKey(name: 'due_date') String? dueDate,
    @JsonKey(name: 'fee_amount') double? feeAmount,
    @JsonKey(name: 'fee_currency') String? feeCurrency,
    required String status,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'updated_at') String? updatedAt,

    // Aggregated fields
    @JsonKey(name: 'task_referee_requests')
    @Default([])
    List<RefereeRequest> refereeRequests,

    TaskEvidence? evidence,

    @JsonKey(name: 'tasker_profile') Profile? tasker,
  }) = _Task;

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);

  const Task._();

  static const _terminalStatuses = {'declined', 'cancelled'};
  static const _matchingStatuses = {'pending', 'matched'};

  List<String> getDetailedStatuses(String currentUserId) {
    if (status == 'draft') return ['draft'];
    if (status == 'closed') return ['closed'];

    final activeRequests = refereeRequests
        .where((r) => !_terminalStatuses.contains(r.status))
        .toList();

    // Tasker view
    if (currentUserId == taskerId) {
      return _taskerStatuses(activeRequests);
    }

    // Referee view
    return _refereeStatuses(activeRequests, currentUserId);
  }

  List<String> _taskerStatuses(List<RefereeRequest> active) {
    if (active.isEmpty || active.every((r) => r.status == 'expired')) {
      return active.isEmpty ? ['matching'] : ['matching_failed'];
    }

    if (active.any((r) => _matchingStatuses.contains(r.status))) {
      return ['matching'];
    }

    final accepted = active
        .where(
          (r) =>
              r.status == 'accepted' ||
              r.status == 'payment_processing' ||
              r.status == 'closed',
        )
        .toList();

    if (accepted.isNotEmpty &&
        accepted.every((r) => r.judgement?.status == 'awaiting_evidence')) {
      return ['matching_complete'];
    }

    if (accepted.any((r) => r.judgement?.status == 'evidence_timeout')) {
      return ['evidence_timeout'];
    }

    if (accepted.every((r) => r.status == 'closed')) {
      return ['closed'];
    }

    // Per-referee statuses for judgement/payment phase
    return accepted.map((r) {
      if (r.status == 'payment_processing') return 'payment_processing';
      if (r.status == 'closed') return 'closed';
      return r.judgement?.status ?? 'matching';
    }).toList();
  }

  List<String> _refereeStatuses(
    List<RefereeRequest> active,
    String currentUserId,
  ) {
    final myRequest = active
        .where((r) => r.matchedRefereeId == currentUserId)
        .firstOrNull;

    if (myRequest == null) return ['matching'];

    if (myRequest.status == 'payment_processing') {
      return ['payment_processing'];
    }
    if (myRequest.status == 'closed') return ['closed'];

    return [myRequest.judgement?.status ?? 'awaiting_evidence'];
  }
}
