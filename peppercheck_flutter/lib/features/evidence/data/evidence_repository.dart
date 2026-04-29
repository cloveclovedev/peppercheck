import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:peppercheck_flutter/app/app_logger.dart';
import 'package:peppercheck_flutter/features/evidence/data/image_normalizer.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'evidence_repository.g.dart';

typedef ProgressCallback = void Function(int current, int total);

class EvidenceRepository {
  final SupabaseClient _client;
  final Logger _logger;
  final ImageNormalizer _normalizer;

  EvidenceRepository(this._client, this._logger, {ImageNormalizer? normalizer})
    : _normalizer = normalizer ?? ImageNormalizer();

  Future<List<Map<String, dynamic>>> _uploadImages(
    String taskId,
    List<XFile> images, {
    ProgressCallback? onPreparing,
    ProgressCallback? onUploading,
  }) async {
    final assets = <Map<String, dynamic>>[];
    final dio = Dio();

    for (var i = 0; i < images.length; i++) {
      final image = images[i];
      onPreparing?.call(i + 1, images.length);

      final normalized = await _normalizer.normalize(image);
      final length = normalized.bytes.length;

      onUploading?.call(i + 1, images.length);

      final response = await _client.functions.invoke(
        'generate-upload-url',
        body: {
          'task_id': taskId,
          'filename': normalized.filename,
          'content_type': normalized.mimeType,
          'file_size_bytes': length,
          'kind': 'evidence',
        },
      );

      if (response.status != 200) {
        throw Exception('Failed to get upload URL: ${response.data}');
      }

      final uploadUrl = response.data['upload_url'] as String;
      final r2Key = response.data['r2_key'] as String;
      final publicUrl = response.data['public_url'] as String?;

      await dio.put(
        uploadUrl,
        data: Stream.fromIterable([normalized.bytes]),
        options: Options(
          headers: {
            'Content-Type': normalized.mimeType,
            'Content-Length': length,
          },
        ),
      );

      assets.add({
        'file_url': r2Key,
        'file_size_bytes': length,
        'content_type': normalized.mimeType,
        'public_url': publicUrl,
      });
    }

    return assets;
  }

  Future<void> uploadEvidence({
    required String taskId,
    required String description,
    required List<XFile> images,
    ProgressCallback? onPreparing,
    ProgressCallback? onUploading,
  }) async {
    try {
      final assets = await _uploadImages(
        taskId,
        images,
        onPreparing: onPreparing,
        onUploading: onUploading,
      );
      await _client.rpc(
        'submit_evidence',
        params: {
          'p_task_id': taskId,
          'p_description': description,
          'p_assets': assets,
        },
      );
    } catch (e, st) {
      _logger.e('uploadEvidence failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> updateEvidence({
    required String evidenceId,
    required String taskId,
    required String description,
    required List<XFile> newImages,
    required List<String> assetIdsToRemove,
    ProgressCallback? onPreparing,
    ProgressCallback? onUploading,
  }) async {
    try {
      List<Map<String, dynamic>>? assetsToAdd;
      if (newImages.isNotEmpty) {
        assetsToAdd = await _uploadImages(
          taskId,
          newImages,
          onPreparing: onPreparing,
          onUploading: onUploading,
        );
      }

      await _client.rpc(
        'update_evidence',
        params: {
          'p_evidence_id': evidenceId,
          'p_description': description,
          if (assetsToAdd != null) 'p_assets_to_add': assetsToAdd,
          if (assetIdsToRemove.isNotEmpty)
            'p_asset_ids_to_remove': assetIdsToRemove,
        },
      );
    } catch (e, st) {
      _logger.e('updateEvidence failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> resubmitEvidence({
    required String evidenceId,
    required String taskId,
    required String description,
    required List<XFile> newImages,
    required List<String> assetIdsToRemove,
    ProgressCallback? onPreparing,
    ProgressCallback? onUploading,
  }) async {
    try {
      List<Map<String, dynamic>>? assetsToAdd;
      if (newImages.isNotEmpty) {
        assetsToAdd = await _uploadImages(
          taskId,
          newImages,
          onPreparing: onPreparing,
          onUploading: onUploading,
        );
      }

      await _client.rpc(
        'resubmit_evidence',
        params: {
          'p_evidence_id': evidenceId,
          'p_description': description,
          if (assetsToAdd != null) 'p_assets_to_add': assetsToAdd,
          if (assetIdsToRemove.isNotEmpty)
            'p_asset_ids_to_remove': assetIdsToRemove,
        },
      );
    } catch (e, st) {
      _logger.e('resubmitEvidence failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> confirmEvidenceTimeout({required String judgementId}) async {
    try {
      await _client.rpc(
        'confirm_evidence_timeout',
        params: {'p_judgement_id': judgementId},
      );
    } catch (e, st) {
      _logger.e('confirmEvidenceTimeout failed', error: e, stackTrace: st);
      rethrow;
    }
  }
}

@Riverpod(keepAlive: true)
EvidenceRepository evidenceRepository(Ref ref) {
  return EvidenceRepository(
    Supabase.instance.client,
    ref.watch(loggerProvider),
  );
}
