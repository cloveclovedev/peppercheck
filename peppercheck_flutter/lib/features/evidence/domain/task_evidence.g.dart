// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_evidence.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TaskEvidence _$TaskEvidenceFromJson(Map<String, dynamic> json) =>
    _TaskEvidence(
      id: json['id'] as String,
      taskId: json['task_id'] as String,
      description: json['description'] as String,
      status: json['status'] as String? ?? 'pending_upload',
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      assets:
          (json['task_evidence_assets'] as List<dynamic>?)
              ?.map(
                (e) => TaskEvidenceAsset.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );

Map<String, dynamic> _$TaskEvidenceToJson(_TaskEvidence instance) =>
    <String, dynamic>{
      'id': instance.id,
      'task_id': instance.taskId,
      'description': instance.description,
      'status': instance.status,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'task_evidence_assets': instance.assets,
    };

_TaskEvidenceAsset _$TaskEvidenceAssetFromJson(Map<String, dynamic> json) =>
    _TaskEvidenceAsset(
      id: json['id'] as String,
      evidenceId: json['evidence_id'] as String,
      fileUrl: json['file_url'] as String,
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt(),
      contentType: json['content_type'] as String?,
      publicUrl: json['public_url'] as String?,
      processingStatus: json['processing_status'] as String? ?? 'pending',
      errorMessage: json['error_message'] as String?,
      createdAt: json['created_at'] as String,
    );

Map<String, dynamic> _$TaskEvidenceAssetToJson(_TaskEvidenceAsset instance) =>
    <String, dynamic>{
      'id': instance.id,
      'evidence_id': instance.evidenceId,
      'file_url': instance.fileUrl,
      'file_size_bytes': instance.fileSizeBytes,
      'content_type': instance.contentType,
      'public_url': instance.publicUrl,
      'processing_status': instance.processingStatus,
      'error_message': instance.errorMessage,
      'created_at': instance.createdAt,
    };
