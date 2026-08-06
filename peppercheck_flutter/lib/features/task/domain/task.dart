import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:peppercheck_flutter/features/evidence/domain/task_evidence.dart';
import 'package:peppercheck_flutter/features/matching/domain/public_profile.dart';
import 'package:peppercheck_flutter/features/matching/domain/referee_request.dart';

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
    required String status,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'updated_at') String? updatedAt,

    // Aggregated fields
    @JsonKey(name: 'task_referee_requests')
    @Default([])
    List<RefereeRequest> refereeRequests,

    TaskEvidence? evidence,

    // Populated by the repository from the DTO layer, never parsed here.
    @JsonKey(includeFromJson: false, includeToJson: false)
    PublicProfile? tasker,
  }) = _Task;

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);

  const Task._();

  static const _terminalStatuses = {'declined', 'cancelled'};
  static const _matchedStatuses = {'accepted', 'payment_processing', 'closed'};

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

  /// Pending-first: while any request is still `pending` the task is matching,
  /// which mirrors the detail poller's completion condition (no request is
  /// `pending`). Only once nothing is pending does an accepted request mean
  /// "matched", and an all-expired set mean "matching failed".
  List<String> _taskerStatuses(List<RefereeRequest> active) {
    if (active.isEmpty) return ['matching'];
    if (active.any((r) => r.status == 'pending')) return ['matching'];

    final accepted = active
        .where((r) => _matchedStatuses.contains(r.status))
        .toList();

    if (accepted.isEmpty) return ['matching_failed'];

    // Phase 4a carries no judgement yet, so a matched request is simply
    // "matching complete". The judgement/evidence/payment branches below stay
    // for Phase 4b/4c, where judgements are populated again.
    if (accepted.every((r) => r.judgement == null)) {
      return ['matching_complete'];
    }

    if (accepted.every((r) => r.judgement?.status == 'awaiting_evidence')) {
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

    // Phase 4a: matched, judgement not provisioned to the client yet.
    if (myRequest.judgement == null) return ['matching_complete'];

    return [myRequest.judgement!.status];
  }
}
