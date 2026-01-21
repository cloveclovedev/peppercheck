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

  // TODO: Implement complex status logic using referee_requests and judgement status
  String get detailedStatus {
    // For now, it just returns the basic status.
    // Future implementation will check refereeRequests, etc.
    return status;
  }
}
