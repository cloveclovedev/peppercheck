// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TaskDto _$TaskDtoFromJson(Map<String, dynamic> json) => _TaskDto(
  id: json['id'] as String,
  taskerId: json['taskerId'] as String,
  title: json['title'] as String,
  description: json['description'] as String?,
  criteria: json['criteria'] as String?,
  dueDate: json['dueDate'] as String?,
  status: json['status'] as String,
  createdAt: json['createdAt'] as String,
  updatedAt: json['updatedAt'] as String,
  tasker: json['tasker'] == null
      ? null
      : PublicProfileDto.fromJson(json['tasker'] as Map<String, dynamic>),
  refereeRequests:
      (json['refereeRequests'] as List<dynamic>?)
          ?.map((e) => RefereeRequestDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <RefereeRequestDto>[],
);

Map<String, dynamic> _$TaskDtoToJson(_TaskDto instance) => <String, dynamic>{
  'id': instance.id,
  'taskerId': instance.taskerId,
  'title': instance.title,
  'description': instance.description,
  'criteria': instance.criteria,
  'dueDate': instance.dueDate,
  'status': instance.status,
  'createdAt': instance.createdAt,
  'updatedAt': instance.updatedAt,
  'tasker': instance.tasker,
  'refereeRequests': instance.refereeRequests,
};
