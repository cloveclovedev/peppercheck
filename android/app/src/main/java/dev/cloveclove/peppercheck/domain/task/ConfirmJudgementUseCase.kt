package dev.cloveclove.peppercheck.domain.task

import dev.cloveclove.peppercheck.repository.JudgementRepository

data class ConfirmJudgementParams(
    val taskId: String,
    val judgementId: String,
    val rateeId: String, // 評価されるRefereeのID
    val rating: Int,
    val comment: String?
)

class ConfirmJudgementUseCase(
    private val judgementRepository: JudgementRepository
) {
    suspend operator fun invoke(params: ConfirmJudgementParams): Result<Unit> {
        return judgementRepository.confirmJudgementAndRateReferee(
            taskId = params.taskId,
            judgementId = params.judgementId,
            rateeId = params.rateeId,
            rating = params.rating,
            comment = params.comment
        )
    }
}