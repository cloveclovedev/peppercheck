package dev.cloveclove.peppercheck.data.evidence

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class TaskEvidenceAssetCreateRequest(
    @SerialName("evidence_id")
    val evidenceId: String,
    @SerialName("file_url")
    val fileUrl: String,
    @SerialName("file_size_bytes")
    val fileSizeBytes: Long? = null,
    @SerialName("content_type")
    val contentType: String? = null,
    @SerialName("public_url")
    val publicUrl: String? = null,
    @SerialName("processing_status")
    val processingStatus: String = "ready"
)