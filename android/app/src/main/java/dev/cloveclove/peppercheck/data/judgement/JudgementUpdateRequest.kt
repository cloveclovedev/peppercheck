package dev.cloveclove.peppercheck.data.judgement

import kotlinx.serialization.Serializable

@Serializable
data class JudgementUpdateRequest(
    val status: String? = null,
    val comment: String? = null
)