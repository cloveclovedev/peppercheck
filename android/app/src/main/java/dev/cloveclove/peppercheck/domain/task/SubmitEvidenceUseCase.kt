package dev.cloveclove.peppercheck.domain.task

import dev.cloveclove.peppercheck.repository.R2FileUploadRepository
import dev.cloveclove.peppercheck.repository.TaskEvidenceRepository
import dev.cloveclove.peppercheck.repository.TaskRepository
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope

class SubmitEvidenceUseCase(
    private val taskEvidenceRepository: TaskEvidenceRepository,
    private val r2FileUploadRepository: R2FileUploadRepository,
    private val taskRepository: TaskRepository
) {
    suspend operator fun invoke(params: SubmitEvidenceParams): Result<Unit> {
        return runCatching {
            // 1. エビデンスレコードの更新または作成
            val evidence = if (params.evidenceId != null) {
                // 更新の場合
                taskEvidenceRepository.updateTaskEvidence(params.evidenceId, params.description).getOrThrow()
            } else {
                // 新規作成の場合
                taskEvidenceRepository.createTaskEvidence(params.taskId, params.description, "pending_upload").getOrThrow()
            }

            // coroutineScopeを使うと、中の処理がすべて完了するまで待ってくれる
            coroutineScope {
                // 2. 削除対象のアセットを並行して削除
                val deleteJobs = params.assetIdsToDelete.map { assetId ->
                    async {
                        // TODO: R2FileUploadRepositoryにファイル削除ロジックを追加する必要がある
                        // val asset = taskEvidenceRepository.getAssetById(assetId).getOrNull()
                        // asset?.fileUrl?.let { r2FileUploadRepository.deleteFile(it) }
                        
                        taskEvidenceRepository.deleteTaskEvidenceAsset(assetId).getOrThrow()
                    }
                }

                // 3. 新規追加の画像を並行してアップロード
                val uploadJobs = params.newImageUris.map { uri ->
                    async {
                        val uploadResult = r2FileUploadRepository.uploadFile(params.taskId, uri, "evidence").getOrThrow()
                        val contentType = r2FileUploadRepository.getContentType(uri).getOrNull()
                        val fileSize = r2FileUploadRepository.getFileSize(uri).getOrNull()

                        taskEvidenceRepository.createTaskEvidenceAsset(
                            evidenceId = evidence.id,
                            fileUrl = uploadResult.r2Key,
                            fileSizeBytes = fileSize,
                            contentType = contentType,
                            publicUrl = uploadResult.publicUrl
                        ).getOrThrow()
                    }
                }
                
                // すべての削除・追加処理が終わるのを待つ
                (deleteJobs + uploadJobs).forEach { it.await() }
            }

            // 4. エビデンスとタスクのステータスを最終更新
            taskEvidenceRepository.updateTaskEvidence(evidence.id, status = "ready").getOrThrow()
            val currentTask = taskRepository.getTaskById(params.taskId).getOrThrow()
            if (currentTask.status == "open") {
                taskRepository.updateTask(taskId = params.taskId, status = "judging").getOrThrow()
            }
        }
    }
}