package dev.cloveclove.peppercheck.data.referee_request

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class TaskRefereeRequestCreateRequest(
    @SerialName("task_id")
    val taskId: String,
    @SerialName("matching_strategy")
    val matchingStrategy: String,
    @SerialName("preferred_referee_id")
    val preferredRefereeId: String? = null,
    val status: String = "pending"
)