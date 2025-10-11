package dev.cloveclove.peppercheck.data.rating

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class RatingHistoryCreateRequest(
    @SerialName("ratee_id")
    val rateeId: String, // 評価される人
    @SerialName("task_id")
    val taskId: String,
    @SerialName("judgement_id")
    val judgementId: String,
    @SerialName("rating_type")
    val ratingType: String, // "tasker" または "referee"
    val rating: Int,
    val comment: String?
    // rater_idはDB側のトリガーで自動設定されるため不要
)