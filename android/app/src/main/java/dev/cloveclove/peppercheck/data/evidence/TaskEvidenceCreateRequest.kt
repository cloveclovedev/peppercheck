package dev.cloveclove.peppercheck.data.evidence

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class TaskEvidenceCreateRequest(
    @SerialName("task_id")
    val taskId: String,
    val description: String,
    val status: String = "pending_upload"
)