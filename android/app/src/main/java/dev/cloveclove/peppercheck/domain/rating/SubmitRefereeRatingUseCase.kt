package dev.cloveclove.peppercheck.domain.rating

data class SubmitRefereeRatingParams(
    val taskId: String,
    val refereeId: String, // 評価されるRefereeのID
    val judgementId: String, // どの判定に対する評価か
    val rating: Int,
    val comment: String?
)

class SubmitRefereeRatingUseCase(
    private val ratingRepository: RatingRepository
) {
    suspend operator fun invoke(params: SubmitRefereeRatingParams): Result<Unit> {
        return ratingRepository.addRatingHistory(
            taskId = params.taskId,
            judgementId = params.judgementId,
            rateeUserId = params.refereeId,
            ratingType = "referee",
            rating = params.rating,
            comment = params.comment
        )
    }
}