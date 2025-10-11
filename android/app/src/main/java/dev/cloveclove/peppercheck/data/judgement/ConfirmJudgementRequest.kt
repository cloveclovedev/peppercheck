package dev.cloveclove.peppercheck.data.judgement

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class ConfirmJudgementRequest(
    @SerialName("p_task_id")
    val taskId: String,

    @SerialName("p_judgement_id")
    val judgementId: String,

    @SerialName("p_ratee_id")
    val rateeId: String,

    @SerialName("p_rating")
    val rating: Int,

    @SerialName("p_comment")
    val comment: String?
)