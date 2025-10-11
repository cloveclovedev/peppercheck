package dev.cloveclove.peppercheck.data.rating

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class RatingHistory(
    val id: String,
    @SerialName("rater_id")
    val raterId: String,
    @SerialName("ratee_id")
    val rateeId: String,
    @SerialName("task_id")
    val taskId: String,
    @SerialName("judgement_id")
    val judgementId: String?,
    @SerialName("rating_type")
    val ratingType: String,
    val rating: Int,
    val comment: String?,
    @SerialName("created_at")
    val createdAt: String
)