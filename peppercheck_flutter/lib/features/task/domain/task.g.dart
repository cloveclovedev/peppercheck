// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Task _$TaskFromJson(Map<String, dynamic> json) => _Task(
  id: json['id'] as String,
  taskerId: json['tasker_id'] as String,
  title: json['title'] as String,
  description: json['description'] as String?,
  criteria: json['criteria'] as String?,
  dueDate: json['due_date'] as String?,
  feeAmount: (json['fee_amount'] as num?)?.toDouble(),
  feeCurrency: json['fee_currency'] as String?,
  status: json['status'] as String,
  createdAt: json['created_at'] as String?,
  updatedAt: json['updated_at'] as String?,
  refereeRequests:
      (json['task_referee_requests'] as List<dynamic>?)
          ?.map((e) => RefereeRequest.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  tasker: json['tasker_profile'] == null
      ? null
      : Profile.fromJson(json['tasker_profile'] as Map<String, dynamic>),
);

Map<String, dynamic> _$TaskToJson(_Task instance) => <String, dynamic>{
  'id': instance.id,
  'tasker_id': instance.taskerId,
  'title': instance.title,
  'description': instance.description,
  'criteria': instance.criteria,
  'due_date': instance.dueDate,
  'fee_amount': instance.feeAmount,
  'fee_currency': instance.feeCurrency,
  'status': instance.status,
  'created_at': instance.createdAt,
  'updated_at': instance.updatedAt,
  'task_referee_requests': instance.refereeRequests,
  'tasker_profile': instance.tasker,
};
