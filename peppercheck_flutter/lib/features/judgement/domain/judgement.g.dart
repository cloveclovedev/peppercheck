// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'judgement.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Judgement _$JudgementFromJson(Map<String, dynamic> json) => _Judgement(
  id: json['id'] as String,
  status: json['status'] as String,
  comment: json['comment'] as String?,
  isConfirmed: json['is_confirmed'] as bool? ?? false,
  reopenCount: (json['reopen_count'] as num?)?.toInt() ?? 0,
  isEvidenceTimeoutConfirmed:
      json['is_evidence_timeout_confirmed'] as bool? ?? false,
  createdAt: json['created_at'] as String,
  updatedAt: json['updated_at'] as String,
);

Map<String, dynamic> _$JudgementToJson(_Judgement instance) =>
    <String, dynamic>{
      'id': instance.id,
      'status': instance.status,
      'comment': instance.comment,
      'is_confirmed': instance.isConfirmed,
      'reopen_count': instance.reopenCount,
      'is_evidence_timeout_confirmed': instance.isEvidenceTimeoutConfirmed,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };
