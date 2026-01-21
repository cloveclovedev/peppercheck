import 'package:freezed_annotation/freezed_annotation.dart';

part 'task_evidence.freezed.dart';
part 'task_evidence.g.dart';

// ignore_for_file: invalid_annotation_target

@freezed
abstract class TaskEvidence with _$TaskEvidence {
  const factory TaskEvidence({
    required String id,
    @JsonKey(name: 'task_id') required String taskId,
    required String description,
    @Default('pending_upload') String status,
    @JsonKey(name: 'created_at') required String createdAt,
    @JsonKey(name: 'updated_at') required String updatedAt,
    @JsonKey(name: 'task_evidence_assets')
    @Default([])
    List<TaskEvidenceAsset> assets,
  }) = _TaskEvidence;

  factory TaskEvidence.fromJson(Map<String, dynamic> json) =>
      _$TaskEvidenceFromJson(json);
}

@freezed
abstract class TaskEvidenceAsset with _$TaskEvidenceAsset {
  const factory TaskEvidenceAsset({
    required String id,
    @JsonKey(name: 'evidence_id') required String evidenceId,
    @JsonKey(name: 'file_url') required String fileUrl,
    @JsonKey(name: 'file_size_bytes') int? fileSizeBytes,
    @JsonKey(name: 'content_type') String? contentType,
    @JsonKey(name: 'public_url') String? publicUrl,
    @JsonKey(name: 'processing_status')
    @Default('pending')
    String processingStatus,
    @JsonKey(name: 'error_message') String? errorMessage,
    @JsonKey(name: 'created_at') required String createdAt,
  }) = _TaskEvidenceAsset;

  factory TaskEvidenceAsset.fromJson(Map<String, dynamic> json) =>
      _$TaskEvidenceAssetFromJson(json);
}
