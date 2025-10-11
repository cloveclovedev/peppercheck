package dev.cloveclove.peppercheck.domain.task

import dev.cloveclove.peppercheck.repository.JudgementRepository

class UpdateJudgementUseCase(
    private val judgementRepository: JudgementRepository
) {
    suspend operator fun invoke(params: UpdateJudgementParams): Result<Unit> {
        return judgementRepository.updateJudgement(
            judgementId = params.judgementId,
            status = params.status,
            comment = params.comment
        )
    }
}