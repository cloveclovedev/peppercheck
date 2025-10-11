package dev.cloveclove.peppercheck.data.evidence

import kotlinx.serialization.Serializable

@Serializable
data class TaskEvidenceUpdateRequest(
    val description: String? = null,
    val status: String? = null
)