import 'package:freezed_annotation/freezed_annotation.dart';

import '../domain/task.dart';
import 'public_profile_dto.dart';
import 'referee_request_dto.dart';

part 'task_dto.freezed.dart';
part 'task_dto.g.dart';

/// Mirrors the task object of the wire contract (§7.1) — the body of
/// `GET/POST/PATCH /tasks…` and the element of the `tasks` / `assignments`
/// page envelopes. No fee, strategy, judgement or evidence fields: Phase 4a
/// does not serve them. The repository maps this to [Task]; domain never
/// imports this DTO.
@freezed
abstract class TaskDto with _$TaskDto {
  const TaskDto._();

  const factory TaskDto({
    required String id,
    required String taskerId,
    required String title,
    String? description,
    String? criteria,
    String? dueDate,
    required String status,
    required String createdAt,
    required String updatedAt,
    PublicProfileDto? tasker,
    @Default(<RefereeRequestDto>[]) List<RefereeRequestDto> refereeRequests,
  }) = _TaskDto;

  factory TaskDto.fromJson(Map<String, dynamic> json) =>
      _$TaskDtoFromJson(json);

  Task toDomain() => Task(
    id: id,
    taskerId: taskerId,
    title: title,
    description: description,
    criteria: criteria,
    dueDate: dueDate,
    status: status,
    createdAt: createdAt,
    updatedAt: updatedAt,
    tasker: tasker?.toDomain(),
    refereeRequests: refereeRequests.map((r) => r.toDomain()).toList(),
  );
}
