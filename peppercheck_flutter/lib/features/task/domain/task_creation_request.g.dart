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
      selectedDateTime: json['selectedDateTime'] == null
          ? null
          : DateTime.parse(json['selectedDateTime'] as String),
      taskStatus: json['taskStatus'] as String? ?? 'open',
      selectedStrategies:
          (json['selectedStrategies'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$TaskCreationRequestToJson(
  _TaskCreationRequest instance,
) => <String, dynamic>{
  'title': instance.title,
  'description': instance.description,
  'criteria': instance.criteria,
  'selectedDateTime': instance.selectedDateTime?.toIso8601String(),
  'taskStatus': instance.taskStatus,
  'selectedStrategies': instance.selectedStrategies,
};
