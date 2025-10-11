package dev.cloveclove.peppercheck.data.evidence

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class TaskEvidence(
    val id: String,
    @SerialName("task_id") 
    val taskId: String,
    val description: String,
    val status: String, // pending_upload, ready
    @SerialName("created_at") 
    val createdAt: String,
    @SerialName("updated_at") 
    val updatedAt: String,
    @SerialName("task_evidence_assets") 
    val taskEvidenceAssets: List<TaskEvidenceAsset> = emptyList()
)

@Serializable
data class TaskEvidenceAsset(
    val id: String,
    @SerialName("evidence_id") 
    val evidenceId: String,
    @SerialName("file_url") 
    val fileUrl: String,
    @SerialName("file_size_bytes") 
    val fileSizeBytes: Long? = null,
    @SerialName("content_type") 
    val contentType: String? = null,
    @SerialName("created_at") 
    val createdAt: String,
    @SerialName("public_url") 
    val publicUrl: String? = null,
    @SerialName("processing_status") 
    val processingStatus: String? = null,
    @SerialName("error_message") 
    val errorMessage: String? = null
)

