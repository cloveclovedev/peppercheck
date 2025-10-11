package dev.cloveclove.peppercheck.data.referee_request

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class TaskRefereeRequest(
    val id: String,
    @SerialName("task_id") 
    val taskId: String,
    @SerialName("matching_strategy") 
    val matchingStrategy: String,
    @SerialName("preferred_referee_id") 
    val preferredRefereeId: String? = null,
    val status: String,
    @SerialName("matched_referee_id") 
    val matchedRefereeId: String? = null,
    @SerialName("responded_at") 
    val respondedAt: String? = null,
    @SerialName("created_at") 
    val createdAt: String,
    @SerialName("updated_at") 
    val updatedAt: String? = null
)

