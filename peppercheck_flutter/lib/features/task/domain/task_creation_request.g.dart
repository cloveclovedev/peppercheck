// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_creation_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TaskCreationRequest _$TaskCreationRequestFromJson(Map<String, dynamic> json) =>
    _TaskCreationRequest(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      criteria: json['criteria'] as String? ?? '',
      dueDate: json['dueDate'] == null
          ? null
          : DateTime.parse(json['dueDate'] as String),
      taskStatus: json['taskStatus'] as String? ?? 'draft',
      matchingStrategies:
          (json['matchingStrategies'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      errorMessage: json['errorMessage'] as String?,
    );

Map<String, dynamic> _$TaskCreationRequestToJson(
  _TaskCreationRequest instance,
) => <String, dynamic>{
  'title': instance.title,
  'description': instance.description,
  'criteria': instance.criteria,
  'dueDate': instance.dueDate?.toIso8601String(),
  'taskStatus': instance.taskStatus,
  'matchingStrategies': instance.matchingStrategies,
  'errorMessage': instance.errorMessage,
};
