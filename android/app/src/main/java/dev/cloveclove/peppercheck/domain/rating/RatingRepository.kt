package dev.cloveclove.peppercheck.domain.rating

import dev.cloveclove.peppercheck.data.rating.RatingHistory

interface RatingRepository {
    /**
     * 評価をrating_historiesテーブルに追加する
     */
    suspend fun addRatingHistory(
        taskId: String,
        judgementId: String,
        rateeUserId: String, // 評価される人
        ratingType: String, // "tasker" または "referee"
        rating: Int,
        comment: String?
    ): Result<Unit>

    /**
     * 特定のタスクについて、Taskerが付けた評価（= Refereeへの評価）のリストを取得する
     */
    suspend fun getRatingsByTaskerForTask(taskId: String): Result<List<RatingHistory>>
}